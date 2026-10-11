import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

import "kscreen.js" as KScreen
import "monitorsettings.js" as MonitorSettings
import "profiles.js" as Profiles
import "userprofiles.js" as UserProfiles

// Settings page: one card per monitor the widget has detected, showing how it
// appears in Display Configuration, with Show, Nickname and Profile settings.
KCM.SimpleKCM {
    id: page

    property string cfg_monitorSettings
    property string cfg_monitorSettingsDefault
    // knownMonitors is deliberately not a cfg_ property: Plasma snapshots those when
    // the dialog opens and writes them all back on Apply, which would overwrite
    // monitors the widget records while the dialog is open. Read it live instead.
    property string knownMonitorsJson: Plasmoid.configuration?.knownMonitors ?? "{}"

    readonly property var settings: MonitorSettings.parse(cfg_monitorSettings)
    readonly property var known: MonitorSettings.parse(knownMonitorsJson)
    // kscreen.js parseOutputs(); empty until kscreen-doctor answers.
    property var outputs: []
    property bool outputsLoaded: false
    // Whether "connected" can be told at all: needs kscreen-doctor's answer.
    readonly property bool connectionKnown: outputsLoaded && outputs.length > 0
    property var userProfiles: []
    readonly property var screens: Array.from(Qt.application.screens).map(s => ({ name: s.name, manufacturer: s.manufacturer, model: s.model }))

    // Connected monitors first, each in display arrangement order, then the rest by name.
    readonly property var monitors: Object.keys(known).filter(id => known[id] && typeof known[id] === "object").map(id => {
        const entry = known[id];
        return Object.assign({}, entry, {
            id: id,
            name: typeof entry.name === "string" && entry.name !== "" ? entry.name : id,
            output: KScreen.outputFor(entry, outputs, screens),
        });
    }).sort((a, b) => {
        if (!!a.output !== !!b.output) {
            return a.output ? -1 : 1;
        }
        if (a.output) {
            return a.output.x - b.output.x || a.output.y - b.output.y;
        }
        return a.name.localeCompare(b.name);
    })

    function change(id, patch) {
        cfg_monitorSettings = JSON.stringify(MonitorSettings.update(settings, id, patch));
    }

    // Takes effect at once: removed from the live list (the widget re-adds it if the
    // monitor is detected again); its settings go with the next Apply.
    function forget(id) {
        const current = MonitorSettings.parse(Plasmoid.configuration?.knownMonitors ?? knownMonitorsJson);
        const next = JSON.stringify(MonitorSettings.without(current, id));
        if (Plasmoid.configuration) {
            Plasmoid.configuration.knownMonitors = next;
        } else {
            knownMonitorsJson = next;
        }
        cfg_monitorSettings = JSON.stringify(MonitorSettings.without(settings, id));
    }

    // Neither command touches the monitors' I2C buses, so they can run alongside the widget's queue.
    Runner {
        id: commandRunner
    }

    Component.onCompleted: {
        commandRunner.enqueue({
            key: "kscreen",
            command: () => KScreen.COMMAND,
            done: (exitCode, stdout) => {
                outputs = KScreen.parseOutputs(stdout);
                outputsLoaded = true;
            },
        });
        commandRunner.enqueue({
            key: "profiles",
            command: () => UserProfiles.LIST_COMMAND,
            done: (exitCode, stdout) => userProfiles = UserProfiles.load(UserProfiles.parseListing(stdout)).defs,
        });
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit * 2
            visible: page.monitors.length === 0
            icon.name: "video-display"
            text: i18n("No monitors detected yet")
            explanation: i18n("Monitors appear here once the widget has found them with ddcutil.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.outputsLoaded && page.outputs.length === 0 && page.monitors.length > 0
            type: Kirigami.MessageType.Information
            text: i18n("Couldn't read the display configuration (kscreen-doctor), so connection details aren't shown.")
        }

        Repeater {
            model: page.monitors
            delegate: Kirigami.AbstractCard {
                id: card

                required property var modelData
                readonly property var output: modelData.output
                readonly property var current: MonitorSettings.settingsFor(page.settings, modelData.id)
                readonly property var automatic: Profiles.matching(modelData.mfgModel, page.userProfiles)
                readonly property var profiles: Profiles.available(page.userProfiles)

                Layout.fillWidth: true

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true

                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 3
                            text: card.current.nickname || card.modelData.name
                            elide: Text.ElideRight
                            opacity: card.current.hidden ? 0.6 : 1
                        }

                        QQC2.Button {
                            visible: page.connectionKnown && !card.output
                            icon.name: "edit-delete-remove"
                            text: i18n("Forget")
                            onClicked: page.forget(card.modelData.id)
                            QQC2.ToolTip.text: i18n("Remove this monitor and its settings from the list")
                            QQC2.ToolTip.visible: hovered
                        }
                    }

                    // How the monitor appears in System Settings › Display Configuration.
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: card.output
                            ? KScreen.describe(card.output, i18n)
                            : page.connectionKnown
                                ? i18n("Not connected · last seen on %1, %2", card.modelData.connector || i18n("unknown connector"),
                                       card.modelData.lastSeen || i18n("unknown date"))
                                : i18n("Last seen on %1, %2", card.modelData.connector || i18n("unknown connector"),
                                       card.modelData.lastSeen || i18n("unknown date"))
                        opacity: card.output ? 1 : 0.7
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        text: card.modelData.id
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                        elide: Text.ElideRight
                    }

                    ScreenLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        visible: !!card.output
                        outputs: page.outputs
                        highlight: card.output ? card.output.name : ""
                    }

                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: !!card.output && card.output.ddcCiAllowed === false
                        type: Kirigami.MessageType.Warning
                        text: i18n("DDC/CI is turned off for this display in System Settings › Display Configuration, so the widget can't control it.")
                    }

                    Kirigami.FormLayout {
                        Layout.fillWidth: true

                        QQC2.Switch {
                            Kirigami.FormData.label: i18n("Show in widget:")
                            checked: !card.current.hidden
                            onToggled: page.change(card.modelData.id, { hidden: !checked })
                        }

                        QQC2.TextField {
                            Kirigami.FormData.label: i18n("Nickname:")
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                            placeholderText: card.modelData.name
                            // The raw saved text, not current.nickname: that one is trimmed,
                            // and rebinding to it while typing would eat the space before the next word.
                            text: page.settings[card.modelData.id]?.nickname ?? ""
                            onTextEdited: page.change(card.modelData.id, { nickname: text })
                        }

                        QQC2.ComboBox {
                            Kirigami.FormData.label: i18n("Profile:")
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
                            textRole: "text"
                            valueRole: "value"
                            model: {
                                const items = [{ value: "", text: i18n("Automatic (%1)", card.automatic.name) }].concat(
                                    card.profiles.map(p => ({ value: p.id, text: p.file ? i18n("%1 (user profile)", p.name) : p.name })));
                                // Keep a choice whose user profile was deleted visible rather than silently resetting it.
                                if (card.current.profile && !items.some(i => i.value === card.current.profile)) {
                                    items.push({ value: card.current.profile, text: i18n("%1 (missing)", card.current.profile) });
                                }
                                return items;
                            }
                            currentIndex: model.findIndex(i => i.value === card.current.profile)
                            onActivated: page.change(card.modelData.id, { profile: currentValue })
                        }
                    }
                }
            }
        }
    }
}
