import QtQuick
import QtTest
import "../contents/ui" as UI

// Runs real commands on Plasma's executable engine (needs plasma5support).
TestCase {
    id: test
    name: "CommandQueue"
    when: windowShown

    UI.CommandQueue {
        id: queue
    }
    property var names: ({})
    Connections {
        target: queue.engine
        function onSourceAdded(source) {
            test.names[source] = true
        }
    }

    function init() {
        names = {}
    }

    function test_repeatedCallsReuseOneSourceName() {
        let done = 0
        function again() {
            queue.run("printf ok", function (code, out) {
                compare(code, 0)
                compare(out, "ok")
                if (++done < 200)
                    again()
            })
        }
        again()
        tryVerify(() => done === 200, 30000)
        compare(Object.keys(names), ["printf ok"])
    }

    function test_overlappingCallsEachGetTheirOwnRun() {
        const outputs = []
        for (let i = 0; i < 5; ++i)
            queue.run("date +%N", (code, out) => outputs.push(out))
        verify(queue.busy("date +%N"))
        tryVerify(() => outputs.length === 5, 10000)
        compare(new Set(outputs).size, 5)
        verify(!queue.busy("date +%N"))
    }

    function test_differentCommandsRunSideBySide() {
        const order = []
        queue.run("sleep 0.3; printf slow", (code, out) => order.push(out))
        queue.run("printf fast", (code, out) => order.push(out))
        tryVerify(() => order.length === 2, 5000)
        compare(order, ["fast", "slow"])
    }

    function test_reportsFailures() {
        let result = null
        queue.run("printf oops >&2; exit 3", (code, out, err) => result = [code, out, err])
        tryVerify(() => result !== null, 5000)
        compare(result, [3, "", "oops"])
    }

    function test_runWithoutCallback() {
        queue.run("true")
        tryVerify(() => !queue.busy("true"), 5000)
    }
}
