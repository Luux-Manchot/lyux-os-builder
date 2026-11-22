import org.kde.breeze.components

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2

import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasma5support 2.0 as PlasmaCore

SessionManagementScreen {
    id: root
    property Item mainPasswordBox: passwordBox
    property bool showUsernamePrompt: !showUserList
    property int usernameFontSize
    property int fontSize: parseInt(config.fontSize) || 11
    property string usernameFontColor
    property string lastUserName
    property bool loginScreenUiVisible: false
    property bool passwordFieldOutlined: true
    property bool hidePasswordRevealIcon: false
    property int visibleBoundary: mapFromItem(loginButton, 0, 0).y
    onHeightChanged: visibleBoundary = mapFromItem(loginButton, 0, 0).y + loginButton.height + Kirigami.Units.smallSpacing

    signal loginRequest(string username, string password)

    onShowUsernamePromptChanged: {
        if (!showUsernamePrompt) {
            lastUserName = ""
        }
    }

    onUserSelected: {
        focusFirstVisibleFormControl();
    }

    QQC2.StackView.onActivating: {
        Qt.callLater(focusFirstVisibleFormControl);
    }

    function focusFirstVisibleFormControl() {
        const nextControl = (userNameInput.visible
            ? userNameInput
            : (passwordBox.visible
                ? passwordBox
                : loginButton));
        nextControl.forceActiveFocus(Qt.TabFocusReason);
    }

    function startLogin() {
        const username = showUsernamePrompt ? userNameInput.text : userList.selectedUser
        const password = passwordBox.text

        footer.enabled = false
        mainStack.enabled = false
        userListComponent.userList.opacity = 0.5

        loginButton.forceActiveFocus();
        loginRequest(username, password);
    }

    Input {
        id: userNameInput
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        font.pointSize: root.fontSize
        font.family: "Inter"
        text: lastUserName
        visible: showUsernamePrompt
        focus: showUsernamePrompt && !lastUserName
        placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Username")
        color: "#ffffff"
        leftPadding: 16
        rightPadding: 16
    }

    Item {
        id: passwordWrapper
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        implicitWidth: passwordBox.implicitWidth
        implicitHeight: 42

        Input {
            id: passwordBox
            anchors.fill: parent
            font.pointSize: root.fontSize
            font.family: "Inter"
            placeholderText: i18nd("plasma_lookandfeel_org.kde.lookandfeel", "Password")
            focus: !showUsernamePrompt || lastUserName
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            onAccepted: startLogin()
            passwordCharacter: "●"
            color: "#ffffff"
            leftPadding: 16
            rightPadding: 44

            property bool showPassword: false

            Shortcut {
                sequences: ["Ctrl+H", "Alt+P"]
                onActivated: passwordBox.showPassword = !passwordBox.showPassword
            }

            Keys.onEscapePressed: {
                mainStack.currentItem.forceActiveFocus();
            }

            Keys.onPressed: {
                if (event.key == Qt.Key_Left && !text) {
                    userList.decrementCurrentIndex();
                    event.accepted = true
                }
                if (event.key == Qt.Key_Right && !text) {
                    userList.incrementCurrentIndex();
                    event.accepted = true
                }
            }

            onTextChanged: {
                if (loginButton.opacity == 0 && length > 0) {
                    showLoginButton.start()
                }
                if (loginButton.opacity > 0 && length == 0) {
                    hideLoginButton.start()
                }
            }

            Connections {
                target: sddm
                onLoginFailed: {
                    passwordBox.selectAll()
                    passwordBox.forceActiveFocus()
                }
            }
        }

        Item {
            id: eyeButton
            z: 99
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: eyeMouseArea.containsMouse ? "#33ffffff" : "transparent"
            }

            Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: passwordBox.showPassword ? "assets/eye-off.svg" : "assets/eye.svg"
                opacity: passwordBox.text.length > 0 ? (eyeMouseArea.containsMouse ? 1.0 : 0.8) : 0.35
                smooth: true
            }

            MouseArea {
                id: eyeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onClicked: {
                    console.log("DEBUG_SDDM: eyeMouseArea clicked! Old showPassword=" + passwordBox.showPassword);
                    passwordBox.showPassword = !passwordBox.showPassword;
                }
            }
        }
    }

    Image {
        id: loginButton
        source: "assets/login.svgz"
        smooth: true
        sourceSize: Qt.size(42, 42)
        width: 42
        height: 42
        anchors {
            left: passwordWrapper.right
            verticalCenter: passwordWrapper.verticalCenter
        }
        anchors.leftMargin: 8
        visible: opacity > 0
        opacity: 0

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: startLogin();
        }

        PropertyAnimation {
            id: showLoginButton
            target: loginButton
            properties: "opacity"
            to: 0.9
            duration: 120
        }
        PropertyAnimation {
            id: hideLoginButton
            target: loginButton
            properties: "opacity"
            to: 0
            duration: 100
        }
    }
}
