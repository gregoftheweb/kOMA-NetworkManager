"""Parsing nmcli output and classifying settings."""


def test_split_terse_unescapes_colons_and_backslashes(net):
    assert net.split_terse(r"a:b\:c:d\\e:") == ["a", "b:c", "d\\e", ""]


def test_parse_fields_collects_indexed_keys(net):
    f = net.parse_fields("IP4.ADDRESS[1]:10.0.0.2/24\nIP4.DNS[1]:1.1.1.1\nIP4.DNS[2]:9.9.9.9\nIP4.GATEWAY:10.0.0.1\n")
    assert f["IP4.ADDRESS"] == ["10.0.0.2/24"]
    assert f["IP4.DNS"] == ["1.1.1.1", "9.9.9.9"]
    assert f["IP4.GATEWAY"] == "10.0.0.1"


def test_link_speed_label(net):
    assert net.link_speed_label(1000) == "1gbit"
    assert net.link_speed_label(2500) == "2.5gbit"
    assert net.link_speed_label(100) == "100mbit"
    assert net.link_speed_label(-1) == ""
    assert net.link_speed_label(0) == ""


def test_classify_dns(net):
    assert net.classify_dns(False, ["1.1.1.1"]) == "DHCP"  # auto DNS still on
    assert net.classify_dns(True, []) == "DHCP"
    assert net.classify_dns(True, ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111"]) == "Cloudflare"
    assert net.classify_dns(True, ["8.8.8.8"]) == "Google"
    assert net.classify_dns(True, ["1.1.1.1", "8.8.8.8"]) == "Custom"  # a mix is custom
    assert net.classify_dns(True, ["192.168.0.1"]) == "Custom"


def test_parse_servers_validates_and_normalizes(net):
    assert net.parse_servers(["1.1.1.1, 9.9.9.9", "2620:FE::FE"]) == ["1.1.1.1", "9.9.9.9", "2620:fe::fe"]
    for bad in (["1.1.1"], ["example.com"], ["1.1.1.1; rm -rf ~"], [""]):
        try:
            net.parse_servers(bad)
        except net.Failed:
            continue
        raise AssertionError(f"accepted {bad}")


def test_cap_servers_keeps_ipv4_first(net):
    assert net.cap_servers(["a", "b"], ["x", "y"]) == (["a", "b"], ["x"])
    assert net.cap_servers(["a", "b", "c", "d"], ["x"]) == (["a", "b", "c"], [])
    assert net.cap_servers([], ["x", "y"]) == ([], ["x", "y"])


def test_human_bytes(net):
    assert net.human_bytes(258) == "258 B"
    assert net.human_bytes(1063000000) == "1013.8 MB"
    assert net.human_bytes(1_200_000_000_000) == "1.1 TB"
