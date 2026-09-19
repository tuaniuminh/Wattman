#include "WattmanSMC.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <arpa/inet.h>

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
typedef int IOReturn;
typedef int kern_return_t;

#define kIOReturnSuccess 0
#define IO_OBJECT_NULL ((io_object_t)0)

extern IOReturn IOMasterPort(mach_port_t, mach_port_t *);
extern CFMutableDictionaryRef IOServiceMatching(const char *);
extern io_service_t IOServiceGetMatchingService(mach_port_t, CFDictionaryRef);
extern kern_return_t IOServiceOpen(io_service_t, mach_port_t, uint32_t, io_connect_t *);
extern kern_return_t IOServiceClose(io_connect_t);
extern kern_return_t IOConnectCallStructMethod(mach_port_t, uint32_t, const void *, size_t, void *, size_t *);
extern kern_return_t IOObjectRelease(io_object_t);

// SMC Definitions
typedef uint32_t SMCKey;
typedef uint32_t SMCDataType;
typedef uint8_t SMCDataAttributes;

typedef struct {
    unsigned char major;
    unsigned char minor;
    unsigned char build;
    unsigned short release;
} SMCVersion;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCPLimitData;

typedef struct {
    uint32_t dataSize;
    SMCDataType dataType;
    SMCDataAttributes dataAttributes;
} SMCKeyInfoData;

typedef struct {
    SMCKey key;
    struct {
        SMCVersion vers;
        SMCPLimitData pLimitData;
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

// Gọi lệnh struct method tới SMC Driver
static IOReturn smc_call(int index, SMCParamStruct *input, SMCParamStruct *output) {
    if (gSMCConnection == IO_OBJECT_NULL) return -1;
    size_t inSize = sizeof(SMCParamStruct);
    size_t outSize = sizeof(SMCParamStruct);
    return IOConnectCallStructMethod(gSMCConnection, index, input, inSize, output, &outSize);
}

// Lấy thông tin kích thước và kiểu dữ liệu của key
static IOReturn smc_get_key_info(SMCKey key, SMCKeyInfoData *keyInfo) {
    SMCParamStruct input = {0};
    SMCParamStruct output = {0};
    input.key = key;
    input.param.data8 = kSMCGetKeyInfo;
    
    IOReturn ret = smc_call(kSMCHandleYPCEvent, &input, &output);
    if (ret == kIOReturnSuccess && output.param.keyInfo.dataSize > 0) {
        *keyInfo = output.param.keyInfo;
        return kIOReturnSuccess;
    }
    return -1;
}

// Đọc giá trị an toàn từ một SMC Key
static IOReturn smc_read_key(SMCKey key, void *buffer, size_t buffer_size) {
    SMCKeyInfoData keyInfo = {0};
    if (smc_get_key_info(key, &keyInfo) != kIOReturnSuccess) {
        return -1;
    }
    
    SMCParamStruct input = {0};
    SMCParamStruct output = {0};
    input.key = key;
    input.param.data8 = kSMCReadKey;
    input.param.keyInfo = keyInfo;
    
    IOReturn ret = smc_call(kSMCHandleYPCEvent, &input, &output);
    if (ret == kIOReturnSuccess) {
        size_t copy_size = keyInfo.dataSize < buffer_size ? keyInfo.dataSize : buffer_size;
        memcpy(buffer, output.param.bytes, copy_size);
        return kIOReturnSuccess;
    }
    return ret;
}

// Khởi tạo kết nối tới AppleSMC service
bool wattman_smc_init(void) {
    if (gSMCInitialized) return gHasSMC;
    
    mach_port_t masterPort = MACH_PORT_NULL;
    if (IOMasterPort(MACH_PORT_NULL, &masterPort) != kIOReturnSuccess) {
        gSMCInitialized = true;
        gHasSMC = false;
        return false;
    }
    
    io_service_t service = IOServiceGetMatchingService(masterPort, IOServiceMatching("AppleSMC"));
    if (service == IO_OBJECT_NULL) {
        gSMCInitialized = true;
        gHasSMC = false;
        return false;
    }
    
    kern_return_t ret = IOServiceOpen(service, mach_task_self(), 0, &gSMCConnection);
    IOObjectRelease(service);
    
    if (ret == kIOReturnSuccess && gSMCConnection != IO_OBJECT_NULL) {
        gHasSMC = true;
    } else {
        gHasSMC = false;
    }
    
    gSMCInitialized = true;
    return gHasSMC;
}

void wattman_smc_close(void) {
    if (gSMCConnection != IO_OBJECT_NULL) {
        IOServiceClose(gSMCConnection);
        gSMCConnection = IO_OBJECT_NULL;
    }
    gSMCInitialized = false;
    gHasSMC = false;
}

// Đọc toàn bộ snapshot dữ liệu từ SMC
bool wattman_smc_read_metrics(WattmanMetrics *metrics) {
    if (!metrics) return false;
    memset(metrics, 0, sizeof(WattmanMetrics));
    
    if (!wattman_smc_init()) {
        // Fallback mô phỏng an toàn nếu thiết bị không có SMC hoặc chạy trong Simulator
        metrics->voltage_mv = 3850;
        metrics->current_ma = -420;
        metrics->power_mw = -1617;
        metrics->wattage = 1.62f;
        metrics->temperature_c = 28.5f;
        metrics->remaining_cap_mah = 2800;
        metrics->full_charge_cap_mah = 3100;
        metrics->design_cap_mah = 3274;
        metrics->qmax_mah = 3300;
        metrics->state_of_charge = 90;
        metrics->battery_health = 94.6f;
        metrics->cycle_count = 145;
        metrics->time_to_empty_min = 380;
        metrics->is_charging = false;
        metrics->adapter_connected = false;
        strncpy(metrics->adapter_desc, "Không có SMC (Simulator/Fallback)", sizeof(metrics->adapter_desc) - 1);
        return true;
    }
    
    // 1. Điện áp trung bình (B0AV) - đơn vị mV
    uint16_t volt = 0;
    if (smc_read_key('B0AV', &volt, 2) == kIOReturnSuccess) {
        metrics->voltage_mv = volt;
    }
    
    // 2. Dòng điện trung bình (B0AC) - đơn vị mA (signed)
    int16_t curr = 0;
    if (smc_read_key('B0AC', &curr, 2) == kIOReturnSuccess) {
        metrics->current_ma = curr;
    }
    
    // 3. Công suất trung bình (B0AP) - đơn vị mW (signed)
    int16_t pwr = 0;
    if (smc_read_key('B0AP', &pwr, 2) == kIOReturnSuccess) {
        metrics->power_mw = pwr;
    } else if (metrics->voltage_mv > 0) {
        metrics->power_mw = (int32_t)((metrics->voltage_mv * metrics->current_ma) / 1000);
    }
    
    // 4. Tính công suất tức thời theo Watts: W = (V_mV * |I_mA|) / 1,000,000
    if (metrics->voltage_mv > 0 && metrics->current_ma != 0) {
        float v = (float)metrics->voltage_mv / 1000.0f;
        float a = fabsf((float)metrics->current_ma) / 1000.0f;
        metrics->wattage = v * a;
    } else if (metrics->power_mw != 0) {
        metrics->wattage = fabsf((float)metrics->power_mw) / 1000.0f;
    } else {
        metrics->wattage = 0.0f;
    }
    
    // 5. Nhiệt độ pin (B0AT) - đơn vị 0.01 độ C
    uint16_t raw_temp = 0;
    if (smc_read_key('B0AT', &raw_temp, 2) == kIOReturnSuccess) {
        metrics->temperature_c = (float)raw_temp * 0.01f;
    }
    
    // 6. Dung lượng pin (mAh)
    smc_read_key('B0RM', &metrics->remaining_cap_mah, 2);    // Dung lượng còn lại
    smc_read_key('B0FC', &metrics->full_charge_cap_mah, 2); // Dung lượng khi sạc đầy
    smc_read_key('B0DC', &metrics->design_cap_mah, 2);      // Dung lượng thiết kế
    smc_read_key('BQX1', &metrics->qmax_mah, 2);            // Qmax
    
    // Tính % sức khỏe pin (Battery Health)
    if (metrics->design_cap_mah > 0 && metrics->full_charge_cap_mah > 0) {
        metrics->battery_health = ((float)metrics->full_charge_cap_mah / (float)metrics->design_cap_mah) * 100.0f;
        if (metrics->battery_health > 100.0f) metrics->battery_health = 100.0f;
    }
    
    // 7. Tỷ lệ % pin và số chu kỳ sạc
    smc_read_key('BRSC', &metrics->state_of_charge, 2);
    smc_read_key('B0CT', &metrics->cycle_count, 2);
    smc_read_key('B0TF', &metrics->time_to_empty_min, 2);
    
    // 8. Trạng thái củ sạc / nguồn điện
    uint8_t ch_exist = 0;
    smc_read_key('CHCE', &ch_exist, 1);
    metrics->adapter_connected = (ch_exist != 0);
    metrics->is_charging = (metrics->current_ma > 50); // Dòng nạp vào pin dương trên 50mA
    
    if (metrics->adapter_connected) {
        if (metrics->wattage >= 15.0f) {
            strncpy(metrics->adapter_desc, "Sạc nhanh USB-PD (High Power)", sizeof(metrics->adapter_desc) - 1);
        } else if (metrics->is_charging) {
            strncpy(metrics->adapter_desc, "Đang sạc qua cáp (Adapter Connected)", sizeof(metrics->adapter_desc) - 1);
        } else {
            strncpy(metrics->adapter_desc, "Đã cắm sạc (Bypass / Giữ pin)", sizeof(metrics->adapter_desc) - 1);
        }
    } else {
        strncpy(metrics->adapter_desc, "Đang dùng pin (Discharging)", sizeof(metrics->adapter_desc) - 1);
    }
    
    return true;
}
