import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

RowLayout {
    id: row

    required property Ddc backend
    required property int code
    property int maximum: 100

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents3.Slider {
        id: slider
        Layout.fillWidth: true
        from: 0
        to: row.backend.maximum(row.code, row.maximum)
        stepSize: 1
        value: row.backend.current(row.code, 0)
        onMoved: if (!throttle.running) {
            throttle.start();
        }
        onPressedChanged: if (!pressed) {
            throttle.stop();
            row.send();
        }
    }

    PlasmaComponents3.Label {
        text: Math.round(slider.value)
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: Kirigami.Units.gridUnit * 1.5
    }

    // Each ddcutil write takes ~0.5 s, so send at most every 250 ms while dragging;
    // Ddc coalesces whatever piles up behind the running write.
    Timer {
        id: throttle
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
