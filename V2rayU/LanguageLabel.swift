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
    case Enable
    case Minute
    case Hour
    case Day
    case Save
    case Confirm
    case Cancel
    case Close
    case Reset
    case Remark
    case Edit
    case Preview
    case Delete
    case DeleteSelected
    case DeleteConfirm
    case DeleteSelectedConfirm
    case DeleteTip
    case OK
    case Add
    case Export
    case Select
    case Duplicate
    // profile share
    case Regenerate
    case Regenerated
    case Copy
    case Copied
    case CopyFailed
    case ShareProfile
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
    // updatePac 主流程提示
    case UpdatingPacRules = "UpdatingPacRules" // Updating Pac Rules ...
    case PacUpdatedByUserRules = "PacUpdatedByUserRules" // PAC has been updated by User Rules.
    case PacUpdateFailedByUserRules = "PacUpdateFailedByUserRules" // It's failed to update PAC by User Rules.
    case UpdatePacError = "UpdatePacError" // updatePac error: \(error)
    // GFWList 相关提示
    case InvalidGfwUrl = "InvalidGfwUrl" // Failed to download latest GFW List: url is not valid
    case GfwListDownloadFailed = "GfwListDownloadFailed" // Failed to download latest GFW List.
    case GfwListDownloadError = "GfwListDownloadError" // Failed to download latest GFW List: \(error)
    case GfwListWriteFailed = "GfwListWriteFailed" // Failed to write latest GFW List.
    case GfwListUpdated = "GfwListUpdated" // gfwList has been updated
    // PAC 更新提示
    case PacUpdatedByGfwList = "PacUpdatedByGfwList" // PAC has been updated by latest GFW List.
    case PacUpdateFailedByCurl = "PacUpdateFailedByCurl" // Failed to update PAC by curl method.
    // dns settings
    case DnsConfiguration
    case DnsJsonFormatTip
    case ViewConfiguration
    case Help
    case Notification
    case DnsInvalidUTF8 = "DnsInvalidUTF8" // Error: 输入内容无法编码为 UTF-8
    case DnsJSONFormatError = "DnsJSONFormatError" // Error: JSON 格式错误 - \(error.localizedDescription)
    case DnsFormatEncodingFail = "DnsFormatEncodingFail" // Error: 格式化后内容无法编码为字符串
    case DnsSaveSuccess = "DnsSaveSuccess" // DNS 配置保存成功
    case DnsSaveFail = "DnsSaveFail" // Error: 保存 DNS 配置失败 - \(error.localizedDescription)
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
    // 自定义规则填写说明
    case CustomRuleGuideTitle          // 标题: “自定义规则填写说明”
    case CustomRuleGuideDescription    // 说明: “每行填写一个规则，可为域名、IP 或 预定义列表。”
    case CustomRulePriorityDescription // 说明: “优先级: 域名阻断 -> 域名代理 -> ...”
    // 规则格式说明部分
    case CustomRuleDomainIntro         // “• 域名：”
    case CustomRuleDomainExample       // “如 example.com、*.google.com”
    case CustomRuleIPIntro             // “• IP：”
    case CustomRuleIPExample           // “如 8.8.8.8、192.168.0.0/16”
    case CustomRulePredefinedIntro     // “• 预定义：”
    case CustomRulePredefinedExample   // “如 geoip:private、geosite:cn、localhost”
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
    case Testing
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
    case FAQ
    case FaqSubtitle
    // table fields
    case TableFieldSort
    case TableFieldRemark
    case TableFieldUrl
    case TableFieldInterval
    case TableFieldUpdateTime
    case TableFieldType
    case TableFieldAddress
    case TableFieldPort
    case TableFieldLatency
    case TableFieldNetwork
    case TableFieldSecurity
    case TableFieldTodayDown
    case TableFieldTodayUp
    case TableFieldTotalDown
    case TableFieldTotalUp
    case TableFieldDomainStrategy
    case TableFieldDirect
    case TableFieldBlock
    case TableFieldProxy
    case SyncAll
    case SearchTip
    case AllGroup
    case SelectGroup
    case SelectAll
    case CopyURI
    case MoveToTop
    case MoveToBottom
    case MoveUp
    case MoveDown
    // about
    case Version
    case Build
    case CoreVersion
    case RelatedFileLocations
    case ClickAndOpenInFinder // 点击路径可在 Finder 打开
    case OpenInFinder // 在 Finder 打开
    case OpenSourceProject
    case OpenSourceLicense // 遵循 GNU GPL v3.0 许可协议
    case OpenSourceLibraries     // 引用开源库
    case UsedButNotLimitedTo     // 有用到且不限于以下
    case OpenInBrowser
    // core update
    case CoreSettingsTitle                // Core Settings
    case CoreSettingsSubtitle          // Manage your core versions
    // 基本操作
    case CheckLatestVersion             // 检查最新版本
    case LocalCoreDirectory             // 本地 Xray Core 目录
    case FileDirectory                        // 文件目录:
    case LocalCoreVersionDetail     // 本地 Xray Core 版本明细
    case GithubLatestVersion           // GitHub 最新版本
    case DownloadAndReplace             // 下载并替换
    // 下载弹窗
    case Downloading                            // 正在下载:
    case DownloadedStatus                 // 已下载: %@ / 总大小: %@
    case CancelDownload                     // 取消下载
    case DownloadHint                          // 下载提示
    case DownloadCanceled                  // 下载已取消
    case DownloadURLInvalid              // 下载地址错误: %@
    case ReplaceSuccess                      // 替换成功！
    case OperationFailed                   // 操作失败: %@
    case DownloadTimeoutError
    case DownloadSaveFailed
    case DownloadErrorOccurred
    case ClearLogFileFailed            // 清除日志文件失败
    case PortInUse                        // 端口已被占用
    case PortInUseTip                       // 端口已被占用, 请更换其他端口号。
    case Install  // 安装
    case InstallTitle                // 安装V2rayUTool工具
    case InstallPermissionTip  // "V2rayU 需要使用管理员权限安装 V2rayUTool 到 ~/.V2rayU/V2rayUTool"
    case InstallFailed                // 安装失败
    case InstallFailedTip // 安装 V2rayUTool 失败: %@
    case InstallFailedManual // 请手动运行安装脚本进行安装。
    case ReplaceCore                            // 替换Core
    case releaseNodesTitle // release Nodes
    case SkipVersion  //  skip Version
    case InstallUpdate  // install Update
    case CheckingForUpdates // Checking For Updates ...
    case InstallV2rayU // Install V2rayU
    case NewVersionTip  // "A new version (\(release.tagName)) is available!"
    case AlreadyLastestVersion  // Already Lastest Version
    case AlreadyLastestToast  // 当前 %@ 已经是最新版了
    case V2rayUUpdateTitle  // V2rayU Update
}
