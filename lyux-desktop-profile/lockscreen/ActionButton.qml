/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2024 Noah Davis <noahadvs@gmail.com>
    SPDX-FileCopyrightText: 2026 LyuX OS / FlowCreativeStudio
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.15
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami

PlasmaComponents3.AbstractButton {
    id: root
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
    font.family: "Inter"
    font.underline: root.activeFocus

    icon.width: Kirigami.Units.iconSizes.large
    icon.height: Kirigami.Units.iconSizes.large

    hoverEnabled: true

    leftInset: Math.max(Kirigami.Units.largeSpacing * 4, (implicitContentWidth - implicitBackgroundWidth) / 2)
    rightInset: leftInset

    padding: Kirigami.Units.smallSpacing
    horizontalPadding: 0
    bottomPadding: 0
    spacing: padding + Kirigami.Units.smallSpacing

    opacity: root.activeFocus || root.hovered ? 1.0 : 0.88
    Behavior on opacity {
        PropertyAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }
    }

    Kirigami.MnemonicData.enabled: root.enabled && root.visible
    Kirigami.MnemonicData.controlType: Kirigami.MnemonicData.SecondaryControl
    Kirigami.MnemonicData.label: root.text

    Shortcut {
        enabled: !(RegExp(/\&[^\&]/).test(root.text))
        sequence: root.Kirigami.MnemonicData.sequence
        onActivated: {
            if (typeof root.animateClick === "function") {
                root.animateClick();
            } else {
                root.clicked();
            }
        }
    }

    background: Rectangle {
        implicitWidth: root.icon.width + root.padding * 2
        implicitHeight: root.icon.height + root.padding * 2
        width: implicitWidth
        height: implicitHeight
        radius: width / 2
        color: root.hovered || root.activeFocus ? Qt.rgba(255, 255, 255, 0.35) : Qt.rgba(255, 255, 255, 0.20)
        border.color: root.hovered || root.activeFocus ? "#3daee9" : Qt.rgba(255, 255, 255, 0.35)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#ffffff"
            opacity: 0.15
            scale: root.down ? 1 : 0
            Behavior on scale {
                PropertyAnimation {
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.InOutQuart
                }
            }
        }
    }

    contentItem: Column {
        spacing: root.spacing
        Kirigami.Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: root.icon.name
            implicitWidth: root.icon.width
            implicitHeight: root.icon.height
            active: root.hovered || root.activeFocus
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, parent.width)
            text: root.Kirigami.MnemonicData.richTextLabel
            font.family: "Inter"
            font.pixelSize: 13
            font.weight: Font.Normal
            color: "#ffffff"
            style: Text.Raised
            styleColor: "#66000000"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }

    Keys.onEnterPressed: clicked()
    Keys.onReturnPressed: clicked()
}
