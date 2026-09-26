import Foundation

@main
struct CheckEngine {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count == 5 || args.count == 6 else {
            print("Usage: check_engine MODELS SOURCE OUTPUT DENOISE"); return
        }
        let engine = UpscaleEngine(modelDirectory: URL(fileURLWithPath: args[1]))
        let info = try UpscaleEngine.probe(args[2])
        let began = Date()
        do {
        try engine.upscale(path: args[2], output: args[3], modelName: "real-cugan-v1",
                           scale: 2, denoise: Int(args[4])!, cancellation: UpscaleCancellation())
        if args.count == 6 { fatalError("Expected the quality guard to reject this fixture") }
        } catch UpscaleFailure.unstableOutput {
            guard args.count == 6 else { throw UpscaleFailure.unstableOutput }
            print("Quality guard rejected unstable fixture: \(args[2])")
            return
        }
        let result = try UpscaleEngine.probe(args[3])
        precondition(result.width == info.width * 2 && result.height == info.height * 2)
        let cancellation = UpscaleCancellation(); cancellation.cancel()
        do {
            try engine.upscale(path: args[2], output: args[3] + ".cancelled", modelName: "real-cugan-v1",
                               scale: 2, denoise: 0, cancellation: cancellation)
            fatalError("Cancellation should throw")
        } catch UpscaleFailure.cancelled { }
        // At each seam the left/right feather weights add to exactly one.
        for pixel in 0..<64 {
            let total = UpscaleEngine.weight(960 + pixel, origin: 0, length: 1000)
                + UpscaleEngine.weight(pixel, origin: 480, length: 1000)
            precondition(abs(total - 1) < 0.00001)
        }
        print("\(args[2]): \(info.width)x\(info.height) -> \(result.width)x\(result.height); \(Date().timeIntervalSince(began))s; cancellation/feather checks passed")
    }
}
