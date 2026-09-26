"""Convert official waifu2x CUnet and Real-ESRGAN anime 2x tensor weights.

See README.md for pinned upstream sources. Never load unverified pickle code.
"""
import argparse
import hashlib
from pathlib import Path
import coremltools as ct
import torch
from torch import nn
from torch.nn import functional as F
import convert  # Imports the shared exact negative-pad export transform.
from waifu_cunet import UNet1, UNet2
from srvgg_arch import SRVGGNetCompact

WEIGHTS = {
    'Waifu2xCUNet2x_scale': ('waifu-scale2x.pth', '9003e281ffb626c8f93928fb58a4687293f32e25ebc3eebdb36a38d48348164a'),
    'Waifu2xCUNet2x_noise1': ('waifu-noise1_scale2x.pth', '6ddd721118e669d47e5bcd837be869ce416c8ddf5f8e09fc2860c22b452c0843'),
    'RealESRGANAnime2x': ('RealESRGANv2-animevideo-xsx2.pth', '27985aa2198711ecd72f9bb274ec7b164e018fc9ce2933daaa7c7ab36a2bd3fe'),
}

class FixedWaifu(nn.Module):
    def __init__(self, state):
        super().__init__()
        assert state['name'] == 'waifu2x.upcunet'
        self.unet1 = UNet1(3, 3, deconv=True)
        self.unet2 = UNet2(3, 3, deconv=False)
        self.no_clip = state['kwargs'].get('no_clip', False)
        self.load_state_dict(state['state_dict'], strict=True)

    def forward(self, image):
        z = self.unet1(F.pad(image, (18, 18, 18, 18), mode='reflect'))
        # Preserve the checkpoint's original constructor default, including its
        # intermediate clamp. Newer training defaults must not change old weights.
        if not self.no_clip:
            z = z.clamp(0, 1)
        return ((self.unet2(z) + z[:, :, 20:-20, 20:-20]) * 255).clamp(0, 255)

class FixedESRGAN(nn.Module):
    def __init__(self, state):
        super().__init__()
        self.net = SRVGGNetCompact(upscale=2)
        self.net.load_state_dict(state['params'], strict=True)

    def forward(self, image):
        # Supply the full 18-convolution receptive field at every tile boundary.
        z = self.net(F.pad(image, (18, 18, 18, 18), mode='reflect'))
        return (z[:, :, 36:-36, 36:-36] * 255).clamp(0, 255)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--weights', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(4)
    for name, (filename, checksum) in WEIGHTS.items():
        path = args.weights / filename
        assert hashlib.sha256(path.read_bytes()).hexdigest() == checksum, path
        state = torch.load(path, map_location='cpu', weights_only=True)
        waifu = name.startswith('Waifu')
        net = (FixedWaifu(state) if waifu else FixedESRGAN(state)).eval()
        sample = torch.zeros(1, 3, 512, 512)
        with torch.inference_mode():
            traced = torch.jit.trace(net, sample)
            assert traced(sample).shape == (1, 3, 1024, 1024)
        model = ct.convert(traced, convert_to='mlprogram',
            minimum_deployment_target=ct.target.iOS16,
            inputs=[ct.ImageType(name='image', shape=sample.shape, scale=1/255.0,
                color_layout=ct.colorlayout.RGB)],
            outputs=[ct.ImageType(name='upscaled', color_layout=ct.colorlayout.RGB)],
            compute_precision=ct.transform.FP16ComputePrecision(
                op_selector=lambda op: op.op_type != 'reduce_mean'),
            compute_units=ct.ComputeUnit.ALL)
        model.author = 'nagadomi / nunif' if waifu else 'Xintao Wang / Real-ESRGAN'
        model.license = 'MIT' if waifu else 'BSD-3-Clause'
        model.short_description = f'{name}; RGB 512 to 1024; fp16; v1'
        model.user_defined_metadata['weights_sha256'] = checksum
        model.save(str(args.output / f'{name}.mlpackage'))
        print(f'Saved {name}', flush=True)
