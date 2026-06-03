import Foundation
import OSLog
import UserNotifications
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

/// Thin wrapper around `UNUserNotificationCenter` for native macOS notifications.
///
/// Lives in the App target (not an SPM module) on purpose: `UNUserNotificationCenter.current()`
/// raises an exception when invoked from an unbundled executable (e.g. `swift run` / `swift test`),
/// so keeping this out of `BeadsWorkspace`/`BeadsContract` keeps the test suite safe.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Invoked when the user taps a notification. The argument is the `PendingLanding.id`
    /// encoded in the notification's `userInfo`. Wired up by the app entry point.
    var onLandingTapped: ((UUID) -> Void)?

    private let landingIDKey = "landingID"
    private let log = Logger(subsystem: "local.beads.workstation", category: "Notifications")

    private override init() {
        super.init()
    }

    /// `true` only when running inside a real app bundle. Guards every center access.
    private var isBundled: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    /// Registers self as the notification-center delegate (needed for foreground banners
    /// and tap handling). Safe to call once at startup.
    func setDelegate() {
        guard isBundled else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    /// Requests permission to show alerts + play sounds. No-op if already decided.
    func requestAuthorization() {
        guard isBundled else {
            log.error("requestAuthorization skipped: no bundle identifier (running unbundled)")
            return
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { [log] granted, error in
            if let error {
                log.error("requestAuthorization failed: \(error.localizedDescription, privacy: .public)")
            } else {
                log.info("requestAuthorization result: granted=\(granted, privacy: .public)")
            }
        }
        center.getNotificationSettings { [log] settings in
            log.info("authorizationStatus=\(settings.authorizationStatus.rawValue, privacy: .public)")
        }
    }

    /// Posts a notification for a finalized agent run. Only `needsReview` and `failed`
    /// produce a banner; other finalized states are intentionally silent.
    func notifyFinalized(landingID: UUID, issueID: String, issueTitle: String, status: AgentRunStatus) {
        guard isBundled else { return }

        let title: String
        let body: String
        switch status {
        case .needsReview:
            title = "✓ Siap di-review"
            body = "\(issueID) · \(issueTitle) telah dikerjakan — tolong di-review"
        case .failed:
            title = "⚠︎ Agent run gagal"
            body = "\(issueID) · \(issueTitle) gagal — perlu perhatian"
        case .prepared, .terminalOpened, .accepted, .abandoned:
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [landingIDKey: landingID.uuidString]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Posts a notification when the scheduler auto-launches an agent.
    func notifySchedulerLaunch(issueID: String, issueTitle: String, agentName: String) {
        guard isBundled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Agent Auto-Launched"
        content.body = "\(agentName) mulai mengerjakan \(issueID): \(issueTitle)"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the banner even when the app is frontmost (macOS suppresses it otherwise).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handle a notification tap: hop to the main actor and route the landing ID.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let raw = info["landingID"] as? String, let id = UUID(uuidString: raw) {
            Task { @MainActor in
                self.onLandingTapped?(id)
            }
        }
        completionHandler()
    }
}
