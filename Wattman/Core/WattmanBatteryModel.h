#import <Foundation/Foundation.h>
#include "WattmanSMC.h"

NS_ASSUME_NONNULL_BEGIN

@protocol WattmanBatteryModelDelegate <NSObject>
- (void)batteryModelDidUpdateMetrics:(WattmanMetrics)metrics;
@end

@interface WattmanBatteryModel : NSObject

@property (nonatomic, weak) id<WattmanBatteryModelDelegate> delegate;
@property (nonatomic, readonly) WattmanMetrics currentMetrics;

// Formatted properties for UI
@property (nonatomic, readonly) NSString *wattageString;          // e.g. "18.5 W"
@property (nonatomic, readonly) NSString *voltageString;          // e.g. "4,180 mV (4.18 V)"
@property (nonatomic, readonly) NSString *currentString;          // e.g. "+2,250 mA" or "-450 mA"
@property (nonatomic, readonly) NSString *temperatureString;      // e.g. "31.4 °C"
@property (nonatomic, readonly) NSString *healthString;           // e.g. "94.2%"
@property (nonatomic, readonly) NSString *capacityString;         // e.g. "2,850 / 3,100 mAh"
@property (nonatomic, readonly) NSString *designCapacityString;   // e.g. "3,274 mAh"
@property (nonatomic, readonly) NSString *cycleCountString;       // e.g. "145 lần"
@property (nonatomic, readonly) NSString *stateOfChargeString;     // e.g. "74%"
@property (nonatomic, readonly) NSString *statusBadgeString;      // e.g. "⚡ Sạc nhanh USB-PD"
@property (nonatomic, readonly) NSString *sourceTypeString;       // e.g. "IOKit (IOPMPowerSource)"
@property (nonatomic, readonly) BOOL isCharging;

+ (instancetype)sharedModel;
- (void)startMonitoringWithInterval:(NSTimeInterval)interval;
- (void)stopMonitoring;
- (void)refreshImmediately;

@end

NS_ASSUME_NONNULL_END
