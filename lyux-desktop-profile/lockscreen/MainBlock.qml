/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2026 LyuX OS / FlowCreativeStudio
    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kscreenlocker 1.0 as ScreenLocker

import org.kde.breeze.components

SessionManagementScreen {
    id: sessionManager

    readonly property alias mainPasswordBox: passwordBox
    property bool lockScreenUiVisible: false
    property alias showPassword: passwordBox.showPassword

    property int visibleBoundary: mapFromItem(loginButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(loginButton, 0, 0).y + loginButton.height + Kirigami.Units.smallSpacing

    signal passwordResult(string password)

    onUserSelected: {
        const nextControl = (passwordBox.visible ? passwordBox : loginButton);
        nextControl.forceActiveFocus(Qt.TabFocusReason);
    }

    function startLogin() {
        const password = passwordBox.text
        loginButton.forceActiveFocus();
        passwordResult(password);
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        spacing: 10

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 42

            QQC2.TextField {
                id: passwordBox
                anchors.fill: parent
                font.family: "Inter"
                font.pointSize: 11
                color: "#ffffff"
                palette.text: "#ffffff"
                echoMode: showPassword ? TextInput.Normal : TextInput.Password
                passwordCharacter: "●"
                placeholderText: i18nd("plasma_shell_org.kde.plasma.desktop", "Mot de passe")
                placeholderTextColor: "#99ffffff"
                focus: true
                enabled: !authenticator.graceLocked
                leftPadding: 16
                rightPadding: 44
                selectByMouse: true
                selectionColor: "#1d99f3"
                selectedTextColor: "#ffffff"
                verticalAlignment: TextInput.AlignVCenter
                text: PasswordSync.password

                property bool showPassword: false

                background: Rectangle {
                    implicitHeight: 42
                    radius: 21
                    color: passwordBox.activeFocus ? "#35ffffff" : "#20ffffff"
                    border.color: passwordBox.activeFocus ? "#3daee9" : "#45ffffff"
                    border.width: passwordBox.activeFocus ? 2 : 1

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }

                onAccepted: {
                    if (lockScreenUiVisible) {
                        startLogin();
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left && !text) {
                        userList.decrementCurrentIndex();
                        event.accepted = true
                    }
                    if (event.key === Qt.Key_Right && !text) {
                        userList.incrementCurrentIndex();
                        event.accepted = true
                    }
                }

                Connections {
                    target: root
                    function onClearPassword() {
                        passwordBox.forceActiveFocus()
                        passwordBox.text = "";
                        passwordBox.text = Qt.binding(() => PasswordSync.password);
                    }
                    function onNotificationRepeated() {
                        sessionManager.playHighlightAnimation();
                    }
                }
            }

            // Bouton oeil pour afficher/masquer le mot de passe
            Item {
                id: eyeButton
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: eyeMouseArea.containsMouse ? "#33ffffff" : "transparent"
                }

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: passwordBox.showPassword ? Qt.resolvedUrl("assets/eye-off.svg") : Qt.resolvedUrl("assets/eye.svg")
                    opacity: passwordBox.text.length > 0 ? (eyeMouseArea.containsMouse ? 1.0 : 0.85) : 0.40
                    smooth: true
                }

                MouseArea {
                    id: eyeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onClicked: {
                        passwordBox.showPassword = !passwordBox.showPassword;
                    }
                }
            }
        }

        Binding {
            target: PasswordSync
            property: "password"
            value: passwordBox.text
        }

        // Bouton rond de validation (flèche droite moderne en verre dépoli)
        Item {
            id: loginButton
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42

            Rectangle {
                anchors.fill: parent
                radius: 21
                color: loginMouseArea.pressed ? "#50ffffff" : (loginMouseArea.containsMouse ? "#38ffffff" : "#22ffffff")
                border.color: loginMouseArea.containsMouse ? "#3daee9" : "#45ffffff"
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: LayoutMirroring.enabled ? "go-previous" : "go-next"
            }

            MouseArea {
                id: loginMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: startLogin()
            }
        }
    }

    component FailableLabel : PlasmaComponents3.Label {
        id: _failableLabel
        required property int kind
        required property string label

        visible: authenticator.authenticatorTypes & kind
        text: label
        textFormat: Text.PlainText
        horizontalAlignment: Text.AlignHCenter
        Layout.fillWidth: true
        color: "#ffffff"
        palette.text: "#ffffff"

        RejectPasswordAnimation {
            id: _rejectAnimation
            target: _failableLabel
            onFinished: _timer.restart()
        }

        Connections {
            target: authenticator
            function onNoninteractiveError(kind, authenticator) {
                if (kind & _failableLabel.kind) {
                    _failableLabel.text = Qt.binding(() => authenticator.errorMessage)
                    _rejectAnimation.start()
                }
            }
        }
        Timer {
            id: _timer
            interval: Kirigami.Units.humanMoment
            onTriggered: {
                _failableLabel.text = Qt.binding(() => _failableLabel.label)
            }
        }
    }

    FailableLabel {
        kind: ScreenLocker.Authenticator.Fingerprint
        label: i18nd("plasma_shell_org.kde.plasma.desktop", "(or scan your fingerprint on the reader)")
    }
    FailableLabel {
        kind: ScreenLocker.Authenticator.Smartcard
        label: i18nd("plasma_shell_org.kde.plasma.desktop", "(or scan your smartcard)")
    }
}
