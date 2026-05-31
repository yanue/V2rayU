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

            Text(String(localized: .DNS))
                .font(.headline)
                .foregroundColor(.secondary)

            HStack {
                getTextLabel(label: .TunDefaultDns, labelWidth: labelWidth)
                TextField(String(localized: .TunDefaultDns), text: $settings.tunDnsDefault)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 7)
                Spacer()
            }

            HStack {
                getTextLabel(label: .TunChinaDns, labelWidth: labelWidth)
                TextField(String(localized: .TunChinaDns), text: $settings.tunDnsChina)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading, 7)
                Spacer()
            }

            HStack {
                getTextLabel(label: .TunFakeipRange, labelWidth: labelWidth)
                TextField(String(localized: .TunFakeipRange), text: $settings.tunFakeipRange)
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
