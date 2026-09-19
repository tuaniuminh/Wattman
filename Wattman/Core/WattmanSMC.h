#ifndef WattmanSMC_h
#define WattmanSMC_h

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Cấu trúc dữ liệu đo đạc pin & công suất thời gian thực
typedef struct {
    // Thông số điện năng tức thời
    uint16_t voltage_mv;        // Điện áp (mV)
    int16_t  current_ma;        // Dòng sạc/xả (mA): Dương (+) là đang sạc, Âm (-) là đang xả
    int32_t  power_mw;          // Công suất (mW)
    float    wattage;           // Công suất tức thời (W) = (voltage * |current|) / 1,000,000
    
    // Nhiệt độ
    float    temperature_c;     // Nhiệt độ pin (°C)
    
    // Dung lượng (mAh)
    uint16_t remaining_cap_mah; // Dung lượng còn lại
    uint16_t full_charge_cap_mah; // Dung lượng tối đa hiện tại (FCC)
    uint16_t design_cap_mah;    // Dung lượng thiết kế ban đầu
    uint16_t qmax_mah;          // Dung lượng hóa học tối đa Qmax
    
    // Tỷ lệ phần trăm
    uint16_t state_of_charge;   // % Pin thực tế từ IC (0-100)
    float    battery_health;    // % Sức khỏe pin = (FCC / DesignCap) * 100
    
    // Tuổi thọ & chu kỳ
    uint16_t cycle_count;       // Số chu kỳ sạc (lần)
    uint16_t time_to_empty_min; // Ước tính thời gian còn lại (phút)
    
    // Nguồn sạc ngoài (External Power)
    bool     is_charging;           // Thiết bị đang nhận sạc
    bool     adapter_connected;     // Có cắm củ sạc / cáp
    char     adapter_desc[64];      // Mô tả nguồn sạc (USB-PD, Apple Adapter, MagSafe, etc.)
    char     adapter_name[48];      // Tên củ sạc (ví dụ: "Apple 20W USB-C Power Adapter")
    char     adapter_manufacturer[32]; // Hãng sản xuất (ví dụ: "Apple")
    uint16_t adapter_watts;         // Công suất định mức củ sạc (W)
    uint16_t adapter_voltage_mv;    // Điện áp ngõ ra củ sạc (mV)
    int32_t  adapter_current_ma;    // Dòng điện ngõ ra củ sạc (mA)
    
    // Thời gian ước tính
    uint16_t time_to_full_min;      // Ước tính thời gian sạc đầy (phút), 0 nếu không xác định
    
    char     source_type[64];       // Nguồn dữ liệu (IOPMPowerSource / AppleSMC)
} WattmanMetrics;

// Khởi tạo và kiểm tra kết nối phần cứng
bool wattman_smc_init(void);

// Đọc toàn bộ snapshot thông số pin thời gian thực
bool wattman_smc_read_metrics(WattmanMetrics *metrics);

// Đóng kết nối phần cứng
void wattman_smc_close(void);

#ifdef __cplusplus
}
#endif

#endif /* WattmanSMC_h */
