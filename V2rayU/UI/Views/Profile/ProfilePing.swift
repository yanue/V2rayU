//
//  ConfigList.swift
//  V2rayU
//
//  Created by yanue on 2024/11/30.
//

import SwiftUI

struct ProfilePingView: View {
    var profile: ProfileEntity?
    var profiles: [ProfileEntity]?
    var isAll: Bool
    var onClose: () -> Void
    @State private var logs: [String] = []
    @State private var isPinging: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(pingTitle)
                    .font(.title2).bold()
                Spacer()
                Button(isPinging ? "Pinging..." : "Ping Now") {
                    isPinging = true
                    logs.removeAll()
                    if isAll {
                        doPingAll()
                    } else if let p = profile {
                        doPingItem(item: p)
                    } else if let items = profiles {
                        doPingMultiple(items: items)
                    }
                }
                .disabled(isPinging)
                .buttonStyle(.borderedProminent)
                .focusable(false)
                
                Button(action: onClose) {
                    Text(String(localized: .Close))
                }
                .focusable(false)
            }
            .padding([.top, .horizontal], 20)
            .padding(.bottom, 8)

            Divider()

            if let p = profile {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(String(localized: .Remark)): \(p.remark)")
                        .font(.subheadline)
                    Text("\(String(localized: .Protocol)): \(p.protocol.rawValue), \(String(localized: .Address)): \(p.address):\(p.port)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Divider().padding(.top, 8)
            } else if let items = profiles, !items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(String(localized: .Selected)) \(items.count) \(String(localized: .Proxies))")
                        .font(.subheadline)
                    Text("\(String(localized: .Protocol)): \(Array(Set(items.map { $0.protocol.rawValue })).joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Divider().padding(.top, 8)
            } else if isAll {
                Text(String(localized: .PingAllProxies))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                Divider().padding(.top, 8)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.textBackgroundColor))
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            if logs.isEmpty {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray.opacity(0.2))
                                    Spacer()
                                }.padding(.top, 80)
                                Spacer()
                            } else {
                                ForEach(logs.indices, id: \ .self) { idx in
                                    Text(logs[idx])
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(idx)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: logs) { _,_ in
                        if let last = logs.indices.last {
                            DispatchQueue.main.async {
                                withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                            }
                        }
                    }
                }
                .frame(minHeight: 160, maxHeight: 220)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer(minLength: 0)

            HStack {
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(width: 560, height: 380)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 2)
        )
        .onAppear {
            logs.removeAll()
            subscribeNotification()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }

    func subscribeNotification() {
        NotificationCenter.default.addObserver(forName: NOTIFY_UPDATE_Ping, object: nil, queue: .main) { notif in
            if let msg = notif.object as? String {
                DispatchQueue.main.async {
                    logs.append(msg)
                }
            }
            DispatchQueue.main.async {
                isPinging = false
            }
        }
    }

    func doPingItem(item: ProfileEntity) {
        Task {
            await PingAll.shared.pingOne(item: item)
        }
    }

    func doPingMultiple(items: [ProfileEntity]) {
        Task {
            for item in items {
                await PingAll.shared.pingOne(item: item)
            }
        }
    }

    func doPingAll() {
        Task {
            await PingAll.shared.run()
        }
    }

    private var pingTitle: String {
        if isAll {
            return "Ping All Proxies"
        } else if let items = profiles, !items.isEmpty {
            return "Ping \(items.count) Proxies"
        } else {
            return "Ping Proxy"
        }
    }
}
