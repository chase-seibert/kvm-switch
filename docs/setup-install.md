# Setup and installation

1. Connect the PA32QCV and verify that its OSD KVM/upstream configuration is
   correct for the two Macs.
2. Build and install with `make install-local`.
3. Launch the app. Onboarding downloads the official ASUS Display Control CLI
   from the ASUS-maintained GitHub repository into the app's Application
   Support directory.
4. Choose Refresh monitor status and confirm the model, serial, monitor ID, and
   device ID match the intended display.
5. Review the source IDs: Thunderbolt 1 = `21`, DisplayPort 1 = `15`, and HDMI
   1 = `17`. Finish setup only after the PA32QCV is found.
6. Test a large input button or a Settings test button. The CLI operation is
   `dwc set InputSource <value> --id <monitor-id>`.
7. Select This Mac's connection role. The global toggle is
   Control-Option-Command-K; direct buttons and menu commands remain available.
8. Repeat setup independently on the second Mac. No Accessibility automation
   permission is required for the CLI-based switching path.

After setup, open Settings with Command-Comma, from the ProArt KVM application
menu, or from the status-item menu. Use the Show switches under Input options
to hide unused sources; for example, turning off HDMI 1 removes it from the
switcher, toggle destination, and menus. At least one source remains enabled.

The app's launch-at-login behavior is intentionally not included in the first
implementation. Add it later with `SMAppService` after switching is stable.
