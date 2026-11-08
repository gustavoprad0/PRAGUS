pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ComboBox {
    id: control
    property bool fullLabels: false
    implicitHeight: 31; font.pixelSize: 12; leftPadding: 18; rightPadding: 18
    palette.text: "#e6e6ed"; palette.buttonText: "#e6e6ed"; palette.highlight: "#3f495e"
    background: Rectangle { radius: 4; color: control.hovered ? "#30313b" : "#24252e"; border.color: control.activeFocus ? "#919bb5" : "#43444f" }
    contentItem: Text { text: control.displayText; color: control.enabled ? "#e0e0e7" : "#777984"; font: control.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: control.fullLabels ? Text.ElideNone : Text.ElideRight }
    indicator: Text { x: control.width - 14; anchors.verticalCenter: parent.verticalCenter; text: "⌄"; color: "#b4b7c7"; font.pixelSize: 13 }
    delegate: ItemDelegate {
        id: option
        required property int index
        width: optionList.width; height: 37; padding: 4
        contentItem: Text { text: control.textAt(option.index); color: option.highlighted ? "#ffffff" : "#d3d4df"; font: control.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: control.fullLabels ? Text.ElideNone : Text.ElideRight }
        background: Rectangle { color: option.highlighted ? "#404451" : "transparent"; radius: 3 }
        highlighted: control.highlightedIndex === index
    }
    popup: Popup {
        id: choices; objectName: "selectionPopup"
        y: control.height + 4; width: control.width; x: 0
        padding: 5; implicitHeight: Math.min(optionList.contentHeight + 10, control.fullLabels ? 320 : 250)
        background: Rectangle { color: "#24252e"; radius: 5; border.color: "#50515e" }
        contentItem: Item {
            ListView {
                id: optionList; objectName: "modelOptions"
                anchors.fill: parent; anchors.rightMargin: contentHeight > height ? 10 : 0
                clip: true; model: choices.visible ? control.delegateModel : null; currentIndex: control.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    parent: optionList.parent; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
                    objectName: "optionScroll"
                    orientation: Qt.Vertical
                    width: 4; minimumSize: .12
                    policy: optionList.contentHeight > optionList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    contentItem: Rectangle { implicitWidth: 4; implicitHeight: 20; radius: 2; color: "#81889c" }
                    background: Rectangle { radius: 2; color: "#343641" }
                }
            }
        }
        onOpened: optionList.positionViewAtIndex(control.currentIndex, ListView.Center)
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 130 } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
    }
}
