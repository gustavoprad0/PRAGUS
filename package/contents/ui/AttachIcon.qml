import QtQuick
import QtQuick.Shapes

Shape {
    implicitWidth: 24; implicitHeight: 24
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: "#d9dbe5"; strokeWidth: 1.7; fillColor: "transparent"
        capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
        PathSvg { path: "M8 13.5L14.5 7A2.1 2.1 0 0 1 17.5 10L9.5 18A3.8 3.8 0 0 1 4.1 12.6L13.3 3.4A5 5 0 0 1 20.4 10.5L11.5 19.4" }
    }
}
