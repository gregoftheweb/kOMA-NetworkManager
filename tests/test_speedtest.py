"""The speed test's measuring loop, with a fake clock and fake transfers."""

import pytest


class Clock:
    def __init__(self):
        self.now = 100.0

    def __call__(self):
        return self.now


def link(clock, bytes_per_second, calls=None, stoppable=True):
    """A fake link: moving `size` bytes advances the clock. A download stops at
    the deadline; an upload (stoppable=False) always finishes its request."""

    def transfer(size, deadline):
        if calls is not None:
            calls.append(size)
        seconds = size / bytes_per_second
        if stoppable and clock.now + seconds > deadline:
            size = int((deadline - clock.now) * bytes_per_second)
            seconds = deadline - clock.now
        clock.now += seconds
        return size

    return transfer


def test_fast_link_stops_at_the_byte_cap(net):
    clock = Clock()
    calls = []
    r = net.measure(link(clock, 125_000_000, calls), 256_000, 5_000_000, 10_000_000, 3, clock=clock)  # 1 Gbit/s
    assert r["bytes"] == 10_000_000
    assert calls[0] == 256_000  # starts small
    assert max(calls) <= 5_000_000
    assert r["mbps"] == 1000.0


def test_slow_link_stops_near_the_time_cap(net):
    clock = Clock()
    r = net.measure(link(clock, 250_000), 256_000, 5_000_000, 10_000_000, 3, clock=clock)  # 2 Mbit/s
    assert r["seconds"] == 3
    assert r["mbps"] == 2.0


def test_slow_upload_overruns_the_deadline_only_slightly(net):
    clock = Clock()
    # 1.7 Mbit/s upload, the speed measured on the dev machine
    r = net.measure(link(clock, 212_500, stoppable=False), 128_000, 1_000_000, 2_000_000, 3, clock=clock)
    assert r["seconds"] <= 3 + net.CHUNK_SECONDS * 2
    assert r["mbps"] == pytest.approx(1.7, abs=0.05)


def test_chunks_never_pass_the_byte_cap(net):
    clock = Clock()
    calls = []
    net.measure(link(clock, 1e12, calls), 30, 1000, 70, 10, clock=clock)
    assert sum(calls) == 70


def test_no_data_is_an_error(net):
    with pytest.raises(net.Failed, match="no data"):
        net.measure(lambda size, deadline: 0, 10, 10, 100, 10, clock=Clock())


def test_network_errors_become_failures(net, monkeypatch):
    def boom(size, deadline):
        raise OSError("connection reset")

    monkeypatch.setattr(net, "_download", boom)
    with pytest.raises(net.Failed, match="speed test failed"):
        net.speedtest("down")


def test_limits_keep_the_sample_light(net):
    down, up = net.SPEEDTEST_LIMITS["down"], net.SPEEDTEST_LIMITS["up"]
    assert down[2] <= 10_000_000 and down[3] <= 3
    assert up[2] <= 2_000_000 and up[3] <= 3
