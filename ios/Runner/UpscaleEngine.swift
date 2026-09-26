import Foundation
import CoreML
import CoreGraphics
import CoreImage
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

/// No Flutter/UIKit dependency: the exact device engine can be exercised on macOS.
enum UpscaleFailure: LocalizedError {
    case invalidImage, animated, cancelled, missingModel, invalidModel, memoryLimit, encoding, unstableOutput, unsupported
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Cannot read the source image."
        case .animated: return "Animated images are not upscaled."
        case .cancelled: return "Upscaling cancelled."
        case .missingModel: return "The selected bundled model is unavailable."
        case .unsupported: return "This device does not support the selected upscaler."
        case .invalidModel: return "Unsupported model, scale or denoise setting."
        case .memoryLimit: return "Image exceeds the local upscaler's memory budget."
        case .encoding: return "Could not write the enhanced image."
        case .unstableOutput: return "The model changed this page's colours or tile edges excessively. Using the original."
        }
    }
}

final class UpscaleCancellation {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    func check() throws {
        lock.lock(); let cancelled = value; lock.unlock()
        if cancelled { throw UpscaleFailure.cancelled }
    }
}

struct UpscaleProbe {
    let width: Int, height: Int, frames: Int
    let gif: Bool
    var dictionary: [String: Any] { ["width": width, "height": height, "frames": frames, "gif": gif] }
}

final class UpscaleEngine {
    static let tile = 512, overlap = 32, stride = 480
    let modelDirectory: URL
    private final class ModelSlot {
        let name: String
        let model: MLModel
        var inUse = true
        init(name: String, model: MLModel) { self.name = name; self.model = model }
    }
    private let modelLock = NSCondition()
    private var models: [ModelSlot] = []
    init(modelDirectory: URL) { self.modelDirectory = modelDirectory }

    private func acquireModel(_ name: String, cancellation: UpscaleCancellation) throws -> ModelSlot {
        modelLock.lock()
        defer { modelLock.unlock() }
        while models.count == 2 && models.allSatisfy({ $0.inUse }) {
            _ = modelLock.wait(until: Date().addingTimeInterval(0.1))
            try cancellation.check()
        }
        if let slot = models.first(where: { $0.name == name && !$0.inUse }) {
            slot.inUse = true
            return slot
        }
        if models.count == 2, let index = models.firstIndex(where: { !$0.inUse }) {
            models.remove(at: index)
        }
        let compiled = modelDirectory.appendingPathComponent(name + ".mlmodelc")
        guard FileManager.default.fileExists(atPath: compiled.path) else { throw UpscaleFailure.missingModel }
        let config = MLModelConfiguration(); config.computeUnits = .all
        let slot = ModelSlot(name: name, model: try MLModel(contentsOf: compiled, configuration: config))
        models.append(slot)
        return slot
    }

    private func releaseModel(_ slot: ModelSlot) {
        modelLock.lock(); slot.inUse = false; modelLock.signal(); modelLock.unlock()
    }

    func purgeIdleModels() {
        modelLock.lock(); models.removeAll { !$0.inUse }; modelLock.unlock()
    }

    static func probe(_ path: String) throws -> UpscaleProbe {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary),
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = props[kCGImagePropertyPixelWidth] as? Int,
            let height = props[kCGImagePropertyPixelHeight] as? Int else { throw UpscaleFailure.invalidImage }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        return UpscaleProbe(width: orientation >= 5 ? height : width,
                            height: orientation >= 5 ? width : height,
                            frames: CGImageSourceGetCount(source),
                            gif: CGImageSourceGetType(source) as String? == UTType.gif.identifier)
    }

    @available(iOS 16.0, macOS 13.0, *)
    func upscale(path: String, output: String, modelName: String, scale: Int, denoise: Int, strength: Int = 100,
                 cancellation: UpscaleCancellation) throws {
        guard scale == 2, (1...100).contains(strength) else { throw UpscaleFailure.invalidModel }
        let name: String?
        switch (modelName, denoise) {
        case ("real-cugan-v1", 0): name = "RealCUGAN2x_conservative"
        case ("real-cugan-v1", 1): name = "RealCUGAN2x_denoise1x"
        case ("waifu2x-cunet-v1", 0): name = "Waifu2xCUNet2x_scale"
        case ("waifu2x-cunet-v1", 1): name = "Waifu2xCUNet2x_noise1"
        case ("realesrgan-anime-v1", 0): name = "RealESRGANAnime2x"
        case ("metalfx-spatial-v1", 0): name = nil
        default: throw UpscaleFailure.invalidModel
        }
        let info = try Self.probe(path)
        guard info.frames == 1, !info.gif else { throw UpscaleFailure.animated }
        // Even Always mode cannot allocate arbitrarily large decoded images.
        guard info.width > 0, info.height > 0, info.width <= 8192,
              info.width * info.height <= 8_000_000 else { throw UpscaleFailure.memoryLimit }
        try cancellation.check()
        // Reuse at most two model instances; each prediction owns a slot so an
        // MLModel never receives concurrent calls and compiled graphs stay bounded.
        let slot = try name.map { try acquireModel($0, cancellation: cancellation) }
        defer { if let slot { releaseModel(slot) } }
        let metalFX = try name == nil ? MetalFXUpscaleTile(size: Self.tile) : nil
        guard let source = CIImage(contentsOf: URL(fileURLWithPath: path),
                                    options: [.applyOrientationProperty: true]) else { throw UpscaleFailure.invalidImage }
        let image = source.transformed(by: CGAffineTransform(translationX: -source.extent.minX,
                                                             y: -source.extent.minY)).clampedToExtent()
        let color = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CIContext(options: [.cacheIntermediates: false])
        defer { context.clearCaches() }
        let baseline = strength < 100 ? image.applyingFilter("CILanczosScaleTransform",
            parameters: [kCIInputScaleKey: 2.0, kCIInputAspectRatioKey: 1.0]) : nil
        let w = info.width * 2, h = info.height * 2, tileOut = Self.tile * 2
        // Only one horizontal strip accumulates float weights. Completed rows
        // become RGBA8 immediately instead of retaining a full float output page.
        var pixels = [UInt8](repeating: 255, count: w * h * 4)
        var strip = [Float](repeating: 0, count: w * tileOut * 4)
        let xs = Self.origins(info.width), ys = Self.origins(info.height)
        for (rowIndex, y) in ys.enumerated() {
            try cancellation.check()
            for x in xs {
                try cancellation.check()
                try autoreleasepool {
                    let rect = CGRect(x: x, y: info.height - y - Self.tile, width: Self.tile, height: Self.tile)
                    guard let crop = context.createCGImage(image, from: rect, format: .RGBA8, colorSpace: color) else { throw UpscaleFailure.invalidImage }
                    let input = try Self.pixelBuffer(crop)
                    let buffer: CVPixelBuffer
                    if let metalFX {
                        buffer = try metalFX.predict(input, cancellation: cancellation)
                    } else {
                        let features = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: input)])
                        let prediction = try slot!.model.prediction(from: features)
                        guard let predicted = prediction.featureValue(for: "upscaled")?.imageBufferValue
                        else { throw UpscaleFailure.invalidImage }
                        buffer = predicted
                    }
                    try cancellation.check()
                    guard CVPixelBufferGetWidth(buffer) == tileOut,
                          CVPixelBufferGetHeight(buffer) == tileOut,
                          CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA else { throw UpscaleFailure.invalidImage }
                    CVPixelBufferLockBaseAddress(buffer, .readOnly)
                    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
                    guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw UpscaleFailure.invalidImage }
                    let bytes = base.assumingMemoryBound(to: UInt8.self), pitch = CVPixelBufferGetBytesPerRow(buffer)
                    try Self.checkColourStability(input: input, output: bytes, pitch: pitch,
                        width: min(Self.tile, info.width - x), height: min(Self.tile, info.height - y))
                    var overlapError: Float = 0
                    var overlapSamples = 0
                    for ty in 0..<min(tileOut, h - y * 2) {
                        let wy = Self.weight(ty, origin: y, length: info.height)
                        for tx in 0..<min(tileOut, w - x * 2) {
                            let weight = wy * Self.weight(tx, origin: x, length: info.width)
                            let dst = (ty * w + x * 2 + tx) * 4, src = ty * pitch + tx * 4
                            if strip[dst + 3] > 0 {
                                overlapError += abs(strip[dst] / strip[dst + 3] - Float(bytes[src + 2]))
                                    + abs(strip[dst + 1] / strip[dst + 3] - Float(bytes[src + 1]))
                                    + abs(strip[dst + 2] / strip[dst + 3] - Float(bytes[src]))
                                overlapSamples += 3
                            }
                            strip[dst] += Float(bytes[src + 2]) * weight
                            strip[dst + 1] += Float(bytes[src + 1]) * weight
                            strip[dst + 2] += Float(bytes[src]) * weight
                            strip[dst + 3] += weight
                        }
                    }
                    if overlapSamples > 0 && overlapError / Float(overlapSamples) > 12 {
                        throw UpscaleFailure.unstableOutput
                    }
                }
            }
            let rows = rowIndex == ys.count - 1 ? h - y * 2 : Self.stride * 2
            // Blend only after raw model quality checks, using a continuous
            // Lanczos baseline so strength cannot conceal invalid model tiles.
            var basePixels = [UInt8]()
            if let baseline {
                basePixels = [UInt8](repeating: 255, count: w * rows * 4)
                let rect = CGRect(x: 0, y: h - y * 2 - rows, width: w, height: rows)
                guard let crop = context.createCGImage(baseline, from: rect, format: .RGBA8, colorSpace: color)
                else { throw UpscaleFailure.invalidImage }
                try basePixels.withUnsafeMutableBytes { bytes in
                    guard let ctx = CGContext(data: bytes.baseAddress, width: w, height: rows, bitsPerComponent: 8,
                        bytesPerRow: w * 4, space: color,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw UpscaleFailure.memoryLimit }
                    ctx.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: rows))
                }
            }
            let amount = Float(strength) / 100
            for row in 0..<rows {
                for col in 0..<w {
                    let src = (row * w + col) * 4, dst = ((y * 2 + row) * w + col) * 4
                    let weight = max(strip[src + 3], Float.leastNormalMagnitude)
                    for c in 0..<3 {
                        let enhanced = strip[src + c] / weight
                        let value = baseline == nil ? enhanced : enhanced * amount + Float(basePixels[src + c]) * (1 - amount)
                        pixels[dst + c] = UInt8(clamping: Int(value.rounded()))
                    }
                }
            }
            let remaining = tileOut - rows
            if remaining > 0 {
                strip.replaceSubrange(0..<(remaining * w * 4), with: strip[(rows * w * 4)..<(tileOut * w * 4)])
            }
            for index in (max(0, remaining) * w * 4)..<strip.count { strip[index] = 0 }
        }
        try cancellation.check()
        guard let data = CGDataProvider(data: Data(pixels) as CFData),
              let result = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: w * 4, space: color,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                    provider: data, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL,
                    UTType.jpeg.identifier as CFString, 1, nil) else { throw UpscaleFailure.encoding }
        CGImageDestinationAddImage(destination, result, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw UpscaleFailure.encoding }
        try cancellation.check()
    }

    static func origins(_ length: Int) -> [Int] {
        var values = [0]
        while values.last! + tile < length { values.append(values.last! + stride) }
        return values
    }

    static func weight(_ coordinate: Int, origin: Int, length: Int) -> Float {
        let overlapOut = overlap * 2
        if origin > 0 && coordinate < overlapOut { return Float(coordinate + 1) / Float(overlapOut + 1) }
        if origin + tile < length && coordinate >= stride * 2 {
            return Float(tile * 2 - coordinate) / Float(overlapOut + 1)
        }
        return 1
    }

    /// Periodic screen tones can drive this anime model outside its training
    /// distribution. Never cache coloured hallucinations or blend bad seams.
    /// A rejected page continues using its original provider, not interpolation.
    private static func checkColourStability(input: CVPixelBuffer, output: UnsafePointer<UInt8>,
                                             pitch: Int, width: Int, height: Int) throws {
        CVPixelBufferLockBaseAddress(input, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(input, .readOnly) }
        let source = CVPixelBufferGetBaseAddress(input)!.assumingMemoryBound(to: UInt8.self)
        let sourcePitch = CVPixelBufferGetBytesPerRow(input)
        var changed = 0, neutral = 0
        for y in Swift.stride(from: 0, to: height, by: 2) {
            for x in Swift.stride(from: 0, to: width, by: 2) {
                let a = y * sourcePitch + x * 4, b = y * 2 * pitch + x * 2 * 4
                let sourceRange = Int(max(source[a], source[a + 1], source[a + 2]))
                    - Int(min(source[a], source[a + 1], source[a + 2]))
                if sourceRange <= 12 {
                    neutral += 1
                    let resultRange = Int(max(output[b], output[b + 1], output[b + 2]))
                        - Int(min(output[b], output[b + 1], output[b + 2]))
                    if resultRange > 40 { changed += 1 }
                }
            }
        }
        if neutral > 128 && Float(changed) / Float(neutral) > 0.02 {
            throw UpscaleFailure.unstableOutput
        }
    }

    private static func pixelBuffer(_ image: CGImage) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                     kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
        guard CVPixelBufferCreate(kCFAllocatorDefault, tile, tile, kCVPixelFormatType_32BGRA, attrs, &buffer) == kCVReturnSuccess,
              let buffer else { throw UpscaleFailure.invalidImage }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: tile, height: tile,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { throw UpscaleFailure.invalidImage }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: tile, height: tile))
        return buffer
    }
}
