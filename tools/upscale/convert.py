"""Convert verified Real-CUGAN weights to the app's fixed 512 RGB Core ML model.

Usage: python convert.py --weights /path/to/weights --output ios/Runner/Models
Weights match the official bilibili/ailab updated_weights.zip release.
Only tensor weights are loaded; no downloaded pickle code is executed.
"""
import argparse
import hashlib
from pathlib import Path
import sys
import coremltools as ct
import torch
from torch import nn
from torch.nn import functional as F

sys.path.insert(0, str(Path(__file__).parent / 'vendor'))
from upcunet_v3 import UpCunet2x

# The upstream U-Nets crop with negative F.pad values. Core ML's pad op
# only accepts positive pads, so express those exact crops as tensor slices.
_original_pad = F.pad
def export_pad(x, padding, mode='constant', value=None):
    left, right, top, bottom = padding
    x = x[:, :, max(0, -top):x.shape[2] - max(0, -bottom),
          max(0, -left):x.shape[3] - max(0, -right)]
    positive = tuple(max(0, n) for n in padding)
    if any(positive):
        return _original_pad(x, positive, mode, value)
    return x
F.pad = export_pad

WEIGHTS = {
    'conservative': '6cfe3b23687915d08ba96010f25198d9cfe8a683aa4131f1acf7eaa58ee1de93',
    'denoise1x': '2e783c39da6a6394fbc250fdd069c55eaedc43971c4f2405322f18949ce38573',
}

class FixedCugan(nn.Module):
    def __init__(self, weights):
        super().__init__()
        self.net = UpCunet2x()
        self.net.load_state_dict(torch.load(weights, map_location='cpu', weights_only=True), strict=True)

    def forward(self, image):
        # Exact upstream tile_mode=0 path, preserving float output for Core ML.
        x = self.net.unet1(F.pad(image, (18, 18, 18, 18), mode='reflect'))
        out = self.net.unet2(x) + x[:, :, 20:-20, 20:-20]
        return torch.clamp(out * 255.0, 0.0, 255.0)

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--weights', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(4)
    for name, checksum in WEIGHTS.items():
        path = args.weights / f'{name}.pth'
        assert hashlib.sha256(path.read_bytes()).hexdigest() == checksum, path
        net = FixedCugan(path).eval()
        sample = torch.zeros(1, 3, 512, 512)
        with torch.inference_mode():
            traced = torch.jit.trace(net, sample)
            assert traced(sample).shape == (1, 3, 1024, 1024)
        model = ct.convert(traced, convert_to='mlprogram',
            minimum_deployment_target=ct.target.iOS16,
            inputs=[ct.ImageType(name='image', shape=sample.shape, scale=1/255.0,
                color_layout=ct.colorlayout.RGB)],
            outputs=[ct.ImageType(name='upscaled', color_layout=ct.colorlayout.RGB)],
            # Global mean reductions retain fp32 to avoid fp16 accumulation overflow.
            compute_precision=ct.transform.FP16ComputePrecision(
                op_selector=lambda op: op.op_type != 'reduce_mean'),
            compute_units=ct.ComputeUnit.ALL)
        model.author = 'bilibili / Real-CUGAN; Core ML conversion for eros_fe_ios'
        model.license = 'MIT; see tools/upscale/vendor/LICENSE'
        model.short_description = f'Real-CUGAN 2x {name}; RGB 512 to 1024; fp16; v1'
        model.user_defined_metadata['weights_sha256'] = checksum
        model.save(str(args.output / f'RealCUGAN2x_{name}.mlpackage'))
        print(f'Saved {name}', flush=True)
