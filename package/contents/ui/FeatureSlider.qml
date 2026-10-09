import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

RowLayout {
    id: row

    required property Ddc backend
    required property int code
    required property string label
    property int maximum: 100

    spacing: Kirigami.Units.smallSpacing
    enabled: backend.has(code)

    PlasmaComponents3.Label {
        text: row.label
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
        elide: Text.ElideRight
    }

    PlasmaComponents3.Slider {
        id: slider
        Layout.fillWidth: true
        from: 0
        to: row.backend.maximum(row.code, row.maximum)
        stepSize: 1
        value: row.backend.current(row.code, 0)
        onMoved: debounce.restart()
        onPressedChanged: if (!pressed) {
            debounce.stop();
            row.send();
        }
    }

    PlasmaComponents3.Label {
        text: Math.round(slider.value)
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
    }

    // Each ddcutil write takes ~0.5 s, so only send while dragging at a modest rate.
    Timer {
        id: debounce
        interval: 250
        onTriggered: row.send()
    }

    function send() {
        const v = Math.round(slider.value);
        if (v !== backend.current(code, -1)) {
            backend.set(code, v);
        }
    }
}
