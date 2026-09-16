PROJECT := ProArtKVM.xcodeproj
SCHEME := ProArtKVM
CONFIGURATION := Debug
DERIVED_DATA := build
APP_NAME := ProArtKVM
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/ProArt KVM.app
INSTALLED_APP_PATH := $(DERIVED_DATA)/Applications/ProArt KVM.app
PROBE_PATH := $(DERIVED_DATA)/ddc-probe
SIGNING_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk -F '"' 'NR == 1 {print $$2}')

.PHONY: setup build sign-app probe-build probe run probe-run format lint test install-local clean

setup:
	@sw_vers
	@swift --version
	@xcodebuild -version

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build
	$(MAKE) sign-app

sign-app:
	@if [ -z "$(SIGNING_IDENTITY)" ]; then echo "No code-signing identity found. Install an Apple Development certificate or pass SIGNING_IDENTITY=..." >&2; exit 1; fi
	codesign --force --deep --sign "$(SIGNING_IDENTITY)" "$(APP_PATH)"
	codesign --verify --deep --strict "$(APP_PATH)"

probe-build:
	mkdir -p $(DERIVED_DATA)
	swiftc -O -target arm64-apple-macosx13.0 -module-cache-path $(DERIVED_DATA)/ModuleCache.noindex Tools/ddc-probe.swift -framework CoreGraphics -framework IOKit -o $(PROBE_PATH)

probe: probe-build
	$(PROBE_PATH)

run: install-local
	open "$(INSTALLED_APP_PATH)"

probe-run: probe

format:
	@if command -v swift-format >/dev/null 2>&1; then swift-format format --in-place ProArtKVM/*.swift Tools/ddc-probe.swift; else echo "swift-format not installed; skipped."; fi

lint:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
	$(MAKE) sign-app

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
