import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
    id: full

    required property DisplayManager manager

    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: layout.implicitHeight + header.implicitHeight + Kirigami.Units.largeSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth
    Layout.preferredHeight: Layout.minimumHeight
    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 3
                    text: full.manager.displays.length === 1 && full.manager.selected ? full.manager.selected.name : i18n("Monitors")
                    elide: Text.ElideRight
                }

                PlasmaComponents3.BusyIndicator {
                    running: full.manager.busy
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }

                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: full.manager.refresh()
                    PlasmaComponents3.ToolTip.text: i18n("Re-detect monitors and re-read settings")
                    PlasmaComponents3.ToolTip.visible: hovered
                }
            }

            PlasmaComponents3.TabBar {
                Layout.fillWidth: true
                visible: full.manager.displays.length > 1
                currentIndex: full.manager.displays.indexOf(full.manager.selected)

                Repeater {
                    model: full.manager.displays
                    delegate: PlasmaComponents3.TabButton {
                        required property var modelData
                        text: modelData.name
                        onClicked: {
                            full.manager.selected = modelData;
                            modelData.refresh();
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: layout
        // Pinned to the top: filling the popup would centre the controls in it.
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Kirigami.Units.largeSpacing
        }
        spacing: Kirigami.Units.smallSpacing

        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth: true
            visible: !full.manager.selected
            iconName: full.manager.error !== "" ? "data-warning" : "video-display"
            text: full.manager.error !== "" ? i18n("No monitors") : i18n("Looking for monitors…")
            explanation: full.manager.error
            helpfulAction: Kirigami.Action {
                enabled: full.manager.error !== ""
                text: i18n("Retry")
                icon.name: "view-refresh"
                onTriggered: full.manager.refresh()
            }
        }

        Loader {
            Layout.fillWidth: true
            active: !!full.manager.selected
            sourceComponent: DisplayPage {
                ddc: full.manager.selected
            }
        }
    }
}
