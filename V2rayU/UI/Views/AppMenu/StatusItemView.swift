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

final class StatusItemView: NSView {
    private let iconView = NSImageView()
    private let spinner = LoadingSpinnerView()
    private let latencyStack = NSStackView()
    private let dotLabel = makeLabel(size: 10)
    private let latencyLabel = makeLabel(size: 10)
    private let speedStack = NSStackView()
    private let downLabel = makeLabel(size: 9)
    private let upLabel = makeLabel(size: 9)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        // template 图标按文字颜色着色，与原 SwiftUI Image 的 .primary 一致
        iconView.contentTintColor = .labelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
        ])

        spinner.isHidden = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.widthAnchor.constraint(equalToConstant: 12),
            spinner.heightAnchor.constraint(equalToConstant: 12),
        ])

        dotLabel.stringValue = "●"
        latencyStack.orientation = .horizontal
        latencyStack.spacing = 4
        latencyStack.setViews([dotLabel, latencyLabel], in: .leading)

        speedStack.orientation = .vertical
        speedStack.alignment = .leading
        speedStack.spacing = 1
        speedStack.setViews([downLabel, upLabel], in: .top)

        // NSStackView 默认 detachesHiddenViews，隐藏的子视图不占宽度也不留间距
        let stack = NSStackView(views: [iconView, spinner, latencyStack, speedStack])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        // 提供 22pt 的期望高度撑起状态栏项；非 required，避免与不同高度的状态栏按钮约束冲突
        let height = heightAnchor.constraint(equalToConstant: 22)
        height.priority = .defaultHigh
        height.isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // 点击交给底下的 NSStatusBarButton 处理
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// 刷新内容，返回内容所需宽度（由调用方设置为状态栏项宽度）
    @discardableResult
    func update(appState: AppState, settings: AppSettings) -> CGFloat {
        if iconView.image?.name() != appState.icon {
            iconView.image = NSImage(named: appState.icon)
        }

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
        let showLatency = running && settings.showLatencyOnTray
        latencyStack.isHidden = !showLatency
        if showLatency {
            dotLabel.textColor = .systemGreen
            latencyLabel.stringValue = "\(String(format: "%.0f", appState.latency)) ms"
            latencyLabel.textColor = getSpeedColor(latency: appState.latency)
        }

        let showSpeed = running && settings.showSpeedOnTray
        speedStack.isHidden = !showSpeed
        if showSpeed {
            downLabel.stringValue = speedText("↓", appState.proxyDownSpeed)
            upLabel.stringValue = speedText("↑", appState.proxyUpSpeed)
        }

        return ceil(fittingSize.width)
    }
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
