# Design

ProArt KVM is a normal foreground macOS app with a Dock icon, a visible native
control window at launch, and a persistent menu-bar status item. The switcher
opens at a compact 560×390 size and both it and Settings are resizable. The
window is centered only on first creation; subsequent focus or menu-bar
activation keeps its current position. The status item uses a system SF Symbol
and opens a compact native `NSMenu` whose input commands use the configured
friendly names:

- Switch to Thunderbolt
- Switch to DisplayPort
- Switch to HDMI
- Toggle KVM — Control-Option-Command-K
- This Mac: Thunderbolt/DisplayPort
- PA32QCV: Connected/Not found
- Settings…
- Quit ProArt KVM

The main window is hosted by SwiftUI and contains only the switcher after setup;
there is no tab control. First launch is a three-step onboarding
wizard: download the official ASUS `dwc` binary, confirm the discovered PA32QCV,
and review the input source IDs. After setup, Switch Inputs presents large
buttons for each enabled input, a role-aware toggle button, the current input,
and connection status. A separate Settings window, opened with Command-Comma
or from either menu, provides download/update controls, the managed binary
path, monitor ID/model/serial/device ID, input visibility switches, per-input
names and SF Symbol/emoji choices, the CLI input IDs, direct test buttons, and
the connection role. It also includes a Start ProArt KVM at login control backed
by macOS Login Items. The app uses
system colors, controls, spacing, and SF Symbols so it follows light/dark
appearance without custom chrome.

The app shows a small native user notification for missing hardware, CLI
failures, and failed switching. No remote wake behavior is attempted.
