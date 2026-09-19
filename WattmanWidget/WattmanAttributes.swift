import ActivityKit
import Foundation

/// Định nghĩa dữ liệu cho Live Activity của Wattman
/// Cập nhật mỗi giây từ main app qua ActivityKit
struct WattmanAttributes: ActivityAttributes {
    public typealias WattmanStatus = ContentState

    /// Trạng thái thay đổi theo thời gian thực (cập nhật liên tục)
    public struct ContentState: Codable, Hashable {
        /// Công suất tức thời (W) = voltage_mv * |current_ma| / 1_000_000
        var watts: Float
        /// Dòng điện (mA): dương = đang sạc, âm = đang xả
        var currentMa: Int
        /// Điện áp pin (mV)
        var voltageMv: UInt
        /// % pin hiện tại (từ iOS, 0-100)
        var batteryPercent: Int
        /// Thiết bị đang nhận sạc
        var isCharging: Bool
        /// Phút còn lại để đầy (0 = không xác định)
        var timeToFullMin: Int
        /// Mô tả ngắn trạng thái (ví dụ: "⚡ Sạc nhanh", "🔋 Đang dùng pin")
        var statusText: String
    }

    /// Thông tin tĩnh (không đổi trong suốt vòng đời activity)
    var bundleID: String = "com.tuaniuminh.Wattman"
}
