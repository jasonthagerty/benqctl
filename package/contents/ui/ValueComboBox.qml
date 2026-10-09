import QtQuick
import org.kde.plasma.components as PlasmaComponents3

import "features.js" as F

// Combo box for a non-continuous VCP feature with a known list of values.
PlasmaComponents3.ComboBox {
    id: combo

    required property Ddc backend
    required property int code
    required property var options

    readonly property int currentFeatureValue: backend.current(code, -1)

    enabled: backend.has(code)
    model: options
    textRole: "label"
    valueRole: "value"
    currentIndex: options.findIndex(o => o.value === currentFeatureValue)
    displayText: currentIndex >= 0 || currentFeatureValue < 0
        ? currentText
        : i18n("Unknown (%1)", F.labelFor(options, currentFeatureValue))

    onActivated: backend.set(code, currentValue)
}
