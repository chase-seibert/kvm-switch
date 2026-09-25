# ProArt KVM project instructions

Also load the user-level guidance at `/Users/cseibert/.codex/AGENTS.md` before
working in this repository.

## Repo map

- `ProArtKVM/` — native menu-bar app sources and app metadata.
- `Tools/ddc-probe.swift` — standalone hardware discovery and DDC probe.
- `docs/` — project brief, architecture, design, requirements, and setup docs.
- `Makefile` — the supported setup, format, lint, test, run, build, and clean commands.
- `CHANGELOG.md` — dated project history.

## Commands

Prefer the Makefile targets for common work:

- `make setup` — check the local Xcode/Swift toolchain.
- `make build` — build the macOS app with Xcode.
- `make sign-app` — sign and verify the built app with the team-backed Apple
  Development identity so macOS Accessibility permission remains tied to a
  stable app identity. The default is `SIGNING_MODE=team`; public contributors
  can use `SIGNING_MODE=adhoc` or `SIGNING_MODE=unsigned` for local testing.
- `make probe-build` — compile the standalone DDC probe.
- `make probe` — enumerate displays and read the PA32QCV when connected.
- `make format` — run Swift formatting when available.
- `make lint` — run Swift compiler lint checks.
- `make test` — run the project verification checks.
- `make install-local` — copy the rebuilt app to the local installed bundle
  used by the Dock at `build/Applications/ProArt KVM.app`.
- `make run` — rebuild, install to that Dock bundle path, and launch it.
- `make clean` — remove generated build output.

After any macOS app code or UI change, relaunch with `make run` so the active
application is the same bundle used by the Dock. Do not launch
`build/Build/Products/Debug/ProArt KVM.app` directly; that creates a separate
app instance from the Dock-installed copy.

The Makefile signs the local app after each build. If multiple certificates are
installed, pass `SIGNING_IDENTITY="..."` to select the intended one. A
different team can override `DEVELOPMENT_TEAM=...`; no repository edits are
needed for that override.

## Documentation index

- [Project charter](docs/project-charter.md)
- [Architecture](docs/architecture.md)
- [Design](docs/design.md)
- [Product requirements](docs/product-requirements.md)
- [Setup and installation](docs/setup-install.md)
- [Initial brainstorm](docs/initial-brainstorm.md)

## Project state

The project is intentionally hardware-specific to one ASUS ProArt PA32QCV and
two Macs. The verified VCP input values remain a hardware-validation step; do
not replace the PA32QCV identity or input-code guardrails with generic monitor
behavior.

Keep documentation current as implementation decisions change. Common commands
should be exposed through the Makefile, and agents should prefer those targets.
