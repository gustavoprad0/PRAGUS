import QtQuick
import "bridge" as Backend

Rectangle {
    required property var client
    color: "#11121a"
    radius: 6
    border.color: "#383a46"
    Backend.DashboardClient { id: dashboard; objectName: "dashboard"; Component.onCompleted: start() }
    Dashboard { objectName: "pragusDashboard"; anchors.fill: parent; anchors.margins: 12; dashboard: dashboard; client: parent.client }
}
