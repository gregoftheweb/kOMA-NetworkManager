/*
    One Wi-Fi network in the kOMA Network Manager popup: signal icon, name,
    lock for secured networks. Click to connect (or disconnect the active one);
    saved networks can be forgotten from the hover button.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "Model.js" as Model

PlasmaComponents.ItemDelegate {
    id: row

    required property var modelData
    required property var host

    Layout.fillWidth: true
    hoverEnabled: true
    enabled: row.host.busy === "" || row.host.busy === row.modelData.ssid
    onClicked: row.modelData.active ? row.host.act(row.modelData.ssid, ["wifi", "disconnect"]) : row.host.act(row.modelData.ssid, ["wifi", "connect", row.modelData.ssid])

    contentItem: RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            source: Model.wifiIcon(row.modelData.signal)
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: row.modelData.ssid
            font.weight: row.modelData.active ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            visible: row.modelData.active
            text: "Connected"
            color: Kirigami.Theme.highlightColor
            font: Kirigami.Theme.smallFont
        }
        PlasmaComponents.BusyIndicator {
            visible: row.host.busy === row.modelData.ssid
            running: visible
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
        }
        PlasmaComponents.ToolButton {
            visible: row.modelData.known && row.hovered && row.host.busy === ""
            icon.name: "edit-delete"
            onClicked: row.host.act(row.modelData.ssid, ["wifi", "forget", row.modelData.ssid])
            PlasmaComponents.ToolTip {
                text: "Forget this network"
            }
        }
        Kirigami.Icon {
            visible: row.modelData.secure
            source: "object-locked"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            opacity: 0.7
        }
    }
}
