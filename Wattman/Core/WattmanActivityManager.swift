import ActivityKit
import Foundation

/// Bridge class cho phép Objective-C gọi ActivityKit
/// Tự động bắt đầu / cập nhật / kết thúc Live Activity khi trạng thái sạc thay đổi
///
/// NOTE: ActivityContent API (activity.content, end(_:dismissalPolicy:)) yêu cầu iOS 16.2+
/// Devices chạy iOS < 16.2 sẽ không có Live Activity (graceful fallback, không crash)
@objc public class WattmanActivityManager: NSObject {

    @objc public static let shared = WattmanActivityManager()

    @available(iOS 16.2, *)
    private var currentActivity: Activity<WattmanAttributes>?

    private override init() {
        super.init()
    }

    // MARK: - Public ObjC API

    /// Bắt đầu hoặc cập nhật Live Activity khi cắm sạc
    @objc public func startActivity(
        watts: Float,
        currentMa: Int,
        voltageMv: UInt,
        batteryPercent: Int,
        isCharging: Bool,
        timeToFullMin: Int,
        statusText: String
    ) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Nếu đã có activity đang chạy thì update thay vì tạo mới
        if currentActivity != nil {
            updateActivity(
                watts: watts,
                currentMa: currentMa,
                voltageMv: voltageMv,
                batteryPercent: batteryPercent,
                isCharging: isCharging,
                timeToFullMin: timeToFullMin,
                statusText: statusText
            )
            return
        }

        let state = WattmanAttributes.ContentState(
            watts: watts,
            currentMa: currentMa,
            voltageMv: voltageMv,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            timeToFullMin: timeToFullMin,
            statusText: statusText
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(60)
        )

        do {
            let activity = try Activity.request(
                attributes: WattmanAttributes(),
                content: content,
                pushType: nil
            )
            currentActivity = activity
            NSLog("[Wattman] Live Activity started: %@", activity.id)
        } catch {
            NSLog("[Wattman] Failed to start Live Activity: %@", error.localizedDescription)
        }
    }

    /// Cập nhật Live Activity với metrics mới (gọi mỗi giây từ poll timer)
    @objc public func updateActivity(
        watts: Float,
        currentMa: Int,
        voltageMv: UInt,
        batteryPercent: Int,
        isCharging: Bool,
        timeToFullMin: Int,
        statusText: String
    ) {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity else { return }

        let state = WattmanAttributes.ContentState(
            watts: watts,
            currentMa: currentMa,
            voltageMv: voltageMv,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            timeToFullMin: timeToFullMin,
            statusText: statusText
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(60)
        )

        Task {
            await activity.update(content)
        }
    }

    /// Kết thúc Live Activity (khi rút sạc)
    @objc public func endActivity() {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity else { return }
        // Dùng content hiện tại làm final state (iOS 16.2 API)
        let finalContent = activity.content
        Task {
            await activity.end(finalContent, dismissalPolicy: .immediate)
            NSLog("[Wattman] Live Activity ended")
        }
        currentActivity = nil
    }

    /// Kiểm tra Live Activities có khả dụng không (iOS 16.2+)
    @objc public var isAvailable: Bool {
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }
}
