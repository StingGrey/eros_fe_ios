import Foundation
import Metal
import CoreVideo

#if canImport(MetalFX) && !targetEnvironment(simulator)
import MetalFX

/// One scaler and texture set per job; all pixels stay on this device.
@available(iOS 16.0, macOS 13.0, *)
final class MetalFXUpscaleTile {
    static var supported: Bool {
        guard let device = MTLCreateSystemDefaultDevice() else { return false }
        return MTLFXSpatialScalerDescriptor.supportsDevice(device)
    }

    private let queue: MTLCommandQueue
    private let scaler: MTLFXSpatialScaler
    private let input: MTLTexture
    private let output: MTLTexture
    private let readback: MTLBuffer
    private let size: Int

    init(size: Int) throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              MTLFXSpatialScalerDescriptor.supportsDevice(device),
              let queue = device.makeCommandQueue() else { throw UpscaleFailure.unsupported }
        let descriptor = MTLFXSpatialScalerDescriptor()
        descriptor.inputWidth = size; descriptor.inputHeight = size
        descriptor.outputWidth = size * 2; descriptor.outputHeight = size * 2
        descriptor.colorTextureFormat = .bgra8Unorm
        descriptor.outputTextureFormat = .bgra8Unorm
        descriptor.colorProcessingMode = .perceptual
        guard let scaler = descriptor.makeSpatialScaler(device: device) else { throw UpscaleFailure.unsupported }
        let source = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: size, height: size, mipmapped: false)
        source.storageMode = .shared; source.usage = scaler.colorTextureUsage
        let destination = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
            width: size * 2, height: size * 2, mipmapped: false)
        // MetalFX requires private output. Read back only after a GPU blit.
        destination.storageMode = .private; destination.usage = scaler.outputTextureUsage
        guard let input = device.makeTexture(descriptor: source),
              let output = device.makeTexture(descriptor: destination),
              let readback = device.makeBuffer(length: size * size * 16, options: .storageModeShared)
        else { throw UpscaleFailure.memoryLimit }
        self.queue = queue; self.scaler = scaler; self.input = input
        self.output = output; self.readback = readback; self.size = size
        scaler.inputContentWidth = size; scaler.inputContentHeight = size
        scaler.colorTexture = input; scaler.outputTexture = output
    }

    func predict(_ buffer: CVPixelBuffer, cancellation: UpscaleCancellation) throws -> CVPixelBuffer {
        try cancellation.check()
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let bytes = CVPixelBufferGetBaseAddress(buffer),
              let command = queue.makeCommandBuffer() else { throw UpscaleFailure.invalidImage }
        input.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0,
            withBytes: bytes, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer))
        scaler.encode(commandBuffer: command)
        guard let blit = command.makeBlitCommandEncoder() else { throw UpscaleFailure.invalidImage }
        let width = size * 2, pitch = width * 4
        blit.copy(from: output, sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: width, depth: 1),
            to: readback, destinationOffset: 0, destinationBytesPerRow: pitch, destinationBytesPerImage: pitch * width)
        blit.endEncoding(); command.commit(); command.waitUntilCompleted()
        try cancellation.check()
        if let error = command.error { throw error }
        guard command.status == .completed else { throw UpscaleFailure.invalidImage }
        var result: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, width, kCVPixelFormatType_32BGRA,
            nil, &result) == kCVReturnSuccess, let result else { throw UpscaleFailure.memoryLimit }
        CVPixelBufferLockBaseAddress(result, [])
        defer { CVPixelBufferUnlockBaseAddress(result, []) }
        guard let target = CVPixelBufferGetBaseAddress(result) else { throw UpscaleFailure.invalidImage }
        for row in 0..<width {
            memcpy(target.advanced(by: row * CVPixelBufferGetBytesPerRow(result)),
                   readback.contents().advanced(by: row * pitch), pitch)
        }
        return result
    }
}
#else
/// MetalFX is absent from the iOS Simulator SDK. Expose that limitation through
/// capabilities; never disguise a different scaler as MetalFX in Simulator.
@available(iOS 16.0, macOS 13.0, *)
final class MetalFXUpscaleTile {
    static var supported: Bool { false }
    init(size: Int) throws { throw UpscaleFailure.unsupported }
    func predict(_ buffer: CVPixelBuffer, cancellation: UpscaleCancellation) throws -> CVPixelBuffer {
        throw UpscaleFailure.unsupported
    }
}
#endif
