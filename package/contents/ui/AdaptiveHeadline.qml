import QtQuick

Item {
    id: root
    property alias text: headline.text
    property color color: "#ebebf0"
    readonly property int renderedPixelSize: fullSize.implicitHeight <= height ? 13 : smallerSize.implicitHeight <= height ? 12 : 11
    readonly property bool truncated: headline.truncated
    Text {
        id: fullSize
        visible: false; width: root.width; text: headline.text
        font.pixelSize: 13; wrapMode: Text.Wrap; textFormat: Text.PlainText
    }
    Text {
        id: smallerSize
        visible: false; width: root.width; text: headline.text
        font.pixelSize: 12; wrapMode: Text.Wrap; textFormat: Text.PlainText
    }
    Text { id: oneLine; visible: false; text: "Ag"; font: headline.font }
    Text {
        id: headline
        anchors.fill: parent; color: root.color
        font.pixelSize: root.renderedPixelSize
        wrapMode: Text.Wrap; textFormat: Text.PlainText
        maximumLineCount: Math.max(1, Math.floor(root.height / Math.max(1, oneLine.implicitHeight)))
        elide: Text.ElideRight
    }
}
