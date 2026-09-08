# Project charter

## Goal

Make switching between two Macs on one ASUS ProArt PA32QCV feel like a native
KVM hotkey, without BetterDisplay, Homebrew, shell scripts, or Accessibility
automation. The app manages the small official ASUS CLI dependency itself.

## Context

- Mac A connects to the PA32QCV Thunderbolt 4 / 96W port.
- Mac B connects by DisplayPort for video and USB-C to the dedicated KVM
  upstream port for USB.
- Keyboard and mouse are connected to the monitor's downstream USB ports.
- The monitor is configured with Upstream 1 = Auto and Upstream 2 = DisplayPort.

## Constraints and non-goals

Use Swift, AppKit/SwiftUI, and the official ASUS Display Control CLI. The app is
deliberately for the PA32QCV, not a generic monitor controller. It does not
remotely wake the other Mac, require cross-Mac state, or automate the ASUS GUI.
The managed CLI is invoked directly with argument arrays and never through a
shell.

The source IDs are the values documented by ASUS's CLI and confirmed against
the working PA32QCV commands: DisplayPort `15`, HDMI `17`, and Thunderbolt
`21`.

## People and roles

- Chase Seibert — owner, tester, and decision maker.
- Codex — implementation and documentation collaborator.

## Questions this project should answer

1. What monitor ID, model, serial, and device ID does the official CLI expose?
2. Does each documented `InputSource` value select the expected PA32QCV input?
3. Does the monitor's KVM follow the input reliably across lid-open,
   clamshell, sleep, and reconnect cases?

## Deliverables

- Native menu-bar application.
- Standalone legacy DDC probe for diagnostics.
- Onboarding-managed official ASUS CLI integration.
- Build/install instructions and hardware-validation record.

## Status

The native implementation is complete. The official CLI has been verified to
discover the target PA32QCV and to switch `InputSource` values; the remaining
validation is exercising each button and KVM upstream behavior on both Macs.
