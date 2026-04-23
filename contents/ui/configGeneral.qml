import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: configPage

    property alias cfg_icsUrl: icsUrlTextField.text
    property alias cfg_refreshInterval: refreshIntervalSpinBox.value
    property string cfg_viewMode: "day"

    spacing: Kirigami.Units.largeSpacing

    Kirigami.FormLayout {
        Layout.fillWidth: true

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Conexión"
        }

        TextField {
            id: icsUrlTextField
            Kirigami.FormData.label: "Enlace ICS Privado:"
            placeholderText: "https://calendar.google.com/calendar/ical/.../basic.ics"
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Opciones"
        }

        SpinBox {
            id: refreshIntervalSpinBox
            Kirigami.FormData.label: "Actualizar cada (min):"
            from: 5
            to: 1440
            stepSize: 5
        }

        ComboBox {
            id: viewModeComboBox
            Kirigami.FormData.label: "Vista inicial:"
            model: ["Hoy", "Semana", "Mes"]
            currentIndex: {
                if (cfg_viewMode === "day") return 0
                if (cfg_viewMode === "week") return 1
                return 2
            }
            onCurrentIndexChanged: {
                const modes = ["day", "week", "month"]
                cfg_viewMode = modes[currentIndex]
            }
        }
    }
}
