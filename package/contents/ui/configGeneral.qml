import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_modelMatch: modelField.text
    property alias cfg_busOverride: busSpin.value
    property string cfg_modelMatchDefault
    property int cfg_busOverrideDefault

    Kirigami.FormLayout {
        QQC2.TextField {
            id: modelField
            Kirigami.FormData.label: i18n("Monitor match:")
            placeholderText: "RD280U"
        }

        QQC2.Label {
            text: i18n("Matched against the model or serial shown by “ddcutil detect”.")
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
        }

        QQC2.SpinBox {
            id: busSpin
            Kirigami.FormData.label: i18n("I²C bus:")
            from: -1
            to: 255
            textFromValue: (value, locale) => value < 0 ? i18n("Auto-detect") : value.toString()
            valueFromText: (text, locale) => text === i18n("Auto-detect") ? -1 : parseInt(text)
        }
    }
}
