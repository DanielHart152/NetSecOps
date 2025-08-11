import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NetSecOps 1.0
import "../components"

ScrollView {
    id: root
    
    CredentialManager {
        id: credentialManager
        onCredentialAdded: function(id, name, host, type) {
            console.log("Credential added:", name, "for", host)
            loadCredentials()
        }
        onCredentialRemoved: function(id) {
            console.log("Credential removed:", id)
            loadCredentials()
        }
        onCredentialPromptRequired: function(host, protocol) {
            console.log("Credential prompt required for", host, protocol)
        }
    }
    
    ListModel {
        id: credentialsModel
    }
    
    function loadCredentials() {
        credentialsModel.clear()
        var creds = credentialManager.getAllCredentials()
        for (var i = 0; i < creds.length; i++) {
            credentialsModel.append(creds[i])
        }
    }
    
    Component.onCompleted: {
        loadCredentials()
    }
    
    ColumnLayout {

        x: 24
        width: root.width-48
        spacing: 24
        // anchors.margins: 24
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Column {
                Layout.fillWidth: true
                spacing: 4
                
                Text {
                    text: "Credentials Manager"
                    color: "#f8fafc"
                    font.pixelSize: 32
                    font.bold: true
                }
                
                Text {
                    text: "Securely manage authentication credentials"
                    color: "#64748b"
                    font.pixelSize: 16
                }
            }
            
            Button {
                icon: "qrc:/svgs/credential/plus.svg"
                text: "Add Credential"
                variant: "cyber"
                onClicked: addCredentialDialog.open()
            }
        }
        
        // Security Settings
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            icon: "qrc:/svgs/shield-white.svg"
            title: "Security Settings"

            Column {
                anchors.fill: parent
                spacing: 16

                RowLayout {
                    width: parent.width

                    Column {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Credential Encryption"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        Text {
                            text: "AES-256 encryption enabled"
                            color: "#64748b"
                            font.pixelSize: 12
                        }
                    }

                    Badge {
                        text: "Active"
                        variant: "success"
                    }
                }

                RowLayout {
                    width: parent.width

                    Column {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Auto-lock Timeout"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }

                        Text {
                            text: "Lock credentials after inactivity"
                            color: "#64748b"
                            font.pixelSize: 12
                        }
                    }

                    ComboBox {
                        width: 128
                        height: 32
                        model: ["15 minutes", "30 minutes", "1 hour", "Never"]

                        background: Rectangle {
                            radius: 6
                            color: "#1e293b"
                            border.color: "#475569"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.currentText
                            color: "#f8fafc"
                            font.pixelSize: 12
                            leftPadding: 8
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        // Credentials List
        Column {
            Layout.fillWidth: true
            spacing: 16
            
            Repeater {
                model: credentialsModel
                
                Card {
                    width: parent.width
                    height: 100
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: 16
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 4
                            
                            RowLayout {
                                spacing: 12
                                
                                // Text {
                                //     text: "🛡️"
                                //     font.pixelSize: 20
                                //     color: "#3b82f6"
                                // }
                                Image {
                                    source: "qrc:/svgs/shield-check.svg"
                                }
                                
                                Text {
                                    text: model.name
                                    color: "#f8fafc"
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                }
                                
                                Badge {
                                    text: model.type
                                    variant: "outline"
                                }
                            }
                            
                            Text {
                                text: "Username: " + model.username + " • Host: " + (model.host || "Any") + " • Last used: " + model.lastUsed
                                color: "#64748b"
                                font.pixelSize: 12
                            }
                        }
                        
                        Row {
                            spacing: 8
                            
                            Button {
                                width: 32
                                height: 32
                                icon: "qrc:/svgs/square-pen.svg"
                                variant: "ghost"
                            }
                            
                            Button {
                                width: 32
                                height: 32
                                icon: "qrc:/svgs/key.svg"
                                variant: "ghost"
                            }
                            
                            Button {
                                width: 32
                                height: 32
                                icon: "qrc:/svgs/trash-2.svg"
                                variant: "ghost"
                                onClicked: {
                                    credentialManager.removeCredential(model.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    // Add Credential Dialog
    Dialog {
        id: addCredentialDialog
        width: 500
        height: 480
        anchors.centerIn: parent
        modal: true
        // flags: Qt.Dialog | Qt.FramelessWindowHint
        
        property bool showPassword: false
        
        background: Rectangle {
            color: "#0f1419"
            border.color: "#1e2328"
            border.width: 1
            radius: 12
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            
            Text {
                text: "Store encrypted credentials for remote access"
                color: "#64748b"
                font.pixelSize: 14
            }
            
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Credential Name"
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                
                Input {
                    id: credNameInput
                    width: parent.width
                    placeholderText: "e.g., Production Server Admin"
                }
            }
            
            Row {
                width: parent.width
                spacing: 16
                
                Column {
                    width: (parent.width - 16) / 2
                    spacing: 8
                    
                    Text {
                        text: "Username"
                        color: "#f8fafc"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    
                    Input {
                        id: credUsernameInput
                        width: parent.width
                        placeholderText: "username"
                    }
                }
                
                Column {
                    width: (parent.width - 16) / 2
                    spacing: 8
                    
                    Text {
                        text: "Type"
                        color: "#f8fafc"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    
                    ComboBox {
                        id: credTypeCombo
                        width: parent.width
                        height: 40
                        model: ["SSH Key", "Password", "Windows", "Domain"]
                        
                        background: Rectangle {
                            radius: 6
                            color: "#1e293b"
                            border.color: "#475569"
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: parent.currentText
                            color: "#f8fafc"
                            font.pixelSize: 14
                            leftPadding: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
            
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Password/Key"
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                
                RowLayout {
                    width: parent.width
                    
                    TextField {
                        id: credPasswordInput
                        Layout.fillWidth: true
                        height: 40
                        placeholderText: "Enter password or paste SSH key"
                        echoMode: addCredentialDialog.showPassword ? TextInput.Normal : TextInput.Password
                        
                        background: Rectangle {
                            radius: 6
                            color: "#1e293b"
                            border.color: parent.activeFocus ? "#3b82f6" : "#475569"
                            border.width: 1
                        }
                        
                        color: "#f8fafc"
                        selectionColor: "#3b82f6"
                        selectedTextColor: "#ffffff"
                        placeholderTextColor: "#64748b"
                        font.pixelSize: 14
                        leftPadding: 12
                        rightPadding: 12
                    }
                    
                    Button {
                        width: 40
                        height: 40
                        text: addCredentialDialog.showPassword ? "🙈" : "👁️"
                        variant: "ghost"
                        onClicked: addCredentialDialog.showPassword = !addCredentialDialog.showPassword
                    }
                }
            }
            
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Host/IP (optional)"
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                
                Input {
                    id: credHostInput
                    width: parent.width
                    placeholderText: "192.168.1.100 or leave empty for any host"
                }
            }
            
            Button {
                width: parent.width
                text: "Save Credential"
                variant: "cyber"
                enabled: credNameInput.text.length > 0 && credUsernameInput.text.length > 0 && credPasswordInput.text.length > 0
                onClicked: {
                    if (credTypeCombo.currentText === "SSH Key") {
                        credentialManager.addSSHKey(
                            credNameInput.text,
                            credHostInput.text,
                            credUsernameInput.text,
                            credPasswordInput.text
                        )
                    } else {
                        credentialManager.addCredential(
                            credNameInput.text,
                            credHostInput.text,
                            credUsernameInput.text,
                            credPasswordInput.text,
                            credTypeCombo.currentText
                        )
                    }
                    
                    // Clear inputs
                    credNameInput.text = ""
                    credHostInput.text = ""
                    credUsernameInput.text = ""
                    credPasswordInput.text = ""
                    
                    addCredentialDialog.close()
                }
            }
        }
    }
}
