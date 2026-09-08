# Initial brainstorm

The initial request is preserved in the user-provided brief. The product is a
single-purpose macOS menu-bar utility for an ASUS ProArt PA32QCV wired to two
Macs: one through Thunderbolt 4, and one through DisplayPort plus the monitor's
dedicated KVM USB-C upstream. Switching the monitor's video input should make
the configured monitor KVM follow the active computer.

The requested implementation sequence was: build a Swift DDC probe, identify
the physical monitor and exact VCP input values, hard-code the verified
PA32QCV profile, then add the minimal menu bar, role preference, global hotkey,
error handling, and optional login behavior.
