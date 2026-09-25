PROJECT := ProArtKVM.xcodeproj
SCHEME := ProArtKVM
CONFIGURATION := Debug
DERIVED_DATA := build
APP_NAME := ProArtKVM
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/ProArt KVM.app
INSTALLED_APP_PATH := $(DERIVED_DATA)/Applications/ProArt KVM.app
PROBE_PATH := $(DERIVED_DATA)/ddc-probe
DEVELOPMENT_TEAM ?= 96NAC4VTEN
SIGNING_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development/ {print $$2; exit}')
SIGNING_MODE ?= team

.PHONY: setup build sign-app probe-build probe run probe-run format lint test install-local clean

setup:
	@sw_vers
	@swift --version
	@xcodebuild -version

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build
	$(MAKE) sign-app

sign-app:
	@set -eu; \
	case "$(SIGNING_MODE)" in \
	  team) identity="$(SIGNING_IDENTITY)"; expected_team="$(DEVELOPMENT_TEAM)"; \
	    if [ -z "$$identity" ]; then echo "No Apple Development signing identity found for team $(DEVELOPMENT_TEAM)." >&2; exit 1; fi ;; \
	  adhoc) identity=-; expected_team= ;; \
	  unsigned) echo "Skipping code signing (SIGNING_MODE=unsigned)."; exit 0 ;; \
	  *) echo "Unsupported SIGNING_MODE=$(SIGNING_MODE); use team, adhoc, or unsigned." >&2; exit 2 ;; \
	esac; \
	codesign --force --deep --sign "$$identity" "$(APP_PATH)"; \
	codesign --verify --deep --strict "$(APP_PATH)"; \
	if [ -n "$$expected_team" ]; then actual_team=$$(codesign -dvvv "$(APP_PATH)" 2>&1 | awk -F= '/^TeamIdentifier=/{print $$2}'); \
	if [ "$$actual_team" != "$$expected_team" ]; then echo "Expected TeamIdentifier=$$expected_team, got $${actual_team:-none}." >&2; exit 1; fi; fi

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
