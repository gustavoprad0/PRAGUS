import QtQuick
import QtQuick.Shapes

Shape {
    id: root
    property bool outgoing: false
    required property color bubbleColor
    implicitWidth: 8; implicitHeight: 11
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: "transparent"; fillColor: root.bubbleColor
        startX: root.outgoing ? 0 : 8; startY: 0
        PathLine { x: root.outgoing ? 8 : 0; y: 0 }
        PathLine { x: root.outgoing ? 0 : 8; y: 11 }
        PathLine { x: root.outgoing ? 0 : 8; y: 0 }
    }
}
