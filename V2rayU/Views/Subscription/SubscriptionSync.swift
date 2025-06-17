//
//  SubscriptionSync.swift
//  V2rayU
//
//  Created by yanue on 2025/6/17.
//

import SwiftUI

struct SubscriptionSyncView: View {
    var subscription: SubModel?
    var isAll: Bool
    var onClose: () -> Void
    @State private var logs: [String] = []
    @State private var isSyncing: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isAll ? "Sync All Subscriptions" : "Sync Subscription")
                    .font(.title2).bold()
                Spacer()
                Button(isSyncing ? "Syncing..." : "Sync Now") {
                    isSyncing = true
                    logs.removeAll()
                    if isAll {
                        doSyncAll()
                    } else if let sub = subscription {
                        doSyncItem(item: sub)
                    }
                }
                .disabled(isSyncing)
                .buttonStyle(.borderedProminent)
                Button(action: onClose) {
                    Text("Close")
                }
            }
            .padding([.top, .horizontal], 20)
            .padding(.bottom, 8)

            Divider()

            if let sub = subscription, !isAll {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remark: \(sub.remark)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Url: \(sub.url)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Divider().padding(.top, 8)
            } else if isAll {
                Text("This will sync all subscriptions.")
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
                    .onChange(of: logs) { _ in
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
        NotificationCenter.default.addObserver(forName: NOTIFY_UPDATE_SubSync, object: nil, queue: .main) { notif in
            if let msg = notif.object as? String {
                DispatchQueue.main.async {
                    logs.append(msg)
                }
            }
            DispatchQueue.main.async {
                isSyncing = false
            }
        }
    }

    func doSyncItem(item: SubModel) {
        Task {
            await SubscriptionHandler.shared.syncOne(item: item)
        }
    }

    func doSyncAll() {
        Task {
            await SubscriptionHandler.shared.sync()
        }
    }
}
