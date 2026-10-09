import QtQuick
import org.kde.plasma.plasmoid

import "features.js" as F

PlasmoidItem {
    id: root

    Ddc {
        id: ddc
        modelMatch: Plasmoid.configuration.modelMatch
        busOverride: Plasmoid.configuration.busOverride
    }

    Plasmoid.icon: "video-display"

    toolTipMainText: ddc.monitorName || i18n("BenQ Monitor")
    toolTipSubText: ddc.error !== ""
        ? ddc.error
        : ddc.has(F.INPUT)
            ? i18n("Input: %1 · Mode: %2",
                   F.labelFor(F.inputs, ddc.current(F.INPUT)),
                   F.labelFor(F.pictureModes, ddc.current(F.PICTURE_MODE)))
            : ""

    // Reading over I2C is slow, so only refresh when the popup is opened.
    onExpandedChanged: if (expanded) {
        ddc.refresh();
    }

    Component.onCompleted: ddc.refresh()

    fullRepresentation: FullRepresentation {
        backend: ddc
    }
}
