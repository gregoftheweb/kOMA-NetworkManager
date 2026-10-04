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
import org.kde.plasma.plasma5support as P5Support
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
    property real speedDown: -1          // Mbit/s from the latest speed test sample
    property real speedUp: -1
    property string speedPhase: ""       // "down" or "up" while a sample runs
    property bool speedPaused: false     // the header's speedometer button
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
    property var callbacks: ({})
    function call(args, callback) {
        var source = "python3 " + shellQuote(cli) + " " + args.map(shellQuote).join(" ") + " # " + Date.now() + Math.random()
        var cbs = callbacks
        cbs[source] = callback
        callbacks = cbs
        runner.connectSource(source)
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            var cb = root.callbacks[source]
            var cbs = root.callbacks
            delete cbs[source]
            root.callbacks = cbs
            if (cb)
                cb(data["exit code"], String(data.stdout || ""), String(data.stderr || ""))
        }
    }

    function refreshStatus() {
        call(["status", "--json"], function (code, out) {
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
        call(["ping", "--json"], function (code, out) {
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
        call(rescan ? ["wifi", "list", "--json", "--rescan"] : ["wifi", "list", "--json"], function (code, out) {
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
        speedPhase = "down"
        call(["speedtest", "down", "--json"], function (code, out) {
            if (run !== root.speedRun)
                return
            var r = Model.parseJson(out)
            root.speedDown = code === 0 && r ? r.mbps : -1
            if (!root.expanded || root.speedPaused) {
                root.speedPhase = ""
                return
            }
            root.speedPhase = "up"
            root.call(["speedtest", "up", "--json"], function (code2, out2) {
                if (run !== root.speedRun)
                    return
                var r2 = Model.parseJson(out2)
                root.speedUp = code2 === 0 && r2 ? r2.mbps : -1
                root.speedPhase = ""
                speedGap.run = run
                speedGap.restart()
            })
        })
    }
    Timer {
        id: speedGap
        property int run: 0
        interval: 2000
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
