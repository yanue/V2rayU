//
//  Language.swift
//  V2rayU
//
//  Created by yanue on 2024/12/19.
//

import SwiftUI

// MARK: - 多语言本地化标签枚举
enum LanguageLabel: String, CaseIterable {
    // MARK: - Language & Theme
    case Language
    case Theme
    case Light
    case Dark
    case FollowSystem

    // MARK: - Base Operations
    case Enable
    case Minute
    case Hour
    case Day
    case Save
    case Saved
    case Total
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
    case DeleteMultipleConfirm
    case OK
    case Add
    case Export
    case Select
    case SetActive
    case Duplicate
    case Regenerate
    case Regenerated
    case Generate
    case Generated
    case Copy
    case Copied
    case CopyFailed
    case ShareProfile

    // MARK: - App Content
    case Activity
    case ActivitySubHead
    case Servers
    case ServerSubHead
    case Subscriptions
    case SubscriptionSubHead
    case Routings
    case RoutingSubHead
    case Settings
    case SettingsSubHead
    case About
    case AboutSubHead
    case AboutAppIntroduction

    // MARK: - Settings Tabs
    case General
    case Shortcuts
    case Advanced
    case PAC
    case DNS
    case Core

    // MARK: - General Settings
    case LaunchAtLogin
    case CheckForUpdateAutomatically
    case AutoUpdateServersFromSubscriptions
    case AutomaticallySelectFastestServer
    case ShowProxySpeedOnTrayIcon
    case ShowLatencyOnTrayIcon
    case EnableProxyStatistics
    case KeyboardShortcuts
    case Toggle
    case ProxyModes
    case View
    case Tools
    case ToggleV2rayOnOff
    case SwitchProxyMode
    case SwitchToTunnelMode
    case SwitchToGlobalMode
    case SwitchToManualMode
    case SwitchToPacMode

    // MARK: - Advanced Settings
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

    // MARK: - PAC Settings
    case PacSettings
    case ConfigureProxyRules
    case GFWListDownloadURL
    case EnterGFWListURL
    case CustomRules
    case AddCustomRules
    case ViewPACFile
    case UpdatePAC
    case PACUpdateNotification

    // MARK: - PAC Notifications & Errors
    case UpdatingPacRules
    case PacUpdatedByUserRules
    case PacUpdateFailedByUserRules
    case UpdatePacError
    case InvalidGfwUrl
    case GfwListDownloadFailed
    case GfwListDownloadError
    case GfwListWriteFailed
    case GfwListUpdated
    case PacUpdatedByGfwList
    case PacUpdateFailedByCurl

    // MARK: - DNS Settings
    case DnsConfiguration
    case DnsJsonFormatTip
    case ViewConfiguration
    case Help
    case Notification
    case DnsInvalidUTF8
    case DnsJSONFormatError
    case DnsFormatEncodingFail
    case DnsSaveSuccess
    case DnsSaveFail

    // MARK: - Subscription Settings
    case SubscriptionSettings
    case SubscriptionSettingsSubHead
    case SubscriptionUrl
    case Sort
    case UpdateInterval
    case AddSubscription
    case EditSubscription
    case SyncAllSubscriptionTitle
    case SyncSubscriptionTitle
    case SyncAllSubscriptionTip
    case SyncSubscriptionNow
    case SyncSubscriptionIng

    // MARK: - Routing Settings
    case RoutingSettings
    case RoutingSettingsSubHead
    case AddRoutingRule
    case EditRoutingRule
    case DomainStrategy
    case DomainMatcher
    case Direct
    case Proxy
    case Block

    // MARK: - Custom Rules Guide
    case CustomRuleGuideTitle
    case CustomRuleGuideDescription
    case CustomRulePriorityDescription
    case CustomRuleDomainIntro
    case CustomRuleDomainExample
    case CustomRuleIPIntro
    case CustomRuleIPExample
    case CustomRulePredefinedIntro
    case CustomRulePredefinedExample

    // MARK: - Profile Settings
    case ProfileSettings
    case ProfileSettingsSubHead
    case `Protocol`
    case Address
    case Username
    case Password
    case OptionalFieldTip
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
    case XhttpPath
    case XhttpHost
    case AllowInsecure
    case ProfileRemark
    case Sni
    case Fingerprint
    case PublicKey
    case ShortID
    case SpiderX
    case Extra
    case Alpn
    case TransportSettings
    case ServerSettings
    case StreamSettings

    // MARK: - Hysteria2 Settings
    case Hysteria2Configuration
    case ObfuscationSettings
    case ObfsType
    case ObfsPassword
    case AuthenticationSettings
    case AuthType
    case None
    case Token
    case AuthPassword
    case BandwidthSettings
    case UploadBandwidth
    case DownloadBandwidth
    case AdvancedSettings
    case HopInterval

    // MARK: - Menu Operations
    case CoreOn
    case CoreOff
    case TurnCoreOff
    case TurnCoreOn
    case ViewCoreLog
    case ViewTunLog
    case ViewFiles
    case ViewErrorLog
    case ViewLogFiles
    case ClearAllLogs
    case OpenHomeFolder
    case Logs
    case ViewConfigJson
    case ViewTunJson
    case ViewPacFile
    case PacMode
    case GlobalMode
    case ManualMode
    case TunMode
    case RoutingList
    case ServerList
    case GoSubscriptionSettings
    case GoRoutingSettings
    case GoServerSettings
    case GoPreferences
    case LatencyTest
    case Testing
    case ImportServersFromClipboard
    case ScanQRCodeFromScreen
    case ShareQrCode
    case CopyHttpProxyShellExportLine
    case CheckForUpdates
    case Quit
    case On
    case Off

    // MARK: - Help & Diagnostics
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
    case V2rayUToolProblem
    case BackgroundProblem
    case GeoipProblem
    case V2rayCoreProblem
    case Diagnostics
    case DiagnosticSubHead
    case FAQ
    case FaqSubtitle
    case SubmitIssue
    case RunDiagnostic

    // MARK: - Table Fields
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
    case DefaultGroup
    case SelectGroup
    case SelectAll
    case CopyURI
    case MoveToTop
    case MoveToBottom
    case MoveUp
    case MoveDown

    // MARK: - About Page
    case Version
    case Build
    case CoreVersion
    case RelatedFileLocations
    case ClickAndOpenInFinder
    case OpenInFinder
    case OpenSourceProject
    case OpenSourceLicense
    case OpenSourceLibraries
    case UsedButNotLimitedTo
    case OpenInBrowser
    case Copyright
    case AllRightsReserved
    case ErrorLog
    case LogFile
    case SelectLogFile
    case OKButton
    case CloseButton
    case Selected
    case Proxies
    case PingAllProxies

    // MARK: - Core Update Management
    case CoreSettingsTitle
    case CoreSettingsSubtitle
    case CheckLatestVersion
    case FetchReleases
    case CoreInfo
    case Architecture
    case CurrentVersion
    case PreviousPage
    case NextPage
    case PageIndicator
    case AvailableVersions
    case UpdateCore
    case LocalCoreDirectory
    case FileDirectory
    case LocalCoreVersionDetail
    case GithubLatestVersion
    case DownloadAndReplace
    case Downloading
    case DownloadedStatus
    case CancelDownload
    case DownloadHint
    case DownloadCanceled
    case DownloadURLInvalid
    case ReplaceSuccess
    case OperationFailed
    case DownloadTimeoutError
    case DownloadSaveFailed
    case DownloadErrorOccurred
    case ClearLogFileFailed
    case PortInUse
    case PortInUseTip
    case Install
    case InstallTitle
    case InstallFailed
    case InstallFailedManual
    case ReplaceCore
    case ReleaseNotesTitle
    case SkipVersion
    case InstallUpdate
    case CheckingForUpdates
    case InstallV2rayU
    case NewVersionTip
    case AlreadyLatestVersion
    case AlreadyLatestToast
    case V2rayUUpdateTitle

    // MARK: - FAQ
    case FaqHowItWorks
    case FaqConfigLocation
    case FaqOperationModes
    case FaqModeRoutingRelation
    case FaqRoutingPriority
    case FaqTrueGlobalProxy
    case FaqManualCoreUpdate
    case FaqHowItWorksDetail
    case FaqConfigLocationDetail2
    case FaqOperationModesDetail2
    case FaqModeRoutingRelationDetail
    case FaqRoutingPriorityDetail2
    case FaqTrueGlobalProxyDetail2
    case FaqManualCoreUpdateDetail2

    // MARK: - Diagnostics - Check Item Titles
    case DiagNetworkConnectivity
    case DiagSystemProxy
    case DiagFirewall
    case DiagCoreRunning
    case DiagLaunchdProcess
    case DiagLocalPortConflict
    case DiagPingLatency
    case DiagLogAnalysis
    case DiagVPNConflict
    case DiagBasicNetwork
    case DiagProxyConnectivity

    // MARK: - Diagnostics - Merged File Check Titles
    case DiagAppDataDir
    case DiagV2rayUTool
    case DiagXrayCore
    case DiagSingBox
    case DiagUpdateScript
    case DiagSudoersCheck
    case DiagTunDaemon
    case DiagConfigCheck
    case DiagGeoDataFiles

    // MARK: - Diagnostics - Status
    case DiagPending
    case DiagChecking
    case DiagPassed
    case DiagFailed

    // MARK: - Diagnostics - Problem Descriptions
    case DiagNetUnavailable
    case DiagNetDNSFailed
    case DiagNetIPFailed
    case DiagProxyNotEnabled
    case DiagProxyPortWrong
    case DiagProxyPortMismatch
    case DiagFirewallBlocked
    case DiagCoreNotInstalled
    case DiagCoreNotExecutable
    case DiagCoreNotRunning
    case DiagCoreStopped
    case DiagCoreStartFailed
    case DiagLaunchdNotLoaded
    case DiagLaunchdNotRunning
    case DiagLaunchdRunning
    case DiagLaunchdReload
    case DiagToolMissing
    case DiagToolNoPermission
    case DiagConfigNotExist
    case DiagConfigInvalid
    case DiagConfigMissingField
    case DiagNodeNotSelected
    case DiagDNSResolveFailed
    case DiagPortConnectFailed
    case DiagPortOccupied
    case DiagGeoipMissing
    case DiagLatencyHigh
    case DiagLatencyFailed
    case DiagBasicNetworkFailed
    case DiagProxyConnectFailed
    case DiagProxyConnectOK
    case DiagBasicNetworkOK
    case DiagConfigValidOK
    case DiagConfigValidProblems
    case DiagSystemProxyOK
    case DiagSystemProxyNotNeeded
    case DiagReportCopied
    case DiagReportTooLong

    // MARK: - Diagnostics - Actions
    case DiagOpenNetworkSettings
    case DiagFixNow
    case DiagRestartCore
    case DiagStartCore
    case DiagCheckNetwork
    case DiagViewConfig
    case DiagReTest

    // MARK: - Diagnostics - Special Modes
    case DiagProxyNotNeededTunnel
    case DiagProxyNotNeededManual
    case DiagProxyNotNeededOff
    case DiagProxyRequired

    // MARK: - Diagnostics - Core Architecture
    case DiagCoreArchCorrect
    case DiagCoreArchMismatch

    // MARK: - Diagnostics - Files (merged items)
    case DiagSingBoxNotExecutable
    case DiagSingBoxNotInstalled
    case DiagSingBoxArchMismatch
    case DiagUpdateScriptMissing
    case DiagUpdateScriptNoPermission
    case DiagSudoersFileMissing
    case DiagSudoersNotEffective
    case DiagTunDaemonMissing
    case DiagConfigFileExists
    case DiagConfigFileMissing
    case DiagConfigFileEmpty
    case DiagGeositeMissing

    // MARK: - Diagnostics - Sub-check labels
    case DiagSubFileExists
    case DiagSubExecutable
    case DiagSubNotExecutable
    case DiagSubRootAdmin
    case DiagSubNotRootAdmin
    case DiagSubSetuid
    case DiagSubNoSetuid
    case DiagSubNoQuarantine
    case DiagSubQuarantined
    case DiagSubVersionTooOld
    case DiagSubVersionUnknown
    case DiagToolVersionOld
    case DiagToolNoSetuid
    case DiagFileQuarantined
    case DiagSubDirExists
    case DiagSubDirWritable
    case DiagSubDirNotWritable
    case DiagSubDirOwnerOK
    case DiagSubDirOwnerWrong
    case DiagSubDbExists
    case DiagSubDbNotExists
    case DiagSubDbWritable
    case DiagSubDbReadonly

    // MARK: - Diagnostics - AppDataDir Problems
    case DiagAppDataDirMissing
    case DiagAppDataDirNotWritable
    case DiagAppDataDirOwnerWrong
    case DiagDbReadonly

    // MARK: - Legacy Migration
    case ImportLegacyData
    case ImportLegacyDataTitle
    case ImportLegacyDataTip
    case LegacyDataMigrated
    case LegacyDataMigrationSuccess
    case LegacyDataMigrationFailed
    case LegacyDataMigrationNoData
    case ImportLegacyDataMigrating
    case ImportLegacyDataDetected
    case ImportLegacyDataNoData
    case ImportLegacyDataServerCount
    case ImportLegacyDataSubCount
    case ImportLegacyConfirmTitle
    case ImportLegacyConfirmMessage
    case ImportLegacyDetectedKeys
    case ImportLegacyServerList
    case ImportLegacySubList
    case ImportLegacyMigratingStart
    case ImportLegacyMigratingComplete
    case ImportLegacyNoDataFound
    case ImportLegacyMigrationFailed
    case ImportLegacyItemsRemaining
    case ImportLegacyV2rayServerList
    case ImportLegacyV2raySubList
    case ImportLegacySuccessServers
    case ImportLegacySuccessSubscriptions
    case RemoveDuplicateServers
    case RemoveDuplicateConfirm
    case RemoveDuplicateConfirmTip
}
