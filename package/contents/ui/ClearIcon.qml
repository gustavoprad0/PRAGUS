import QtQuick
import QtQuick.Shapes

Shape {
    property color ink: "#d9dbe5"
    implicitWidth: 24; implicitHeight: 24
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: ink; strokeWidth: 1.7; fillColor: "transparent"
        capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
        PathSvg { path: "M5 7H19 M9 7V4H15V7 M7 7L8 20H16L17 7 M10 10V17 M14 10V17" }
    }
}
