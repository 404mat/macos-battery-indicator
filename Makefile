.PHONY: build run

DERIVED_DATA_PATH ?= .build/XcodeDerivedData
APP_PATH = $(CURDIR)/$(DERIVED_DATA_PATH)/Build/Products/Debug/BatteryIndicator.app

build:
	xcodebuild \
		-project BatteryIndicator.xcodeproj \
		-scheme BatteryIndicator \
		-configuration Debug \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		-quiet \
		ONLY_ACTIVE_ARCH=YES \
		build

run: build
	open "$(APP_PATH)"
