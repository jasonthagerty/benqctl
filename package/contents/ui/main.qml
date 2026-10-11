import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid

import "monitorsettings.js" as MonitorSettings

PlasmoidItem {
    id: root

    DisplayManager {
        id: displayManager
        preferredConnector: root.Screen.name
        monitorSettings: MonitorSettings.parse(Plasmoid.configuration.monitorSettings)
        Component.onCompleted: detect()

        // Remember monitors so the settings page can list ones that aren't connected.
        onSeen: found => {
            const result = MonitorSettings.remember(MonitorSettings.parse(Plasmoid.configuration.knownMonitors),
                                                    found, MonitorSettings.today());
            if (result.changed) {
                Plasmoid.configuration.knownMonitors = JSON.stringify(result.known);
            }
        }
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
