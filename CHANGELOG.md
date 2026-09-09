# Changelog

## 2026-09-08

- Replaced the in-window tab view with a single switcher view and a separate
  Settings window opened by Command-Comma, the app menu, or the status menu.
- Added per-input visibility settings; disabled sources are removed from the
  switcher, toggle destination, and menu-bar commands.
- Added per-input friendly names and SF Symbol/emoji icon choices in Settings;
  custom presentation is reflected in the switcher and menu-bar commands while
  ASUS CLI source IDs remain unchanged.
- Added a Settings toggle for starting ProArt KVM at login using macOS's native
  `SMAppService` login-item registration and approval status.
- Made the main switcher and Settings windows resizable, with a compact 560×390
  switcher starting size to remove unused vertical space.
- Reduced the enforced minimums so the switcher can reach 500×360 content points
  and Settings can reach 560×440 with scrolling.
- Fixed focus/reopen behavior so the window is centered only when first
  created and keeps its user-selected position afterward.
- Added a proper multi-resolution `AppIcon.icns` from the generated KVM monitor
  artwork so macOS renders the custom icon in the Dock and Finder.
- Refactored switching to use ASUS's official `dwc` CLI after confirming it
  discovers the PA32QCV and switches `InputSource` successfully.
- Added first-launch onboarding that downloads the macOS CLI, confirms the
  monitor, and explains the PA32QCV source IDs (Thunderbolt 21, DisplayPort 15,
  HDMI 17).
- Added Settings & Hardware controls for CLI updates, monitor diagnostics, and
  direct per-input test switches.
- Removed the manual Thunderbolt VCP-value setup from the user flow.
- Fixed the Switch Inputs window expanding to near-full-screen height by
  constraining the native window to a compact 680×520 content area.
- Fixed display enumeration on current macOS and separated monitor discovery
  from legacy I2C/DDC availability. The connected PA32QCV is now identified as
  an online external display, while unavailable VCP control is explained in
  Settings.
- Created the native ProArt KVM macOS menu-bar app scaffold.
- Added an IOKit/CoreGraphics DDC/CI implementation for VCP `0x60`.
- Added the standalone `ddc-probe` hardware discovery tool.
- Added PA32QCV identity matching, per-Mac connection role preferences, native
  Carbon global hotkey handling, menu-bar commands, and project documentation.
- Added a visible SwiftUI control window with large input-switch buttons and a
  hardware/settings screen showing discovered display identity and VCP options.
- Changed the app to a normal Dock-visible macOS application so its control
  window is discoverable without relying on accessory-app behavior.
