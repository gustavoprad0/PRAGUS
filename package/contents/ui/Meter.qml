import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property string label
    required property real value
    property string detail: value >= 0 ? Math.round(value) + "%" : "—"
    property bool remaining: false
    property bool battery: false
    property string hint: ""
    readonly property color positiveColor: "#36e29a"
    readonly property color warningColor: "#ffbf32"
    readonly property color negativeColor: "#ff5067"
    readonly property color levelColor: value < 0 ? "#767982" : remaining
        ? (value <= 20 ? negativeColor : value <= 40 ? warningColor : positiveColor)
        : (value >= 90 ? negativeColor : value >= 70 ? warningColor : positiveColor)
    Layout.minimumWidth: 0
    spacing: 4
    RowLayout {
        Layout.fillWidth: true; spacing: 5
        Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: root.label; color: "#ebebf0"; font.pixelSize: 11; elide: Text.ElideRight }
        Text { text: root.detail; color: "#ebebf0"; font.pixelSize: 11; font.weight: Font.DemiBold }
        Item {
            visible: root.battery; implicitWidth: 15; implicitHeight: 9
            Rectangle { width: 13; height: 8; radius: 1; anchors.verticalCenter: parent.verticalCenter; color: "transparent"; border.color: root.levelColor
                Rectangle { x: 2; y: 2; width: 9 * Math.max(0, Math.min(100, root.value)) / 100; height: 4; radius: .5; color: root.levelColor }
            }
            Rectangle { x: 13; width: 2; height: 4; radius: .5; anchors.verticalCenter: parent.verticalCenter; color: root.levelColor }
        }
    }
    Rectangle {
        Layout.fillWidth: true; implicitHeight: 5; radius: 1; color: "#40424b"
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, root.value)) / 100; height: parent.height; radius: 1; color: root.levelColor
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 250 } }
        }
    }
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered && root.hint.length > 0
    ToolTip.text: root.hint
    Accessible.name: label + ": " + detail
}
