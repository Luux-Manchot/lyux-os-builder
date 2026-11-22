import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: root
    spacing: 12

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    P5Support.DataSource {
        id: timeSource
        engine: "time"
        connectedSources: ["Local"]
        interval: 1000
    }

    readonly property var currentDateTime: (timeSource.data["Local"] && timeSource.data["Local"]["DateTime"]) ? timeSource.data["Local"]["DateTime"] : new Date()

    function capitalize(s) {
        if (!s || s.length === 0) return "";
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function getFormattedDate(dt) {
        if (!dt) return "";
        var formatted = Qt.formatDate(dt, Qt.locale(), Locale.LongFormat);
        return capitalize(formatted);
    }

    // Affichage de l'heure principale (grand format en gras, moderne et lisible)
    Text {
        id: timeLabel
        text: Qt.formatTime(root.currentDateTime, "HH:mm")
        font.family: "Inter"
        font.pixelSize: 102
        font.weight: Font.Bold
        font.letterSpacing: -2.0
        color: "#ffffff"
        Layout.alignment: Qt.AlignHCenter
        renderType: Text.NativeRendering
    }

    // Capsule élégante translucide en verre dépoli pour le jour et la date
    Rectangle {
        id: dateCapsule
        Layout.alignment: Qt.AlignHCenter
        implicitHeight: 36
        implicitWidth: dateRow.implicitWidth + 32
        radius: 18
        color: Qt.rgba(0, 0, 0, 0.30)
        border.color: Qt.rgba(255, 255, 255, 0.24)
        border.width: 1

        RowLayout {
            id: dateRow
            anchors.centerIn: parent
            spacing: 8

            Image {
                source: "assets/calendar.svg"
                sourceSize.width: 14
                sourceSize.height: 14
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                opacity: 0.95
                smooth: true
            }

            Text {
                id: dateLabel
                text: root.getFormattedDate(root.currentDateTime)
                font.family: "Inter"
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: "#ffffff"
                renderType: Text.NativeRendering
            }
        }
    }
}
