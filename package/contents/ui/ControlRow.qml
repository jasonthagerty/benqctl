import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// A labelled row for one profile control (see profiles.js).
RowLayout {
    id: row

    required property Ddc backend
    required property var modelData
    readonly property var control: modelData

    spacing: Kirigami.Units.smallSpacing
    enabled: backend.has(control.code) && !backend.locked(control.code)

    PlasmaComponents3.Label {
        text: row.control.label
        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
        elide: Text.ElideRight
    }

    Loader {
        Layout.fillWidth: true
        sourceComponent: ({
            slider: sliderComponent,
            choice: choiceComponent,
            buttons: buttonsComponent,
            toggle: toggleComponent,
        })[row.control.type]
    }

    Component {
        id: sliderComponent
        FeatureSlider {
            backend: row.backend
            code: row.control.code
            maximum: row.control.max || 100
        }
    }

    Component {
        id: choiceComponent
        ValueComboBox {
            backend: row.backend
            code: row.control.code
            options: row.control.values
        }
    }

    Component {
        id: buttonsComponent
        ValueButtons {
            backend: row.backend
            code: row.control.code
            options: row.control.values
        }
    }

    Component {
        id: toggleComponent
        Item {
            implicitHeight: toggle.implicitHeight
            PlasmaComponents3.Switch {
                id: toggle
                checked: row.backend.current(row.control.code, -1) === row.control.on
                onToggled: row.backend.set(row.control.code, checked ? row.control.on : row.control.off)
            }
        }
    }
}
