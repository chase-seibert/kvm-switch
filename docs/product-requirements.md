# Product requirements

- As the owner of two Macs and one PA32QCV, I want to switch monitor inputs
  from a global hotkey, so that I can move between computers without reaching
  for the monitor controls.
- As a user whose keyboard follows the monitor KVM, I want each Mac to know its
  own physical connection role, so that switching away from one Mac does not
  depend on shared state or a return event.
- As a user, I want direct Thunderbolt and DisplayPort menu actions, so that I
  can recover explicitly when a readback is unavailable.
- As a safety-conscious user, I want the app to verify the PA32QCV identity
  before sending an input command, so that another connected display is never
  targeted.
- As a hardware tester, I want a read-only legacy probe plus explicit candidate
  writes, so that low-level monitor transport can still be investigated when
  the supported CLI is unavailable.
- As a Mac user, I want a native Dock-visible app with a focused control window
  and a menu-bar shortcut, so that the KVM controls are easy to discover.
- As a first-time user, I want onboarding to download the official ASUS Display
  Control CLI and verify the PA32QCV before enabling controls.
- As a troubleshooting user, I want Settings to show the CLI path, monitor ID,
  model, serial, device ID, current input, and source IDs used for switching.
- As a user, I want Thunderbolt, DisplayPort, and HDMI input buttons to call the
  same direct input-selection operation proven by the ASUS CLI.
- As a user, I want to hide unused input sources such as HDMI 1, so the
  switcher and menus show only the controls I use.
- As a hardware tester, I want experimental monitor power-on and power-off
  buttons in Settings, so I can validate the PA32QCV's raw VCP power behavior
  before adding it to the main UI or a schedule.
- As a Mac user, I want hardware settings in a dedicated Settings window opened
  with Command-Comma, rather than mixed into the switching view.
- As a Mac user, I want an optional Start at Login setting, so ProArt KVM is
  available automatically after I sign in.
