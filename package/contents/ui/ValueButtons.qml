import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3

// Row of buttons selecting one value of a non-continuous VCP feature.
RowLayout {
    id: row

    required property Ddc backend
    required property int code
    required property var options

    Repeater {
        model: row.options
        delegate: PlasmaComponents3.Button {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.label
            checkable: true
            checked: row.backend.current(row.code, -1) === modelData.value
            onClicked: {
                row.backend.set(row.code, modelData.value);
                // Switching can reconfigure the monitor; read back what actually happened.
                row.backend.refresh();
            }
        }
    }
}
