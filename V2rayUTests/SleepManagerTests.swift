import AppKit
import Testing
@testable import V2rayU

@Suite struct SystemSleepManagerTests {
    @Test("Sleep and wake observers use the workspace notification center")
    func usesWorkspaceNotificationCenter() {
        #expect(
            SystemSleepManager.workspaceNotificationCenter
                === NSWorkspace.shared.notificationCenter
        )
        #expect(
            SystemSleepManager.workspaceNotificationCenter
                !== NotificationCenter.default
        )
    }
}
