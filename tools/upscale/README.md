# Real-CUGAN 2× for the iOS reader

The app bundles two real Core ML models, `RealCUGAN2x_conservative` and `RealCUGAN2x_denoise1x`. The default is conservative restoration. No model download or server request is needed at runtime. The app retains its original image whenever probing, prediction, output validation or disk access fails.

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
xcrun swiftc -O ios/Runner/UpscaleEngine.swift tools/upscale/check_engine.swift -o /path/to/check-engine
/path/to/check-engine /path/to/compiled /path/to/source.png /path/to/output.jpg 0
```

Append `reject` for a fixture expected to trip the quality guard. The harness also checks 2× dimensions, cancellation and complementary seam weights. `stress_engine.swift` runs 50 predictions with two workers and logs resident memory. Its repeated source exercises allocations, not the complete Flutter reader or Instruments.

On Apple M4 Pro, the Core ML compute plan assigns 47 operations to ANE, 42 to GPU and 2 to CPU; estimated costs are 78.1%, 21.7% and 0.2%. These are the local compiler's estimates, not an iPad measurement. A 50-job, 1200×1600 source run finished in 27.78s, with peak RSS 362.7 MiB and peak system footprint 1.45 GiB. RSS stabilized around 330–345 MiB; graph/model reuse reduced allocation pressure. The user’s iPad still needs main-flow checks, 20 actual low-resolution pages, high-resolution/ratio skips, 400% seam inspection, cache re-entry, and a 50-page Instruments run.
