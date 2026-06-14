import SwiftUI

struct TunView: View {
    @ObservedObject var settings = AppSettings.shared
    private var labelWidth: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: .TunSettings))
                .font(.headline)
                .foregroundColor(.secondary)

            HStack {
                getTextLabel(label: .TunAddress, labelWidth: labelWidth)
                TextField(String(localized: .TunAddress), text: $settings.tunAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 7)
                Spacer()
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
                Spacer()
                Picker("", selection: $settings.tunStack) {
                    ForEach(TunStack.allCases, id: \.self) { pick in
                        Text(pick.rawValue)
                    }
                }
            }

            HStack {
                getTextLabel(label: .TunLogLevel, labelWidth: labelWidth)
                Spacer()
                Picker("", selection: $settings.tunLogLevel) {
                    ForEach(V2rayLogLevel.allCases, id: \.self) { pick in
                        Text(pick.rawValue)
                    }
                }
            }

            HStack {
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

            HStack {
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

            Divider()

            Text(String(localized: .TunDns))
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    getTextLabel(label: .TunRemoteDns, labelWidth: labelWidth)
                    Spacer()
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
                Button(String(localized: .Save)) {
                    settings.saveSettings()
                }
                .focusable(false)
            }
        }
        .padding()
        .onDisappear {
            AppSettings.shared.saveSettings()
        }
    }
}
