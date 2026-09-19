#import "WattmanBatteryModel.h"

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

- (BOOL)isCharging {
    return _metrics.is_charging;
}

@end
