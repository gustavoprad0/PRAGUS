import QtQuick

SequentialAnimation {
    id: root
    required property Item targetItem
    property int pageCount: 1
    property int page: 0
    property int nextPage: 0
    function goTo(requestedPage) {
        if (running) return
        nextPage = Math.max(0, Math.min(pageCount - 1, requestedPage))
        if (nextPage !== page) restart()
    }
    onPageCountChanged: {
        page = Math.max(0, Math.min(page, pageCount - 1))
        nextPage = Math.max(0, Math.min(nextPage, pageCount - 1))
    }
    ParallelAnimation {
        NumberAnimation { target: root.targetItem; property: "opacity"; to: 0; duration: 110 }
        NumberAnimation { target: root.targetItem; property: "scale"; to: .97; duration: 110 }
    }
    ScriptAction { script: root.page = root.nextPage }
    ParallelAnimation {
        NumberAnimation { target: root.targetItem; property: "opacity"; to: 1; duration: 180 }
        NumberAnimation { target: root.targetItem; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutCubic }
    }
}
