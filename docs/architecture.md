# Architecture

## Components

- `ASUSCLIManager` downloads the official macOS `dwc` archive into a managed
  Application Support directory with its required `libVCPLibrary.dylib`, runs
  it with argument arrays, and parses monitor discovery and input values.
- `PA32QCVController` is the narrow monitor-specific facade. It selects only a
  discovered PA32QCV and maps the documented `InputSource` IDs to friendly
  Thunderbolt, DisplayPort, and HDMI options.
- `Preferences` persists onboarding completion, the Mac's connection role,
  enabled inputs, per-input names/icons, display text scale, the optional
  post-switch screen lock, and its per-Mac fallback shortcut in `UserDefaults`.
- `LoginItemManager` registers or unregisters the main app with Apple's
  `SMAppService` and reads the system status back for the Settings toggle.
- `ScreenLockManager` invokes the system helper used by Apple's Lock Screen
  menu action, falling back to the user's configured Control-Command-Q or
  Control-Command-L shortcut on newer macOS versions, when the opt-in
  post-switch setting is enabled. It also exposes Accessibility permission
  request/settings actions for Settings diagnostics.
- `MainWindowController` owns one SwiftUI-hosted window containing the switcher
  and a collapsible settings section; it resizes the window when that section
  is toggled. Command-W closes the window without terminating the menu-bar app.
- `MenuBarController` owns the `NSStatusItem`, menu commands, asynchronous
  switching, status/error notifications, and initial synchronization read.
- `HotKeyController` registers Control-Option-Command-K with Carbon's native
  event hotkey API.

## Data flow

```text
onboarding/settings
        ↓
managed ASUS `dwc` download
        ↓
menu, window, or global hotkey
        ↓
PA32QCVController → `dwc list` / `get InputSource` / `set InputSource`
                  → optional macOS Lock Screen action
        ↓
monitor input and PA32QCV KVM upstream selection
```

The target Mac's role determines the destination, so switching away from the
current Mac does not require the source Mac to receive a later keyboard event.
Both Macs run their own copy of the app and their own local preferences.

## Important tradeoffs

- ASUS's supported CLI is used as the transport because the legacy IOKit I2C
  service is not exposed for this monitor path on the target Apple Silicon Mac.
- The app never invokes a shell or trusts the user's PATH; executable arguments
  are passed directly to `Process` and the binary is stored per-user.
- The CLI's monitor ID, model, serial, device ID, and current input are shown
  in Settings so discovery is inspectable rather than opaque.
- The app uses ASUS's documented PA32QCV IDs: Thunderbolt `21`, DisplayPort
  `15`, and HDMI `17`.
- The old `DDCController` and `DisplayDiscovery` sources remain only as
  historical reference; they are no longer part of the app target. The
  standalone `Tools/ddc-probe.swift` remains the diagnostic implementation.
- The app re-discovers the PA32QCV for each operation, making unplug/replug
  recovery natural without polling.
