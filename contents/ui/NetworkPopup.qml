/*
    The kOMA Network Manager popup: connection header, live stats, DNS
    provider switch and Wi-Fi networks, laid out like Omarchy's network panel
    but drawn with KDE's components and colors.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import "Model.js" as Model

PlasmaExtras.Representation {
    id: popup

    // the PlasmoidItem from main.qml: status, ping, networks, act(), ...
    required property var host

    readonly property var lists: Model.splitNetworks(popup.host.networks)
    property bool customOpen: false

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    // fit the content (short without Wi-Fi), up to a scrolling maximum
    readonly property real fitHeight: Math.min(content.implicitHeight + (popup.header ? popup.header.implicitHeight : 0) + Kirigami.Units.largeSpacing * 2 + Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 30)
    // min = max = content height: a fixed-height popup, so Plasma doesn't
    // restore a stale saved popupHeight from an earlier opening
    Layout.minimumHeight: fitHeight
    Layout.preferredHeight: fitHeight
    Layout.maximumHeight: fitHeight
    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: Model.statusIcon(popup.host.status)
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: Model.connectionTitle(popup.host.status)
                elide: Text.ElideRight
            }
            PlasmaComponents.ToolButton {
                icon.name: "speedometer"
                checkable: true
                checked: !popup.host.speedPaused
                onToggled: popup.host.speedPaused = !checked
                PlasmaComponents.ToolTip {
                    text: popup.host.speedPaused ? "Speed test paused" : "Speed test runs while this is open"
                }
            }
            PlasmaComponents.Switch {
                visible: popup.host.hasWifi
                checked: popup.host.status.wifiEnabled === true
                enabled: popup.host.busy === ""
                onToggled: popup.host.act("radio", ["wifi", "radio", checked ? "on" : "off"])
                PlasmaComponents.ToolTip {
                    text: "Wi-Fi"
                }
            }
        }
    }

    Kirigami.InlineMessage {
        id: banner
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Kirigami.Units.smallSpacing
        }
        visible: popup.host.message.length > 0
        type: popup.host.messageIsError ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
        text: popup.host.message
        showCloseButton: true
        onVisibleChanged: if (!visible)
            popup.host.message = ""
    }

    PlasmaComponents.ScrollView {
        id: scroll
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: banner.visible ? banner.bottom : parent.top
        }
        contentWidth: availableWidth

        ColumnLayout {
            id: content
            width: scroll.availableWidth
            spacing: Kirigami.Units.largeSpacing

            // ------------------------------------------------------------ stats
            GridLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: popup.host.status.connected === true
                columns: 4
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: [["Ping", Model.formatLatency(popup.host.pingMs)], ["Packet Loss", popup.host.pingSamples.length ? popup.host.lossPercent + "%" : "—"], ["Receiving", Model.formatRate(popup.host.rxRate)], ["Sending", Model.formatRate(popup.host.txRate)], ["Downloaded", Model.formatBytes(popup.host.status.rxBytes)], ["Uploaded", Model.formatBytes(popup.host.status.txBytes)], ["Download Speed", popup.host.speedPhase === "down" && popup.host.speedDown < 0 ? "testing…" : Model.formatSpeed(popup.host.speedDown)], ["Upload Speed", popup.host.speedPhase === "up" && popup.host.speedUp < 0 ? "testing…" : Model.formatSpeed(popup.host.speedUp)], ["IP Address", popup.host.status.ip || "—"], ["Gateway", popup.host.status.gateway || "—"]]
                    delegate: RowLayout {
                        required property var modelData
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: parent.modelData[0]
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: parent.modelData[1]
                            font.family: "monospace"
                            elide: Text.ElideLeft
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                visible: popup.host.status.connected !== true
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                text: "No network connection"
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }

            // -------------------------------------------------------------- DNS
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                text: "DNS Provider"
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: Model.DNS_PROVIDERS
                    delegate: PlasmaComponents.Button {
                        id: dnsButton
                        required property string modelData
                        readonly property bool current: (popup.host.status.dns || {}).provider === modelData
                        Layout.fillWidth: true
                        text: modelData
                        checkable: true
                        checked: current || (modelData === "Custom" && popup.customOpen)
                        enabled: popup.host.busy === "" && popup.host.status.connected === true
                        onClicked: {
                            if (dnsButton.modelData === "Custom") {
                                popup.customOpen = !popup.customOpen
                                dnsButton.checked = Qt.binding(() => dnsButton.current || popup.customOpen)
                                return
                            }
                            popup.customOpen = false
                            popup.host.act("dns", ["dns", "set", dnsButton.modelData.toLowerCase()])
                        }
                        PlasmaComponents.BusyIndicator {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            height: parent.height * 0.6
                            width: height
                            visible: popup.host.busy === "dns" && dnsButton.checked
                            running: visible
                        }
                    }
                }
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: !popup.customOpen && ((popup.host.status.dns || {}).servers || []).length > 0
                text: ((popup.host.status.dns || {}).servers || []).join(", ")
                opacity: 0.6
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
            RowLayout {  // Custom servers
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: popup.customOpen
                PlasmaComponents.TextField {
                    id: customServers
                    Layout.fillWidth: true
                    placeholderText: "DNS servers, e.g. 9.9.9.9 149.112.112.112"
                    text: (popup.host.status.dns || {}).provider === "Custom" ? popup.host.status.dns.servers.join(" ") : ""
                    onAccepted: applyCustom.clicked()
                }
                PlasmaComponents.Button {
                    id: applyCustom
                    text: "Apply"
                    enabled: popup.host.busy === "" && Model.parseServers(customServers.text).error === ""
                    onClicked: {
                        var parsed = Model.parseServers(customServers.text)
                        popup.customOpen = false
                        popup.host.act("dns", ["dns", "set", "custom"].concat(parsed.servers))
                    }
                }
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                visible: popup.customOpen && customServers.text.trim().length > 0 && Model.parseServers(customServers.text).error !== ""
                text: Model.parseServers(customServers.text).error
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
            }

            // ------------------------------------------------------------ Wi-Fi
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: popup.host.hasWifi && popup.lists.known.length > 0
                text: "Known Networks"
            }
            Repeater {
                model: popup.host.hasWifi ? popup.lists.known : []
                delegate: WifiRow {
                    host: popup.host
                }
            }
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: popup.host.hasWifi && popup.lists.other.length > 0
                text: "Other Networks"
            }
            Repeater {
                model: popup.host.hasWifi ? popup.lists.other : []
                delegate: WifiRow {
                    host: popup.host
                }
            }
            Kirigami.ListSectionHeader {
                Layout.fillWidth: true
                visible: !popup.host.hasWifi
                text: "Wi-Fi"
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: !popup.host.hasWifi
                text: "No Wi-Fi on this machine."
                opacity: 0.7
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: popup.host.hasWifi && !popup.host.status.wifiEnabled
                text: "Wi-Fi is off"
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.7
            }
            Item {
                Layout.preferredHeight: Kirigami.Units.smallSpacing
            }
        }
    }
}
