import UIKit
import Flutter
import flutter_downloader

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        let registry = engineBridge.pluginRegistry
        GeneratedPluginRegistrant.register(with: registry)
        if let registrar = registry.registrar(forPlugin: "Upscaler") {
            Upscaler.register(with: registrar)
        }
        if let registrar = registry.registrar(forPlugin: "NativeGlassPlugin") {
            NativeGlassPlugin.register(with: registrar)
        }
    }
}

private func registerPlugins(registry: FlutterPluginRegistry) {
    if !registry.hasPlugin("FlutterDownloaderPlugin"),
       let registrar = registry.registrar(forPlugin: "FlutterDownloaderPlugin") {
        FlutterDownloaderPlugin.register(with: registrar)
    }
}
