// MIT — Copyright 2026 Columbia Foundry
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Runs shell commands on Plasma's executable engine, one fixed source name per command.
//
// Never make names unique (`cmd # Date.now()`): every DataSource on the engine keeps a
// property for each name the engine has ever removed and rebuilds them all on each
// removal, so plasmashell gets slower with every call until it pegs a core.
//
// Calls to the same command run one after another. The next run starts once the engine
// has removed the previous source: reconnecting before that replays the cached result
// instead of running the command again.
QtObject {
    id: root

    // command -> callbacks each waiting for a run of their own; the first is in flight
    property var queues: ({})
    // command -> true from its run finishing until the engine has removed the source.
    // Tracked here because the DataSource's own `sources` list keeps removed names.
    property var settling: ({})

    // callback(exitCode, stdout, stderr), or nothing to just run it
    function run(command, callback) {
        const queue = queues[command] || []
        queue.push(callback || null)
        queues[command] = queue
        if (queue.length === 1 && !settling[command])
            engine.connectSource(command)
    }

    function resume(command) {
        if (busy(command) && !settling[command])
            engine.connectSource(command)
    }

    function busy(command) {
        return (queues[command] || []).length > 0
    }

    readonly property P5Support.DataSource engine: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            if (!root.busy(source))
                return
            root.settling[source] = true
            disconnectSource(source)
            const callback = root.queues[source].shift()
            if (callback)
                callback(data["exit code"], String(data.stdout || ""), String(data.stderr || ""))
        }
        // The engine signals removal before deleting the old source, so reconnect a
        // moment later or the run attaches to the source being deleted.
        onSourceRemoved: function (source) {
            root.settling[source] = false
            if (root.busy(source))
                Qt.callLater(root.resume, source)
        }
    }
}
