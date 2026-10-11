import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    DisplayManager {
        id: displayManager
        preferredConnector: root.Screen.name
        Component.onCompleted: detect()
    }

    Plasmoid.icon: "video-display"

    toolTipMainText: displayManager.displays.length === 1 ? displayManager.displays[0].name : i18n("Monitors")
    toolTipSubText: displayManager.error !== ""
        ? displayManager.error
        : displayManager.displays.length === 1
            ? displayManager.displays[0].status
            : displayManager.displays.map(d => `${d.name}: ${d.status}`).join("\n")

    // Reading over I2C is slow, so only refresh when the popup is opened, and then
    // only the monitor this widget is on; other tabs are read when selected.
    onExpandedChanged: expanded => {
        if (!expanded) {
            return;
        }
        displayManager.ensureFresh();
        displayManager.selected = displayManager.forConnector(displayManager.preferredConnector);
        if (displayManager.selected) {
            displayManager.selected.refresh();
        }
    }

    fullRepresentation: FullRepresentation {
        manager: displayManager
    }
}
