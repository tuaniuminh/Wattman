.PHONY: all clean

IPHONEOS_DEPLOYMENT_TARGET ?= 12.0
THEOS ?= $(HOME)/theos
SDKROOT ?= $(THEOS)/sdks/iPhoneOS13.7.sdk

ifeq ($(wildcard $(SDKROOT)),)
	SDKROOT = $(firstword $(wildcard $(THEOS)/sdks/iPhoneOS*.sdk))
endif

ifeq ($(wildcard $(THEOS)/toolchain/linux/iphone/bin/clang),)
	ifneq ($(wildcard /Applications/Xcode.app),)
		CC = xcrun -sdk iphoneos clang
		LDID = ldid
	else
		CC = clang
		LDID = ldid
	endif
else
	CC = $(THEOS)/toolchain/linux/iphone/bin/clang
	LDID = $(THEOS)/toolchain/linux/iphone/bin/ldid
endif

CFLAGS = -target arm64-apple-ios$(IPHONEOS_DEPLOYMENT_TARGET) \
         -fobjc-arc \
         -Wall \
         -O2 \
         -isysroot $(SDKROOT) \
         -I.

LDFLAGS = -target arm64-apple-ios$(IPHONEOS_DEPLOYMENT_TARGET) \
          -isysroot $(SDKROOT) \
          -framework UIKit \
          -framework Foundation \
          -framework CoreGraphics \
          -framework CoreFoundation \
          -framework IOKit \
          -lobjc

SOURCES = main.m \
          AppDelegate.m \
          Core/WattmanSMC.c \
          Core/WattmanBatteryModel.m \
          UI/WattmanCardView.m \
          UI/WattmanViewController.m

BUILD_DIR = build
APP_DIR = $(BUILD_DIR)/Payload/Wattman.app

all: $(BUILD_DIR)/Wattman.tipa

$(BUILD_DIR)/Wattman.tipa: $(BUILD_DIR)/Wattman.ipa
	cp $(BUILD_DIR)/Wattman.ipa $(BUILD_DIR)/Wattman.tipa

$(BUILD_DIR)/Wattman.ipa: $(APP_DIR)/Wattman
	@echo "[*] Packaging Wattman.ipa..."
	@cd $(BUILD_DIR) && zip -qry Wattman.ipa Payload
	@echo "[+] Build complete: $(BUILD_DIR)/Wattman.ipa and $(BUILD_DIR)/Wattman.tipa"

$(APP_DIR)/Wattman: $(SOURCES)
	@echo "[*] Compiling Wattman for arm64..."
	@mkdir -p $(APP_DIR)
	@cp Info.plist $(APP_DIR)/Info.plist
	$(CC) $(CFLAGS) $(LDFLAGS) $(SOURCES) -o $(APP_DIR)/Wattman
	@echo "[*] Signing with TrollStore entitlements..."
	$(LDID) -SWattman.entitlements $(APP_DIR)/Wattman

clean:
	rm -rf $(BUILD_DIR)
