import QtQuick

Rectangle {
    color: "#171820"; radius: 5; border.color: "#2b2d38"
    Canvas {
        anchors.fill: parent; opacity: .35
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset(); ctx.fillStyle = "#4b4e60"
            for (let x = 12; x < width; x += 19) for (let y = 12; y < height; y += 19) {
                ctx.beginPath(); ctx.arc(x, y, .65, 0, Math.PI * 2); ctx.fill()
            }
        }
    }
}
