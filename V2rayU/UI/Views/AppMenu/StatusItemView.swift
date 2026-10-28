//
//  StatusItemView.swift
//  V2rayU
//
//  Created by yanue on 2025/11/8.
//

import AppKit

// 状态栏与菜单顶部状态行使用纯 AppKit 实现：
// 这两个视图在整个运行期常驻且每秒随速度刷新，常驻的 NSHostingView 是 AttributeGraph 崩溃的高发点，
// 改为由 AppMenuManager 主动调用 update() 刷新。

private func makeLabel(size: CGFloat) -> NSTextField {
    let label = NSTextField(labelWithString: "")
    label.font = .monospacedDigitSystemFont(ofSize: size, weight: .regular)
    label.textColor = .labelColor
    label.lineBreakMode = .byClipping
    return label
}

private func speedText(_ prefix: String, _ value: Double) -> String {
    "\(prefix) \(String(format: "%.0f", value)) KB/s"
}

// MARK: - 加载指示器

// 启动期间主线程忙于初始化，NSProgressIndicator 依赖主线程 runloop 驱动动画会卡住不转。
// 这里用 CAReplicatorLayer 画系统风格的花瓣转圈（8 根短线依次渐隐），
// 动画由渲染服务驱动，主线程阻塞时也能持续转动。
private final class LoadingSpinnerView: NSView {
    private let replicator = CAReplicatorLayer()
    private let spoke = CALayer()
    private static let spokeCount = 8
    private static let duration: CFTimeInterval = 0.8
    private static let animationKey = "fade"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        replicator.instanceCount = Self.spokeCount
        replicator.instanceTransform = CATransform3DMakeRotation(-2 * .pi / CGFloat(Self.spokeCount), 0, 0, 1)
        replicator.instanceDelay = Self.duration / CFTimeInterval(Self.spokeCount)
        spoke.opacity = 0.25
        replicator.addSublayer(spoke)
        layer?.addSublayer(replicator)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        replicator.frame = bounds
        // 短线位于圆环上半部：宽 1.5pt，从半径 30% 延伸到边缘，副本绕中心旋转
        let size = min(bounds.width, bounds.height)
        let width: CGFloat = 1.5
        let length = size * 0.3
        spoke.bounds = CGRect(x: 0, y: 0, width: width, height: length)
        spoke.cornerRadius = width / 2
        spoke.position = CGPoint(x: bounds.midX, y: bounds.midY + size / 2 - length / 2)
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 移出/移入窗口时 layer 动画可能被移除，按当前状态补上
        if !isHidden { start() }
    }

    private func updateColor() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            spoke.backgroundColor = NSColor.labelColor.cgColor
        }
    }

    func start() {
        updateColor()
        guard spoke.animation(forKey: Self.animationKey) == nil else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0.25
        fade.duration = Self.duration
        fade.repeatCount = .infinity
        fade.isRemovedOnCompletion = false
        spoke.add(fade, forKey: Self.animationKey)
    }

    func stop() {
        spoke.removeAnimation(forKey: Self.animationKey)
    }
}

// MARK: - 状态栏视图

// 图标、延迟、网速合成一张图交给 NSStatusBarButton 自己画 (button.image)，不在按钮上叠加自绘子视图：
// - 系统只对按钮自己画的图片做“非活动屏幕变暗”，叠加的子视图（NSTextField 或自绘 NSView）都不会变暗 (#1704)
// - 按钮里放 NSTextField 时，macOS 27 给菜单栏截图切换外观会让它重绘、又触发下一次截图，CPU 常驻 60% (#1705)
// 只有图标 / 网速时用 template 图，与其它菜单栏图标一致；显示彩色延迟时用普通图片。
// 本视图只承载启动时的转圈动画（动画无法放进图片），盖在按钮上、不接收点击。
final class StatusItemView: NSView {
    private struct Content: Equatable {
        var icon: String
        var starting: Bool
        var latency: String?
        var latencyColor: NSColor?
        var down: String?
        var up: String?
    }

    private static let height: CGFloat = 22
    private static let padding: CGFloat = 4
    private static let spacing: CGFloat = 4
    private static let iconSize: CGFloat = 18
    private static let spinnerSize: CGFloat = 12
    private static let latencyFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
    private static let speedFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
    private static let speedLineSpacing: CGFloat = 1

    private let spinner = LoadingSpinnerView()
    private var content: Content?
    private var width: CGFloat = NSStatusItem.squareLength

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        spinner.isHidden = true
        addSubview(spinner)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // 点击交给底下的 NSStatusBarButton 处理
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let size = Self.spinnerSize
        spinner.frame = NSRect(x: Self.padding + Self.iconSize + Self.spacing,
                               y: (bounds.height - size) / 2, width: size, height: size)
    }

    /// 刷新内容，返回内容所需宽度（由调用方设置为状态栏项宽度）
    @discardableResult
    func update(appState: AppState, settings: AppSettings) -> CGFloat {
        // 加载中只显示图标 + 转圈；停止状态只显示图标；运行中才按设置显示延迟和速度
        // 只有目标是开启时才转圈：启动时上次为停止、或正在停止，都不转
        let starting = appState.isCoreStarting && appState.v2rayTurnOn
        spinner.isHidden = !starting
        if starting {
            spinner.start()
        } else {
            spinner.stop()
        }

        let running = !starting && appState.v2rayTurnOn
        var next = Content(icon: appState.icon, starting: starting)
        if running && settings.showLatencyOnTray {
            next.latency = "\(String(format: "%.0f", appState.latency)) ms"
            next.latencyColor = getSpeedColor(latency: appState.latency)
        }
        if running && settings.showSpeedOnTray {
            next.down = speedText("↓", appState.proxyDownSpeed)
            next.up = speedText("↑", appState.proxyUpSpeed)
        }
        if next != content {
            render(next)
        }
        return width
    }

    private func render(_ content: Content) {
        self.content = content
        let latencyFont = Self.latencyFont
        let speedFont = Self.speedFont
        let dot = "●"
        let latencyWidth = content.latency.map {
            ceil(textWidth(dot, latencyFont) + Self.spacing + textWidth($0, latencyFont))
        }
        let speedWidth: CGFloat? = content.down.flatMap { down in
            content.up.map { ceil(max(textWidth(down, speedFont), textWidth($0, speedFont))) }
        }

        var segments: [CGFloat] = [Self.iconSize]
        if content.starting { segments.append(Self.spinnerSize) }
        if let latencyWidth { segments.append(latencyWidth) }
        if let speedWidth { segments.append(speedWidth) }
        let contentWidth = segments.reduce(0, +) + Self.spacing * CGFloat(segments.count - 1)
        let size = NSSize(width: Self.padding * 2 + contentWidth, height: Self.height)

        // template 图由系统着色，画成黑色即可；普通图片的 labelColor 在每次绘制时按当前外观解析
        // （drawingHandler 图片随外观重绘，不需要也不能在外观变化时重设 button.image，否则又会引发 #1705 的循环）
        let template = content.latency == nil
        let iconImage = NSImage(named: content.icon)
        let image = NSImage(size: size, flipped: false) { rect in
            let textColor: NSColor = template ? .black : .labelColor
            var x = Self.padding
            if let iconImage {
                let iconRect = NSRect(x: x, y: (rect.height - Self.iconSize) / 2,
                                      width: Self.iconSize, height: Self.iconSize)
                if template {
                    iconImage.draw(in: iconRect)
                } else {
                    // template 图标按文字颜色着色
                    let tinted = NSImage(size: iconRect.size, flipped: false) { r in
                        iconImage.draw(in: r)
                        textColor.set()
                        r.fill(using: .sourceAtop)
                        return true
                    }
                    tinted.draw(in: iconRect)
                }
            }
            x += Self.iconSize + Self.spacing
            if content.starting {
                x += Self.spinnerSize + Self.spacing
            }
            if let latency = content.latency, let latencyWidth {
                let y = (rect.height - lineHeight(latencyFont)) / 2
                (dot as NSString).draw(at: NSPoint(x: x, y: y),
                                       withAttributes: [.font: latencyFont, .foregroundColor: NSColor.systemGreen])
                let dotWidth = textWidth(dot, latencyFont) + Self.spacing
                (latency as NSString).draw(at: NSPoint(x: x + dotWidth, y: y),
                                           withAttributes: [.font: latencyFont, .foregroundColor: content.latencyColor ?? textColor])
                x += latencyWidth + Self.spacing
            }
            if let down = content.down, let up = content.up {
                let line = lineHeight(speedFont)
                let top = (rect.height + line * 2 + Self.speedLineSpacing) / 2
                let attributes: [NSAttributedString.Key: Any] = [.font: speedFont, .foregroundColor: textColor]
                (down as NSString).draw(at: NSPoint(x: x, y: top - line), withAttributes: attributes)
                (up as NSString).draw(at: NSPoint(x: x, y: top - line * 2 - Self.speedLineSpacing), withAttributes: attributes)
            }
            return true
        }
        image.isTemplate = template

        width = size.width
        if let button = superview as? NSButton {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.image = image
        }
    }
}

private func textWidth(_ text: String, _ font: NSFont) -> CGFloat {
    (text as NSString).size(withAttributes: [.font: font]).width
}

private func lineHeight(_ font: NSFont) -> CGFloat {
    ceil(font.ascender - font.descender)
}

// MARK: - 菜单顶部状态行

final class CoreStatusItemView: NSView {
    private let wifiView = NSImageView()
    private let latencyLabel = makeLabel(size: 11)
    private let upLabel = makeLabel(size: 11)
    private let downLabel = makeLabel(size: 11)
    private var lastTurnOn: Bool?

    init() {
        super.init(frame: .zero)

        let left = NSStackView(views: [wifiView, latencyLabel])
        left.orientation = .horizontal
        left.spacing = 4
        let right = NSStackView(views: [upLabel, downLabel])
        right.orientation = .horizontal
        right.spacing = 8

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.setViews([left], in: .leading)
        stack.setViews([right], in: .trailing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
        // 菜单宽度由 view 的 frame 决定，跟随菜单宽度拉伸
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(appState: AppState) {
        let on = appState.v2rayTurnOn
        if lastTurnOn != on {
            lastTurnOn = on
            wifiView.image = NSImage(systemSymbolName: on ? "wifi" : "wifi.slash", accessibilityDescription: nil)
            wifiView.contentTintColor = on ? .systemGreen : .systemGray
            upLabel.textColor = on ? .systemBlue : .systemGray
            downLabel.textColor = on ? .systemRed : .systemGray
        }
        latencyLabel.stringValue = "\(String(format: "%.0f", appState.latency)) ms"
        latencyLabel.textColor = on ? getSpeedColor(latency: appState.latency) : .systemGray
        upLabel.stringValue = speedText("↑", appState.proxyUpSpeed)
        downLabel.stringValue = speedText("↓", appState.proxyDownSpeed)
    }
}
