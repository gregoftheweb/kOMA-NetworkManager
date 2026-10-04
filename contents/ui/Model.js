.pragma library

// kOMA Network Manager: pure helpers for the panel (no I/O), unit-tested in
// tests/tst_model.qml. Ping windows follow Omarchy's network panel: the shown
// latency averages the last 5 answers, packet loss counts the last 24 probes.

var PING_AVERAGE_WINDOW = 5
var PING_HISTORY_WINDOW = 24
var DNS_PROVIDERS = ["DHCP", "Cloudflare", "Google", "Custom"];

// Append a ping sample (ms, or null for a lost packet), keeping the window.
function pushSample(samples, value, limit) {
    var next = (samples || []).slice()
    next.push(value === undefined ? null : value)
    var max = limit || PING_HISTORY_WINDOW
    return next.length > max ? next.slice(next.length - max) : next
}

// Average of the last `window` answered pings, or -1 when none answered.
function averageLatency(samples, window) {
    var answered = (samples || []).filter(function (v) {
        return v !== null
    })
    var recent = answered.slice(-(window || PING_AVERAGE_WINDOW))
    if (recent.length === 0)
        return -1
    var sum = 0
    for (var i = 0; i < recent.length; i++)
        sum += recent[i]
    return sum / recent.length
}

// Percentage of lost probes in the history, rounded.
function packetLoss(samples) {
    var all = samples || []
    if (all.length === 0)
        return 0
    var lost = all.filter(function (v) {
        return v === null
    }).length
    return Math.round(lost * 100 / all.length)
}

// Bytes per second between two counter readings taken `seconds` apart.
// Counters reset (a reconnect) or a missing reading give 0, never negative.
function rate(previous, current, seconds) {
    if (previous === undefined || previous === null || current === undefined || current === null)
        return 0
    if (!(seconds > 0) || current < previous)
        return 0
    return (current - previous) / seconds
}

function formatBytes(n) {
    var units = ["B", "KB", "MB", "GB", "TB"]
    var v = Math.max(0, Number(n) || 0)
    var i = 0
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024
        i++
    }
    if (i === 0)
        return Math.round(v) + " B"
    return (v >= 100 ? v.toFixed(0) : v.toFixed(v >= 10 ? 1 : 2).replace(/\.?0+$/, "")) + " " + units[i]
}

function formatRate(bytesPerSecond) {
    return formatBytes(bytesPerSecond) + "/s"
}

function formatSpeed(mbps) {
    if (mbps === undefined || mbps === null || mbps < 0)
        return "—"
    return (mbps < 10 ? mbps.toFixed(1) : Math.round(mbps)) + " Mbit/s"
}

// JSON.parse that returns null instead of throwing.
function parseJson(text) {
    try {
        return JSON.parse(text)
    } catch (e) {
        return null
    }
}

function formatLatency(ms) {
    if (ms === undefined || ms === null || ms < 0)
        return "—"
    return (ms < 10 ? ms.toFixed(1).replace(/\.0$/, "") : Math.round(ms)) + " ms"
}

// "Ethernet (1gbit)", "Ethernet", or the Wi-Fi network name.
function connectionTitle(status) {
    if (!status || !status.connected)
        return "Not connected"
    if (status.type === "wifi")
        return status.ssid || status.connection || "Wi-Fi"
    return "Ethernet" + (status.speedLabel ? " (" + status.speedLabel + ")" : "")
}

// Theme icon for the panel, by connection type and Wi-Fi signal.
function statusIcon(status) {
    if (!status || !status.connected)
        return "network-disconnect"
    if (status.type !== "wifi")
        return "network-wired-activated"
    var s = status.signal || 0
    var level = s >= 80 ? "excellent" : s >= 55 ? "good" : s >= 30 ? "ok" : s > 5 ? "low" : "none"
    return "network-wireless-signal-" + level
}

function wifiIcon(signal) {
    return statusIcon({
        "connected": true,
        "type": "wifi",
        "signal": signal
    })
}

// Split networks into the two lists the panel shows; the active one leads
// "Known networks" even if it was never saved (a captive-portal hotspot).
function splitNetworks(networks) {
    var known = [], other = []
    var list = networks || []
    for (var i = 0; i < list.length; i++) {
        var n = list[i]
        if (n.known || n.active)
            known.push(n)
        else
            other.push(n)
    }
    return {
        "known": known,
        "other": other
    }
}

// Only well-formed IPv4/IPv6 addresses, separated by spaces or commas.
function parseServers(text) {
    var parts = String(text || "").split(/[\s,]+/).filter(function (p) {
        return p.length > 0
    })
    var ipv4 = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/
    var ipv6 = /^[0-9a-fA-F:]+$/
    var ok = []
    for (var i = 0; i < parts.length; i++) {
        var p = parts[i]
        if (ipv4.test(p) || (p.indexOf(":") >= 0 && ipv6.test(p)))
            ok.push(p)
        else
            return {
                "servers": [],
                "error": "Not an IP address: " + p
            }
    }
    return {
        "servers": ok,
        "error": ok.length ? "" : "Enter at least one DNS server"
    }
}
