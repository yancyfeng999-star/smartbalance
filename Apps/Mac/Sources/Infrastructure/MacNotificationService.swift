import Foundation
import UserNotifications

/// macOS 系统通知。
public final class MacNotificationService: @unchecked Sendable {
    public static let shared = MacNotificationService()

    private let center = UNUserNotificationCenter.current()
    private var authorized = false

    public init() {}

    @MainActor
    public func requestAuthorizationIfNeeded() async {
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            authorized = false
        }
    }

    public func post(title: String, body: String, id: String = UUID().uuidString) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
