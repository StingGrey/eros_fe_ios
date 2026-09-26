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

/// One glass surface per functional group. Buttons share its material, rather
/// than each producing a separate lens. UIKit owns the material and interaction.
private final class GlassHost: UIView, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private let surface = UIVisualEffectView()
    private let scroll = UIScrollView()
    private let selection = UIView()
    private var buttons: [UIButton] = []
    private var params: [String: Any] = [:]
    private var items: [[String: Any]] = []
    private var observer: NSObjectProtocol?
    private var selectedIndex: Int?
    private var style = "toolbar"
    private var vertical = false
    private var labels = false
    private var radius: CGFloat = 26
    private var accent = UIColor.systemBlue

    init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "eros_fe/glass/\(id)", binaryMessenger: messenger)
        super.init(frame: frame)
        backgroundColor = .clear
        // Do not clip the effect view: doing so cuts off the glass edge/lensing.
        addSubview(surface)
        surface.contentView.addSubview(scroll)
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.addSubview(selection)
        selection.isUserInteractionEnabled = false
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update" else { result(FlutterMethodNotImplemented); return }
            self?.update(call.arguments as? [String: Any] ?? [:]); result(nil)
        }
        observer = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.updateMaterial() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    deinit {
        channel.setMethodCallHandler(nil)
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
    func view() -> UIView { self }

    func update(_ values: [String: Any]) {
        let oldStyle = style
        let oldVertical = vertical
        let oldIDs = items.compactMap { $0["id"] as? String }
        let oldDark = overrideUserInterfaceStyle
        let oldTint = params["tint"] as? NSNumber
        params = values
        items = values["items"] as? [[String: Any]] ?? []
        style = values["style"] as? String ?? "toolbar"
        vertical = values["vertical"] as? Bool ?? false
        labels = values["showLabels"] as? Bool ?? false
        radius = CGFloat((values["radius"] as? NSNumber)?.doubleValue ?? 26)
        accent = Self.color(values["accent"]) ?? .systemBlue
        overrideUserInterfaceStyle = (values["dark"] as? Bool ?? false) ? .dark : .light
        if surface.effect == nil || oldDark != overrideUserInterfaceStyle || oldTint != values["tint"] as? NSNumber {
            updateMaterial()
        }
        isUserInteractionEnabled = !items.isEmpty
        if oldIDs != items.compactMap({ $0["id"] as? String }) || oldStyle != style || oldVertical != vertical {
            buttons.forEach { $0.removeFromSuperview() }
            buttons = items.enumerated().map { index, item in
                let button = UIButton(type: .system)
                button.tag = index
                button.addAction(UIAction { [weak self] _ in self?.tapped(index) }, for: .touchUpInside)
                button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:))))
                scroll.addSubview(button)
                return button
            }
        }
        let oldSelection = selectedIndex
        let previousSelectionFrame = selection.frame
        selectedIndex = items.firstIndex { $0["selected"] as? Bool == true }
        configureButtons()
        setNeedsLayout()
        layoutIfNeeded()
        if oldSelection != nil && oldSelection != selectedIndex {
            selection.frame = previousSelectionFrame
        }
        moveSelection(animated: oldSelection != nil && oldSelection != selectedIndex)
    }

    private func updateMaterial() {
        if #available(iOS 26.0, *), !UIAccessibility.isReduceTransparencyEnabled {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = items.count == 1
            glass.tintColor = Self.color(params["tint"])
            surface.effect = glass
        } else {
            surface.effect = UIAccessibility.isReduceTransparencyEnabled ? nil : UIBlurEffect(style: .systemMaterial)
        }
        surface.backgroundColor = UIAccessibility.isReduceTransparencyEnabled ? .secondarySystemGroupedBackground : .clear
    }

    private func configureButtons() {
        for (index, button) in buttons.enumerated() {
            let item = items[index]
            let selected = item["selected"] as? Bool ?? false
            let prominent = item["prominent"] as? Bool ?? false
            var config = UIButton.Configuration.plain()
            if prominent, #available(iOS 26.0, *) { config = .prominentGlass() }
            let symbol = item["symbol"] as? String ?? ""
            config.image = symbol.isEmpty ? nil : UIImage(systemName: symbol)
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: style == "navigation" ? 21 : 18, weight: selected ? .semibold : .medium)
            if labels || style == "segments" {
                config.title = item["label"] as? String
                config.imagePlacement = vertical ? .leading : (style == "navigation" ? .top : .leading)
                config.imagePadding = vertical ? 12 : 3
                let size: CGFloat = style == "navigation" && !vertical ? 10 : 14
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                    var out = incoming
                    out.font = .systemFont(ofSize: size, weight: selected ? .semibold : .medium)
                    return out
                }
            }
            config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: vertical ? 14 : 8, bottom: 4, trailing: 8)
            config.baseForegroundColor = prominent ? .white : (selected ? accent : .label)
            config.baseBackgroundColor = accent
            config.cornerStyle = .capsule
            button.configuration = config
            button.contentHorizontalAlignment = vertical ? .leading : .center
            button.isEnabled = item["enabled"] as? Bool ?? true
            button.accessibilityLabel = item["label"] as? String
            button.accessibilityIdentifier = "eros.\(style).\(item["id"] as? String ?? "")"
            button.accessibilityTraits = selected ? [.button, .selected] : [.button]
            button.isPointerInteractionEnabled = true
        }
    }

    private func tapped(_ index: Int) {
        guard index < items.count, let id = items[index]["id"] as? String else { return }
        if style == "navigation" || style == "segments" {
            for i in items.indices { items[i]["selected"] = i == index }
            selectedIndex = index
            configureButtons()
            moveSelection(animated: true)
        }
        channel.invokeMethod("tap", arguments: id)
    }
    @objc private func longPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let index = gesture.view?.tag, index < items.count,
              let id = items[index]["id"] as? String else { return }
        channel.invokeMethod("longPress", arguments: id)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        surface.frame = bounds
        if #available(iOS 26.0, *) {
            surface.cornerConfiguration = .capsule(maximumRadius: radius)
        } else {
            surface.layer.cornerRadius = min(radius, bounds.height / 2)
            surface.layer.cornerCurve = .continuous
        }
        scroll.frame = surface.bounds.insetBy(dx: 5, dy: 5)
        guard !buttons.isEmpty else { return }
        let height = scroll.bounds.height
        var position: CGFloat = 0
        for button in buttons {
            let width: CGFloat
            if vertical { width = scroll.bounds.width }
            else if style == "segments" { width = max(60, button.sizeThatFits(CGSize(width: 500, height: height)).width + 12) }
            else { width = scroll.bounds.width / CGFloat(buttons.count) }
            let itemHeight = vertical ? height / CGFloat(buttons.count) : height
            button.frame = CGRect(x: vertical ? 0 : position, y: vertical ? position : 0, width: width, height: itemHeight)
            position += vertical ? itemHeight : width
        }
        scroll.contentSize = CGSize(width: vertical ? scroll.bounds.width : position, height: height)
        moveSelection(animated: false, reveal: false)
    }
    private func moveSelection(animated: Bool, reveal: Bool = true) {
        guard let index = selectedIndex, index < buttons.count else { selection.isHidden = true; return }
        selection.isHidden = false
        selection.backgroundColor = accent.withAlphaComponent(overrideUserInterfaceStyle == .dark ? 0.23 : 0.11)
        let frame = buttons[index].frame.insetBy(dx: 1, dy: 1)
        let changes = {
            self.selection.frame = frame
            self.selection.layer.cornerRadius = min(self.radius - 5, frame.height / 2)
        }
        if animated && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
        } else { changes() }
        if reveal && style == "segments" { scroll.scrollRectToVisible(frame.insetBy(dx: -12, dy: 0), animated: animated) }
    }
    private static func color(_ value: Any?) -> UIColor? {
        guard let argb = (value as? NSNumber)?.uint32Value else { return nil }
        return UIColor(red: CGFloat((argb >> 16) & 255) / 255, green: CGFloat((argb >> 8) & 255) / 255,
                       blue: CGFloat(argb & 255) / 255, alpha: CGFloat((argb >> 24) & 255) / 255)
    }
}
