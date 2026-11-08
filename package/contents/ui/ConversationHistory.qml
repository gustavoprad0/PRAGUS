pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

FocusScope {
    id: popup
    required property var client
    property color ink: "#ebebf0"
    property color muted: "#a4a5b0"
    property color accent: "#adb9d7"
    property bool opened: false
    readonly property bool compact: height < 360
    signal closed(bool restoreFocus)
    function open() {
        opened = true
        popup.client.refreshHistory()
        conversations.positionViewAtBeginning()
        Qt.callLater(function() { search.forceActiveFocus() })
    }
    function close(restoreFocus = true) {
        if (!opened) return
        opened = false
        focus = false
        closed(restoreFocus)
    }
    readonly property var matchingConversations: {
        const query = search.text.trim().toLocaleLowerCase()
        return popup.client.history.filter(function(conversation) {
            return !query || [conversation.title, conversation.preview, conversation.cwd, conversation.source].join(" ").toLocaleLowerCase().indexOf(query) >= 0
        })
    }
    function sourceLabel(source) {
        return String(source || "Codex local")
    }
    function updatedLabel(updatedAt) {
        if (!updatedAt) return ""
        const value = Number(updatedAt)
        const date = isNaN(value) ? new Date(updatedAt) : new Date(value < 100000000000 ? value * 1000 : value)
        if (isNaN(date.getTime())) return ""
        return Qt.formatDateTime(date, "dd/MM · HH:mm")
    }
    Connections {
        target: popup.client
        function onConversationLoaded() { popup.close() }
    }
    objectName: "conversationHistory"
    visible: opacity > 0
    opacity: opened ? 1 : 0
    enabled: opened
    Accessible.role: Accessible.Dialog
    Accessible.name: "Histórico de conversas"
    Keys.onEscapePressed: event => { popup.close(); event.accepted = true }
    Behavior on opacity { NumberAnimation { duration: 140 } }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => { wheel.accepted = true }
    }
    Rectangle { anchors.fill: parent; radius: 7; color: "#20212b"; border.color: "#525667" }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: popup.compact ? 10 : 12
        clip: true
        spacing: popup.compact ? 6 : 8
        RowLayout {
            Layout.fillWidth: true; spacing: 4
            Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: "Conversas"; color: popup.ink; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
            ToolButton {
                id: newButton
                objectName: "newHistoryConversation"
                implicitWidth: 26; implicitHeight: 26; padding: 0
                enabled: !popup.client.busy && !popup.client.conversationLoading
                onClicked: { popup.client.newChat(); popup.close() }
                background: Rectangle { radius: 4; color: newButton.hovered ? "#343641" : "transparent" }
                contentItem: Text { text: "+"; color: newButton.enabled ? popup.accent : popup.muted; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                ToolTip.visible: hovered; ToolTip.text: "Nova conversa"; Accessible.name: "Nova conversa"
            }
            ToolButton {
                id: refreshButton
                objectName: "refreshHistory"
                implicitWidth: 26; implicitHeight: 26; padding: 0
                enabled: !popup.client.historyBusy && !popup.client.conversationLoading
                onClicked: popup.client.refreshHistory()
                background: Rectangle { radius: 4; color: refreshButton.hovered ? "#343641" : "transparent" }
                contentItem: Text { text: "↻"; color: refreshButton.enabled ? popup.accent : popup.muted; font.pixelSize: 19; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                ToolTip.visible: hovered; ToolTip.text: "Atualizar histórico"; Accessible.name: "Atualizar histórico"
            }
            ToolButton {
                id: closeButton
                implicitWidth: 26; implicitHeight: 26; padding: 0
                onClicked: popup.close()
                background: Rectangle { radius: 4; color: closeButton.hovered ? "#343641" : "transparent" }
                contentItem: Text { text: "×"; color: popup.accent; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                ToolTip.visible: hovered; ToolTip.text: "Fechar histórico"; Accessible.name: "Fechar histórico"
            }
        }
        TextField {
            id: search
            objectName: "historySearch"
            Layout.fillWidth: true; implicitHeight: 31; padding: 7
            placeholderText: "Buscar uma conversa…"; placeholderTextColor: "#9496a4"
            color: popup.ink; font.pixelSize: 12
            background: Rectangle { radius: 5; color: "#191a23"; border.color: search.activeFocus ? popup.accent : "#424552" }
            onAccepted: {
                if (popup.matchingConversations.length === 1 && !popup.client.busy && !popup.client.conversationLoading) {
                    popup.client.loadConversation(popup.matchingConversations[0].id)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; visible: popup.client.historyBusy || popup.client.conversationLoading; spacing: 6
            BusyIndicator { running: visible; implicitWidth: 16; implicitHeight: 16 }
            Text { Layout.fillWidth: true; text: popup.client.conversationLoading ? "Recuperando conversa e contexto…" : "Buscando conversas…"; color: popup.muted; font.pixelSize: 11; wrapMode: Text.Wrap }
        }
        Text {
            Layout.fillWidth: true; visible: !!popup.client.historyError
            text: popup.client.historyError; color: "#ffc4b6"; font.pixelSize: 11; wrapMode: Text.Wrap; textFormat: Text.PlainText
            maximumLineCount: 3; elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 70
            ListView {
                id: conversations
                objectName: "conversationHistoryList"
                anchors.fill: parent; anchors.rightMargin: 10; clip: true; spacing: 6
                model: popup.matchingConversations
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    id: historyScroll
                    parent: conversations.parent
                    anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
                    width: 6; policy: ScrollBar.AsNeeded; minimumSize: .08
                    contentItem: Rectangle { implicitWidth: 6; radius: 3; color: "#929bb1"; opacity: historyScroll.active ? 1 : .7 }
                    background: Rectangle { radius: 3; color: "#30343f" }
                }
                footer: ToolButton {
                    id: moreButton
                    objectName: "loadMoreHistory"
                    width: conversations.width; height: visible ? 34 : 0
                    visible: popup.client.historyHasMore
                    enabled: !popup.client.historyBusy && !popup.client.conversationLoading
                    onClicked: popup.client.loadMoreHistory()
                    background: Rectangle { radius: 4; color: moreButton.hovered ? "#343641" : "#282a35" }
                    contentItem: Text { text: popup.client.historyBusy ? "Buscando…" : "Carregar mais conversas"; color: popup.accent; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
                delegate: ItemDelegate {
                    id: conversation
                    objectName: "historyConversationRow"
                    required property var modelData
                    readonly property bool active: popup.client.threadId === modelData.id
                    width: conversations.width; height: modelData.preview ? (popup.compact ? 70 : 92) : 64; padding: popup.compact ? 8 : 10
                    enabled: !popup.client.busy && !popup.client.conversationLoading
                    onClicked: {
                        popup.client.loadConversation(modelData.id)
                    }
                    background: Rectangle {
                        radius: 5
                        color: conversation.hovered ? "#343744" : conversation.active ? "#30384b" : "#282a35"
                        border.color: conversation.active ? "#7584a4" : "transparent"
                    }
                    contentItem: Item {
                        ColumnLayout {
                        anchors.fill: parent; spacing: 4
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text {
                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                text: conversation.modelData.title || "Conversa sem título"; textFormat: Text.PlainText
                                color: popup.ink; font.pixelSize: popup.compact ? 12 : 13; font.weight: Font.DemiBold; elide: Text.ElideRight
                            }
                            Text { visible: conversation.active; text: "Atual"; color: popup.accent; font.pixelSize: 10 }
                        }
                        Text {
                            Layout.fillWidth: true; Layout.minimumWidth: 0; Layout.fillHeight: true; visible: !!conversation.modelData.preview
                            text: conversation.modelData.preview || ""; textFormat: Text.PlainText
                            color: popup.muted; font.pixelSize: popup.compact ? 11 : 12; maximumLineCount: popup.compact ? 1 : 2; elide: Text.ElideRight; wrapMode: Text.Wrap
                            verticalAlignment: Text.AlignTop
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: popup.sourceLabel(conversation.modelData.source); color: popup.accent; font.pixelSize: 10; elide: Text.ElideRight }
                            Text { text: popup.updatedLabel(conversation.modelData.updatedAt); color: popup.muted; font.pixelSize: 10 }
                        }
                        }
                    }
                    ToolTip.visible: hovered && !!modelData.cwd
                    ToolTip.text: (modelData.title || "Conversa sem título") + (modelData.cwd ? "\n" + modelData.cwd : "")
                    Accessible.name: (modelData.title || "Conversa sem título") + ", " + popup.sourceLabel(modelData.source)
                }
            }
            Text {
                anchors.fill: parent; anchors.margins: 8
                visible: !popup.client.historyBusy && conversations.count === 0
                text: search.text.trim() ? "Nenhuma conversa encontrada." : "Nenhuma conversa disponível no histórico."
                color: popup.muted; font.pixelSize: 12; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
