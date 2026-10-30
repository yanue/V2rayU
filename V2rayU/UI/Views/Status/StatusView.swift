//
//  StatusView.swift
//  V2rayU
//
//  概览页 (参考 Surge Dashboard): 顶部状态大卡, 中间整宽实时流量图, 底部 4 个统计方块
//

import Charts
import SwiftUI

// MARK: - 数据

struct TrafficSample: Identifiable {
    let id: Int
    let time: Date
    /// 字节/秒
    let up: Double
    let down: Double
}

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published var samples: [TrafficSample] = []
    @Published var coreType: CoreType? = nil
    @Published var coreVersion = ""
    @Published var subscriptions: [SubscriptionEntity] = []
    @Published var runningProfile: ProfileEntity? = nil
    @Published var ruleSetLastUpdate: Date? = RuleSetUpdater.lastUpdate
    /// sing-box 下的活跃连接数; xray 或未运行时为 nil
    @Published var connectionCount: Int? = nil
    /// 流量图周期和节点筛选 (nil = 全部节点)
    @Published var period: TrafficPeriod = .live { didSet { loadHistory() } }
    /// 空字符串 = 全部节点
    @Published var profileFilter: String = "" { didSet { loadHistory() } }
    @Published var buckets: [TrafficBucket] = []
    @Published var historyProfiles: [HistoryProfile] = []
    /// 顶部大卡显示当前路由名用
    @Published var routings: [RoutingEntity] = []

    /// 订阅的流量 / 到期信息很少变, 不跟着 3 秒刷新
    func loadSubscriptions() {
        subscriptions = SubscriptionStore.shared.fetchAll()
    }

    func loadRoutings() {
        routings = RoutingStore.shared.fetchAll()
    }

    struct HistoryProfile: Identifiable, Hashable {
        let id: String
        let name: String
    }

    func loadHistory() {
        guard period != .live else { buckets = []; return }
        buckets = TrafficHistoryStore.shared.buckets(period: period, profileUuid: profileFilter.isEmpty ? nil : profileFilter)
        let names = Dictionary(ProfileStore.shared.fetchAll().map { ($0.uuid, $0.remark) }, uniquingKeysWith: { a, _ in a })
        historyProfiles = TrafficHistoryStore.shared.profileUuids()
            .map { HistoryProfile(id: $0, name: names[$0] ?? String($0.prefix(8))) }
            .sorted { $0.name < $1.name }
    }

    var periodTotal: (up: Int64, down: Int64) {
        buckets.reduce((Int64(0), Int64(0))) { ($0.0 + $1.up, $0.1 + $1.down) }
    }

    static let windowSeconds = 60
    private var sampleId = 0
    private var task: Task<Void, Never>?

    func start() {
        stop()
        // 先铺满 60 个 0, 图一开始就是完整宽度
        let now = Date()
        samples = (0..<Self.windowSeconds).map { i in
            TrafficSample(id: i, time: now.addingTimeInterval(Double(i - Self.windowSeconds)), up: 0, down: 0)
        }
        sampleId = Self.windowSeconds
        refresh()
        loadRoutings()
        loadSubscriptions()
        task = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { break }
                self.sample()
                tick += 1
                if tick % 3 == 0 { self.refresh() }
                if tick % 30 == 0 { self.loadHistory(); self.loadSubscriptions() }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// 窗口关闭 / 最小化 / 被完全挡住时 onDisappear 不一定触发, 按窗口可见性停 / 恢复刷新
    func setWindowVisible(_ visible: Bool) {
        if !visible {
            stop()
        } else if task == nil {
            start()
        }
    }

    func sample() {
        let state = AppState.shared
        let on = state.v2rayTurnOn
        // AppState 里的网速是 KiB/s (托盘直接显示的值), 这里换成字节/秒; 显示时也按 1024 换算, 和托盘对得上
        let s = TrafficSample(id: sampleId, time: Date(),
                              up: on ? state.proxyUpSpeed * 1024 : 0,
                              down: on ? state.proxyDownSpeed * 1024 : 0)
        sampleId += 1
        samples.append(s)
        if samples.count > Self.windowSeconds { samples.removeFirst(samples.count - Self.windowSeconds) }
    }

    func refresh() {
        runningProfile = ProfileStore.shared.getRunning()
        ruleSetLastUpdate = RuleSetUpdater.lastUpdate
        loadIpInfo()
        let on = AppState.shared.v2rayTurnOn
        Task {
            let core = await V2rayLaunch.shared.lastCore
            var count: Int? = nil
            if on, core == .SingBox {
                count = try? await ClashConnectionsHandler.shared.fetch().list.count
            }
            await MainActor.run {
                coreType = on ? core : nil
                connectionCount = count
                switch core {
                case .SingBox: coreVersion = Self.shortVersion(getSingboxVersion())
                case .XrayCore: coreVersion = Self.shortVersion(getCoreShortVersion())
                case .none: coreVersion = ""
                }
            }
        }
    }

    // MARK: IP 信息 (经代理查, 看到的就是出口)

    struct IpInfo: Equatable {
        var ip = "", country = "", countryCode = "", city = "", isp = "", asn = ""

        /// 🇭🇰 Hong Kong / 🇺🇸 United States · Los Angeles; 城市和国家同名时只显示一次
        var regionText: String {
            var parts: [String] = []
            if !countryCode.isEmpty { parts.append(countryCodeToEmoji(countryCode)) }
            if !country.isEmpty { parts.append(country) }
            var text = parts.joined(separator: " ")
            if !city.isEmpty, city != country { text += " · \(city)" }
            return text
        }

        /// "AS45102 Alibaba..." 只留 AS 号
        var asnNumber: String { asn.split(separator: " ").first.map(String.init) ?? asn }
    }

    @Published var ipInfo: IpInfo? = nil
    @Published var ipLoading = false
    private var ipFetchedFor: String? = nil

    var xrayVersion: String { Self.shortVersion(getCoreShortVersion()) }
    var singboxVersion: String { Self.shortVersion(getSingboxShortVersion()) }

    static func shortVersion(_ raw: String) -> String {
        raw.range(of: #"\d+\.\d+(\.\d+)?"#, options: .regularExpression).map { String(raw[$0]) } ?? "-"
    }

    var portsText: String {
        let s = AppSettings.shared
        if s.enableMixedPort {
            return "\(s.mixedPort) · PAC \(getPacPort())"
        }
        return "\(getSocksProxyPort())/\(getHttpProxyPort()) · PAC \(getPacPort())"
    }

    /// 节点变了或手动刷新才重新查, 别每 3 秒打一次接口。
    /// 只在代理开着时查: 没开代理时请求会直连, 等于把真实 IP 发给第三方。
    func loadIpInfo(force: Bool = false) {
        guard AppState.shared.v2rayTurnOn else {
            ipInfo = nil
            ipFetchedFor = nil
            return
        }
        let key = AppState.shared.runningProfile
        guard force || ipFetchedFor != key, !ipLoading else { return }
        ipFetchedFor = key
        ipLoading = true
        Task {
            let info = await Self.fetchIpInfo()
            await MainActor.run {
                ipInfo = info
                ipLoading = false
                // 失败 (比如刚启动端口还没就绪) 就清掉标记, 下次 3 秒刷新再试
                if info == nil { ipFetchedFor = nil }
            }
        }
    }

    static func fetchIpInfo() async -> IpInfo? {
        guard let url = URL(string: "http://ip-api.com/json/?fields=status,query,country,countryCode,city,isp,as") else { return nil }
        let config = getProxyUrlSessionConfigure()
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, _) = try await session.data(from: url)
            guard let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (j["status"] as? String) == "success" else { return nil }
            return IpInfo(ip: j["query"] as? String ?? "", country: j["country"] as? String ?? "",
                          countryCode: j["countryCode"] as? String ?? "", city: j["city"] as? String ?? "",
                          isp: j["isp"] as? String ?? "", asn: j["as"] as? String ?? "")
        } catch {
            logger.info("fetchIpInfo failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 订阅剩余流量合计 (只算机场返回了总量的), 没有返回 nil
    var subscriptionRemaining: Int? {
        let withTotal = subscriptions.map(\.userInfo).filter { $0.total > 0 }
        guard !withTotal.isEmpty else { return nil }
        return withTotal.reduce(0) { $0 + max(0, $1.total - $1.used) }
    }

    /// 最近的到期时间
    var nearestExpire: SubscriptionUserInfo? {
        subscriptions.map(\.userInfo).filter(\.hasExpire).min { $0.expire < $1.expire }
    }
}

// MARK: - 视图

struct StatusView: View {
    @ObservedObject private var appState = AppState.shared
    @StateObject private var vm = OverviewViewModel()
    @Environment(\.colorScheme) private var colorScheme
    /// 悬停位置记成"倒数第几个点", 数据每秒往前滚时读数跟着更新, 不会停在旧的那一秒
    @State private var hoverFromEnd: Int? = nil
    private var hoverSample: TrafficSample? {
        guard let n = hoverFromEnd, n < vm.samples.count else { return nil }
        return vm.samples[vm.samples.count - 1 - n]
    }
    @State private var hoverBucket: TrafficBucket? = nil

    // 两条线的颜色: 浅色/深色分别过了色盲区分和对比度检查
    private var upColor: Color {
        colorScheme == .dark ? Color(red: 0x39 / 255, green: 0x87 / 255, blue: 0xe5 / 255)
                             : Color(red: 0x2a / 255, green: 0x78 / 255, blue: 0xd6 / 255)
    }
    private var downColor: Color {
        colorScheme == .dark ? Color(red: 0xe8 / 255, green: 0x5a / 255, blue: 0x5f / 255)
                             : Color(red: 0xe3 / 255, green: 0x49 / 255, blue: 0x48 / 255)
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(icon: "gauge.with.dots.needle.33percent", title: localizedString(.Overview), subtitle: localizedString(.StatusSubHead)) {
                runStatusBadge
                runModePicker
                toggleCoreButton
            }
            ScrollView {
                VStack(spacing: 12) {
                    heroCard
                    trafficCard
                    tiles
                    infoCards
                }
                .padding(.top, 4)
            }
        }
        .padding(8)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { note in
            guard let win = note.object as? NSWindow, win === MainWindowManager.shared.mainWindow else { return }
            vm.setWindowVisible(win.isVisible && win.occlusionState.contains(.visible))
        }
        .onChange(of: appState.v2rayTurnOn) { _, _ in vm.refresh() }
        .onChange(of: appState.runningProfile) { _, _ in vm.refresh() }
        .onChange(of: appState.runningRouting) { _, _ in vm.loadRoutings() }
        .onChange(of: vm.period) { _, _ in hoverBucket = nil; hoverFromEnd = nil }
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15)))
    }

    /// 右上角模式下拉用短名, 全称太长
    private func shortModeName(_ mode: RunMode) -> String {
        switch mode {
        case .tun: return String(localized: .ModeShortTun)
        case .global: return String(localized: .ModeShortGlobal)
        case .pac: return String(localized: .ModeShortPac)
        case .manual: return String(localized: .ModeShortManual)
        }
    }

    // MARK: 右上角: 运行状态 + 启动/停止

    /// 和菜单栏一样: 运行中只切模式, 未运行时按所选模式启动
    private var runModePicker: some View {
        Picker("", selection: Binding(
            get: { appState.runMode },
            set: { mode in Task { await appState.switchRunMode(mode: mode) } }
        )) {
            ForEach(RunMode.allCases, id: \.self) { mode in
                Text(shortModeName(mode)).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .disabled(appState.isCoreStarting)
        .focusable(false)
    }

    /// 绿 = 运行中, 灰 = 已停止; 运行中带上核心和版本
    private var runStatusBadge: some View {
        let on = appState.v2rayTurnOn
        return HStack(spacing: 5) {
            Circle()
                .fill(on ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 8, height: 8)
            Text(on ? String(localized: .OverviewRunning) : String(localized: .OverviewStopped))
                .font(.caption.weight(.medium))
                .foregroundColor(on ? .green : .secondary)
            if let core = vm.coreType {
                Text("· \(core == .SingBox ? "sing-box" : "xray") \(vm.coreVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill((on ? Color.green : Color.secondary).opacity(0.12)))
    }

    private var toggleCoreButton: some View {
        let on = appState.v2rayTurnOn
        return Button(action: { Task { await appState.toggleCore() } }) {
            HStack(spacing: 4) {
                if appState.isCoreStarting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: on ? "stop.fill" : "play.fill")
                }
                Text(on ? String(localized: .TurnCoreOff) : String(localized: .TurnCoreOn))
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(on ? .red : .accentColor)
        .disabled(appState.isCoreStarting)
        .focusable(false)
    }

    // MARK: 顶部大卡: 节点 + 路由 | 延迟 + 当前网速

    private var heroCard: some View {
        let on = appState.v2rayTurnOn
        let current = vm.samples.last
        return panel {
            HStack(alignment: .center, spacing: 12) {
                // 前面一列是说明文字, 后面是可点的下拉
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                    GridRow {
                        fieldLabel(.OverviewServer)
                        serverMenu
                    }
                    GridRow {
                        fieldLabel(.OverviewRouting)
                        routingMenu
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                latencyFigure(on: on)
                speedFigure(arrow: "arrow.up", color: upColor, label: String(localized: .TableFieldUpload), value: current?.up ?? 0)
                speedFigure(arrow: "arrow.down", color: downColor, label: String(localized: .TableFieldDownload), value: current?.down ?? 0)
            }
        }
    }

    private func fieldLabel(_ label: LanguageLabel) -> some View {
        Text(String(localized: label)).font(.caption).foregroundColor(.secondary)
    }

    /// 节点名点开就是菜单栏那份服务器菜单 (含组合), 用系统菜单弹出, 页面每秒刷新也不会把它关掉
    private var serverMenu: some View {
        let p = vm.runningProfile
        return PopUpMenuButton(makeMenu: { AppMenuManager.shared.getServerSubMenus() }) {
            HStack(spacing: 6) {
                if let p, !p.serverRegion.isEmpty { Text(countryCodeToEmoji(p.serverRegion)) }
                Text(p?.remark ?? String(localized: .OverviewNoNode))
                    .font(.headline)
                    .foregroundColor(p == nil ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundColor(.secondary)
            }
            .selectBox()
        }
        .disabled(appState.isCoreStarting)
    }

    private var routingMenu: some View {
        let name = vm.routings.first { $0.uuid == appState.runningRouting }?.remark ?? "-"
        return PopUpMenuButton(makeMenu: {
            let menu = NSMenu()
            for r in RoutingStore.shared.fetchAll() {
                let item = ClosureMenuItem(title: r.remark) { Task { await AppState.shared.switchRouting(uuid: r.uuid) } }
                item.state = r.uuid == AppState.shared.runningRouting ? .on : .off
                menu.addItem(item)
            }
            return menu
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch").foregroundColor(.secondary)
                Text(name).font(.headline).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundColor(.secondary)
            }
            .selectBox()
        }
        .disabled(appState.isCoreStarting || vm.routings.isEmpty)
    }

    /// 延迟和上传/下载同一个样式, 颜色跟托盘一致; 点刷新重测当前节点
    private func latencyFigure(on: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(Color(on ? getSpeedColor(latency: appState.latency) : .systemGray)).frame(width: 8, height: 8)
                Text(String(localized: .TableFieldLatency)).font(.caption).foregroundColor(.secondary)
                if let p = vm.runningProfile, on {
                    Button(action: { Task { await LatencyTestRunner.shared.runOne(item: p) } }) {
                        Image(systemName: "arrow.clockwise").font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help(String(localized: .LatencyTest))
                    .focusable(false)
                }
            }
            Text(on ? String(format: "%.0f ms", appState.latency) : "-")
                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                // 数字颜色和托盘上的延迟一样: 绿 < 200ms, 橙 < 500ms, 红, 无数据灰
                .foregroundColor(Color(on ? getSpeedColor(latency: appState.latency) : .systemGray))
        }
        .frame(width: 70, alignment: .trailing)
    }

    /// 大号网速数字, 前面的色点兼作流量图的图例
    private func speedFigure(arrow: String, color: Color, label: String, value: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.caption).foregroundColor(.secondary)
            }
            Text("\(formatKiB(value))/s")
                .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundColor(.primary)
        }
        .frame(width: 86, alignment: .trailing)
    }

    // MARK: 流量图: 两条面积线, 一个纵轴, 悬停十字线

    private var trafficCard: some View {
        panel {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Picker("", selection: $vm.period) {
                        Text(String(localized: .TrafficPeriodLive)).tag(TrafficPeriod.live)
                        Text(String(localized: .TrafficPeriodDays)).tag(TrafficPeriod.days30)
                        Text(String(localized: .TrafficPeriodMonths)).tag(TrafficPeriod.months12)
                        Text(String(localized: .TrafficPeriodAll)).tag(TrafficPeriod.all)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .focusable(false)

                    if vm.period != .live {
                        Picker("", selection: $vm.profileFilter) {
                            Text(String(localized: .TrafficAllServers)).tag("")
                            ForEach(vm.historyProfiles) { p in
                                Text(p.name).tag(p.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                    }
                    Spacer(minLength: 8)
                    trafficCaption
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(height: 22)
                Group {
                    if vm.period == .live {
                        trafficChart
                    } else {
                        historyChart
                    }
                }
                .frame(height: 180)
            }
        }
    }

    /// 右上角说明: 实时看悬停那一秒, 历史看悬停那一格或整个周期合计
    @ViewBuilder
    private var trafficCaption: some View {
        if vm.period == .live, let h = hoverSample {
            Text("\(h.time.formatted(date: .omitted, time: .standard))  ↑ \(formatKiB(h.up))/s  ↓ \(formatKiB(h.down))/s")
                .font(.caption.monospacedDigit()).foregroundColor(.secondary)
        } else if vm.period != .live {
            let b = hoverBucket
            let up = b?.up ?? vm.periodTotal.up
            let down = b?.down ?? vm.periodTotal.down
            Text("\(b?.key ?? String(localized: .Total))  ↑ \(formatBytesFixed(Double(up), base: 1024))  ↓ \(formatBytesFixed(Double(down), base: 1024))")
                .font(.caption.monospacedDigit()).foregroundColor(.secondary)
        }
    }

    private func gradient(_ c: Color) -> LinearGradient {
        LinearGradient(colors: [c.opacity(0.35), c.opacity(0.02)], startPoint: .top, endPoint: .bottom)
    }

    private var trafficChart: some View {
        Chart {
            ForEach(vm.samples) { s in
                AreaMark(x: .value("t", s.time), y: .value("v", s.down), series: .value("s", "down"))
                    .foregroundStyle(gradient(downColor))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("t", s.time), y: .value("v", s.down), series: .value("s", "down"))
                    .foregroundStyle(downColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                AreaMark(x: .value("t", s.time), y: .value("v", s.up), series: .value("s", "up"))
                    .foregroundStyle(gradient(upColor))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("t", s.time), y: .value("v", s.up), series: .value("s", "up"))
                    .foregroundStyle(upColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
            }
            if let h = hoverSample {
                RuleMark(x: .value("t", h.time))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("t", h.time), y: .value("v", h.down)).foregroundStyle(downColor).symbolSize(50)
                PointMark(x: .value("t", h.time), y: .value("v", h.up)).foregroundStyle(upColor).symbolSize(50)
            }
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text("\(formatKiB(v))/s").font(.caption2) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) { Text(d.formatted(date: .omitted, time: .standard)).font(.caption2) }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            let x = loc.x - geo[proxy.plotAreaFrame].origin.x
                            if let t: Date = proxy.value(atX: x) {
                                if let i = vm.samples.indices.min(by: { abs(vm.samples[$0].time.timeIntervalSince(t)) < abs(vm.samples[$1].time.timeIntervalSince(t)) }) {
                                    hoverFromEnd = vm.samples.count - 1 - i
                                }
                            }
                        case .ended:
                            hoverFromEnd = nil
                        }
                    }
            }
        }
    }

    /// 历史流量: 每个周期一组柱子 (上传 / 下载并排), 一个纵轴
    private var historyChart: some View {
        Chart {
            ForEach(vm.buckets) { b in
                BarMark(x: .value("t", b.key), y: .value("v", Double(b.down)))
                    .foregroundStyle(downColor)
                    .position(by: .value("s", "down"))
                    .cornerRadius(3)
                BarMark(x: .value("t", b.key), y: .value("v", Double(b.up)))
                    .foregroundStyle(upColor)
                    .position(by: .value("s", "up"))
                    .cornerRadius(3)
            }
            if let h = hoverBucket {
                RuleMark(x: .value("t", h.key))
                    .foregroundStyle(Color.secondary.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 18))
            }
        }
        .chartLegend(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(formatBytesFixed(v, base: 1024)).font(.caption2) }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                if let k = value.as(String.self), labeledKeys.contains(k) {
                    AxisValueLabel { Text(shortLabel(k)).font(.caption2).fixedSize() }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let loc):
                            let x = loc.x - geo[proxy.plotAreaFrame].origin.x
                            if let k: String = proxy.value(atX: x) {
                                hoverBucket = vm.buckets.first { $0.key == k }
                            }
                        case .ended:
                            hoverBucket = nil
                        }
                    }
            }
        }
        .overlay {
            if vm.periodTotal == (0, 0) {
                Text(String(localized: .TrafficNoHistory)).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    /// 横轴只标几个, 不然挤在一起: 30 天每 5 天一个, 其它全标
    private var labeledKeys: Set<String> {
        let keys = vm.buckets.map(\.key)
        guard keys.count > 12 else { return Set(keys) }
        let step = 5
        let last = keys.count - 1
        return Set(keys.enumerated().filter { (last - $0.offset) % step == 0 }.map(\.element))
    }

    private func shortLabel(_ key: String) -> String {
        switch vm.period {
        case .days30: return String(key.dropFirst(5))   // MM-dd
        case .months12: return String(key.dropFirst(2)) // yy-MM
        default: return key
        }
    }

    // MARK: IP 信息 / 系统信息 (参考 Clash Verge 首页)

    private var infoCards: some View {
        HStack(alignment: .top, spacing: 12) {
            panel {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(String(localized: .OverviewIpInfo), systemImage: "network").font(.headline).foregroundColor(.secondary)
                        Spacer()
                        Button(action: { vm.loadIpInfo(force: true) }) {
                            if vm.ipLoading { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.clockwise") }
                        }
                        .buttonStyle(.borderless)
                        .disabled(vm.ipLoading || !appState.v2rayTurnOn)
                        .focusable(false)
                    }
                    if let ip = vm.ipInfo {
                        infoRow("IP", ip.ip, mono: true)
                        infoRow(String(localized: .OverviewIpRegion), ip.regionText)
                        infoRow("ISP", ip.isp)
                        infoRow("ASN", ip.asnNumber, mono: true)
                    } else {
                        Text(vm.ipLoading ? String(localized: .Loading)
                             : String(localized: appState.v2rayTurnOn ? .OverviewIpUnavailable : .CoreNotRunning))
                            .font(.callout).foregroundColor(.secondary)
                    }
                }
            }
            panel {
                VStack(alignment: .leading, spacing: 6) {
                    Label(String(localized: .OverviewSystem), systemImage: "desktopcomputer").font(.headline).foregroundColor(.secondary)
                    infoRow("macOS", ProcessInfo.processInfo.operatingSystemVersionString.replacingOccurrences(of: "Version ", with: ""))
                    infoRow("V2rayU", "v\(appVersion)")
                    infoRow("Xray", vm.xrayVersion, mono: true)
                    infoRow("sing-box", vm.singboxVersion, mono: true)
                    infoRow(String(localized: .OverviewPorts), vm.portsText, mono: true)
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).foregroundColor(.secondary).frame(width: 96, alignment: .leading).lineLimit(1)
            Text(value.isEmpty ? "-" : value)
                .font(mono ? .callout.monospaced() : .callout)
                .lineLimit(1).truncationMode(.middle)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    // MARK: 底部统计方块, 点了跳到对应页

    private var tiles: some View {
        let p = vm.runningProfile
        let today = Double((p?.todayUp ?? 0) + (p?.todayDown ?? 0))
        let remaining = vm.subscriptionRemaining.map { formatBytesFixed(Double($0), base: 1024) }
        let expire = vm.nearestExpire
        return HStack(spacing: 12) {
            tile(icon: "arrow.up.arrow.down", title: String(localized: .OverviewToday),
                 value: formatKiB(today), detail: p.map { "↑ \(formatKiB(Double($0.todayUp)))  ↓ \(formatKiB(Double($0.todayDown)))" }) {
                NavigationState.shared.mainTab = .server
            }
            tile(icon: "point.3.connected.trianglepath.dotted", title: String(localized: .Connections),
                 value: vm.connectionCount.map(String.init) ?? "-",
                 detail: vm.coreType == .XrayCore ? String(localized: .OverviewSingboxOnly) : nil) {
                NavigationState.shared.mainTab = .connections
            }
            tile(icon: "link.circle", title: String(localized: .OverviewSubRemaining),
                 value: remaining ?? "-",
                 detail: expire.map { "\(String(localized: .TableFieldExpire)) \($0.expireText)" },
                 warn: expire?.daysLeft.map { $0 <= 7 } ?? false) {
                NavigationState.shared.mainTab = .subscription
            }
            tile(icon: "doc.badge.arrow.up", title: String(localized: .CoreTabRuleSets),
                 value: vm.ruleSetLastUpdate.map { $0.formatted(.relative(presentation: .named)) } ?? String(localized: .RuleSetNever),
                 detail: nil) {
                NavigationState.shared.coreSettingTab = .ruleSets
                NavigationState.shared.mainTab = .core
            }
        }
    }

    private func tile(icon: String, title: String, value: String, detail: String?, warn: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon).font(.caption).foregroundColor(.secondary).lineLimit(1)
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(warn ? .orange : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detail ?? " ").font(.caption2).foregroundColor(.secondary).lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}


// MARK: - 系统菜单弹出按钮

/// 点击后在按钮正下方弹出 NSMenu。
/// SwiftUI 的 Menu 在页面刷新时会被关掉 (概览页每秒都在刷网速), NSMenu 弹出期间不受影响。
struct PopUpMenuButton<Label: View>: View {
    let makeMenu: () -> NSMenu
    @ViewBuilder let label: () -> Label
    @State private var anchor = MenuAnchor()

    var body: some View {
        Button(action: {
            guard let view = anchor.view else { return }
            let menu = makeMenu()
            menu.minimumWidth = view.bounds.width
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: -4), in: view)
        }) {
            label().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .background(MenuAnchorView(anchor: anchor))
    }
}

final class MenuAnchor {
    weak var view: NSView?
}

private struct MenuAnchorView: NSViewRepresentable {
    let anchor: MenuAnchor
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        anchor.view = v
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}

/// 点击执行闭包的菜单项, 不用另找 target
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func fire() { handler() }
}

private extension View {
    /// 顶部大卡的选择框外观: 撑满宽度, 浅色圆角底
    func selectBox() -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
    }
}

/// 概览页的流量按 1024 换算, 和托盘的 KB/s 一致
private func formatKiB(_ bytes: Double) -> String {
    formatBytesFixed(bytes, base: 1024)
}
