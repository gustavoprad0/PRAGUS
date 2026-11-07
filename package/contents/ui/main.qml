import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "bridge" as Backend

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    Backend.CodexClient {
        id: backendClient
        Component.onCompleted: start()
    }
    fullRepresentation: PragusShell {
        client: backendClient
        Layout.minimumWidth: 240
        Layout.minimumHeight: 592
        Layout.preferredWidth: 720
        Layout.preferredHeight: 592
    }
    compactRepresentation: Rectangle {
        implicitWidth: 32; implicitHeight: 32
        color: "transparent"
        Text { anchors.centerIn: parent; text: ">_"; color: "#a9ddc1"; font.family: "monospace"; font.bold: true }
        MouseArea { anchors.fill: parent; onClicked: root.expanded = !root.expanded }
    }
}
