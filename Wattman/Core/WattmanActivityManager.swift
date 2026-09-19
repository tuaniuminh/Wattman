import ActivityKit
import Foundation

/// Bridge class cho phép Objective-C gọi ActivityKit
/// Tự động bắt đầu / cập nhật / kết thúc Live Activity khi trạng thái sạc thay đổi
@objc public class WattmanActivityManager: NSObject {

    @objc public static let shared = WattmanActivityManager()

    private var currentActivity: Activity<WattmanAttributes>?

    private override init() {
        super.init()
    }

    // MARK: - Public ObjC API

    /// Bắt đầu Live Activity khi cắm sạc
    @objc public func startActivity(
        watts: Float,
        currentMa: Int,
        voltageMv: UInt,
        batteryPercent: Int,
        isCharging: Bool,
        timeToFullMin: Int,
        statusText: String
    ) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NSLog("[Wattman] Live Activities not enabled on this device")
            return
        }

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
            staleDate: Date().addingTimeInterval(60) // stale sau 60 giây không update
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
        guard #available(iOS 16.1, *) else { return }
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
        guard #available(iOS 16.1, *) else { return }
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            NSLog("[Wattman] Live Activity ended")
        }
        currentActivity = nil
    }

    /// Kiểm tra Live Activities có khả dụng không
    @objc public var isAvailable: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }
}
