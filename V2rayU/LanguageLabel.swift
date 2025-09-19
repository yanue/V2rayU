//
//  Language.swift
//  V2rayU
//
//  Created by yanue on 2024/12/19.
//

import SwiftUI

// MARK: - 多语言本地化标签枚举
enum LanguageLabel: String, CaseIterable {
    case Language
    case Theme
    case Light
    case Dark
    case FollowSystem
    // base
    case Save
    case Confirm
    case Cancel
    case Close
    case Reset
    case Remark
    case Edit
    case Preview
    // profile share
    case Regenerate
    case Regenerated
    case Copy
    case Copied
    // app content
    case Activity
    case ActivitySubHead
    case Servers
    case ServerSubHead
    case Subscriptions
    case SubscriptionSubHead
    case Routings
    case RoutingSubHead // "匹配优先级: 域名阻断 -> 域名代理 -> 域名直连 -> IP阻断 -> IP代理 -> IP直连"
    case Settings
    case SettingsSubHead
    case About
    case AboutSubHead
    // settiings tab
    case General
    case Advanced
    case PAC
    case DNS
    case Core
    // general settings
    case LaunchAtLogin
    case CheckForUpdateAutomatically
    case AutoUpdateServersFromSubscriptions
    case AutomaticallySelectFastestServer
    case ShowProxySpeedOnTrayIcon
    case ShowLatencyOnTrayIcon
    case EnableProxyStatistics
    case KeyboardShortcuts
    case ToggleV2rayOnOff
    case SwitchProxyMode
    // advanced settings
    case LocalSocksListenPort
    case EnableUDP
    case LocalHttpListenPort
    case LocalPacListenPort
    case AllowLAN
    case EnableSniffing
    case EnableMux
    case Mux
    case EnableTrafficStatistics
    case V2rayCoreLogLevel
    // pac settings
    case PacSettings
    case ConfigureProxyRules
    case GFWListDownloadURL
    case EnterGFWListURL
    case CustomRules
    case AddCustomRules
    case ViewPACFile
    case UpdatePAC
    case PACUpdatedByUserRules
    case PACUpdateFailed
    case PACUpdatedByGFWList
    case FailedToDownloadGFWList
    case FailedToWriteGFWList
    case FailedToUpdatePAC
    case UpdatingPACRules
    case PACUpdateError
    case PACUpdateSuccess
    case PACUpdateNotification
    // dns settings
    case DnsConfiguration
    case DnsJsonFormatTip
    case ViewConfiguration
    case Help
    case Notification
    // subscription form
    case SubscriptionSettings
    case SubscriptionSettingsSubHead
    case SubscriptionUrl
    case sort
    case updateInterval
    case AddSubscription
    case EditSubscription
    case SyncAllSubscriptionTitle
    case SyncSubscriptionTitle
    case SyncAllSubscriptionTip
    case SyncSubscriptionNow
    case SyncSubscriptionIng
    // routing settings
    case RoutingSettings
    case RoutingSettingsSubHead
    case AddRoutingRule
    case EditRoutingRule
    case domainStrategy
    case domainMatcher
    case Direct
    case Proxy
    case Block
    // Profile Settings
    case ProfileSettings
    case ProfileSettingsSubHead
    case `Protocol`
    case Address
    case Password
    case Method
    case Port
    case ID
    case UserID
    case AlterID
    case Security
    case Encryption
    case Network
    case HeaderType
    case HttpHost
    case HttpPath
    case WsHost
    case WsPath
    case DsPath
    case WsHeaders
    case Flow
    case TcpFastOpen
    case EnableTls
    case SkipCertVerify
    case TlsSettings
    case XtlsSettings
    case RealitySettings
    case ServerName
    case Key
    case Seed
    case Congestion
    case MTU
    case TTI
    case UplinkCapacity
    case DownloadCapacity
    case xhttpPath
    case xhttpHost
    case AllowInsecure
    case ProfileRemark
    case Sni
    case Fingerprint
    case PublicKey
    case ShortID
    case SpiderX
    case Alpn
    case TransportSettings
    case ServerSettings
    case StreamSettings
    // menu
    case CoreOn
    case CoreOff
    case TurnCoreOff
    case TurnCoreOn
    case ViewLog
    case ViewConfigJson
    case ViewPacFile
    case PacMode
    case GlobalMode
    case ManualMode
    case RoutingList
    case ServerList
    case goSubscriptionSettings
    case goRoutingSettings
    case goServerSettings
    case goPreferences
    case Ping
    case ImportServersFromClipboard
    case ScanQRCodeFromScreen
    case ShareQrCode
    case CopyHttpProxyShellExportLine
    case CheckForUpdates
    case Quit
    case On
    case Off
    // help page
    case HelpPageTitle
    case HelpPageSubHead
    case GithubIssues
    case Refresh
    case V2rayCoreSwitchStatus
    case V2rayCoreRunningStatus
    case BackgroundActivity
    case BackgroundActivitySubtitleRunning
    case BackgroundActivitySubtitleNotRunning
    case OpenSettings
    case Restart
    case PingState
    case RunPingNow
    case V2rayCoreInstallAndVersion
    case V2rayUToolPermission
    case GeoipFile
    case Installed
    case Missing
    case PermissionException
    case V2rayCoreNotInstalled
    case UnableToOpenSystemSettings
    case PleaseManuallyOpenBackgroundActivity
    case Fix
    case PingProblem
    // problem descriptions
    case V2rayUToolProblem
    case BackgroundProblem
    case GeoipProblem
    case V2rayCoreProblem
    case Diagnostics
    case QA
    case Abount
}
