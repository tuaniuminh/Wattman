#include "WattmanSMC.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#if __has_include(<mach/mach.h>)
#include <mach/mach.h>
#else
typedef unsigned int mach_port_t;
extern mach_port_t mach_task_self_;
#define mach_task_self() mach_task_self_
#define MACH_PORT_NULL 0
#endif

// IOKit dynamic definitions
typedef mach_port_t io_object_t;
typedef io_object_t io_service_t;
typedef io_object_t io_connect_t;
typedef io_object_t io_registry_entry_t;
typedef int IOReturn;
typedef int kern_return_t;

#define kIOReturnSuccess 0
#define IO_OBJECT_NULL ((io_object_t)0)

extern CFMutableDictionaryRef IOServiceMatching(const char *);
extern io_service_t IOServiceGetMatchingService(mach_port_t, CFDictionaryRef);
extern kern_return_t IOServiceOpen(io_service_t, mach_port_t, uint32_t, io_connect_t *);
extern kern_return_t IOServiceClose(io_connect_t);
extern kern_return_t IOConnectCallStructMethod(mach_port_t, uint32_t, const void *, size_t, void *, size_t *);
extern kern_return_t IORegistryEntryCreateCFProperties(io_registry_entry_t, CFMutableDictionaryRef *, CFAllocatorRef, uint32_t);
extern kern_return_t IOObjectRelease(io_object_t);

// IOPowerSources API (IOKit)
extern CFTypeRef IOPSCopyPowerSourcesInfo(void);
extern CFArrayRef IOPSCopyPowerSourcesList(CFTypeRef blob);
extern CFDictionaryRef IOPSGetPowerSourceDescription(CFTypeRef blob, CFTypeRef ps);

// SMC Definitions
typedef uint32_t SMCKey;
typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t dataAttributes;
} SMCKeyInfoData;

typedef struct {
    SMCKey key;
    struct {
        unsigned char vers[6];
        uint16_t pLimitData[8];
        SMCKeyInfoData keyInfo;
        uint8_t result;
        uint8_t status;
        uint8_t data8;
        uint32_t data32;
        unsigned char bytes[120];
    } param;
} SMCParamStruct;

#define kSMCHandleYPCEvent 2
#define kSMCReadKey 5
#define kSMCGetKeyInfo 9

static io_connect_t gSMCConnection = IO_OBJECT_NULL;
static bool gSMCInitialized = false;
static bool gHasSMC = false;

#pragma mark - Helper Functions

static int cf_get_int(CFDictionaryRef dict, CFStringRef key, int default_val) {
    if (!dict) return default_val;
    CFTypeRef val = CFDictionaryGetValue(dict, key);
    if (!val) return default_val;
    if (CFGetTypeID(val) == CFNumberGetTypeID()) {
        int num = 0;
        if (CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &num)) {
            return num;
        }
    }
    return default_val;
}

static int64_t cf_get_int64(CFDictionaryRef dict, CFStringRef key, int64_t default_val) {
    if (!dict) return default_val;
    CFTypeRef val = CFDictionaryGetValue(dict, key);
    if (!val) return default_val;
    if (CFGetTypeID(val) == CFNumberGetTypeID()) {
        int64_t num = 0;
        if (CFNumberGetValue((CFNumberRef)val, kCFNumberSInt64Type, &num)) {
            return num;
        }
    }
    return default_val;
}

static bool cf_get_bool(CFDictionaryRef dict, CFStringRef key, bool default_val) {
    if (!dict) return default_val;
    CFTypeRef val = CFDictionaryGetValue(dict, key);
    if (!val) return default_val;
    if (CFGetTypeID(val) == CFBooleanGetTypeID()) {
        return CFBooleanGetValue((CFBooleanRef)val);
    }
    if (CFGetTypeID(val) == CFNumberGetTypeID()) {
        int num = 0;
        CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &num);
        return num != 0;
    }
    return default_val;
}

static bool cf_get_string(CFDictionaryRef dict, CFStringRef key, char *buf, size_t buf_len) {
    if (!dict || !buf || buf_len == 0) return false;
    CFTypeRef val = CFDictionaryGetValue(dict, key);
    if (!val) return false;
    if (CFGetTypeID(val) == CFStringGetTypeID()) {
        return CFStringGetCString((CFStringRef)val, buf, (CFIndex)buf_len, kCFStringEncodingUTF8);
    }
    return false;
}

#pragma mark - AppleSMC Low Level

static IOReturn smc_call(int index, SMCParamStruct *input, SMCParamStruct *output) {
    if (gSMCConnection == IO_OBJECT_NULL) return -1;
    size_t inSize = sizeof(SMCParamStruct);
    size_t outSize = sizeof(SMCParamStruct);
    return IOConnectCallStructMethod(gSMCConnection, index, input, inSize, output, &outSize);
}

static IOReturn smc_read_key(SMCKey key, void *buffer, size_t buffer_size) {
    if (!gHasSMC || gSMCConnection == IO_OBJECT_NULL) return -1;
    
    SMCParamStruct input = {0};
    SMCParamStruct output = {0};
    input.key = key;
    input.param.data8 = kSMCGetKeyInfo;
    
    IOReturn ret = smc_call(kSMCHandleYPCEvent, &input, &output);
    if (ret != kIOReturnSuccess || output.param.keyInfo.dataSize == 0) {
        return -1;
    }
    
    input.param.data8 = kSMCReadKey;
    input.param.keyInfo = output.param.keyInfo;
    
    ret = smc_call(kSMCHandleYPCEvent, &input, &output);
    if (ret == kIOReturnSuccess) {
        size_t copy_size = output.param.keyInfo.dataSize < buffer_size ? output.param.keyInfo.dataSize : buffer_size;
        memcpy(buffer, output.param.bytes, copy_size);
        return kIOReturnSuccess;
    }
    return ret;
}

#pragma mark - Initialization

bool wattman_smc_init(void) {
    if (gSMCInitialized) return gHasSMC;
    gSMCInitialized = true;
    
    // Truy cập trực tiếp cổng chính (0 / kIOMainPortDefault) mà không qua IOMasterPort
    io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSMC"));
    if (service != IO_OBJECT_NULL) {
        kern_return_t ret = IOServiceOpen(service, mach_task_self(), 0, &gSMCConnection);
        IOObjectRelease(service);
        if (ret == kIOReturnSuccess && gSMCConnection != IO_OBJECT_NULL) {
            gHasSMC = true;
            return true;
        }
    }
    
    gHasSMC = false;
    return false;
}

void wattman_smc_close(void) {
    if (gSMCConnection != IO_OBJECT_NULL) {
        IOServiceClose(gSMCConnection);
        gSMCConnection = IO_OBJECT_NULL;
    }
    gSMCInitialized = false;
    gHasSMC = false;
}

#pragma mark - Core Metric Extraction

// Đọc dữ liệu pin từ IOPMPowerSource và AppleSmartBattery
static bool read_from_iopm_powersource(WattmanMetrics *metrics) {
    if (!metrics) return false;
    
    // Tìm kiếm các service quản lý nguồn pin trong IOKit
    io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching("IOPMPowerSource"));
    if (service == IO_OBJECT_NULL) {
        service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSmartBattery"));
    }
    if (service == IO_OBJECT_NULL) {
        service = IOServiceGetMatchingService(0, IOServiceMatching("AppleARMIODevice"));
    }
    
    CFMutableDictionaryRef props = NULL;
    if (service != IO_OBJECT_NULL) {
        IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0);
        IOObjectRelease(service);
    }
    
    // Nếu IORegistry không mở được, thử qua IOPSCopyPowerSourcesInfo
    if (!props) {
        CFTypeRef psInfo = IOPSCopyPowerSourcesInfo();
        if (psInfo) {
            CFArrayRef psList = IOPSCopyPowerSourcesList(psInfo);
            if (psList && CFArrayGetCount(psList) > 0) {
                CFDictionaryRef desc = IOPSGetPowerSourceDescription(psInfo, CFArrayGetValueAtIndex(psList, 0));
                if (desc) {
                    props = (CFMutableDictionaryRef)CFDictionaryCreateCopy(kCFAllocatorDefault, desc);
                }
            }
            if (psList) CFRelease(psList);
            CFRelease(psInfo);
        }
    }
    
    if (!props) {
        return false;
    }
    
    // 1. Kiểm tra sub-dictionary BatteryData (chứa thông tin sâu của pin)
    CFDictionaryRef batteryData = (CFDictionaryRef)CFDictionaryGetValue(props, CFSTR("BatteryData"));
    CFDictionaryRef batteryFCCData = (CFDictionaryRef)CFDictionaryGetValue(props, CFSTR("BatteryFCCData"));
    
    // 2. Điện áp (Voltage) - đơn vị mV
    int volt = 0;
    if (batteryData) {
        volt = cf_get_int(batteryData, CFSTR("Voltage"), 0);
    }
    if (volt <= 0) {
        volt = cf_get_int(props, CFSTR("Voltage"), 0);
    }
    metrics->voltage_mv = (uint16_t)volt;
    
    // 3. Dòng điện (Amperage / Current) - đơn vị mA (signed: dương là sạc, âm là xả)
    int current = 0;
    current = cf_get_int(props, CFSTR("InstantAmperage"), 0);
    if (current == 0) {
        current = cf_get_int(props, CFSTR("Amperage"), 0);
    }
    if (current == 0 && batteryData) {
        current = cf_get_int(batteryData, CFSTR("InstantAmperage"), 0);
        if (current == 0) {
            current = cf_get_int(batteryData, CFSTR("Amperage"), 0);
        }
    }
    metrics->current_ma = (int16_t)current;
    
    // 4. Mức pin (State of Charge %)
    int soc = 0;
    soc = cf_get_int(props, CFSTR("CurrentCapacity"), 0);
    if (soc <= 0 && batteryData) {
        soc = cf_get_int(batteryData, CFSTR("StateOfCharge"), 0);
    }
    metrics->state_of_charge = (uint16_t)soc;
    
    // 5. Dung lượng pin (mAh)
    // AppleRawCurrentCapacity / AppleRawMaxCapacity / DesignCapacity
    int remain_cap = cf_get_int(props, CFSTR("AppleRawCurrentCapacity"), 0);
    int full_cap   = cf_get_int(props, CFSTR("AppleRawMaxCapacity"), 0);
    int design_cap = cf_get_int(props, CFSTR("DesignCapacity"), 0);
    
    if (remain_cap <= 0) {
        remain_cap = cf_get_int(props, CFSTR("AbsoluteCapacity"), 0);
    }
    if (full_cap <= 0) {
        full_cap = cf_get_int(props, CFSTR("NominalChargeCapacity"), 0);
    }
    if (full_cap <= 0) {
        full_cap = cf_get_int(props, CFSTR("MaxCapacity"), 0);
    }
    if (design_cap <= 0 && batteryData) {
        design_cap = cf_get_int(batteryData, CFSTR("DesignCapacity"), 0);
    }
    
    metrics->remaining_cap_mah = (uint16_t)remain_cap;
    metrics->full_charge_cap_mah = (uint16_t)full_cap;
    metrics->design_cap_mah = (uint16_t)design_cap;
    
    // Qmax (Dung lượng hóa học tối đa)
    int qmax = 0;
    if (batteryData) {
        CFTypeRef qVal = CFDictionaryGetValue(batteryData, CFSTR("Qmax"));
        if (qVal && CFGetTypeID(qVal) == CFArrayGetTypeID() && CFArrayGetCount((CFArrayRef)qVal) > 0) {
            CFNumberRef qNum = (CFNumberRef)CFArrayGetValueAtIndex((CFArrayRef)qVal, 0);
            if (qNum && CFGetTypeID(qNum) == CFNumberGetTypeID()) {
                CFNumberGetValue(qNum, kCFNumberIntType, &qmax);
            }
        }
        if (qmax <= 0) {
            qmax = cf_get_int(batteryData, CFSTR("QmaxCell0"), 0);
        }
    }
    metrics->qmax_mah = (uint16_t)qmax;
    
    // Tính % sức khỏe pin (Battery Health)
    if (design_cap > 0 && full_cap > 0) {
        metrics->battery_health = ((float)full_cap / (float)design_cap) * 100.0f;
    }
    
    // 6. Số chu kỳ sạc (Cycle Count)
    int cycles = 0;
    if (batteryData) {
        cycles = cf_get_int(batteryData, CFSTR("CycleCount"), 0);
    }
    if (cycles <= 0) {
        cycles = cf_get_int(props, CFSTR("CycleCount"), 0);
    }
    metrics->cycle_count = (uint16_t)cycles;
    
    // 7. Nhiệt độ pin
    int raw_temp = cf_get_int(props, CFSTR("Temperature"), 0);
    if (raw_temp == 0 && batteryData) {
        raw_temp = cf_get_int(batteryData, CFSTR("Temperature"), 0);
    }
    if (raw_temp > 500) {
        metrics->temperature_c = (float)raw_temp / 100.0f;
    } else if (raw_temp > 50) {
        metrics->temperature_c = (float)raw_temp / 10.0f;
    } else if (raw_temp > 0) {
        metrics->temperature_c = (float)raw_temp;
    }
    
    // 8. Trạng thái cắm sạc & sạc ngoài
    bool ext_connected = cf_get_bool(props, CFSTR("ExternalConnected"), false) ||
                         cf_get_bool(props, CFSTR("AppleRawExternalConnected"), false);
    bool is_chg = cf_get_bool(props, CFSTR("IsCharging"), false);
    
    if (current > 50) {
        is_chg = true;
        ext_connected = true;
    }
    metrics->adapter_connected = ext_connected;
    metrics->is_charging = is_chg;
    
    // 9. Chi tiết củ sạc (Adapter Details)
    CFDictionaryRef adapterDetails = (CFDictionaryRef)CFDictionaryGetValue(props, CFSTR("AdapterDetails"));
    int adapter_watts = 0;
    if (adapterDetails) {
        adapter_watts = cf_get_int(adapterDetails, CFSTR("Watts"), 0);
        char ad_name[64] = {0};
        if (cf_get_string(adapterDetails, CFSTR("Name"), ad_name, sizeof(ad_name))) {
            snprintf(metrics->adapter_desc, sizeof(metrics->adapter_desc), "%s (%dW)", ad_name, adapter_watts);
        }
    }
    
    if (metrics->adapter_desc[0] == '\0') {
        if (metrics->adapter_connected) {
            if (adapter_watts > 0) {
                snprintf(metrics->adapter_desc, sizeof(metrics->adapter_desc), "Củ sạc %dW", adapter_watts);
            } else if (metrics->current_ma > 1500) {
                snprintf(metrics->adapter_desc, sizeof(metrics->adapter_desc), "Sạc nhanh USB-PD");
            } else if (metrics->is_charging) {
                snprintf(metrics->adapter_desc, sizeof(metrics->adapter_desc), "Đang sạc qua cáp");
            } else {
                snprintf(metrics->adapter_desc, sizeof(metrics->adapter_desc), "Cắm sạc (Bypass / Đầy)");
            }
        } else {
            snprintf(metrics->adapter_desc, sizeof(metrics->adapter_desc), "Đang dùng pin");
        }
    }
    
    // 10. Thời gian còn lại
    int tte = cf_get_int(props, CFSTR("InstantTimeToEmpty"), 0);
    if (tte <= 0) {
        tte = cf_get_int(props, CFSTR("AvgTimeToEmpty"), 0);
    }
    metrics->time_to_empty_min = (uint16_t)tte;
    
    CFRelease(props);
    return true;
}

#pragma mark - Public Interface

bool wattman_smc_read_metrics(WattmanMetrics *metrics) {
    if (!metrics) return false;
    memset(metrics, 0, sizeof(WattmanMetrics));
    
    // Bước 1: Đọc từ IOKit IOPMPowerSource (Hoạt động trên 100% thiết bị iOS)
    bool iopm_ok = read_from_iopm_powersource(metrics);
    
    // Bước 2: Thử mở và đọc thêm từ AppleSMC (nếu thiết bị có SMC driver)
    bool smc_active = wattman_smc_init();
    if (smc_active) {
        uint16_t smc_volt = 0;
        int16_t  smc_curr = 0;
        int16_t  smc_pwr = 0;
        uint16_t smc_temp = 0;
        uint16_t smc_cycles = 0;
        uint16_t smc_fcc = 0;
        uint16_t smc_design = 0;
        
        if (smc_read_key('B0AV', &smc_volt, 2) == kIOReturnSuccess && smc_volt > 0) {
            metrics->voltage_mv = smc_volt;
        }
        if (smc_read_key('B0AC', &smc_curr, 2) == kIOReturnSuccess && smc_curr != 0) {
            metrics->current_ma = smc_curr;
        }
        if (smc_read_key('B0AP', &smc_pwr, 2) == kIOReturnSuccess && smc_pwr != 0) {
            metrics->power_mw = smc_pwr;
        }
        if (smc_read_key('B0AT', &smc_temp, 2) == kIOReturnSuccess && smc_temp > 0) {
            metrics->temperature_c = (float)smc_temp * 0.01f;
        }
        if (smc_read_key('B0CT', &smc_cycles, 2) == kIOReturnSuccess && smc_cycles > 0) {
            metrics->cycle_count = smc_cycles;
        }
        if (smc_read_key('B0FC', &smc_fcc, 2) == kIOReturnSuccess && smc_fcc > 0) {
            metrics->full_charge_cap_mah = smc_fcc;
        }
        if (smc_read_key('B0DC', &smc_design, 2) == kIOReturnSuccess && smc_design > 0) {
            metrics->design_cap_mah = smc_design;
        }
        
        uint8_t ch_exist = 0;
        if (smc_read_key('CHCE', &ch_exist, 1) == kIOReturnSuccess) {
            metrics->adapter_connected = (ch_exist != 0);
        }
    }
    
    // Ghi nhận nguồn dữ liệu nhận diện
    if (iopm_ok && smc_active) {
        snprintf(metrics->source_type, sizeof(metrics->source_type), "IOKit & AppleSMC");
    } else if (iopm_ok) {
        snprintf(metrics->source_type, sizeof(metrics->source_type), "IOKit (IOPMPowerSource)");
    } else if (smc_active) {
        snprintf(metrics->source_type, sizeof(metrics->source_type), "AppleSMC");
    } else {
        snprintf(metrics->source_type, sizeof(metrics->source_type), "Chưa đọc được dữ liệu");
        return false;
    }
    
    // Bước 3: Tính toán công suất sạc tức thời (Watts)
    // P = U * I: Điện áp (mV) * |Dòng điện (mA)| / 1,000,000
    if (metrics->voltage_mv > 0 && metrics->current_ma != 0) {
        float v = (float)metrics->voltage_mv / 1000.0f;
        float a = fabsf((float)metrics->current_ma) / 1000.0f;
        metrics->wattage = v * a;
        metrics->power_mw = (int32_t)(((int64_t)metrics->voltage_mv * (int64_t)metrics->current_ma) / 1000);
    } else if (metrics->power_mw != 0) {
        metrics->wattage = fabsf((float)metrics->power_mw) / 1000.0f;
    } else {
        metrics->wattage = 0.0f;
    }
    
    // Cập nhật trạng thái sạc dựa trên dòng nạp thực tế
    if (metrics->current_ma > 30) {
        metrics->is_charging = true;
        metrics->adapter_connected = true;
    } else if (!metrics->adapter_connected) {
        metrics->is_charging = false;
    }
    
    return true;
}
