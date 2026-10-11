import QtQuick

// Finds DDC/CI monitors with ddcutil detect and keeps one Ddc per monitor,
// matched across re-detections by identity rather than bus number.
Item {
    id: manager

    // Ddc objects in detection order.
    property var displays: []
    property Ddc selected: null
    // Screen the widget is on; its monitor is selected by default.
    property string preferredConnector
    property string error: ""
    property double lastDetect: 0
    readonly property bool busy: commandRunner.busy

    Runner {
        id: commandRunner
    }

    Component {
        id: ddcComponent
        Ddc {
            runner: commandRunner
        }
    }

    // Detection is cheap (~0.2 s, ddcutil caches it), so redo it whenever it may be stale.
    function ensureFresh() {
        if (Date.now() - lastDetect > 60000) {
            detect();
        }
    }

    function detect() {
        commandRunner.enqueue({
            key: "detect",
            command: () => "ddcutil detect --terse",
            done: (exitCode, stdout, stderr) => {
                if (exitCode !== 0) {
                    error = (stderr || stdout).trim() || i18n("ddcutil exited with code %1", exitCode);
                    return;
                }
                lastDetect = Date.now();
                apply(parseDetect(stdout));
            },
        });
    }

    // Re-detects, then re-reads the selected monitor.
    function refresh() {
        detect();
        if (selected) {
            selected.refresh();
        }
    }

    // Connector names from ddcutil ("DP-1") match Qt's Screen.name.
    function forConnector(connector) {
        return displays.find(d => d.connector === connector) || displays[0] || null;
    }

    function parseDetect(stdout) {
        const found = [];
        for (const block of stdout.split(/\n\s*\n/)) {
            if (block.startsWith("Invalid display")) {
                continue;
            }
            const busMatch = block.match(/I2C bus:\s*\/dev\/i2c-(\d+)/);
            const monitorMatch = block.match(/Monitor:\s*(.*)/);
            if (!busMatch || !monitorMatch) {
                continue;
            }
            const connectorMatch = block.match(/DRM connector:\s*(?:card\d+-)?(\S+)/);
            const monitor = monitorMatch[1].trim();
            const [mfg, model, serial] = monitor.split(":");
            const connector = connectorMatch ? connectorMatch[1] : "";
            found.push({
                id: serial ? monitor : `${monitor}@${connector || busMatch[1]}`,
                mfgModel: `${mfg}:${model}`,
                name: model || monitor,
                connector: connector,
                bus: parseInt(busMatch[1]),
            });
        }
        const shared = key => found.filter(f => found.some(o => o !== f && o[key] === f[key]));
        // Some monitors share a serial (e.g. "0"); keep ids unique. Then tell identical models apart.
        for (const f of shared("id")) {
            f.id = `${f.id}@${f.connector || f.bus}`;
        }
        for (const f of shared("name")) {
            f.name = `${f.name} (${f.connector || f.bus})`;
        }
        return found;
    }

    function apply(found) {
        const old = {};
        for (const d of displays) {
            old[d.displayId] = d;
        }
        const next = found.map(f => {
            let d = old[f.id];
            if (d) {
                delete old[f.id];
                const retry = d.bus !== f.bus || d.error !== "";
                d.bus = f.bus;
                d.connector = f.connector;
                d.name = f.name;
                if (retry) {
                    d.refresh();
                }
                return d;
            }
            d = ddcComponent.createObject(manager, {
                displayId: f.id,
                mfgModel: f.mfgModel,
                name: f.name,
                connector: f.connector,
                bus: f.bus,
            });
            // The bus may have moved; find it again so the next action works.
            d.failed.connect(manager.detect);
            d.refresh();
            return d;
        });
        for (const id in old) {
            commandRunner.cancel(`${id}/`);
            old[id].destroy();
        }
        displays = next;
        if (!next.includes(selected)) {
            selected = forConnector(preferredConnector);
        }
        error = next.length > 0 ? "" : i18n("No monitor with DDC/CI found. Check that DDC/CI is enabled in the monitor's menu and that “ddcutil detect” works as your user.");
    }

    // Monitors take a moment to answer DDC/CI after they appear.
    Timer {
        id: hotplug
        interval: 3000
        onTriggered: manager.detect()
    }

    Connections {
        target: Qt.application
        function onScreensChanged() {
            hotplug.restart();
        }
    }
}
