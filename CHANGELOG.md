# Changelog

All notable changes to kOMA Network Manager. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-04

### Added

- Panel widget with the connection's state as its icon, and a popup in the layout of Omarchy's network panel, drawn with KDE's own components and colors.
- Live stats while the popup is open: ping and packet loss (to 1.1.1.1), receive and send rates, totals downloaded and uploaded, IP address and gateway; Ethernet link speed in the title ("Ethernet (1gbit)").
- One-click DNS provider: DHCP, Cloudflare, Google, or Custom servers; the selected one has a highlight-colored border and bold label. Set on every Ethernet and Wi-Fi connection through NetworkManager and re-applied live, with no password or root helper.
- Wi-Fi: known and other networks with signal and lock icons; connect, disconnect, forget; Wi-Fi on/off switch. Machines without Wi-Fi show "No Wi-Fi on this machine." and a shorter popup.
- The popup fits its content; the panel icon is system-tray size.
- Speed test while the popup is open: one request per ~3 s download (max 10 MB) or streamed upload (max 2 MB) sample against speed.cloudflare.com, back to back with a 5 s pause, never while closed; pause button in the header. `komanet speedtest down|up` (exit code 3 when rate-limited).
- When the speed test server rate-limits (HTTP 429), the cells read `rt. limit [last:19mbps]` with the last good result, and the next try waits a minute. Last results are kept in the widget's settings, so they survive restarts.
- Ping and packet loss pause while a speed sample runs, so they describe the network at rest rather than the test's own queueing (a saturated 1.7 Mbit/s upload pushed ping to 138 ms and 17% loss).
- `komanet` CLI: `status`, `ping`, `dns`, `dns set`, `wifi list|connect|disconnect|forget|radio`, `speedtest`.
- Tests (pytest against recorded nmcli output, QML unit tests), linting and formatting gates (`make check`), pre-commit hook, `make package`.

[0.1.0]: https://github.com/columbiafoundry/kOMA-NetworkManager/releases/tag/v0.1.0
