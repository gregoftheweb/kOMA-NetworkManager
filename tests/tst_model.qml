// Unit tests for Model.js (ping windows, traffic rates, formatting, network lists).
import QtQuick
import QtTest
import "../contents/ui/Model.js" as M

TestCase {
    name: "Model"

    function test_pushSample_keeps_the_window() {
        var s = []
        for (var i = 0; i < 30; i++)
            s = M.pushSample(s, i)
        compare(s.length, 24)
        compare(s[0], 6)
        compare(M.pushSample([1], undefined), [1, null])
    }

    function test_averageLatency_uses_recent_answers_only() {
        compare(M.averageLatency([100, 1, 2, null, 3, 4, 5]), 3)
        compare(M.averageLatency([null, null]), -1)
        compare(M.averageLatency([]), -1)
    }

    function test_packetLoss() {
        compare(M.packetLoss([1, null, 2, null]), 50)
        compare(M.packetLoss([1, 2, 3]), 0)
        compare(M.packetLoss([]), 0)
        compare(M.packetLoss([null, 1, 1]), 33)
    }

    function test_rate_never_negative() {
        compare(M.rate(1000, 3000, 2), 1000)
        compare(M.rate(5000, 100, 2), 0)
        // counters reset after a reconnect
        compare(M.rate(undefined, 100, 2), 0)
        compare(M.rate(100, 200, 0), 0)
    }

    function test_formatting() {
        compare(M.formatBytes(258), "258 B")
        compare(M.formatBytes(1063000000), "1014 MB")
        compare(M.formatBytes(1536), "1.5 KB")
        compare(M.formatBytes(1024 * 1024 * 15.25), "15.3 MB")
        compare(M.formatRate(218), "218 B/s")
        compare(M.formatLatency(10.6), "11 ms")
        compare(M.formatLatency(0.781), "0.8 ms")
        compare(M.formatLatency(-1), "—")
    }

    function test_connectionTitle() {
        compare(M.connectionTitle({
            "connected": true,
            "type": "ethernet",
            "speedLabel": "1gbit"
        }), "Ethernet (1gbit)")
        compare(M.connectionTitle({
            "connected": true,
            "type": "wifi",
            "ssid": "OBNET"
        }), "OBNET")
        compare(M.connectionTitle({
            "connected": false
        }), "Not connected")
    }

    function test_icons_follow_state_and_signal() {
        compare(M.statusIcon({
            "connected": false
        }), "network-disconnect")
        compare(M.statusIcon({
            "connected": true,
            "type": "ethernet"
        }), "network-wired-activated")
        compare(M.wifiIcon(90), "network-wireless-signal-excellent")
        compare(M.wifiIcon(40), "network-wireless-signal-ok")
        compare(M.wifiIcon(2), "network-wireless-signal-none")
    }

    function test_splitNetworks() {
        var r = M.splitNetworks([
            {
                "ssid": "A",
                "known": true
            },
            {
                "ssid": "B",
                "known": false
            },
            {
                "ssid": "C",
                "known": false,
                "active": true
            }
        ])
        compare(r.known.map(n => n.ssid), ["A", "C"])
        compare(r.other.map(n => n.ssid), ["B"])
    }

    function test_parseServers() {
        compare(M.parseServers("1.1.1.1, 9.9.9.9 2620:fe::fe").servers, ["1.1.1.1", "9.9.9.9", "2620:fe::fe"])
        verify(M.parseServers("1.1.1").error.length > 0)
        verify(M.parseServers("example.com").error.length > 0)
        verify(M.parseServers("8.8.8.8;reboot").error.length > 0)
        compare(M.parseServers("  ").error, "Enter at least one DNS server")
    }

    function test_formatSpeed_and_parseJson() {
        compare(M.formatSpeed(20.44), "20 Mbit/s")
        compare(M.formatSpeed(1.54), "1.5 Mbit/s")
        compare(M.formatSpeed(-1), "—")
        compare(M.parseJson('{"mbps": 3}').mbps, 3)
        compare(M.parseJson("not json"), null)
    }

    function test_speedText() {
        compare(M.speedText(19.4, true, "ok"), "19 Mbit/s")
        // keep showing the last result while retesting
        compare(M.speedText(-1, true, ""), "testing…")
        compare(M.speedText(19.4, false, "limited"), "rt. limit [last:19mbps]")
        compare(M.speedText(1.54, false, "limited"), "rt. limit [last:1.5mbps]")
        compare(M.speedText(-1, false, "limited"), "rt. limit [last:—]")
        compare(M.speedText(19.4, false, "failed"), "19 Mbit/s")
        // a failure keeps the last good value
        compare(M.speedText(-1, false, "failed"), "unavailable")
        compare(M.speedText(-1, false, ""), "—")
    }
}
