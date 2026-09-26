import Foundation
import CoreGraphics
import ImageIO

@main
struct CheckAlgorithms {
    static func rgb(_ path: String) throws -> [UInt8] {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw UpscaleFailure.invalidImage }
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let ctx = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    static func main() throws {
        let args = CommandLine.arguments
        precondition(args.count == 4, "Usage: check_algorithms MODELS SOURCE OUTPUT_DIRECTORY")
        let engine = UpscaleEngine(modelDirectory: URL(fileURLWithPath: args[1]))
        let source = try UpscaleEngine.probe(args[2])
        var algorithms = [("real-cugan-v1", 0), ("real-cugan-v1", 1),
                          ("waifu2x-cunet-v1", 0), ("waifu2x-cunet-v1", 1), ("realesrgan-anime-v1", 0)]
        print("MetalFX supported: \(MetalFXUpscaleTile.supported)")
        if MetalFXUpscaleTile.supported { algorithms.append(("metalfx-spatial-v1", 0)) }
        for (model, denoise) in algorithms {
            try autoreleasepool {
                var outputs: [[UInt8]] = []
                for strength in [25, 100] {
                    let output = "\(args[3])/\(model)-d\(denoise)-s\(strength).jpg"
                    let began = Date()
                    try engine.upscale(path: args[2], output: output, modelName: model, scale: 2,
                        denoise: denoise, strength: strength, cancellation: UpscaleCancellation())
                    let info = try UpscaleEngine.probe(output)
                    precondition(info.width == source.width * 2 && info.height == source.height * 2)
                    outputs.append(try rgb(output))
                    print("\(model) d\(denoise) \(strength)%: \(info.width)x\(info.height) \(Date().timeIntervalSince(began))s")
                }
                let changed = zip(outputs[0], outputs[1]).filter { abs(Int($0) - Int($1)) > 2 }.count
                precondition(changed > 100, "Strength must visibly change pixels")
                print("strength changed >2 levels in \(changed) channels")
                let cancel = UpscaleCancellation(); cancel.cancel()
                do {
                    try engine.upscale(path: args[2], output: args[3] + "/cancelled.jpg", modelName: model,
                        scale: 2, denoise: denoise, cancellation: cancel)
                    fatalError("Cancellation must throw")
                } catch UpscaleFailure.cancelled {}
            }
        }
        do {
            try engine.upscale(path: args[2], output: args[3] + "/invalid.jpg", modelName: "unknown",
                scale: 2, denoise: 0, cancellation: UpscaleCancellation())
            fatalError("Unknown algorithms must not silently fall back")
        } catch UpscaleFailure.invalidModel {}
        print("All algorithm, strength, dimension and cancellation checks passed")
    }
}
