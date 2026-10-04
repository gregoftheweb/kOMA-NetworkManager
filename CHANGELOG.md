# Changelog

All notable changes to kOMA Network Manager. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-04

### Added

- Panel widget with the connection's state as its icon, and a popup in the layout of Omarchy's network panel, drawn with KDE's own components and colors.
- Live stats while the popup is open: ping and packet loss (to 1.1.1.1), receive and send rates, totals downloaded and uploaded, IP address and gateway; Ethernet link speed in the title ("Ethernet (1gbit)").
- One-click DNS provider: DHCP, Cloudflare, Google, or Custom servers. Set on every Ethernet and Wi-Fi connection through NetworkManager and re-applied live, with no password or root helper.
- Wi-Fi: known and other networks with signal and lock icons; connect, disconnect, forget; Wi-Fi on/off switch.
- `komanet` CLI: `status`, `ping`, `dns`, `dns set`, `wifi list|connect|disconnect|forget|radio`.
- Tests (pytest against recorded nmcli output, QML unit tests), linting and formatting gates (`make check`), pre-commit hook, `make package`.

[0.1.0]: https://github.com/columbiafoundry/kOMA-NetworkManager/releases/tag/v0.1.0
