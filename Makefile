PROJECT := ProArtKVM.xcodeproj
SCHEME := ProArtKVM
CONFIGURATION := Debug
DERIVED_DATA := build
APP_NAME := ProArtKVM
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/ProArt KVM.app
PROBE_PATH := $(DERIVED_DATA)/ddc-probe

.PHONY: setup build probe-build probe run probe-run format lint test install-local clean

setup:
	@sw_vers
	@swift --version
	@xcodebuild -version

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build

probe-build:
	mkdir -p $(DERIVED_DATA)
	swiftc -O -target arm64-apple-macosx13.0 -module-cache-path $(DERIVED_DATA)/ModuleCache.noindex Tools/ddc-probe.swift -framework CoreGraphics -framework IOKit -o $(PROBE_PATH)

probe: probe-build
	$(PROBE_PATH)

run: build
	open "$(APP_PATH)"

probe-run: probe

format:
	@if command -v swift-format >/dev/null 2>&1; then swift-format format --in-place ProArtKVM/*.swift Tools/ddc-probe.swift; else echo "swift-format not installed; skipped."; fi

lint:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build

test: build probe-build
	@test -d "$(APP_PATH)"
	@test -x "$(PROBE_PATH)"
	@echo "Build verification passed. Hardware verification still requires a connected PA32QCV."

install-local: build
	mkdir -p build/Applications
	rm -rf "build/Applications/ProArt KVM.app"
	cp -R "$(APP_PATH)" build/Applications/

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) clean
	rm -f "$(PROBE_PATH)"
