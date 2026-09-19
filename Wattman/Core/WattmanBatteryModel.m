#import "WattmanBatteryModel.h"

// Import Swift-generated header để gọi WattmanActivityManager
// File này được tạo tự động bởi Swift compiler khi build
#if __has_include("Wattman-Swift.h")
#import "Wattman-Swift.h"
#define WATTMAN_HAS_ACTIVITY_MANAGER 1
#else
#define WATTMAN_HAS_ACTIVITY_MANAGER 0
#endif

@interface WattmanBatteryModel () {
    WattmanMetrics _metrics;
}
@property (nonatomic, strong) NSTimer *pollTimer;
@end

@implementation WattmanBatteryModel

+ (instancetype)sharedModel {
    static WattmanBatteryModel *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[WattmanBatteryModel alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        wattman_smc_init();
        [self refreshImmediately];
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
    wattman_smc_close();
}

- (void)startMonitoringWithInterval:(NSTimeInterval)interval {
    [self stopMonitoring];
    
    [self refreshImmediately];
    self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                      target:self
                                                    selector:@selector(pollTimerTick)
                                                    userInfo:nil
                                                     repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.pollTimer forMode:NSRunLoopCommonModes];
}

- (void)stopMonitoring {
    if (self.pollTimer) {
        [self.pollTimer invalidate];
        self.pollTimer = nil;
    }
}

- (void)pollTimerTick {
    [self refreshImmediately];
}

- (void)refreshImmediately {
    WattmanMetrics newMetrics;
    if (wattman_smc_read_metrics(&newMetrics)) {
        _metrics = newMetrics;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(batteryModelDidUpdateMetrics:)]) {
                [self.delegate batteryModelDidUpdateMetrics:self->_metrics];
            }
            
#if WATTMAN_HAS_ACTIVITY_MANAGER
            // Cập nhật hoặc bắt đầu Live Activity
            WattmanActivityManager *mgr = [WattmanActivityManager shared];
            if (mgr.isAvailable) {
                // Tạo status text
                NSString *status;
                if (self->_metrics.current_ma > 30) {
                    status = self->_metrics.wattage >= 15.0f ? @"⚡ Sạc nhanh USB-PD" : @"🔌 Đang nhận sạc";
                } else if (self->_metrics.adapter_connected) {
                    status = @"✅ Pin đầy / Bypass";
                } else {
                    status = @"🔋 Đang dùng pin";
                }
                
                BOOL shouldBeActive = self->_metrics.adapter_connected || self->_metrics.is_charging;
                
                if (shouldBeActive) {
                    [mgr startActivityWithWatts:self->_metrics.wattage
                                     currentMa:(NSInteger)self->_metrics.current_ma
                                     voltageMv:(NSUInteger)self->_metrics.voltage_mv
                                batteryPercent:(NSInteger)self->_metrics.state_of_charge
                                    isCharging:self->_metrics.is_charging
                                 timeToFullMin:(NSInteger)self->_metrics.time_to_full_min
                                    statusText:status];
                } else {
                    [mgr endActivity];
                }
            }
#endif
        });
    }
}

- (WattmanMetrics)currentMetrics {
    return _metrics;
}

#pragma mark - Formatted Getters

- (NSString *)wattageString {
    return [NSString stringWithFormat:@"%.2f W", _metrics.wattage];
}

- (NSString *)voltageString {
    float volts = (float)_metrics.voltage_mv / 1000.0f;
    return [NSString stringWithFormat:@"%u mV (%.2f V)", _metrics.voltage_mv, volts];
}

- (NSString *)currentString {
    if (_metrics.current_ma > 0) {
        return [NSString stringWithFormat:@"+%d mA (Đang nạp)", _metrics.current_ma];
    } else if (_metrics.current_ma < 0) {
        return [NSString stringWithFormat:@"%d mA (Đang xả)", _metrics.current_ma];
    }
    return @"0 mA (Nghỉ)";
}

- (NSString *)temperatureString {
    if (_metrics.temperature_c <= 0.0f) {
        return @"Đang đo...";
    }
    return [NSString stringWithFormat:@"%.1f °C", _metrics.temperature_c];
}

- (NSString *)healthString {
    if (_metrics.battery_health <= 0.0f) {
        return @"Chưa xác định";
    }
    return [NSString stringWithFormat:@"%.1f%%", _metrics.battery_health];
}

- (NSString *)capacityString {
    if (_metrics.remaining_cap_mah == 0 && _metrics.full_charge_cap_mah == 0) {
        return @"Đang đọc...";
    }
    return [NSString stringWithFormat:@"%u / %u mAh", _metrics.remaining_cap_mah, _metrics.full_charge_cap_mah];
}

- (NSString *)designCapacityString {
    if (_metrics.design_cap_mah == 0) {
        return @"Đang đọc...";
    }
    return [NSString stringWithFormat:@"%u mAh", _metrics.design_cap_mah];
}

- (NSString *)cycleCountString {
    return [NSString stringWithFormat:@"%u lần", _metrics.cycle_count];
}

- (NSString *)stateOfChargeString {
    return [NSString stringWithFormat:@"%u%%", _metrics.state_of_charge];
}

- (NSString *)statusBadgeString {
    if (_metrics.current_ma > 30 || _metrics.is_charging) {
        if (_metrics.wattage >= 15.0f) {
            return @"⚡ Sạc nhanh USB-PD";
        }
        return @"🔌 Đang nhận sạc";
    } else if (_metrics.adapter_connected) {
        return @"🛑 Cắm sạc (Bypass/Đầy)";
    }
    return @"🔋 Đang dùng pin";
}

- (NSString *)sourceTypeString {
    if (strlen(_metrics.source_type) > 0) {
        return [NSString stringWithUTF8String:_metrics.source_type];
    }
    return @"IOKit (Phần cứng)";
}

- (NSString *)adapterDetailString {
    // Hiển thị tên củ sạc và thông số điện
    NSMutableString *detail = [NSMutableString string];
    
    if (_metrics.adapter_name[0] != '\0') {
        [detail appendFormat:@"%s", _metrics.adapter_name];
    }
    
    if (_metrics.adapter_voltage_mv > 0 && _metrics.adapter_current_ma > 0) {
        float volt = (float)_metrics.adapter_voltage_mv / 1000.0f;
        float curr = fabsf((float)_metrics.adapter_current_ma) / 1000.0f;
        if (detail.length > 0) [detail appendString:@"\n"];
        [detail appendFormat:@"%.1fV / %.2fA", volt, curr];
        if (_metrics.adapter_watts > 0) {
            [detail appendFormat:@" (%dW)", _metrics.adapter_watts];
        }
    } else if (_metrics.adapter_watts > 0) {
        if (detail.length > 0) [detail appendString:@" "];
        [detail appendFormat:@"(%dW)", _metrics.adapter_watts];
    }
    
    if (detail.length == 0) {
        // Fallback: dùng adapter_desc
        if (_metrics.adapter_desc[0] != '\0') {
            return [NSString stringWithUTF8String:_metrics.adapter_desc];
        }
        return _metrics.adapter_connected ? @"Đã kết nối" : @"Không có";
    }
    return [detail copy];
}

- (NSString *)timeToFullString {
    if (_metrics.is_charging || _metrics.current_ma > 30) {
        if (_metrics.time_to_full_min > 0) {
            uint16_t h = _metrics.time_to_full_min / 60;
            uint16_t m = _metrics.time_to_full_min % 60;
            if (h > 0) {
                return [NSString stringWithFormat:@"~%u giờ %u phút để đầy", h, m];
            } else {
                return [NSString stringWithFormat:@"~%u phút để đầy", m];
            }
        }
        return @"Đang tính...";
    }
    // Không đang sạc — hiển thị thời gian xả
    if (_metrics.time_to_empty_min > 0 && _metrics.time_to_empty_min < 1440) {
        uint16_t h = _metrics.time_to_empty_min / 60;
        uint16_t m = _metrics.time_to_empty_min % 60;
        return [NSString stringWithFormat:@"Còn ~%u giờ %u phút", h, m];
    }
    return _metrics.adapter_connected ? @"Bypass / Đầy" : @"Không xác định";
}

- (BOOL)isCharging {
    return _metrics.is_charging;
}

@end
