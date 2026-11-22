import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

TextField {
    id: control
    placeholderTextColor: "#99ffffff"
    color: "#ffffff"
    palette.text: "#ffffff"
    font.pointSize: 11
    font.family: config.font || "Inter"
    font.weight: Font.Normal
    selectByMouse: true
    selectionColor: "#1d99f3"
    selectedTextColor: "#ffffff"
    verticalAlignment: TextInput.AlignVCenter
    width: parent.width

    background: Rectangle {
        implicitHeight: 42
        radius: 21
        color: control.activeFocus ? "#38ffffff" : "#20ffffff"
        border.color: control.activeFocus ? "#3daee9" : "#48ffffff"
        border.width: control.activeFocus ? 2 : 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }
}
