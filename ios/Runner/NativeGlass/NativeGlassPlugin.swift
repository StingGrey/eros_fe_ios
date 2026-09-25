import Flutter
import UIKit

final class NativeGlassPlugin: NSObject, FlutterPlugin, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let views = NSHashTable<GlassHost>.weakObjects()
    private var covered = false
    private var channel: FlutterMethodChannel?

    init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }

    static func register(with registrar: FlutterPluginRegistrar) {
        let plugin = NativeGlassPlugin(messenger: registrar.messenger())
        registrar.register(plugin, withId: "eros_fe/glass_container")
        let channel = FlutterMethodChannel(name: "eros_fe/glass", binaryMessenger: registrar.messenger())
        plugin.channel = channel
        registrar.addMethodCallDelegate(plugin, channel: channel)
    }
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "setCovered", let hidden = call.arguments as? Bool else {
            result(FlutterMethodNotImplemented); return
        }
        covered = hidden
        for view in views.allObjects { view.isHidden = hidden }
        result(nil)
    }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let host = GlassHost(frame: frame, id: viewId, messenger: messenger)
        host.update(args as? [String: Any] ?? [:])
        host.isHidden = covered
        views.add(host)
        return host
    }
}

private final class GlassHost: UIView, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private var group = UIVisualEffectView()
    private var panels: [UIVisualEffectView] = []
    private var buttons: [UIButton] = []
    private var params: [String: Any] = [:]
    private var radius: CGFloat = 26
    private var gap: CGFloat = 8
    private var accessibilityObserver: NSObjectProtocol?

    init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "eros_fe/glass/\(id)", binaryMessenger: messenger)
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(group)
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update" else { result(FlutterMethodNotImplemented); return }
            self?.update(call.arguments as? [String: Any] ?? [:]); result(nil)
        }
        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in guard let self else { return }; self.update(self.params) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    deinit {
        channel.setMethodCallHandler(nil)
        if let observer = accessibilityObserver { NotificationCenter.default.removeObserver(observer) }
    }
    func view() -> UIView { self }

    func update(_ values: [String: Any]) {
        params = values
        radius = CGFloat((values["radius"] as? NSNumber)?.doubleValue ?? 26)
        let spacing = CGFloat((values["spacing"] as? NSNumber)?.doubleValue ?? 12)
        overrideUserInterfaceStyle = (values["dark"] as? Bool ?? false) ? .dark : .light
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        if #available(iOS 26.0, *), !reduceTransparency {
            let effect = UIGlassContainerEffect()
            effect.spacing = spacing
            group.effect = effect
        } else { group.effect = nil }
        for panel in panels { panel.removeFromSuperview() }
        panels.removeAll(); buttons.removeAll()
        let items = values["items"] as? [[String: Any]] ?? []
        isUserInteractionEnabled = !items.isEmpty
        let configurations = items.isEmpty ? [[:]] : items
        for item in configurations {
            let effect: UIVisualEffect?
            if #available(iOS 26.0, *), !reduceTransparency {
                let glass = UIGlassEffect(style: .regular)
                glass.isInteractive = !items.isEmpty
                glass.tintColor = Self.color(values["tint"])
                effect = glass
            } else { effect = reduceTransparency ? nil : UIBlurEffect(style: .systemUltraThinMaterial) }
            let panel = UIVisualEffectView(effect: effect)
            panel.backgroundColor = reduceTransparency ? .secondarySystemGroupedBackground : .clear
            panel.layer.cornerRadius = radius
            panel.layer.cornerCurve = .continuous
            panel.clipsToBounds = true
            group.contentView.addSubview(panel); panels.append(panel)
            guard let id = item["id"] as? String else { continue }
            let button = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: item["symbol"] as? String ?? "circle")
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            if values["showLabels"] as? Bool == true {
                config.title = item["label"] as? String
                config.imagePlacement = .top
                config.imagePadding = 3
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var out = incoming; out.font = .preferredFont(forTextStyle: .caption2); return out
                }
            }
            config.baseForegroundColor = item["selected"] as? Bool == true ? .systemBlue : .label
            button.configuration = config
            button.isEnabled = item["enabled"] as? Bool ?? true
            button.accessibilityLabel = item["label"] as? String
            button.accessibilityTraits = item["selected"] as? Bool == true ? [.button, .selected] : [.button]
            button.addAction(UIAction { [weak self] _ in self?.channel.invokeMethod("tap", arguments: id) }, for: .touchUpInside)
            panel.contentView.addSubview(button); buttons.append(button)
        }
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        group.frame = bounds
        let count = CGFloat(panels.count)
        guard count > 0 else { return }
        let width = max(0, (bounds.width - gap * (count - 1)) / count)
        for (index, panel) in panels.enumerated() {
            panel.frame = CGRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: bounds.height)
            panel.layer.cornerRadius = min(radius, bounds.height / 2)
            if index < buttons.count { buttons[index].frame = panel.bounds }
        }
    }
    private static func color(_ value: Any?) -> UIColor? {
        guard let argb = (value as? NSNumber)?.uint32Value else { return nil }
        return UIColor(red: CGFloat((argb >> 16) & 255) / 255,
                       green: CGFloat((argb >> 8) & 255) / 255,
                       blue: CGFloat(argb & 255) / 255,
                       alpha: CGFloat((argb >> 24) & 255) / 255)
    }
}
