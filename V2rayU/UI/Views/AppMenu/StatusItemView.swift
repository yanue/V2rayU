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

// MARK: - 状态栏视图

final class StatusItemView: NSView {
    private let iconView = NSImageView()
    private let latencyStack = NSStackView()
    private let spinner = NSProgressIndicator()
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

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.widthAnchor.constraint(equalToConstant: 12),
            spinner.heightAnchor.constraint(equalToConstant: 12),
        ])
        dotLabel.stringValue = "●"
        latencyStack.orientation = .horizontal
        latencyStack.spacing = 4
        latencyStack.setViews([spinner, dotLabel, latencyLabel], in: .leading)

        speedStack.orientation = .vertical
        speedStack.alignment = .leading
        speedStack.spacing = 1
        speedStack.setViews([downLabel, upLabel], in: .top)

        let stack = NSStackView(views: [iconView, latencyStack, speedStack])
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

    func update(appState: AppState, settings: AppSettings) {
        if iconView.image?.name() != appState.icon {
            iconView.image = NSImage(named: appState.icon)
        }

        latencyStack.isHidden = !settings.showLatencyOnTray
        if settings.showLatencyOnTray {
            let starting = appState.isCoreStarting
            // NSStackView 只会收起 isHidden 的视图，停止的 spinner 也要隐藏，否则会留出空白
            spinner.isHidden = !starting
            dotLabel.isHidden = starting
            latencyLabel.isHidden = starting
            if starting {
                spinner.startAnimation(nil)
            } else {
                spinner.stopAnimation(nil)
                dotLabel.textColor = appState.v2rayTurnOn ? .systemGreen : .systemGray
                latencyLabel.stringValue = "\(String(format: "%.0f", appState.latency)) ms"
                latencyLabel.textColor = getSpeedColor(latency: appState.latency)
            }
        } else {
            spinner.stopAnimation(nil)
        }

        speedStack.isHidden = !settings.showSpeedOnTray
        if settings.showSpeedOnTray {
            downLabel.stringValue = speedText("↓", appState.proxyDownSpeed)
            upLabel.stringValue = speedText("↑", appState.proxyUpSpeed)
        }
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
