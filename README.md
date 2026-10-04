# kOMA Network Manager

**Your network at a glance, from the panel**: live ping, packet loss and traffic, your IP and gateway, Wi-Fi networks, and one-click DNS switching between DHCP, Cloudflare, Google or your own servers.

kOMA Network Manager brings [Omarchy](https://omarchy.org)'s network panel to KDE Plasma 6, in KDE's own look: it uses your Plasma style, color scheme and icons. It's part of kOMA (KDE + Omarchy), a set of add-ons that make Plasma look and drive like Omarchy.

## Features

- **Connection header**: "Ethernet (1gbit)" or your Wi-Fi network's name, and a Wi-Fi on/off switch.
- **Live stats** while the popup is open: Ping and Packet Loss, Receiving and Sending rates, Downloaded and Uploaded totals, IP Address and Gateway.
- **Speed test** while the popup is open: Download and Upload Speed, sampled continuously against [speed.cloudflare.com](https://speed.cloudflare.com). The speedometer button in the header pauses it.
- **DNS Provider**: DHCP, Cloudflare, Google or Custom, applied instantly to every Ethernet and Wi-Fi connection. No password, no root helper: it goes through NetworkManager, which lets the logged-in user change connection settings.
- **Wi-Fi**: Known and Other networks with signal strength and a lock for secured ones. Click to connect or disconnect; hover a known network to forget it. Passwords are asked by KDE's own prompt, never passed on a command line.
- **Panel icon** shows the connection type and Wi-Fi signal; hover for the IP address and DNS provider.

## Network use

While the popup is **closed**, kOMA Network Manager only reads local state every 30 seconds and sends nothing.

While it's **open**:

- every 2 seconds, one small ping to your router and one to 1.1.1.1;
- one Wi-Fi scan per opening;
- the speed test, back to back with a 2-second pause: a download sample of at most 10 MB, then an upload sample of at most 2 MB, each about 3 seconds. This briefly fills your connection, which also raises the ping shown while it runs. Press the speedometer button to pause it.

Closing the popup stops everything; a sample already in flight finishes within about 3 seconds.

## Requirements

- KDE Plasma 6 with NetworkManager
- `nmcli` (part of NetworkManager), `iproute2`, `ping`
- Python 3.11 or newer (standard library only)
- For Wi-Fi passwords: KDE's NetworkManager integration, `plasma-nm`, which provides the password prompt (installed with a normal Plasma desktop)

DNS changes need NetworkManager's `settings.modify.system` permission for your user; check with `nmcli general permissions`. It's `yes` for the active desktop user on a standard setup.

## Install

From the KDE Store: right-click the panel, **Add or Manage Widgets**, **Get New Widgets**, and search for "kOMA Network Manager".

From source:

```sh
git clone https://github.com/columbiafoundry/kOMA-NetworkManager
cd kOMA-NetworkManager
bin/install              # the widget, the komanet command in ~/.local/bin, and places it on your panels
bin/install --no-place   # the same, without touching your panels
```

## Command line

```text
komanet status                       the connection: link speed, IP, gateway, traffic, DNS
komanet ping                         one ping to the router and one to 1.1.1.1
komanet dns                          current DNS provider and servers
komanet dns set dhcp|cloudflare|google
komanet dns set custom 9.9.9.9 149.112.112.112
komanet wifi list [--rescan]
komanet wifi connect|forget SSID
komanet wifi disconnect
komanet wifi radio on|off
komanet speedtest down|up             a ~3 s sample, at most 10 MB down / 2 MB up
```

Add `--json` to `status`, `ping`, `dns` and `wifi list` for machine-readable output.

## Development

```sh
make setup      # pytest + ruff in .venv, prettier + shellcheck in node_modules, git hook
make check      # ruff, qmllint, qmlformat, prettier, shellcheck, metadata, Python and QML tests
make format     # apply every formatter
make package    # dist/com.columbiafoundry.komanetworkmanager-<version>.plasmoid for the KDE Store
bin/dev-reload  # reinstall and restart plasmashell
```

## License

MIT © 2026 Columbia Foundry. See [LICENSE](LICENSE).
