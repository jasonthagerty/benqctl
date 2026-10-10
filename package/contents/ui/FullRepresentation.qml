import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

import "features.js" as F

PlasmaExtras.Representation {
    id: full

    required property Ddc backend

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: layout.implicitHeight + header.implicitHeight + Kirigami.Units.largeSpacing * 2
    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: full.backend.monitorName || i18n("BenQ Monitor")
                elide: Text.ElideRight
            }

            PlasmaComponents3.BusyIndicator {
                running: full.backend.busy
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }

            PlasmaComponents3.ToolButton {
                icon.name: "view-refresh"
                onClicked: full.backend.refresh()
                PlasmaComponents3.ToolTip.text: i18n("Re-read monitor settings")
                PlasmaComponents3.ToolTip.visible: hovered
            }
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: full.backend.error !== ""
            type: Kirigami.MessageType.Error
            text: full.backend.error
            actions: Kirigami.Action {
                text: i18n("Retry")
                icon.name: "view-refresh"
                onTriggered: full.backend.refresh()
            }
        }

        Kirigami.Heading {
            level: 5
            text: i18n("Input")
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2

            PlasmaComponents3.Label {
                text: i18n("Video")
            }
            ValueButtons {
                Layout.fillWidth: true
                backend: full.backend
                code: F.INPUT
                options: F.inputs
            }

            PlasmaComponents3.Label {
                text: i18n("USB (KVM)")
            }
            ValueButtons {
                Layout.fillWidth: true
                backend: full.backend
                code: F.KVM
                options: F.kvmPorts
            }
        }

        Kirigami.Heading {
            level: 5
            text: i18n("Picture")
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: full.backend.hdrActive
            type: Kirigami.MessageType.Information
            text: i18n("The monitor is in HDR mode, which locks picture mode, color temperature, brightness, contrast and saturation. Turn off HDR for this display in System Settings › Display & Monitor to change them.")
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2

            PlasmaComponents3.Label {
                text: i18n("Mode")
            }
            ValueComboBox {
                Layout.fillWidth: true
                backend: full.backend
                code: F.PICTURE_MODE
                options: F.pictureModes
            }

            PlasmaComponents3.Label {
                text: i18n("Color temp")
            }
            ValueComboBox {
                Layout.fillWidth: true
                backend: full.backend
                code: F.COLOR_PRESET
                options: F.colorPresets
            }
        }

        FeatureSlider {
            Layout.fillWidth: true
            backend: full.backend
            code: F.BRIGHTNESS
            label: i18n("Brightness")
        }

        FeatureSlider {
            Layout.fillWidth: true
            backend: full.backend
            code: F.CONTRAST
            label: i18n("Contrast")
        }

        FeatureSlider {
            Layout.fillWidth: true
            backend: full.backend
            code: F.SHARPNESS
            label: i18n("Sharpness")
            maximum: 10
        }

        FeatureSlider {
            Layout.fillWidth: true
            backend: full.backend
            code: F.SATURATION
            label: i18n("Saturation")
            maximum: 10
        }

        Kirigami.Heading {
            level: 5
            text: i18n("Eye care & lighting")
            Layout.topMargin: Kirigami.Units.smallSpacing
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2

            PlasmaComponents3.Label {
                text: i18n("Night protection")
            }
            ValueComboBox {
                Layout.fillWidth: true
                backend: full.backend
                code: F.NIGHT_PROTECTION
                options: F.nightProtectionStates
            }

            PlasmaComponents3.Label {
                text: i18n("MoonHalo")
            }
            ValueComboBox {
                Layout.fillWidth: true
                backend: full.backend
                code: F.MOONHALO
                options: F.moonHaloStates
            }
        }

        FeatureSlider {
            Layout.fillWidth: true
            backend: full.backend
            code: F.LOW_BLUE_LIGHT
            label: i18n("Low blue light")
            maximum: 10
        }

        RowLayout {
            id: audioHeading
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing

            readonly property bool muted: full.backend.current(F.MUTE, F.UNMUTED) === F.MUTED

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 5
                text: i18n("Audio")
            }

            PlasmaComponents3.ToolButton {
                enabled: full.backend.has(F.MUTE)
                icon.name: audioHeading.muted ? "audio-volume-muted" : "audio-volume-high"
                onClicked: full.backend.set(F.MUTE, audioHeading.muted ? F.UNMUTED : F.MUTED)
                PlasmaComponents3.ToolTip.text: audioHeading.muted ? i18n("Unmute") : i18n("Mute")
                PlasmaComponents3.ToolTip.visible: hovered
            }
        }

        FeatureSlider {
            Layout.fillWidth: true
            backend: full.backend
            code: F.VOLUME
            label: i18n("Volume")
        }
    }
}
