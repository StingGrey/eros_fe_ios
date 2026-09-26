import Flutter
import Foundation
import UIKit

final class Upscaler: NSObject, FlutterPlugin {
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "eros_fe.upscale"
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .userInitiated
        return queue
    }()
    // Accessed only on the platform thread. Tokens themselves are thread-safe.
    private var tasks: [String: UpscaleCancellation] = [:]
    private let engine = UpscaleEngine(modelDirectory: Bundle.main.resourceURL!)

    private var memoryObserver: NSObjectProtocol?
    override init() {
        super.init()
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: nil) { [weak self] _ in
                DispatchQueue.global(qos: .utility).async { self?.engine.purgeIdleModels() }
            }
    }
    deinit { if let observer = memoryObserver { NotificationCenter.default.removeObserver(observer) } }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "eros_fe/upscale", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(Upscaler(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        if call.method == "capabilities" {
            DispatchQueue.global(qos: .utility).async {
                var models: [String] = []
                if #available(iOS 16.0, *) {
                    models = ["real-cugan-v1", "waifu2x-cunet-v1", "realesrgan-anime-v1"]
                    if MetalFXUpscaleTile.supported { models.append("metalfx-spatial-v1") }
                }
                let supported = models
                DispatchQueue.main.async { result(["models": supported]) }
            }
            return
        }
        if call.method == "cancel", let id = args["taskId"] as? String {
            tasks[id]?.cancel(); result(nil); return
        }
        guard let path = args["path"] as? String else {
            result(FlutterError(code: "arguments", message: "A local source path is required.", details: nil)); return
        }
        if call.method == "probe" {
            DispatchQueue.global(qos: .utility).async {
                do {
                    let info = try UpscaleEngine.probe(path)
                    DispatchQueue.main.async { result(info.dictionary) }
                } catch { Self.finish(error, result) }
            }
            return
        }
        guard call.method == "upscale" else { result(FlutterMethodNotImplemented); return }
        guard let id = args["taskId"] as? String, let output = args["output"] as? String,
              let model = args["model"] as? String, let scale = args["scale"] as? Int,
              let denoise = args["denoise"] as? Int, let strength = args["strength"] as? Int, tasks[id] == nil else {
            result(FlutterError(code: "arguments", message: "Invalid upscale request.", details: nil)); return
        }
        let cancellation = UpscaleCancellation(); tasks[id] = cancellation
        queue.addOperation { [self] in
            do {
                try autoreleasepool {
                guard #available(iOS 16.0, *) else { throw UpscaleFailure.missingModel }
                try engine.upscale(path: path, output: output, modelName: model, scale: scale,
                                   denoise: denoise, strength: strength, cancellation: cancellation)
                }
                DispatchQueue.main.async { self.tasks.removeValue(forKey: id); result(output) }
            } catch {
                try? FileManager.default.removeItem(atPath: output)
                DispatchQueue.main.async {
                    self.tasks.removeValue(forKey: id)
                    let failure = error as? UpscaleFailure
                    let code = failure == .cancelled ? "cancelled" : (failure == .unstableOutput ? "quality" : (failure == .unsupported ? "unsupported" : "upscale"))
                    result(FlutterError(code: code,
                                        message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    private static func finish(_ error: Error, _ result: @escaping FlutterResult) {
        DispatchQueue.main.async { result(FlutterError(code: "probe", message: error.localizedDescription, details: nil)) }
    }
}
