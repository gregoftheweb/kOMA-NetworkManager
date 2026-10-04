"""status, ping, DNS and Wi-Fi commands against the fake system."""

import pytest


def test_status_reports_the_default_route_device(net):
    s = net.status()
    assert (s["device"], s["type"], s["connection"]) == ("enp2s0", "ethernet", "Wired connection 1")
    assert (s["ip"], s["prefix"], s["gateway"]) == ("192.168.0.17", 24, "192.168.0.1")
    assert (s["speedMbps"], s["speedLabel"]) == (1000, "1gbit")
    assert (s["rxBytes"], s["txBytes"]) == (1063000000, 388500000)
    assert s["dns"] == {"provider": "Custom", "servers": ["1.1.1.1", "8.8.8.8"]}
    assert (s["wifiDevice"], s["wifiEnabled"]) == ("wlan0", True)


def test_status_when_nothing_is_connected(net):
    net.fake.answers[("nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status")] = (
        "enp2s0:ethernet:unavailable:\nlo:loopback:connected (externally):lo\n"
    )
    assert net.status() == {"connected": False, "wifiDevice": None, "wifiEnabled": False}


def test_ping_router_and_internet(net):
    assert net.ping() == {"router": 0.781, "internet": 10.6}
    del net.fake.ping["1.1.1.1"]  # lost packet
    assert net.ping()["internet"] is None


def test_set_dns_cloudflare_on_every_ethernet_and_wifi_profile(net):
    msg = net.set_dns("Cloudflare")
    assert "Cloudflare" in msg and "2 connection(s)" in msg
    mods = [c for c in net.fake.changes() if c[2] == "modify"]
    assert [c[3] for c in mods] == ["7081facb-f515-3a6e-b7ef-6e2558ac894f", "aaaa-wifi-1"]  # not the bridge
    m = mods[0]
    assert m[m.index("ipv4.dns") + 1] == "1.1.1.1 1.0.0.1"
    assert m[m.index("ipv4.ignore-auto-dns") + 1] == "yes"
    assert m[m.index("ipv6.dns") + 1] == "2606:4700:4700::1111"  # capped at 3 without resolved
    assert ("nmcli", "device", "reapply", "enp2s0") in net.fake.calls


def test_set_dns_keeps_all_servers_with_systemd_resolved(net):
    net.fake.answers[("systemctl", "is-active", "systemd-resolved")] = "active\n"
    net.set_dns("google")
    m = next(c for c in net.fake.changes() if c[2] == "modify")
    assert m[m.index("ipv6.dns") + 1] == "2001:4860:4860::8888 2001:4860:4860::8844"


def test_set_dns_dhcp_clears_overrides(net):
    net.set_dns("dhcp")
    m = next(c for c in net.fake.changes() if c[2] == "modify")
    assert m[m.index("ipv4.dns") + 1] == ""
    assert m[m.index("ipv4.ignore-auto-dns") + 1] == "no"
    assert m[m.index("ipv6.ignore-auto-dns") + 1] == "no"


def test_set_dns_custom_splits_ipv4_and_ipv6(net):
    net.set_dns("custom", ["192.168.0.1", "2620:fe::fe"])
    m = next(c for c in net.fake.changes() if c[2] == "modify")
    assert m[m.index("ipv4.dns") + 1] == "192.168.0.1"
    assert m[m.index("ipv6.dns") + 1] == "2620:fe::fe"


def test_set_dns_refuses_bad_input_before_changing_anything(net):
    with pytest.raises(net.Failed, match="not an IP"):
        net.set_dns("custom", ["8.8.8.8", "evil;reboot"])
    with pytest.raises(net.Failed, match="unknown DNS provider"):
        net.set_dns("quad9")
    with pytest.raises(net.Failed, match="at least one"):
        net.set_dns("custom", [])
    assert net.fake.changes() == []


def test_set_dns_surfaces_nmcli_errors(net):
    net.fake.fail[("nmcli", "connection", "modify")] = "Error: insufficient privileges.\n"
    with pytest.raises(net.Failed, match="insufficient privileges"):
        net.set_dns("google")


def test_wifi_list_dedupes_flags_known_and_sorts(net):
    nets = net.wifi_networks()
    assert [n["ssid"] for n in nets] == ["OBNET", "xfinitywifi", "Coffee: Shop", "Mind_Control_Emitter"]
    obnet = nets[0]
    assert (obnet["signal"], obnet["known"], obnet["secure"]) == (82, True, True)
    assert nets[1]["secure"] is False
    assert nets[2]["secure"] is False  # "--" means open
    assert all(n["ssid"] for n in nets)  # hidden networks skipped


def test_wifi_list_puts_the_active_network_first(net):
    net.fake.wifi_list = " :OBNET:82:WPA2\n*:xfinitywifi:40:\n"
    nets = net.wifi_networks()
    assert nets[0]["ssid"] == "xfinitywifi"
    assert nets[0]["active"]


def test_wifi_connect_known_uses_saved_profile(net):
    net.wifi_connect("OBNET")
    assert ("nmcli", "connection", "up", "aaaa-wifi-1") in net.fake.changes()


def test_wifi_connect_new_network_never_puts_a_password_on_the_command_line(net):
    net.wifi_connect("xfinitywifi")
    cmd = next(c for c in net.fake.calls if c[:4] == ("nmcli", "device", "wifi", "connect"))
    assert cmd == ("nmcli", "device", "wifi", "connect", "xfinitywifi")


def test_wifi_forget(net):
    net.wifi_forget("OBNET")
    assert ("nmcli", "connection", "delete", "aaaa-wifi-1") in net.fake.changes()
    with pytest.raises(net.Failed, match="not a saved network"):
        net.wifi_forget("Nope")


def test_wifi_disconnect_needs_a_connected_wifi(net):
    with pytest.raises(net.Failed, match="not connected"):
        net.wifi_disconnect()


def test_wifi_radio(net):
    net.wifi_radio("off")
    assert ("nmcli", "radio", "wifi", "off") in net.fake.changes()
