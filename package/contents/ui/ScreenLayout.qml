import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

import "kscreen.js" as KScreen

// Miniature of the screen arrangement in System Settings › Display Configuration:
// each enabled output as a rectangle at its position, one of them highlighted.
Item {
    id: layout

    // kscreen.js parseOutputs() entries.
    property var outputs: []
    // Connector name of the output to highlight ("DP-1"); "" for none.
    property string highlight

    readonly property var area: KScreen.bounds(outputs)
    readonly property real ratio: area.width > 0 ? Math.min(width / area.width, maximumHeight / area.height) : 0
    property real maximumHeight: Kirigami.Units.gridUnit * 5

    implicitWidth: Kirigami.Units.gridUnit * 14
    implicitHeight: area.height * ratio

    Repeater {
        model: layout.outputs.filter(o => o.enabled && o.width > 0)
        delegate: Rectangle {
            id: screen

            required property var modelData
            readonly property bool current: modelData.name === layout.highlight

            // Centre the arrangement horizontally.
            x: (layout.width - layout.area.width * layout.ratio) / 2 + (modelData.x - layout.area.x) * layout.ratio
            y: (modelData.y - layout.area.y) * layout.ratio
            width: modelData.width * layout.ratio - 2
            height: modelData.height * layout.ratio - 2
            radius: Kirigami.Units.cornerRadius
            color: current ? Kirigami.Theme.highlightColor : Kirigami.Theme.alternateBackgroundColor
            border.color: current ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
            border.width: 1

            QQC2.Label {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.smallSpacing * 2
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: screen.modelData.primary ? `${screen.modelData.name} ★` : screen.modelData.name
                color: screen.current ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                font: Kirigami.Theme.smallFont
            }
        }
    }
}
