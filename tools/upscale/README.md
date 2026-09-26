# Local 2× enhancement for the iOS reader

The original Real-CUGAN option bundles two Core ML models, `RealCUGAN2x_conservative` and `RealCUGAN2x_denoise1x`. The default is conservative restoration. No model download or server request is needed at runtime. The app retains its original image whenever probing, prediction, output validation or disk access fails.

## Reproduce the conversion

Use Python 3.12 and `pip install -r tools/upscale/requirements.txt` in a virtual environment. Download [updated_weights.zip from bilibili's official release](https://github.com/bilibili/ailab/releases/download/Real-CUGAN/updated_weights.zip). Extract `up2x-latest-conservative.pth` and `up2x-latest-denoise1x.pth`, renaming them to `conservative.pth` and `denoise1x.pth` in a scratch directory. Run:

```
python tools/upscale/convert.py --weights /path/to/scratch --output ios/Runner/Models
```

The script checks SHA-256 before loading tensors with `weights_only=True`. The same hashes were independently checked against the upstream-linked Hugging Face mirror. The vendored architecture is from bilibili/ailab's Real-CUGAN; its MIT license is included. Negative padding is exported as equivalent cropping. Input is fixed RGB 512×512, normalized to 0–1; output is RGB 1024×1024 in 0–255. Weights and most operations use fp16; spatial mean reductions retain fp32. Models require iOS 16; iOS 15.6 displays original images.

## Runtime

`Upscaler` registers `eros_fe/upscale` (`probe`, `upscale`, `cancel`). All image exchange uses file paths. `UpscaleEngine` uses `.all`, reuses at most two exclusive model instances, and checks cancellation between tiles and before output publication. Tiles overlap by 32 source pixels with complementary feather weights. One horizontal strip accumulates float samples; completed rows become RGBA8. Output is JPEG quality 0.95. Metadata probing applies EXIF orientation without decoding the page. Animations and GIFs are skipped.

The reader uses its existing preload setting for current visible pages plus the forward preload window. Leaving the window cancels queued/running work. One ImageProvider decorator handles local/archive files and network disk-cache files. The original appears immediately on a cold page; completion evicts its image key and rebuilds only that page. Persistent results live under Application Support/upscale. The key hashes the first 64 KiB plus an 8-byte big-endian file length, with model revision, scale and denoise appended. Access timestamps implement disk LRU; the default budget is 4 GiB. Settings use the existing profile/Rx persistence.

## Quality limitation found during validation

A synthetic periodic halftone page exposed colour hallucination in the original conservative model and significant fp16 device-dependent error. Do not claim this model preserves every manga screen tone. The engine checks excessive chroma changes in neutral input regions and disagreement across overlaps. A rejected output is never published; a small content-addressed rejection marker prevents repeated inference. The original remains visible. `Always` bypasses the height/ratio rules only; animation, memory and output-quality checks still apply. The quality check is a heuristic, not a guarantee for every page.

Three upstream demonstration crops (fine line illustration, hair texture, compressed cartoon) passed visual inspection. Their source sizes include thumbnail dimensions; the native harness intentionally bypasses reader eligibility to stress model output. A fourth synthetic line/text/halftone page was rejected, as intended. These are public fixtures, not the user's gallery pages. The UI exposes conservative and light denoising so a user can compare them on real pages.

## Validation commands

The same Swift engine can run on a Mac without Flutter:

```
xcrun coremlcompiler compile ios/Runner/Models/RealCUGAN2x_conservative.mlpackage /path/to/compiled
xcrun coremlcompiler compile ios/Runner/Models/RealCUGAN2x_denoise1x.mlpackage /path/to/compiled
xcrun swiftc -O ios/Runner/MetalFXUpscaleTile.swift ios/Runner/UpscaleEngine.swift tools/upscale/check_engine.swift -o /path/to/check-engine
/path/to/check-engine /path/to/compiled /path/to/source.png /path/to/output.jpg 0
```

Append `reject` for a fixture expected to trip the quality guard. The harness also checks 2× dimensions, cancellation and complementary seam weights. `stress_engine.swift` runs 50 predictions with two workers and logs resident memory. Its repeated source exercises allocations, not the complete Flutter reader or Instruments.

On Apple M4 Pro, the Core ML compute plan assigns 47 operations to ANE, 42 to GPU and 2 to CPU; estimated costs are 78.1%, 21.7% and 0.2%. These are the local compiler's estimates, not an iPad measurement. A 50-job, 1200×1600 source run finished in 27.78s, with peak RSS 362.7 MiB and peak system footprint 1.45 GiB. RSS stabilized around 330–345 MiB; graph/model reuse reduced allocation pressure. The user’s iPad still needs main-flow checks, 20 actual low-resolution pages, high-resolution/ratio skips, 400% seam inspection, cache re-entry, and a 50-page Instruments run.

## Additional algorithms and adjustable strength

The reader now includes four selectable algorithms, all at 2×:

- Real-CUGAN: existing conservative / light denoising weights.
- waifu2x CUnet: official scale-only / noise1+scale2x weights from [nunif's 2022-11-09 release](https://github.com/nagadomi/nunif/releases/download/0.0.0/waifu2x_pretrained_models_20221109.tar.gz). Architecture is pinned to `nagadomi/nunif@d23721f1b5f0a4c92c3ee1be013180bf298730c5`. Preserve the checkpoint's `no_clip` constructor default; do not substitute the newer training default. Inference-only U-Nets and MIT license are vendored.
- Real-ESRGAN Anime: official [RealESRGANv2-animevideo-xsx2.pth](https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.3.0/RealESRGANv2-animevideo-xsx2.pth), the compact native 2× AnimeVideo model. This is not x4plus_anime_6B. SRVGG architecture is pinned to `xinntao/Real-ESRGAN@a4abfb2979a7bbff3f69f58f58ae324608821e27`; BSD-3-Clause license is included. Reflect padding supplies the 18-convolution receptive field before cropping back to the 1024 output.
- MetalFX: Apple's `MTLFXSpatialScaler` in perceptual colour mode on BGRA8 textures. This is spatial scaling, without a neural restoration model or temporal frame history. Runtime capabilities query `supportsDevice`; unsupported hardware retains the original and displays the reason, without substituting a different algorithm. Output textures use private storage and GPU blit readback. Apple's iOS Simulator SDK does not include MetalFX; the simulator build explicitly reports it unsupported, while device builds use the real framework.

To reproduce the three additional Core ML packages, extract the two selected nunif checkpoints to `waifu-scale2x.pth` and `waifu-noise1_scale2x.pth` beside the Real-ESRGAN checkpoint, then run:

```
python tools/upscale/convert_extra.py --weights /path/to/scratch --output ios/Runner/Models
```

The script records and checks all SHA-256 values, loads only tensors, and uses the same image ranges and precision policy as the original conversion. All model licenses are also included in the app's About → Licenses screen.

Processing strength is separate from denoising. `0%` bypasses processing and displays the original. `1–100%` blends the selected algorithm's full output with a continuous Lanczos 2× baseline in sRGB, after raw colour/seam validation. It changes the actual cached pixels, not only the UI label, and does not reduce inference cost. The UI commits the slider on release. Cache revision `r2` includes algorithm, effective denoise and strength; changing settings cancels pending jobs and invalidates image keys. Fixed-denoise algorithms normalize the denoise argument to zero.

The reader page counter distinguishes waiting, queued, processing, cached-ready, decoded enhanced, and original. Tap it to see the selected algorithm, strength, source/output dimensions and skip/failure reason. Only a decoded enhanced provider marks a page enhanced; a finished native job alone does not. Status storage is limited to the active reading/preload window.

Native validation on Apple M4 Pro used a synthetic 730×790 line/text/shading fixture spanning four tiles. All six algorithm/denoise combinations produced 1460×1580 images at 25% and 100%, with changed output pixels and working cancellation. MetalFX was supported and completed the warm 100% case in approximately 0.05s; this is a Mac fixture measurement, not an iPad performance claim. The three converted packages differed from their PyTorch references by mean absolute error 0.095–0.162 on an 8-bit scale for one 512×512 crop. These fixtures do not establish quality for all manga textures.

```
xcrun swiftc -O ios/Runner/MetalFXUpscaleTile.swift ios/Runner/UpscaleEngine.swift tools/upscale/check_algorithms.swift -o /path/to/check-algorithms
/path/to/check-algorithms /path/to/compiled /path/to/source.png /path/to/output-directory
```

When building any older native harness, also include `ios/Runner/MetalFXUpscaleTile.swift` in its `swiftc` inputs.
