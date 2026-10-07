/*
    kOMA Network Manager — Omarchy-style network panel for KDE Plasma 6.

    Live link stats, one-click DNS provider switching and Wi-Fi networks, in
    KDE's own look. All system access goes through the bundled `komanet` CLI
    (contents/code/komanet), run through Plasma's "executable" data engine.
    While the popup is closed only the local connection state is read; ping
    and Wi-Fi scans run only while it is open.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "Model.js" as Model

PlasmoidItem {
    id: root

    readonly property string cli: decodeURIComponent(Qt.resolvedUrl("../code/komanet").toString().replace("file://", ""))

    property var status: ({})
    property var networks: []
    property var pingSamples: []
    property real pingMs: -1
    property int lossPercent: 0
    property real rxRate: 0
    property real txRate: 0
    property var lastCounters: null      // {rx, tx, at} from the previous status read
    property string busy: ""             // what an action is running on ("dns", an SSID, ...)
    // last good speed test results (Mbit/s), kept in the widget's config
    property real speedDown: Plasmoid.configuration.lastDownMbps
    property real speedUp: Plasmoid.configuration.lastUpMbps
    property string speedPhase: ""       // "down" or "up" while a sample runs
    property bool speedPaused: false     // the header's speedometer button
    property string speedNote: ""        // why the last sample failed (not for rate limits)
    property string speedDownState: ""   // "ok" | "limited" | "failed" for the latest sample
    property string speedUpState: ""
    property int speedRun: 0             // bumped on every open/close so stale runs stop
    property string message: ""
    property bool messageIsError: false

    readonly property bool hasWifi: !!status.wifiDevice

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 14
    Plasmoid.icon: Model.statusIcon(status)
    toolTipMainText: Model.connectionTitle(status)
    toolTipSubText: status.connected ? status.ip + (status.dns ? "  ·  DNS: " + status.dns.provider : "") : ""

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // ---------------------------------------------------------------- CLI calls
    function command(args) {
        return "python3 " + shellQuote(cli) + " " + args.map(shellQuote).join(" ")
    }
    function call(args, callback) {
        commands.run(command(args), callback)
    }
    // for polls: skip a tick rather than queue behind a slow run
    function poll(args, callback) {
        if (!commands.busy(command(args)))
            call(args, callback)
    }

    CommandQueue {
        id: commands
    }

    function refreshStatus() {
        poll(["status", "--json"], function (code, out) {
            if (code !== 0)
                return
            try {
                var s = JSON.parse(out)
            } catch (e) {
                return
            }
            var now = Date.now() / 1000
            if (lastCounters && s.connected && s.device === lastCounters.device) {
                rxRate = Model.rate(lastCounters.rx, s.rxBytes, now - lastCounters.at)
                txRate = Model.rate(lastCounters.tx, s.txBytes, now - lastCounters.at)
            }
            lastCounters = s.connected ? {
                "device": s.device,
                "rx": s.rxBytes,
                "tx": s.txBytes,
                "at": now
            } : null
            status = s
        })
    }

    function refreshPing() {
        // a running speed sample fills the line, so a ping now would measure the
        // test's own queueing; ping and packet loss describe the network at rest
        if (speedPhase !== "")
            return
        poll(["ping", "--json"], function (code, out) {
            if (code !== 0)
                return
            try {
                var p = JSON.parse(out)
            } catch (e) {
                return
            }
            pingSamples = Model.pushSample(pingSamples, p.internet)
            pingMs = Model.averageLatency(pingSamples)
            lossPercent = Model.packetLoss(pingSamples)
        })
    }

    function refreshNetworks(rescan) {
        if (!hasWifi) {
            networks = []
            return
        }
        poll(rescan ? ["wifi", "list", "--json", "--rescan"] : ["wifi", "list", "--json"], function (code, out) {
            if (code === 0) {
                try {
                    networks = JSON.parse(out)
                } catch (e) {}
            }
        })
    }

    // Speed test: while the popup is open, a ~3 s download sample, then a ~3 s
    // upload sample, then again after a short pause. Never while closed.
    function startSpeedTests() {
        speedRun += 1
        speedCycle(speedRun)
    }
    function speedCycle(run) {
        if (run !== speedRun || !expanded || speedPaused || !status.connected) {
            speedPhase = ""
            return
        }
        speedSample(run, "down", function () {
            speedSample(run, "up", function () {
                speedPhase = ""
                speedGap.interval = 5000
                speedGap.run = run
                speedGap.restart()
            })
        })
    }
    // One sample; on success stores Mbit/s, on failure -1 and the reason.
    function speedSample(run, direction, next) {
        if (run !== speedRun || !expanded || speedPaused) {
            speedPhase = ""
            return
        }
        speedPhase = direction
        call(["speedtest", direction, "--json"], function (code, out, err) {
            if (run !== root.speedRun)
                return
            var r = code === 0 ? Model.parseJson(out) : null
            var state = r ? "ok" : (code === 3 ? "limited" : "failed");
            // keep the last good result when a sample fails
            if (direction === "down") {
                root.speedDownState = state
                if (r)
                    Plasmoid.configuration.lastDownMbps = r.mbps
            } else {
                root.speedUpState = state
                if (r)
                    Plasmoid.configuration.lastUpMbps = r.mbps
            }
            root.speedNote = state === "failed" ? (err.trim().replace(/^komanet: /, "") || "speed test failed") : ""
            if (state === "limited") {
                // both directions use the same server
                root.speedDownState = "limited"
                root.speedUpState = "limited"
                // the server wants a rest: skip the other direction, try again in a minute
                root.speedPhase = ""
                speedGap.interval = 60000
                speedGap.run = run
                speedGap.restart()
                return
            }
            next()
        })
    }
    Timer {
        id: speedGap
        property int run: 0
        interval: 5000
        onTriggered: root.speedCycle(run)
    }
    onSpeedPausedChanged: if (!speedPaused)
        startSpeedTests()

    // An action: shows a busy marker on `key`, then the CLI's one-line result.
    function act(key, args) {
        if (busy)
            return
        busy = key
        call(args, function (code, out, err) {
            busy = ""
            messageIsError = code !== 0
            message = (messageIsError ? err || out : out).trim().replace(/^komanet: /, "")
            messageTimer.restart()
            refreshStatus()
            refreshNetworks(false)
        })
    }

    Timer {
        id: messageTimer
        interval: 6000
        onTriggered: root.message = ""
    }

    // Closed: the panel icon only needs the local state, every 30 s.
    // Open: counters and ping every 2 s (one small ping each to the router
    // and to 1.1.1.1), Wi-Fi list every 10 s from NetworkManager's cache.
    Timer {
        interval: root.expanded ? 2000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refreshStatus()
            if (root.expanded)
                root.refreshPing()
        }
    }
    Timer {
        interval: 10000
        running: root.expanded && root.hasWifi
        repeat: true
        onTriggered: root.refreshNetworks(false)
    }
    onExpandedChanged: {
        if (root.expanded) {
            pingSamples = []
            pingMs = -1
            lossPercent = 0
            refreshStatus()
            refreshPing()
            // one fresh scan per opening
            refreshNetworks(true)
            startSpeedTests()
        } else {
            // let any sample in flight finish unseen
            speedRun += 1
            speedPhase = ""
        }
    }

    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        // system tray size, so it lines up with the tray icons next to it
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height, Kirigami.Units.iconSizes.smallMedium)
            height: width
            source: Plasmoid.icon
            active: parent.containsMouse
        }
    }

    fullRepresentation: NetworkPopup {
        host: root
    }
}
