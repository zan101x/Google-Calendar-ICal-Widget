import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../code/parser.js" as Parser

PlasmoidItem {
    id: root

    // Ajuste de tamaño
    width: Kirigami.Units.gridUnit * 22
    height: Kirigami.Units.gridUnit * 28

    // Usamos el objeto global 'plasmoid' para configurar el fondo si la propiedad directa falla
    Component.onCompleted: {
        if (typeof plasmoid.backgroundHints !== "undefined") {
            plasmoid.backgroundHints = 0; 
        }
        root.fetchICS();
    }

    property var allEvents: []
    property var filteredEvents: []
    property bool isLoading: false
    property string statusMessage: ""
    property string activeMode: plasmoid.configuration.viewMode || "day"

    fullRepresentation: Item {
        implicitWidth: Kirigami.Units.gridUnit * 22
        implicitHeight: Kirigami.Units.gridUnit * 28
        
        // DIBUJAMOS EL FONDO MANUALMENTE PARA ASEGURAR REDONDEO
        Rectangle {
            anchors.fill: parent
            radius: 25
            color: Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.8)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.mediumSpacing

            // HEADER
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: [
                            { label: "Hoy", mode: "day" },
                            { label: "Semana", mode: "week" },
                            { label: "Mes", mode: "month" }
                        ]
                        delegate: PlasmaComponents.ToolButton {
                            Layout.fillWidth: true
                            text: modelData.label
                            checked: root.activeMode === modelData.mode
                            onClicked: {
                                root.activeMode = modelData.mode
                                root.applyFilter()
                            }
                            
                            contentItem: PlasmaComponents.Label {
                                text: parent.text
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.weight: parent.checked ? Font.Bold : Font.Normal
                                opacity: parent.checked ? 1.0 : 0.6
                            }

                            background: Rectangle {
                                color: "white"
                                opacity: parent.checked ? 0.1 : 0
                                radius: 10
                            }
                        }
                    }
                }

                Button {
                    icon.name: "view-refresh-symbolic"
                    flat: true
                    onClicked: root.fetchICS()
                    opacity: 0.6
                }
            }

            // LISTA
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: eventList
                    anchors.fill: parent
                    model: root.filteredEvents
                    spacing: Kirigami.Units.mediumSpacing
                    ScrollBar.vertical: ScrollBar { }

                    delegate: Item {
                        width: eventList.width
                        height: delegateCol.implicitHeight + Kirigami.Units.largeSpacing

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: "white"
                            opacity: 0.04
                        }

                        ColumnLayout {
                            id: delegateCol
                            anchors.centerIn: parent
                            width: parent.width - Kirigami.Units.largeSpacing * 2
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                PlasmaComponents.Label {
                                    text: modelData.summary || "Sin título"
                                    font.weight: Font.Bold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    implicitWidth: typeText.implicitWidth + Kirigami.Units.smallSpacing * 2
                                    implicitHeight: typeText.implicitHeight + Kirigami.Units.smallSpacing
                                    radius: 6
                                    border.width: 1
                                    color: {
                                        if (modelData.type === "Tarea") return Qt.rgba(0.2, 0.8, 0.2, 0.12)
                                        return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.12)
                                    }
                                    border.color: {
                                        if (modelData.type === "Tarea") return Qt.rgba(0.2, 0.8, 0.2, 0.5)
                                        return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.5)
                                    }

                                    PlasmaComponents.Label {
                                        id: typeText
                                        anchors.centerIn: parent
                                        text: modelData.type || "Evento"
                                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 0.85
                                        font.weight: Font.DemiBold
                                        color: {
                                            if (modelData.type === "Tarea") return "#4caf50"
                                            return Kirigami.Theme.highlightColor
                                        }
                                    }
                                }
                            }

                            PlasmaComponents.Label {
                                text: {
                                    const d = modelData.dtstart
                                    if (!d) return ""
                                    return Qt.formatDate(d, "dd MMM") + " · " + (d.isAllDay ? "Todo el día" : Qt.formatTime(d, "HH:mm"))
                                }
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                                opacity: 0.6
                            }
                        }
                    }
                }
            }
        }
    }

    function applyFilter() {
        if (!allEvents) return
        const now = new Date()
        const start = new Date(); start.setHours(0,0,0,0)
        const end = new Date()
        if (root.activeMode === "day") end.setHours(23, 59, 59, 999)
        else if (root.activeMode === "week") end.setDate(now.getDate() + 7)
        else end.setMonth(now.getMonth() + 1)

        filteredEvents = allEvents.filter(e => e.dtstart <= end && (e.dtend ? e.dtend > start : e.dtstart >= start))
    }

    function fetchICS() {
        const url = plasmoid.configuration.icsUrl
        if (!url) return
        isLoading = true
        
        // Evitar caché de red agregando timestamp
        const randomUrl = url + (url.indexOf("?") === -1 ? "?" : "&") + "t=" + new Date().getTime()
        
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isLoading = false
                if (xhr.status === 200) {
                    allEvents = Parser.parseICS(xhr.responseText)
                    applyFilter()
                    statusMessage = "Act: " + Qt.formatTime(new Date(), "HH:mm")
                }
            }
        }
        xhr.open("GET", randomUrl); xhr.send()
    }

    Connections {
        target: plasmoid.configuration
        function onIcsUrlChanged() { root.fetchICS() }
    }

    Timer {
        id: refreshTimer
        interval: (plasmoid.configuration.refreshInterval || 30) * 60000
        running: true
        repeat: true
        onTriggered: root.fetchICS()
    }

}
