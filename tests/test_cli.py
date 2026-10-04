"""The command line itself."""

import subprocess
import sys

from conftest import CLI


def run(*args):
    return subprocess.run([sys.executable, str(CLI), *args], capture_output=True, text=True, check=False)


def test_help_lists_commands():
    out = run("--help").stdout
    for cmd in ("status", "ping", "dns", "wifi"):
        assert cmd in out


def test_bad_radio_state_is_rejected():
    assert run("wifi", "radio", "sideways").returncode == 2


def test_bad_dns_server_exits_1_without_touching_anything():
    res = run("dns", "set", "custom", "not-an-ip")
    assert res.returncode == 1
    assert "not an IP address" in res.stderr
