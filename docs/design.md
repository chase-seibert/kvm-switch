# Design

ProArt KVM is a normal foreground macOS app with a Dock icon, a visible native
control window at launch, and a persistent menu-bar status item. The unified
window opens at a compact 560×460 size and expands or collapses when its
settings section is toggled. The window is centered only on first creation;
subsequent focus or menu-bar activation keeps its current position. Command-W
closes the window while the menu-bar app continues running. The status item uses
a system SF Symbol
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

The main window is hosted by SwiftUI. First launch is a three-step onboarding
wizard: download the official ASUS `dwc` binary, confirm the discovered PA32QCV,
and review the input source IDs. After setup, Switch Inputs presents large
buttons for each enabled input, a role-aware toggle button, the current input,
and connection status. A toggleable Settings section below the switcher provides
download/update controls, the managed binary path, monitor ID/model/serial/device
ID, input visibility switches, per-input names and SF Symbol/emoji choices, the
CLI input IDs, direct test buttons, and the connection role. It also includes a
Start ProArt KVM at login control backed by macOS Login Items. The app uses
system colors, controls, spacing, and SF Symbols so it follows light/dark
appearance without custom chrome.

Settings also includes an option to start with the window hidden, leaving only
the menu-bar item visible. Choosing Open App from the menu-bar menu, or
reactivating the app from the Dock, shows the window.

Settings also includes an opt-in control to lock the Mac after a successful
input switch. When enabled, the app uses the same system Lock Screen action as
the Apple menu. On macOS versions without the system helper, each Mac can use
its configured fallback shortcut, such as Control-Command-Q or
Control-Command-L, so switches from the window, status menu, and global hotkey
all have the same behavior.

The app shows a small native user notification for missing hardware, CLI
failures, and failed switching. No remote wake behavior is attempted.
