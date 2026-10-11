import QtQuick

import "ddcutil.js" as Ddcutil
import "userprofiles.js" as UserProfiles

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
    // Expanded user profile definitions, and "file: problem" for ones that failed.
    property var userProfiles: []
    property var profileErrors: []
    property bool profilesRequested: false
    // Serialised userProfiles, so a reload that changes nothing doesn't rebuild every page.
    property string profilesKey: "[]"
    readonly property bool busy: commandRunner.busy

    Runner {
        id: commandRunner
    }

    Component {
        id: ddcComponent
        Ddc {
            runner: commandRunner
            userProfiles: manager.userProfiles
        }
    }

    // Detection is cheap (~0.2 s, ddcutil caches it), so redo it whenever it may be stale.
    function ensureFresh() {
        if (Date.now() - lastDetect > 60000) {
            detect();
        }
    }

    // Reads user profiles. Queued like any command, so displays detected after
    // it resolve their profiles with the user profiles already loaded.
    function loadProfiles() {
        profilesRequested = true;
        commandRunner.enqueue({
            key: "profiles",
            command: () => UserProfiles.LIST_COMMAND,
            done: (exitCode, stdout, stderr) => {
                const result = UserProfiles.load(UserProfiles.parseListing(stdout));
                const key = JSON.stringify(result.defs, (k, v) => v instanceof RegExp ? v.source : v);
                if (key !== profilesKey) {
                    profilesKey = key;
                    userProfiles = result.defs;
                }
                profileErrors = exitCode === 0 ? result.errors : result.errors.concat([stderr.trim()]);
            },
        });
    }

    function detect() {
        if (!profilesRequested) {
            loadProfiles();
        }
        commandRunner.enqueue({
            key: "detect",
            command: () => "ddcutil detect --terse",
            done: (exitCode, stdout, stderr) => {
                if (exitCode !== 0) {
                    error = (stderr || stdout).trim() || i18n("ddcutil exited with code %1", exitCode);
                    return;
                }
                lastDetect = Date.now();
                apply(Ddcutil.parseDetect(stdout));
            },
        });
    }

    // Reloads user profiles, re-detects, then re-reads the selected monitor.
    function refresh() {
        loadProfiles();
        detect();
        if (selected) {
            selected.refresh();
        }
    }

    // Connector names from ddcutil ("DP-1") match Qt's Screen.name.
    function forConnector(connector) {
        return displays.find(d => d.connector === connector) || displays[0] || null;
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
                // Retry only if the display moved: one that keeps failing (e.g. in
                // standby) would otherwise loop failed -> detect -> refresh forever.
                const retry = d.bus !== f.bus;
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
