import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import "../code/parser.js" as Parser

ItemDelegate {
    id: root
    width: ListView.view.width
    property string summary: ""
    property var startTime: null
    property string location: ""
    property string description: ""
    property bool isAllDay: false

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            // Indicador de tiempo vertical
            Rectangle {
                Layout.preferredWidth: 4
                Layout.fillHeight: true
                color: root.startTime && Parser.isToday(root.startTime) ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                radius: 2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    text: root.summary
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: root.startTime !== null

                    PlasmaComponents.Label {
                        text: Parser.formatTime(root.startTime)
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.9
                        opacity: 0.7
                    }

                    PlasmaComponents.Label {
                        text: "• " + Parser.formatDate(root.startTime)
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.9
                        opacity: 0.7
                        visible: !Parser.isToday(root.startTime)
                    }
                }
            }
        }

        // Ubicación si existe
        RowLayout {
            Layout.fillWidth: true
            visible: root.location !== ""
            spacing: Kirigami.Units.smallSpacing
            
            Kirigami.Icon {
                source: "marker"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 0.6
                Layout.preferredHeight: Kirigami.Units.gridUnit * 0.6
                opacity: 0.6
            }

            PlasmaComponents.Label {
                text: root.location
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                opacity: 0.6
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
