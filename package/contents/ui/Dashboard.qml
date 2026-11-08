import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window

Item {
    id: root
    required property var dashboard
    required property var client
    readonly property bool wide: width >= 580
    readonly property color ink: "#ebebf0"
    readonly property color muted: "#a4a5b0"
    readonly property color accent: "#adb9d7"
    property bool modelOptionsExpanded: false
    readonly property color composerButtonColor: sendButton.enabled ? "#4d5d7b" : "#343641"
    readonly property real lowerCardHeight: 160
    property double currentSeconds: Math.floor(Date.now() / 1000)
    function resetCountdown(resetAt) {
        if (!(resetAt > 0)) return "—"
        const seconds = Math.max(0, Math.floor(resetAt - currentSeconds))
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor(seconds % 3600 / 60)
        return String(hours).padStart(2, "0") + ":" + String(minutes).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0")
    }
    Timer {
        interval: 1000; repeat: true; running: root.visible; triggeredOnStart: true
        onTriggered: root.currentSeconds = Math.floor(Date.now() / 1000)
    }
    Connections {
        target: root.Window.window
        function onActiveChanged() {
            if (root.Window.window && !root.Window.window.active) {
                root.modelOptionsExpanded = false
                historyPopup.close(false)
            }
        }
    }
    property bool clearing: false
    property int nextNewsPage: 0
    property bool followAnswer: true
    function moveNews(delta) {
        if (newsTransition.running) return
        nextNewsPage = Math.max(0, Math.min(newsPages - 1, newsPage + delta))
        if (nextNewsPage !== newsPage) newsTransition.restart()
    }
    readonly property bool newsRefreshing: dashboard.newsBusy || newsRefreshFeedback.running
    function refreshNews() {
        if (newsRefreshing) return
        nextNewsPage = 0
        newsTransition.restart()
        newsRefreshFeedback.restart()
        dashboard.refresh()
    }
    Timer { id: newsRefreshFeedback; objectName: "newsRefreshFeedback"; interval: 800 }
    function advanceNews() {
        if (newsPaused || newsPages <= 1) return
        moveNews(newsPage >= newsPages - 1 ? -newsPage : 1)
    }
    Timer {
        objectName: "newsRotation"
        interval: 30000; repeat: true
        running: root.visible && root.newsPages > 1 && !root.newsPaused && !newsTransition.running && !root.newsRefreshing
        onTriggered: root.advanceNews()
    }
    function clearConversation() {
        if (client.busy || client.conversationLoading || clearing || (!answers.count && !client.attachments.length)) return
        clearing = true; clearTransition.restart()
    }
    property int newsPage: 0
    readonly property int newsPages: Math.max(1, dashboard.news.length)
    readonly property bool newsPaused: newsHover.hovered
    function percent(v) { return v >= 0 ? Math.round(v) + "%" : "—" }
    function gib(used, total) { const digits = total >= 100 ? 0 : 1; return used >= 0 ? used.toFixed(digits).replace(".", ",") + " / " + total.toFixed(digits).replace(".", ",") + " GiB" : "—" }
    function newsTitle(story) {
        const title = String(story.title || "").trim()
        const source = String(story.source || "").trim()
        if (source) {
            for (const separator of [" - ", " – ", " — "]) {
                const suffix = separator + source
                if (title.toLowerCase().endsWith(suffix.toLowerCase())) return title.slice(0, -suffix.length).trim()
            }
        }
        return title
    }
    function modelName(id, name) {
        const match = id.match(/^gpt[- ]?(\d+(?:\.\d+)*)(?:-(.+))?$/i)
        return match ? "GPT " + match[1] + (match[2] ? " - " + match[2].replace(/-/g, " ").toUpperCase() : "") : (name || id)
    }
    function effortName(value) {
        const names = {none: "NENHUM", minimal: "MÍNIMO", low: "BAIXO", medium: "MÉDIO", high: "ALTO", xhigh: "EXTRA ALTO", max: "MÁXIMO", ultra: "ULTRA"}
        return names[value] || String(value).replace(/[_-]+/g, " ").toLocaleUpperCase()
    }
    function ask() {
        root.followAnswer = true
        if ((composer.text.trim() || client.attachments.length) && !client.busy && !client.conversationLoading && client.send(composer.text)) composer.clear()
    }
    function showHistory() {
        root.modelOptionsExpanded = false
        const viewport = dashboardScroll.contentItem
        const top = questionCard.mapToItem(viewport.contentItem, 0, 0).y
        if (top < viewport.contentY) viewport.contentY = top
        else if (top + questionCard.height > viewport.contentY + viewport.height) {
            viewport.contentY = Math.max(0, Math.min(top, top + questionCard.height - viewport.height))
        }
        historyPopup.open()
    }
    FileDialog {
        id: attachmentPicker
        objectName: "attachmentPicker"
        title: "Anexar à pergunta"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Imagens e arquivos (*)"]
        onAccepted: {
            for (let i = 0; i < selectedFiles.length; i++) client.addAttachment(selectedFiles[i])
            composer.forceActiveFocus()
        }
    }
    component Card: Rectangle {
        color: "#1c1d26"; radius: 5; border.color: "#343540"
        Layout.minimumWidth: 0
    }
    component Caption: Text {
        color: root.muted; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: .8
    }
    component HeadingDivider: Rectangle {
        Layout.fillWidth: true; implicitHeight: 1; color: "#3a3c48"
    }
    component SectionHeading: RowLayout {
        property alias text: heading.text
        Layout.fillWidth: true; spacing: 10
        Caption { id: heading; objectName: "sectionTitle" }
        HeadingDivider {}
    }
    component IconButton: ToolButton {
        id: control
        property string hint: ""
        implicitWidth: 24; implicitHeight: 24
        padding: 0
        background: Rectangle { radius: 5; color: control.hovered ? "#343641" : "transparent" }
        contentItem: Text { text: control.text; color: control.enabled ? root.accent : "#6d707e"; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        ToolTip.visible: hovered && hint.length > 0
        ToolTip.text: hint
        Accessible.name: hint
    }
    SequentialAnimation {
        id: clearTransition
        ParallelAnimation { NumberAnimation { target: answers; property: "opacity"; to: 0; duration: 130 } NumberAnimation { target: answers; property: "scale"; to: .97; duration: 130 } }
        ScriptAction { script: client.newChat() }
        PauseAnimation { duration: 200 }
        ScriptAction { script: root.clearing = false }
        ParallelAnimation { NumberAnimation { target: answers; property: "opacity"; to: 1; duration: 160 } NumberAnimation { target: answers; property: "scale"; to: 1; duration: 160 } }
    }
    SequentialAnimation {
        id: newsTransition
        ParallelAnimation { NumberAnimation { target: newsContent; property: "opacity"; to: 0; duration: 110 } NumberAnimation { target: newsContent; property: "scale"; to: .97; duration: 110 } }
        ScriptAction { script: root.newsPage = root.nextNewsPage }
        ParallelAnimation { NumberAnimation { target: newsContent; property: "opacity"; to: 1; duration: 180 } NumberAnimation { target: newsContent; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic } }
    }
    PageTransition {
        id: connectionsPaging; objectName: "connectionsPaging"
        targetItem: connectionList; pageCount: Math.max(1, Math.ceil(dashboard.peripheralDevices.length / 3))
    }
    PageTransition {
        id: attachmentPaging; objectName: "attachmentPaging"
        targetItem: attachmentRow; pageCount: Math.max(1, Math.ceil(client.attachments.length / attachmentTray.pageSize))
    }
    ConversationHistory {
        id: historyPopup
        parent: questionCard
        anchors.fill: parent
        z: 100
        client: root.client; ink: root.ink; muted: root.muted; accent: root.accent
        onClosed: restoreFocus => { if (restoreFocus) historyButton.forceActiveFocus() }
    }
    MouseArea {
        id: dismissHistory; objectName: "dismissHistory"
        parent: root.Window.window ? root.Window.window.contentItem : root
        anchors.fill: parent
        z: 10000
        enabled: historyPopup.opened
        visible: enabled
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => {
            const position = historyPopup.mapFromItem(dismissHistory, mouse.x, mouse.y)
            if (position.x < 0 || position.y < 0 || position.x >= historyPopup.width || position.y >= historyPopup.height) historyPopup.close(false)
            mouse.accepted = false
        }
        onWheel: wheel => { wheel.accepted = false }
    }
    ScrollView {
        id: dashboardScroll
        anchors.fill: parent; clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            width: parent.width
            spacing: 8
            GridLayout {
                id: mainGrid
                Layout.fillWidth: true
                Layout.preferredHeight: root.wide ? Math.max(448, root.height - 120) : implicitHeight
                columns: root.wide ? 2 : 1
                columnSpacing: 8; rowSpacing: 8
                ColumnLayout {
                    Layout.row: 0; Layout.column: 0
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0
                    Layout.minimumHeight: root.wide ? 448 : 0
                    Layout.preferredWidth: 1; spacing: 8
            Card {
                objectName: "identityCard"
                Layout.preferredWidth: 1; Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.wide ? 1 : 220
                color: "#191a23"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6
                    Item {
                        Layout.fillWidth: true; implicitHeight: 30
                        Row {
                            anchors.centerIn: parent; spacing: 7
                            Image { width: 28; height: 28; source: "assets/pragus.png"; sourceSize: Qt.size(56, 56); fillMode: Image.PreserveAspectFit }
                            Caption { anchors.verticalCenter: parent.verticalCenter; text: "PRAGUS"; color: root.ink; font.pixelSize: 13; font.letterSpacing: 1.5 }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#3a3c48" }
                    Item { Layout.fillHeight: true; Layout.minimumHeight: 2 }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: dashboard.greeting; color: root.ink; font.pixelSize: 22; font.weight: Font.DemiBold }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: dashboard.localDate; color: root.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; objectName: "clockText"; text: dashboard.localTime; color: "#e6e7ed"; font.pixelSize: 30; minimumPixelSize: 20; fontSizeMode: Text.HorizontalFit; font.weight: Font.ExtraBold; font.family: "Noto Sans"; font.features: { "tnum": 1 } }
                    Item { Layout.fillHeight: true; Layout.minimumHeight: 2 }
                    ColumnLayout {
                        objectName: "identityWeatherFooter"
                        Layout.fillWidth: true; spacing: 6
                        Rectangle { objectName: "identityFooterDivider"; Layout.fillWidth: true; implicitHeight: 1; color: "#3a3c48" }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: dashboard.weatherLocation; color: root.ink; font.pixelSize: 11; wrapMode: Text.Wrap }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: dashboard.weatherTemperature ? dashboard.weatherTemperature + " · " + dashboard.weatherSummary.split(" · ")[0] + "\n" + (dashboard.weatherSummary.split(" · ")[1] || "") + (dashboard.weatherStale ? "\n" + dashboard.weatherStatus.split(" · ")[0].replace("Última atualização às ", "Atualizado ") : "") : dashboard.weatherStatus; color: root.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
                    }
                }
            }
            Card {
                objectName: "connectionsCard"
                Layout.preferredWidth: 1
                Layout.fillWidth: true; Layout.fillHeight: !root.wide
                Layout.minimumHeight: root.wide ? root.lowerCardHeight : 0
                Layout.maximumHeight: root.wide ? root.lowerCardHeight : Infinity
                Layout.preferredHeight: root.wide ? root.lowerCardHeight : 160
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 6
                    SectionHeading { text: "CONEXÕES" }
                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: connectionList.implicitHeight; clip: true
                        ColumnLayout {
                            id: connectionList; width: parent.width; spacing: 7
                            Repeater {
                                model: dashboard.peripheralDevices.slice(connectionsPaging.page * 3, connectionsPaging.page * 3 + 3)
                                delegate: Meter {
                                    required property var modelData
                                    Layout.fillWidth: true; label: modelData.name; value: modelData.percent; remaining: true; battery: true
                                    hint: modelData.name + (modelData.percent >= 0 ? " · " + root.percent(modelData.percent) : " · bateria não informada pelo dispositivo")
                                }
                            }
                        }
                        Text { visible: dashboard.peripheralDevices.length === 0; text: "Nenhum periférico identificado"; color: root.muted; font.pixelSize: 11 }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 2; visible: connectionsPaging.pageCount > 1
                        Text { Layout.fillWidth: true; text: (connectionsPaging.page + 1) + "/" + connectionsPaging.pageCount; color: root.muted; font.pixelSize: 11 }
                        IconButton { objectName: "previousConnections"; implicitWidth: 22; implicitHeight: 20; text: "‹"; hint: "Conexões anteriores"; enabled: connectionsPaging.page > 0 && !connectionsPaging.running; onClicked: connectionsPaging.goTo(connectionsPaging.page - 1) }
                        IconButton { objectName: "nextConnections"; implicitWidth: 22; implicitHeight: 20; text: "›"; hint: "Próximas conexões"; enabled: connectionsPaging.page < connectionsPaging.pageCount - 1 && !connectionsPaging.running; onClicked: connectionsPaging.goTo(connectionsPaging.page + 1) }
                    }
                }
            }
                }
                ColumnLayout {
                    Layout.row: root.wide ? 0 : 1; Layout.column: root.wide ? 1 : 0
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0
                    Layout.preferredWidth: root.wide ? 3 : 1; spacing: 8
            Card {
                id: questionCard; objectName: "questionCard"
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.minimumHeight: root.wide ? 220 : 0
                Layout.preferredWidth: 1
                Layout.preferredHeight: root.wide ? Math.max(192, root.height - 288) : 320
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Caption { objectName: "sectionTitle"; text: "PERGUNTE AO PRAGUS" }
                        HeadingDivider {}
                        IconButton {
                            id: historyButton
                            objectName: "openHistory"; hint: "Histórico de conversas"; enabled: !client.busy && !client.conversationLoading && !root.clearing
                            onClicked: root.showHistory()
                            contentItem: Item {
                                opacity: historyButton.enabled ? 1 : .4
                                Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: "transparent"; border.color: root.accent; border.width: 1.5 }
                                Rectangle { x: parent.width / 2 - .7; y: parent.height / 2 - 4; width: 1.4; height: 5; radius: .7; color: root.accent }
                                Rectangle { x: parent.width / 2; y: parent.height / 2; width: 4; height: 1.4; radius: .7; color: root.accent; rotation: 25; transformOrigin: Item.Left }
                            }
                        }
                        IconButton {
                            objectName: "clearChat"; hint: "Limpar conversa e anexos"; enabled: !client.busy && !client.conversationLoading && !root.clearing && (answers.count > 0 || client.attachments.length > 0)
                            onClicked: root.clearConversation()
                            contentItem: ClearIcon { opacity: parent.enabled ? 1 : .4 }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Meter { objectName: "fiveHourMeter"; Layout.fillWidth: true; label: "5h - " + root.resetCountdown(client.fiveHourReset); value: client.fiveHourUsed >= 0 ? 100 - client.fiveHourUsed : -1; remaining: true; detail: value >= 0 ? root.percent(value) + " livre" : "—"; hint: client.quotaError || root.percent(client.fiveHourUsed) + " utilizado" }
                        Meter { objectName: "weeklyMeter"; Layout.fillWidth: true; label: "Semanal - " + root.resetCountdown(client.weeklyReset); value: client.weeklyUsed >= 0 ? 100 - client.weeklyUsed : -1; remaining: true; detail: value >= 0 ? root.percent(value) + " livre" : "—"; hint: client.quotaError || root.percent(client.weeklyUsed) + " utilizado" }
                    }
                    ColumnLayout {
                        id: modelSettingsGroup; objectName: "modelSettingsGroup"
                        Layout.fillWidth: true; spacing: 6
                    ToolButton {
                        id: modelToggle
                        objectName: "modelSettingsToggle"
                        Layout.fillWidth: true; Layout.preferredHeight: 18; padding: 0
                        onClicked: root.modelOptionsExpanded = !root.modelOptionsExpanded
                        background: Rectangle { radius: 3; color: modelToggle.hovered ? "#292c37" : "transparent" }
                        contentItem: RowLayout {
                            spacing: 6
                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#3a3d4b" }
                            Item {
                                implicitWidth: 24; implicitHeight: 16
                                rotation: root.modelOptionsExpanded ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Rectangle { x: 6; y: 7; width: 7; height: 1.5; radius: .75; rotation: 40; color: root.accent; antialiasing: true }
                                Rectangle { x: 11; y: 7; width: 7; height: 1.5; radius: .75; rotation: -40; color: root.accent; antialiasing: true }
                            }
                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#3a3d4b" }
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: root.modelOptionsExpanded ? "Recolher modelo e esforço" : "Selecionar modelo e esforço"
                        Accessible.name: ToolTip.text
                    }
                    Item {
                        id: modelSettingsSlot
                        objectName: "modelSettings"
                        Layout.fillWidth: true
                        implicitHeight: root.modelOptionsExpanded ? 31 : 0
                        visible: implicitHeight > 0
                        enabled: root.modelOptionsExpanded
                        clip: true; opacity: Math.min(1, height / 31)
                        Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Popup {
                            id: modelPanelPopup
                            objectName: "modelPanelPopup"
                            parent: modelSettingsGroup
                            x: modelSettingsSlot.x; y: modelSettingsSlot.y
                            width: modelSettingsSlot.width; height: 31; padding: 0
                            visible: root.modelOptionsExpanded
                            modal: false; dim: false; focus: false
                            background: null
                            closePolicy: Popup.CloseOnPressOutsideParent | Popup.CloseOnEscape
                            onClosed: root.modelOptionsExpanded = false
                        contentItem: RowLayout {
                        spacing: 5
                        ModelSelect {
                            objectName: "modelSelect"; Layout.fillWidth: true; Layout.minimumWidth: 0
                            model: client.models.map(function(m) { return {id: m.id, name: root.modelName(m.id, m.name)} }); textRole: "name"; valueRole: "id"
                            currentIndex: { for (let i = 0; i < client.models.length; i++) if (client.models[i].id === client.model) return i; return -1 }
                            enabled: root.modelOptionsExpanded && client.ready && !client.busy && !root.clearing
                            onActivated: client.model = currentValue
                            ToolTip.visible: hovered; ToolTip.text: "Modelo: " + client.model
                        }
                        ModelSelect {
                            id: effortSelect; objectName: "effortSelect"
                            readonly property real labelWidth: model.reduce(function(width, option) { return Math.max(width, effortFontMetrics.advanceWidth(option.name)) }, 0)
                            Layout.minimumWidth: Math.ceil(labelWidth) + leftPadding + rightPadding
                            Layout.preferredWidth: Layout.minimumWidth
                            Layout.maximumWidth: Layout.minimumWidth
                            fullLabels: true; font.capitalization: Font.AllUppercase
                            leftPadding: 12; rightPadding: 22
                            FontMetrics { id: effortFontMetrics; font: effortSelect.font }
                            model: client.efforts.map(function(e) { return {id: e, name: root.effortName(e)} })
                            textRole: "name"; valueRole: "id"; currentIndex: client.efforts.indexOf(client.effort)
                            enabled: root.modelOptionsExpanded && client.ready && !client.busy && !root.clearing
                            onActivated: client.effort = currentValue
                            ToolTip.visible: hovered; ToolTip.text: "Nível de raciocínio"
                        }
                    }
                        }
                    }
                    }
                    RowLayout {
                        id: attachmentTray; objectName: "attachmentTray"
                        readonly property bool paginated: client.attachments.length > Math.max(1, Math.min(3, Math.floor((width + 5) / 115)))
                        readonly property int pageSize: Math.max(1, Math.min(3, Math.floor((width - (paginated ? 89 : 0) + 5) / 115)))
                        Layout.fillWidth: true; Layout.preferredHeight: 26; Layout.minimumHeight: 26; Layout.maximumHeight: 26
                        visible: client.attachments.length > 0; spacing: 5
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0; clip: true
                            Row {
                                id: attachmentRow; objectName: "attachmentRow"; width: parent.width; height: 26; spacing: 5
                                Repeater {
                                    model: client.attachments.slice(attachmentPaging.page * attachmentTray.pageSize, (attachmentPaging.page + 1) * attachmentTray.pageSize)
                                    delegate: Rectangle {
                                        required property var modelData
                                        objectName: "attachmentChip"
                                        width: Math.min(142, Math.max(0, (attachmentRow.width - 5 * (attachmentTray.pageSize - 1)) / attachmentTray.pageSize)); height: 26; radius: 5; color: "#2a2d3a"; border.color: "#4a4e60"
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 3; spacing: 4
                                            Image { visible: modelData.kind === "image"; source: modelData.preview || ""; Layout.preferredWidth: 18; Layout.preferredHeight: 18; fillMode: Image.PreserveAspectFit }
                                            Text { Layout.fillWidth: true; Layout.minimumWidth: 0; text: modelData.name; color: root.ink; font.pixelSize: 11; elide: Text.ElideMiddle }
                                            IconButton { implicitWidth: 18; implicitHeight: 18; text: "×"; hint: "Remover anexo"; enabled: !client.busy; onClicked: client.removeAttachment(modelData.id) }
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.preferredWidth: 84; Layout.minimumWidth: 84; Layout.maximumWidth: 84
                            visible: attachmentTray.paginated; spacing: 2
                            IconButton { objectName: "previousAttachments"; implicitWidth: 22; implicitHeight: 20; text: "‹"; hint: "Anexos anteriores"; enabled: attachmentPaging.page > 0 && !attachmentPaging.running; onClicked: attachmentPaging.goTo(attachmentPaging.page - 1) }
                            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: (attachmentPaging.page + 1) + "/" + attachmentPaging.pageCount; color: root.muted; font.pixelSize: 11 }
                            IconButton { objectName: "nextAttachments"; implicitWidth: 22; implicitHeight: 20; text: "›"; hint: "Próximos anexos"; enabled: attachmentPaging.page < attachmentPaging.pageCount - 1 && !attachmentPaging.running; onClicked: attachmentPaging.goTo(attachmentPaging.page + 1) }
                        }
                    }
                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 35; clip: true
                        ChatBackdrop { anchors.fill: parent }
                        ColumnLayout {
                            anchors.centerIn: parent; visible: root.clearing; spacing: 3
                            BusyIndicator { running: root.clearing; Layout.alignment: Qt.AlignHCenter; implicitWidth: 22; implicitHeight: 22 }
                            Text { text: "Limpando…"; color: root.muted; font.pixelSize: 12 }
                        }
                    ListView {
                        id: answers; objectName: "answers"
                        anchors.fill: parent
                        anchors.topMargin: 10 + (attachmentErrorLabel.visible ? attachmentErrorLabel.height + 4 : 0)
                        anchors.bottomMargin: 8 + (activity.visible ? activity.height + 6 : 0)
                        enabled: !root.clearing
                        model: client.messages; clip: true; spacing: 8
                        boundsBehavior: Flickable.StopAtBounds
                        maximumFlickVelocity: 550; flickDeceleration: 4500
                        onMovementStarted: root.followAnswer = false
                        onContentHeightChanged: if (root.followAnswer) Qt.callLater(function() { answers.positionViewAtEnd() })
                        onHeightChanged: if (root.followAnswer) Qt.callLater(function() { answers.positionViewAtEnd() })
                        delegate: Item {
                            id: message
                            required property string speaker
                            required property string body
                            required property var files
                            width: answers.width; height: bubble.implicitHeight + 4
                            Rectangle {
                                id: bubble
                                objectName: "chatBubble"
                                property string speaker: message.speaker
                                width: Math.min(message.width * (message.speaker === "user" ? .82 : .88), Math.max(76, bodyText.implicitWidth + 22))
                                implicitHeight: messageColumn.implicitHeight + 18
                                anchors.right: message.speaker === "user" ? parent.right : undefined
                                anchors.left: message.speaker === "user" ? undefined : parent.left
                                anchors.leftMargin: 13; anchors.rightMargin: 13
                                radius: 9; color: message.speaker === "user" ? "#333b50" : "#282933"
                                BubbleTail {
                                    objectName: "chatBubbleTail"
                                    outgoing: message.speaker === "user"; bubbleColor: bubble.color
                                    visible: message.y + bubble.y + 8 - answers.contentY >= 0 && message.y + bubble.y + 19 - answers.contentY <= answers.height
                                    anchors.top: parent.top; anchors.topMargin: 8
                                    anchors.left: outgoing ? parent.right : undefined
                                    anchors.right: outgoing ? undefined : parent.left
                                }
                                Column {
                                    id: messageColumn; width: parent.width - 20; anchors.centerIn: parent; spacing: 4
                                    Text { text: message.speaker === "user" ? "Eu" : "Pragus"; color: root.accent; font.pixelSize: 11; font.weight: Font.DemiBold }
                                    Repeater {
                                        model: message.files
                                        delegate: Column {
                                            required property var modelData
                                            width: messageColumn.width; spacing: 3
                                            Image { visible: modelData.kind === "image"; width: Math.min(parent.width, 180); height: visible ? 40 : 0; source: modelData.preview || ""; fillMode: Image.PreserveAspectFit; horizontalAlignment: Image.AlignLeft }
                                            Text { width: parent.width; text: "↳ " + modelData.name; color: root.accent; font.pixelSize: 11; elide: Text.ElideMiddle }
                                        }
                                    }
                                    Text { id: bodyText; width: parent.width; text: message.body; color: root.ink; font.pixelSize: 13; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                                }
                            }
                        }
                        Connections { target: client; function onScrollToLatest() { Qt.callLater(function() { answers.positionViewAtEnd() }) } function onChanged() { if (client.busy) Qt.callLater(function() { answers.positionViewAtEnd() }) } }
                        WheelHandler {
                            target: null
                            onWheel: event => {
                                root.followAnswer = false; answers.cancelFlick()
                                const delta = event.pixelDelta.y ? event.pixelDelta.y * .65 : event.angleDelta.y / 120 * 22
                                const minimum = answers.originY
                                answers.contentY = Math.max(minimum, Math.min(minimum + Math.max(0, answers.contentHeight - answers.height), answers.contentY - delta))
                                event.accepted = true
                            }
                        }
                        ScrollBar.vertical: ScrollBar { width: 3 }
                    }
                    Rectangle {
                        id: activity; objectName: "answerActivity"
                        readonly property bool working: client.busy || client.conversationLoading
                        width: Math.min(parent.width - 26, activityContent.implicitWidth + 20)
                        implicitHeight: activityContent.implicitHeight + 16
                        anchors.left: parent.left; anchors.leftMargin: 13
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                        visible: working || !!client.error
                        radius: 9; color: client.error ? "#352b30" : "#282c38"
                        border.color: client.error ? "#6b4548" : "#41495c"
                        RowLayout {
                            id: activityContent
                            anchors.fill: parent; anchors.margins: 8; spacing: 8
                            Image {
                                visible: activity.working; source: "assets/pragus.png"
                                Layout.preferredWidth: 20; Layout.preferredHeight: 20; sourceSize: Qt.size(40, 40)
                                fillMode: Image.PreserveAspectFit
                                SequentialAnimation on opacity {
                                    running: activity.visible && activity.working && root.visible; loops: Animation.Infinite
                                    NumberAnimation { to: .45; duration: 850; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 850; easing.type: Easing.InOutSine }
                                }
                            }
                            Text {
                                Layout.fillWidth: true; Layout.minimumWidth: 0
                                text: client.error || (client.conversationLoading ? "Pragus recuperando contexto" : "Pragus está respondendo")
                                color: client.error ? "#ffc4b6" : root.accent; font.pixelSize: 12; wrapMode: Text.Wrap
                            }
                            Row {
                                visible: activity.working; spacing: 3
                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        required property int index
                                        width: 4; height: 4; radius: 2; color: root.accent; opacity: .3
                                        SequentialAnimation on opacity {
                                            running: activity.visible && activity.working && root.visible; loops: Animation.Infinite
                                            PauseAnimation { duration: index * 140 }
                                            NumberAnimation { to: 1; duration: 280; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: .3; duration: 380; easing.type: Easing.InOutSine }
                                            PauseAnimation { duration: (2 - index) * 140 + 240 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text { id: attachmentErrorLabel; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; z: 3; visible: !!client.attachmentError; text: client.attachmentError; color: "#ff909e"; font.pixelSize: 11; wrapMode: Text.Wrap }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 5
                        ToolButton {
                            id: attachButton
                            objectName: "attachFile"; implicitWidth: 28; implicitHeight: 28; padding: 0
                            enabled: client.ready && !client.busy && !client.conversationLoading && !root.clearing
                            onClicked: { client.dismissAttachmentError(); attachmentPicker.open() }
                            background: Rectangle { objectName: "attachmentButtonBackground"; radius: 5; color: root.composerButtonColor }
                            contentItem: Item { AttachIcon { anchors.centerIn: parent; width: 24; height: 24; scale: .8; opacity: attachButton.enabled ? 1 : .4 } }
                            ToolTip.visible: hovered; ToolTip.text: "Anexar imagens e arquivos"
                            Accessible.name: "Anexar imagens e arquivos"
                        }
                        TextField {
                            id: composer; objectName: "composer"
                            Layout.fillWidth: true; Layout.minimumWidth: 0
                            implicitHeight: 33; padding: 7
                            placeholderTextColor: "#9496a4"
                            placeholderText: client.conversationLoading ? "Recuperando conversa…" : client.ready ? "Pergunte ao Pragus…" : "Conectando ao Pragus…"
                            enabled: client.ready && !client.busy && !client.conversationLoading && !root.clearing; color: root.ink; font.pixelSize: 12
                            background: Rectangle { color: "#24252e"; radius: 5; border.color: composer.activeFocus ? root.accent : "#464854" }
                            onAccepted: root.ask()
                        }
                        ToolButton {
                            id: sendButton; objectName: "sendQuestion"
                            implicitWidth: 28; implicitHeight: 28; padding: 0
                            enabled: client.busy || (client.ready && !client.conversationLoading && (composer.text.trim().length > 0 || client.attachments.length > 0))
                            onClicked: client.busy ? client.stop() : root.ask()
                            background: Rectangle { objectName: "sendButtonBackground"; radius: 5; color: root.composerButtonColor }
                            contentItem: Item {
                                Rectangle { visible: client.busy; anchors.centerIn: parent; width: 8; height: 8; radius: 1; color: "#e6e7ec" }
                                Text { visible: !client.busy; anchors.centerIn: parent; text: "↑"; color: "#e6e7ec"; font.pixelSize: 19 }
                            }
                            ToolTip.visible: hovered; ToolTip.text: client.busy ? "Parar resposta" : "Enviar pergunta"
                            Accessible.name: client.busy ? "Parar resposta" : "Enviar pergunta"
                        }
                    }
                }
            }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.wide ? 2 : 1; uniformCellWidths: true
                        columnSpacing: 8; rowSpacing: 8
            Card {
                objectName: "systemCard"
                Layout.row: root.wide ? 0 : 1; Layout.column: 0
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: root.wide ? root.lowerCardHeight : 160
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 10; spacing: 8
                    SectionHeading { text: "SISTEMA" }
                    GridLayout {
                        columns: 1; rowSpacing: 5; Layout.fillWidth: true; Layout.fillHeight: true
                        Repeater {
                            model: 4
                            delegate: Meter {
                                required property int index
                                objectName: "systemMetric"
                                Layout.fillWidth: true
                                label: ["CPU", "GPU", "RAM", "DISCO"][index]
                                value: [dashboard.cpuUsage, dashboard.gpuUsage, dashboard.memoryUsage, dashboard.storageUsage][index]
                                detail: [root.percent(dashboard.cpuUsage), root.percent(dashboard.gpuUsage), root.gib(dashboard.memoryUsedGiB, dashboard.memoryTotalGiB), root.gib(dashboard.storageUsedGiB, dashboard.storageTotalGiB)][index]
                            }
                        }
                    }
                }
            }
            Card {
                objectName: "newsCard"
                Layout.minimumHeight: root.wide ? root.lowerCardHeight : 230
                Layout.maximumHeight: root.wide ? root.lowerCardHeight : 230
                Layout.row: 0; Layout.column: root.wide ? 1 : 0
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: root.wide ? root.lowerCardHeight : 230
                ColumnLayout {
                    id: newsBody
                    anchors.fill: parent; anchors.margins: 8; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Caption { objectName: "sectionTitle"; text: "NO RADAR" }
                        HeadingDivider {}
                        IconButton {
                            implicitWidth: 22; implicitHeight: 20
                            objectName: "refreshNews"; hint: root.newsRefreshing ? "Buscando notícias…" : "Atualizar notícias e voltar à primeira página"
                            enabled: !root.newsRefreshing; onClicked: root.refreshNews()
                            contentItem: Item {
                                id: newsRefreshGlyph; objectName: "newsRefreshGlyph"
                                Text { anchors.centerIn: parent; text: "↻"; color: root.accent; font.pixelSize: 18 }
                                NumberAnimation on rotation {
                                    objectName: "newsRefreshSpin"
                                    from: 0; to: 360; duration: 800; loops: Animation.Infinite; running: root.newsRefreshing
                                    onRunningChanged: if (!running) newsRefreshGlyph.rotation = 0
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        id: newsContent; objectName: "newsContent"
                        Layout.fillHeight: true; Layout.fillWidth: true; spacing: 4
                        Repeater {
                            objectName: "newsStories"
                            model: dashboard.news.slice(Math.min(root.newsPage, root.newsPages - 1), Math.min(root.newsPage, root.newsPages - 1) + 1)
                            delegate: ItemDelegate {
                                required property var modelData
                                Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                                padding: 8; clip: true
                                onClicked: if (modelData.link) Qt.openUrlExternally(modelData.link)
                                background: Rectangle { color: parent.hovered ? "#343641" : "#252630"; radius: 5 }
                                contentItem: ColumnLayout {
                                    spacing: 4
                                    AdaptiveHeadline { objectName: "newsHeadline"; Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0; text: root.newsTitle(modelData); color: root.ink }
                                    Text { objectName: "newsSource"; Layout.fillWidth: true; text: modelData.source || "Google News"; color: root.muted; font.pixelSize: 11; textFormat: Text.PlainText; elide: Text.ElideRight }
                                }
                                ToolTip.visible: hovered; ToolTip.text: root.newsTitle(modelData)
                            }
                        }
                        Text { Layout.fillWidth: true; Layout.fillHeight: true; visible: dashboard.news.length === 0; text: dashboard.newsStatus; color: root.muted; font.pixelSize: 11; wrapMode: Text.Wrap }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: "Google News · " + (Math.min(root.newsPage, root.newsPages - 1) + 1) + "/" + root.newsPages; color: root.muted; font.pixelSize: 11 }
                        IconButton { implicitWidth: 22; implicitHeight: 20; text: "‹"; hint: "Notícias anteriores"; enabled: root.newsPage > 0; onClicked: root.moveNews(-1) }
                        IconButton { implicitWidth: 22; implicitHeight: 20; objectName: "nextNews"; text: "›"; hint: "Próximas notícias"; enabled: root.newsPage < root.newsPages - 1; onClicked: root.moveNews(1) }
                    }
                }
                HoverHandler { id: newsHover; objectName: "newsHover" }
                WheelHandler { onWheel: event => { root.moveNews(event.angleDelta.y < 0 ? 1 : -1); event.accepted = true } }
            }
                    }
                }
            }
            Card {
                Layout.fillWidth: true; Layout.preferredHeight: 112
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 9; spacing: 3
                    SectionHeading { text: "PREVISÃO DO TEMPO" }
                    Flickable {
                        id: weatherStrip
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        contentWidth: Math.max(width, 560); contentHeight: height
                        flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
                        RowLayout {
                        width: weatherStrip.contentWidth; height: weatherStrip.height; spacing: 2
                        Repeater {
                            model: dashboard.forecast
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true; Layout.fillHeight: true; radius: 4; color: modelData.isToday ? "#2b2d38" : "transparent"
                                Column {
                                    anchors.centerIn: parent; spacing: 1
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.day; color: modelData.isToday ? root.ink : root.muted; font.pixelSize: 11; font.bold: modelData.isToday }
                                    WeatherIcon { anchors.horizontalCenter: parent.horizontalCenter; code: modelData.code }
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
                                        Text { text: modelData.high; color: root.ink; font.pixelSize: 12; font.weight: Font.DemiBold }
                                        Text { text: modelData.low; color: root.muted; font.pixelSize: 12 }
                                    }
                                }
                                HoverHandler { id: forecastHover }
                                ToolTip.visible: forecastHover.hovered
                                ToolTip.text: modelData.date + " · " + modelData.summary
                            }
                        }
                        Text { Layout.fillWidth: true; visible: dashboard.forecast.length === 0; text: dashboard.weatherStatus; color: root.muted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
                        }
                    }
                }
            }
        }
    }
}
