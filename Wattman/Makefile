.PHONY: all clean

IPHONEOS_DEPLOYMENT_TARGET ?= 12.0
THEOS ?= $(HOME)/theos
SDKROOT ?= $(THEOS)/sdks/iPhoneOS13.7.sdk

ifeq ($(wildcard $(SDKROOT)),)
	SDKROOT = $(firstword $(wildcard $(THEOS)/sdks/iPhoneOS*.sdk))
endif

ifneq ($(wildcard $(THEOS)/toolchain/linux/iphone/bin/clang),)
	CC = $(THEOS)/toolchain/linux/iphone/bin/clang
	LDID = $(THEOS)/toolchain/linux/iphone/bin/ldid
else ifneq ($(wildcard /Applications/Xcode.app),)
	CC = xcrun -sdk iphoneos clang
	LDID = ldid
else
	CC = clang
	LDID = ldid
endif

CFLAGS = -target arm64-apple-ios$(IPHONEOS_DEPLOYMENT_TARGET) \
         -target arm64-apple-darwin \
         -fobjc-arc \
         -fconstant-cfstrings \
         -Wno-deprecated-declarations \
         -Wno-unused-variable \
         -O2 \
         -isysroot $(SDKROOT) \
         -I.

LDFLAGS = -target arm64-apple-ios$(IPHONEOS_DEPLOYMENT_TARGET) \
          -target arm64-apple-darwin \
          -isysroot $(SDKROOT) \
          -framework UIKit \
          -framework Foundation \
          -framework CoreGraphics \
          -framework CoreFoundation \
          -framework IOKit \
          -lobjc

BUILD_DIR = build
OBJ_DIR = $(BUILD_DIR)/obj
APP_DIR = $(BUILD_DIR)/Payload/Wattman.app

OBJS = $(OBJ_DIR)/main.o \
       $(OBJ_DIR)/AppDelegate.o \
       $(OBJ_DIR)/WattmanSMC.o \
       $(OBJ_DIR)/WattmanBatteryModel.o \
       $(OBJ_DIR)/WattmanCardView.o \
       $(OBJ_DIR)/WattmanViewController.o

all: $(BUILD_DIR)/Wattman.tipa $(BUILD_DIR)/Wattman.ipa

$(BUILD_DIR)/Wattman.tipa: $(BUILD_DIR)/Wattman.ipa
	cp $(BUILD_DIR)/Wattman.ipa $(BUILD_DIR)/Wattman.tipa

$(BUILD_DIR)/Wattman.ipa: $(APP_DIR)/Wattman
	@echo "[*] Packaging Wattman.ipa..."
	@cd $(BUILD_DIR) && zip -qry Wattman.ipa Payload
	@echo "[+] Successfully built $(BUILD_DIR)/Wattman.ipa and $(BUILD_DIR)/Wattman.tipa"

$(APP_DIR)/Wattman: $(OBJS)
	@echo "[*] Linking Wattman binary..."
	@mkdir -p $(APP_DIR)
	@cp Info.plist $(APP_DIR)/Info.plist
	@if [ -f Resources/AppIcon.jpg ]; then cp Resources/AppIcon.jpg $(APP_DIR)/AppIcon.jpg; fi
	$(CC) $(OBJS) $(LDFLAGS) -o $(APP_DIR)/Wattman
	@echo "[*] Signing with TrollStore entitlements..."
	$(LDID) -SWattman.entitlements $(APP_DIR)/Wattman

$(OBJ_DIR)/main.o: main.m
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/AppDelegate.o: AppDelegate.m
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/WattmanSMC.o: Core/WattmanSMC.c
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/WattmanBatteryModel.o: Core/WattmanBatteryModel.m
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/WattmanCardView.o: UI/WattmanCardView.m
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/WattmanViewController.o: UI/WattmanViewController.m
	@mkdir -p $(OBJ_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)
