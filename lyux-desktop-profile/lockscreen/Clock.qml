import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.kirigami 2.20 as Kirigami

ColumnLayout {
    id: root
    spacing: 6

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    P5Support.DataSource {
        id: timeSource
        engine: "time"
        connectedSources: ["Local"]
        interval: 1000
    }

    Text {
        text: Qt.formatTime(timeSource.data["Local"]["DateTime"], "HH:mm")
        font.family: "Inter"
        font.pixelSize: 80
        font.weight: Font.ExtraLight
        color: "#ffffff"
        Layout.alignment: Qt.AlignHCenter
        style: Text.Raised
        styleColor: "#55000000"
    }

    Text {
        text: Qt.formatDate(timeSource.data["Local"]["DateTime"], Qt.locale(), Locale.LongFormat)
        font.family: "Inter"
        font.pixelSize: 18
        font.weight: Font.Medium
        color: "#ddffffff"
        Layout.alignment: Qt.AlignHCenter
        style: Text.Raised
        styleColor: "#44000000"
    }
}
