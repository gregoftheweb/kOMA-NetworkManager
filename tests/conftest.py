"""Load the komanet script as a module, with a fake system behind run().

FakeSystem answers commands from a table of recorded outputs (taken from a real
machine) and records every command, so tests check both what komanet reports
and exactly which nmcli changes it would make. Nothing touches the real network.
"""

import importlib.machinery
import importlib.util
import json
from pathlib import Path

import pytest

CLI = Path(__file__).resolve().parents[1] / "contents" / "code" / "komanet"

DEVICE_STATUS = """enp2s0:ethernet:connected:Wired connection 1
docker0:bridge:connected (externally):docker0
lo:loopback:connected (externally):lo
wlan0:wifi:disconnected:
"""
DEVICE_SHOW = """GENERAL.CON-UUID:7081facb-f515-3a6e-b7ef-6e2558ac894f
IP4.ADDRESS[1]:192.168.0.17/24
IP4.GATEWAY:192.168.0.1
IP4.DNS[1]:1.1.1.1
IP4.DNS[2]:8.8.8.8
"""
CONN_DNS = """ipv4.dns:1.1.1.1,8.8.8.8
ipv4.ignore-auto-dns:yes
ipv6.dns:
ipv6.ignore-auto-dns:no
"""
CONNECTIONS = """7081facb-f515-3a6e-b7ef-6e2558ac894f:802-3-ethernet
e7de0e69-5716-4d60-a1dc-32a711b88103:bridge
aaaa-wifi-1:802-11-wireless
"""
CONNECTIONS_NAMED = """Wired connection 1:7081facb-f515-3a6e-b7ef-6e2558ac894f:802-3-ethernet
OBNET:aaaa-wifi-1:802-11-wireless
"""
WIFI_LIST = """ :OBNET:82:WPA2
 :OBNET:60:WPA2
 :xfinitywifi:70:
 :Mind_Control_Emitter:40:WPA2 WPA3
 ::90:WPA2
 :Coffee\\: Shop:55:--
"""


class FakeSystem:
    def __init__(self):
        self.calls = []
        self.answers = {
            ("nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"): DEVICE_STATUS,
            ("nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"): DEVICE_STATUS,
            (
                "nmcli",
                "-t",
                "-f",
                "GENERAL.CON-UUID,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS",
                "device",
                "show",
                "enp2s0",
            ): DEVICE_SHOW,
            ("nmcli", "-t", "-f", "IP4.GATEWAY", "device", "show", "enp2s0"): "IP4.GATEWAY:192.168.0.1\n",
            (
                "nmcli",
                "-t",
                "-f",
                "ipv4.dns,ipv4.ignore-auto-dns,ipv6.dns,ipv6.ignore-auto-dns",
                "connection",
                "show",
                "7081facb-f515-3a6e-b7ef-6e2558ac894f",
            ): CONN_DNS,
            ("nmcli", "-t", "-f", "UUID,TYPE", "connection", "show"): CONNECTIONS,
            ("nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"): CONNECTIONS_NAMED,
            (
                "nmcli",
                "-t",
                "-f",
                "802-11-wireless.ssid",
                "connection",
                "show",
                "aaaa-wifi-1",
            ): "802-11-wireless.ssid:OBNET\n",
            ("nmcli", "radio", "wifi"): "enabled\n",
            ("ip", "-j", "route", "show", "default"): json.dumps([{"dev": "enp2s0", "metric": 100}]),
            ("systemctl", "is-active", "systemd-resolved"): "inactive\n",
        }
        self.wifi_list = WIFI_LIST
        self.ping = {
            "192.168.0.1": "64 bytes from 192.168.0.1: icmp_seq=1 ttl=64 time=0.781 ms\n",
            "1.1.1.1": "64 bytes from 1.1.1.1: icmp_seq=1 ttl=57 time=10.6 ms\n",
        }
        self.fail = {}  # command prefix tuple -> stderr

    def run(self, cmd, timeout=15, stdin=None):
        cmd = tuple(cmd)
        self.calls.append(cmd)
        for prefix, err in self.fail.items():
            if cmd[: len(prefix)] == prefix:
                return 10, "", err
        if cmd[:4] == ("nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY"):
            return 0, self.wifi_list, ""
        if cmd[0] == "ping":
            out = self.ping.get(cmd[-1])
            return (0, out, "") if out else (1, "", "")
        if cmd in self.answers:
            return 0, self.answers[cmd], ""
        if (
            cmd[0] == "nmcli"
            and cmd[1] in ("connection", "device", "radio")
            and cmd[2] in ("modify", "reapply", "up", "delete", "disconnect", "wifi", "connect")
        ):
            return 0, "", ""
        return 0, "", ""

    def changes(self):
        """The commands that change something."""
        verbs = {"modify", "reapply", "up", "delete", "disconnect", "connect", "on", "off"}
        return [c for c in self.calls if c[0] == "nmcli" and verbs & set(c[1:4])]


@pytest.fixture
def net(tmp_path, monkeypatch):
    sysfs = tmp_path / "sys/class/net"
    stats = sysfs / "enp2s0" / "statistics"
    stats.mkdir(parents=True)
    (sysfs / "enp2s0" / "speed").write_text("1000\n")
    (stats / "rx_bytes").write_text("1063000000\n")
    (stats / "tx_bytes").write_text("388500000\n")
    monkeypatch.setenv("KOMANET_SYSFS", str(sysfs))
    loader = importlib.machinery.SourceFileLoader("komanet", str(CLI))
    spec = importlib.util.spec_from_loader("komanet", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    fake = FakeSystem()
    monkeypatch.setattr(mod, "run", fake.run)
    mod.fake = fake
    mod.sysfs = sysfs
    return mod
