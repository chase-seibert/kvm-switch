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
- `make probe-build` — compile the standalone DDC probe.
- `make probe` — enumerate displays and read the PA32QCV when connected.
- `make format` — run Swift formatting when available.
- `make lint` — run Swift compiler lint checks.
- `make test` — run the project verification checks.
- `make clean` — remove generated build output.

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
