import SwiftUI

struct TunView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showIPv6Warning = false
    private let labelWidth: CGFloat = 150

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: .TunSettings))
                    .font(.headline)
                    .foregroundColor(.secondary)

                // MARK: - 基本设置

                HStack {
                    getTextLabel(label: .TunAddress, labelWidth: labelWidth)
                    TextField(String(localized: .TunAddress), text: $settings.tunAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                    Spacer()
                }

                HStack {
                    getTextLabel(label: .TunAddressIPv6, labelWidth: labelWidth)
                    TextField(String(localized: .TunAddressIPv6), text: $settings.tunAddressIPv6)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                }

                HStack {
                    getTextLabel(label: .TunMtu, labelWidth: labelWidth)
                    TextField(String(localized: .TunMtu), value: $settings.tunMtu, formatter: NumberFormatter())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                    Spacer()
                }

                HStack {
                    getTextLabel(label: .TunStack, labelWidth: labelWidth)
                    Picker("", selection: $settings.tunStack) {
                        ForEach(TunStack.allCases, id: \.self) { pick in
                            Text(pick.rawValue)
                        }
                    }
                    .padding(.leading, 7)
                    Spacer()
                }

                HStack {
                    getTextLabel(label: .TunLogLevel, labelWidth: labelWidth)
                    Picker("", selection: $settings.tunLogLevel) {
                        ForEach(V2rayLogLevel.allCases, id: \.self) { pick in
                            Text(pick.rawValue)
                        }
                    }
                    .padding(.leading, 7)
                    Spacer()
                }

                // MARK: - 路由 & IPv6

                HStack {
                    Spacer().frame(width: labelWidth)
                    Toggle(isOn: $settings.tunStrictRoute) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: .TunStrictRoute))
                            Text(String(localized: .TunStrictRouteTip))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer().frame(width: labelWidth)
                        Toggle(isOn: $settings.tunEnableIPv6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: .TunEnableIPv6))
                                Text(String(localized: .TunEnableIPv6Tip))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }

                    if settings.tunEnableIPv6 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle(isOn: $settings.tunShowIPv6Reminder) {
                                    Text(String(localized: .TunShowIPv6Reminder))
                                        .font(.caption)
                                }
                                Spacer()
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .padding(.leading, labelWidth + 20)
                    }
                }

                HStack {
                    Spacer().frame(width: labelWidth)
                    Toggle(isOn: $settings.tunAutoRebuild) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: .TunAutoRebuild))
                            Text(String(localized: .TunAutoRebuildTip))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }

                HStack(alignment: .top) {
                    getTextLabel(label: .TunRouteExcludeHosts, labelWidth: labelWidth)
                    VStack(alignment: .leading, spacing: 4) {
                        TextEditor(text: $settings.tunRouteExcludeHosts)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 64, maxHeight: 80)
                            .padding(4)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(nsColor: .separatorColor))
                            }
                        Text(String(localized: .TunRouteExcludeHostsTip))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                // MARK: - DNS

                Text(String(localized: .TunDns))
                    .font(.headline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        getTextLabel(label: .TunRemoteDns, labelWidth: labelWidth)
                        Picker("", selection: $settings.tunDnsRemote) {
                            Text("1.1.1.1 (Cloudflare)").tag("1.1.1.1")
                            Text("8.8.8.8 (Google)").tag("8.8.8.8")
                            Text("9.9.9.9 (Quad9)").tag("9.9.9.9")
                            Text("208.67.222.222 (OpenDNS)").tag("208.67.222.222")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                    }
                    Label(String(localized: .TunRemoteDnsTip), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, labelWidth + 7)
                }

                HStack {
                    getTextLabel(label: .TunChinaDns, labelWidth: labelWidth)
                    TextField(String(localized: .TunChinaDns), text: $settings.tunDnsChina)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 7)
                    Spacer()
                }

                Divider()

                HStack {
                    Spacer()
                    Button(String(localized: .Save)) {
                        settings.saveSettings()
                    }
                    Spacer()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
            AppSettings.shared.saveSettings()
        }
        .onChange(of: settings.tunEnableIPv6) { _, newValue in
            if newValue {
                showIPv6Warning = true
            }
        }
        .alert(String(localized: .TunEnableIPv6), isPresented: $showIPv6Warning) {
            Button(String(localized: .OK)) { }
        } message: {
            Text(String(localized: .TunEnableIPv6ChromeWarning))
        }
    }
}
