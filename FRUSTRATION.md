# Frustration log

## 2026-09-08 — Official ASUS CLI is the working transport

The legacy IOKit-I2C route could identify the display but could not control it
on this Apple Silicon/macOS display path. ASUS's official `dwc` macOS binary
does discover the physical PA32QCV (`dwc list` → monitor ID 1, serial
`W1LMSV003666`, device ID 2) and successfully reads/writes `InputSource`
(`get` → 21; `set ... 15` switches to DisplayPort). The app now uses that
supported transport and makes the source IDs visible in onboarding and Settings.

## 2026-09-08 — Xcode 26 debug bundle used a preview stub

The first Debug build produced an executable shell linked with
`___debug_blank_executor_main`; LaunchServices reported that the app executable
was missing. Setting `ENABLE_DEBUG_DYLIB = NO` in the target build settings
restored a launchable macOS application bundle.

## 2026-09-08 — Legacy DDC path is absent on the connected monitor

The standalone probe initially reported `No external displays found.` because
this macOS returned a non-success status from the sizing form of
`CGGetOnlineDisplayList`, even though it populated the display IDs. After
using a fixed buffer, CoreGraphics identified the connected PA32QCV as display
`0x2`, vendor `0x6B3`, product `0x320C`. The legacy
`CGDisplayIOServicePort` bridge returns `0` for that display, so public
IOKit-I2C DDC/CI access is unavailable on this Apple Silicon/macOS host. The
app now reports the monitor as found while keeping VCP controls disabled until
an accessible DDC transport is available.

## 2026-09-08 — Git metadata is restricted in the harness

The workspace did not contain a writable Git metadata directory. `git init`
was attempted so the new-project scaffold could use local versioning, but the
harness rejected writes to `.git`; source files remain intact and can be
initialized normally in a local checkout.

## 2026-09-08 — Swift AppKit delegate was not installed implicitly

The first normal-app launches entered `NSApplication`’s run loop with a Dock
item but `NSApp.delegate == nil`, leaving the app with no UX window. An
explicit `ProArtKVMApp` delegate bootstrap now installs the delegate before
starting the run loop; a debugger check confirms the app creates its windows.
