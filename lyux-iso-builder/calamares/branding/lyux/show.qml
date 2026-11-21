import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: presentation
    color: "#0F172A"
    anchors.fill: parent

    SwipeView {
        id: view
        currentIndex: 0
        anchors.fill: parent

        Item {
            id: slide1
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Bienvenue sur LyuX OS"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#38BDF8"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: "Distribution GNU/Linux standardisée pour les lycées\nOpération Manchot"
                    font.pixelSize: 16
                    color: "#94A3B8"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item {
            id: slide2
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Environnement Moderne KDE Plasma"
                    font.pixelSize: 26
                    font.bold: true
                    color: "#38BDF8"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: "Interface fluide sous serveur d'affichage X11\nConfiguration française intégrale et clavier AZERTY latin9"
                    font.pixelSize: 16
                    color: "#94A3B8"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item {
            id: slide3
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Intégration Active Directory & Partages Réseau"
                    font.pixelSize: 26
                    font.bold: true
                    color: "#38BDF8"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: "Authentification centralisée SSSD / Kerberos\nMontage automatique des dossiers Espace Personnel et Partages Classes via pam_mount"
                    font.pixelSize: 16
                    color: "#94A3B8"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Item {
            id: slide4
            Column {
                anchors.centerIn: parent
                spacing: 16
                Text {
                    text: "Profils Pédagogiques & Supervision Veyon"
                    font.pixelSize: 26
                    font.bold: true
                    color: "#38BDF8"
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    text: "Outils NSI/Maths (VS Code, Python, GeoGebra, Jupyter) et Sciences (Avogadro, Tracker)\nSupervision pédagogique en direct avec Veyon Master & Service"
                    font.pixelSize: 16
                    color: "#94A3B8"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    PageIndicator {
        id: indicator
        count: view.count
        currentIndex: view.currentIndex
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
    }

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: {
            view.currentIndex = (view.currentIndex + 1) % view.count
        }
    }
}
