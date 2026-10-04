"""The speed test: one request per sample, bounded by bytes and time."""

import io
import urllib.error

import pytest


class Clock:
    def __init__(self):
        self.now = 100.0

    def __call__(self):
        return self.now


def link(clock, bytes_per_second, *, drain=0.0):
    """A fake single request: moves bytes until the cap or the deadline, then
    (for an upload) takes `drain` seconds to empty the send buffer."""

    def transfer(max_bytes, deadline):
        seconds = max_bytes / bytes_per_second
        moved = max_bytes
        if clock.now + seconds > deadline:
            moved = int((deadline - clock.now) * bytes_per_second)
            seconds = deadline - clock.now
        clock.now += seconds + drain
        return moved

    return transfer


def test_fast_link_stops_at_the_byte_cap(net):
    clock = Clock()
    r = net.measure(link(clock, 125_000_000), 10_000_000, 3, clock=clock)  # 1 Gbit/s
    assert (r["bytes"], r["mbps"], r["seconds"]) == (10_000_000, 1000.0, 0.08)


def test_slow_link_stops_at_the_deadline(net):
    clock = Clock()
    r = net.measure(link(clock, 250_000), 10_000_000, 3, clock=clock)  # 2 Mbit/s
    assert (r["seconds"], r["mbps"]) == (3, 2.0)


def test_upload_time_includes_draining_the_buffer(net):
    clock = Clock()
    r = net.measure(link(clock, 212_500, drain=0.3), 2_000_000, 3, clock=clock)
    assert r["seconds"] == 3.3
    assert r["mbps"] == 1.5  # 637,500 bytes over 3.3 s


def test_no_data_is_an_error(net):
    with pytest.raises(net.Failed, match="no data"):
        net.measure(lambda max_bytes, deadline: 0, 100, 10, clock=Clock())


def test_one_request_per_sample(net, monkeypatch):
    calls = []

    def fake_urlopen(req, timeout):
        calls.append(req.full_url)
        return io.BytesIO(b"x" * 1000)

    monkeypatch.setattr(net.urllib.request, "urlopen", fake_urlopen)
    r = net.speedtest("down")
    assert calls == [f"{net.SPEEDTEST_URL}/__down?bytes=10000000"]
    assert r["bytes"] == 1000


def test_rate_limit_is_its_own_error(net, monkeypatch):
    def limited(req, timeout):
        raise urllib.error.HTTPError(req.full_url, 429, "Too Many Requests", {}, None)

    monkeypatch.setattr(net.urllib.request, "urlopen", limited)
    with pytest.raises(net.RateLimited, match="rate limiting"):
        net.speedtest("down")


def test_network_errors_become_failures(net, monkeypatch):
    def boom(max_bytes, deadline):
        raise OSError("connection reset")

    monkeypatch.setattr(net, "_download", boom)
    with pytest.raises(net.Failed, match="speed test failed"):
        net.speedtest("down")


def test_limits_keep_the_sample_light(net):
    assert net.SPEEDTEST_LIMITS["down"] == (10_000_000, 3.0)
    assert net.SPEEDTEST_LIMITS["up"][0] <= 2_000_000
