import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// All controls for one monitor, laid out from its profile.
ColumnLayout {
    id: page

    required property Ddc ddc

    spacing: Kirigami.Units.smallSpacing

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: (page.ddc?.error ?? "") !== ""
        type: Kirigami.MessageType.Error
        text: page.ddc?.error ?? ""
        actions: Kirigami.Action {
            text: i18n("Retry")
            icon.name: "view-refresh"
            onTriggered: page.ddc?.refresh()
        }
    }

    Repeater {
        model: page.ddc?.activeLocks ?? []
        delegate: Kirigami.InlineMessage {
            required property var modelData
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Information
            text: modelData.message
        }
    }

    Repeater {
        model: page.ddc?.profile?.sections ?? []
        delegate: ColumnLayout {
            id: section

            required property var modelData
            required property int index

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                level: 5
                text: section.modelData.title
                Layout.topMargin: section.index > 0 ? Kirigami.Units.smallSpacing : 0
            }

            Repeater {
                model: section.modelData.controls
                delegate: ControlRow {
                    Layout.fillWidth: true
                    backend: page.ddc
                }
            }
        }
    }

    PlasmaComponents3.Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        visible: !!page.ddc?.profile
        // The connector is the output's name in System Settings › Display Configuration.
        text: [page.ddc?.connector ?? "",
               page.ddc?.profile?.file
                   ? i18n("Profile: %1 (%2)", page.ddc.profile.name, page.ddc.profile.file)
                   : i18n("Profile: %1", page.ddc?.profile?.name ?? "")].filter(s => s).join(" · ")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        elide: Text.ElideRight
    }
}
