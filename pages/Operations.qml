import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NetSecOps 1.0
import "../components"

ScrollView {
    id: root
    
    CredentialManager {
        id: credentialManager
    }
    
    ActivityLogger {
        id: activityLogger
    }
    
    RemoteExecutor {
        id: remoteExecutor
        Component.onCompleted: {
            setCredentialManager(credentialManager)
        }
        onJobStarted: function(jobId, type, target) {
            activeJobsModel.append({
                id: jobId,
                type: type,
                target: target,
                progress: 0,
                status: "running"
            })
            activityLogger.logActivity("execution", type, target, "started")
        }
        onJobProgress: function(jobId, progress) {
            updateJobProgress(jobId, progress)
        }
        onJobCompleted: function(jobId, output) {
            updateJobStatus(jobId, "completed", 100)
            var job = getJobById(jobId)
            if (job) {
                activityLogger.logActivity("execution", job.type, job.target, "success")
            }
            console.log("Job", jobId, "completed:", output)
        }
        onJobFailed: function(jobId, error) {
            updateJobStatus(jobId, "failed", 100)
            var job = getJobById(jobId)
            if (job) {
                activityLogger.logActivity("execution", job.type, job.target, "failed")
            }
            console.log("Job", jobId, "failed:", error)
        }
        onOutputReceived: function(jobId, output) {
            console.log("Output from job", jobId + ":", output)
        }
        onCredentialRequired: function(host, protocol, jobId) {
            credentialPrompt.host = host
            credentialPrompt.protocol = protocol
            credentialPrompt.jobId = jobId
            credentialPrompt.open()
        }
    }
    
    ListModel {
        id: activeJobsModel
    }
    
    function updateJobProgress(jobId, progress) {
        for (var i = 0; i < activeJobsModel.count; i++) {
            if (activeJobsModel.get(i).id === jobId) {
                activeJobsModel.setProperty(i, "progress", progress)
                break
            }
        }
    }
    
    function updateJobStatus(jobId, status, progress) {
        for (var i = 0; i < activeJobsModel.count; i++) {
            if (activeJobsModel.get(i).id === jobId) {
                activeJobsModel.setProperty(i, "status", status)
                activeJobsModel.setProperty(i, "progress", progress)
                break
            }
        }
    }
    
    function getJobById(jobId) {
        for (var i = 0; i < activeJobsModel.count; i++) {
            if (activeJobsModel.get(i).id === jobId) {
                return activeJobsModel.get(i)
            }
        }
        return null
    }
    
    ColumnLayout {
        x: 24
        width: root.width-48
        spacing: 24
        anchors.margins: 24
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Column {
                Layout.fillWidth: true
                spacing: 4
                
                Text {
                    text: "Operations Center"
                    color: "#f8fafc"
                    font.pixelSize: 32
                    font.bold: true
                }
                
                Text {
                    text: "Manage remote execution and file operations"
                    color: "#64748b"
                    font.pixelSize: 16
                }
            }
            
            Button {
                icon: "qrc:/svgs/network_discovery/play.svg"
                text: "Quick Execute"
                variant: "cyber"
                onClicked: quickExecuteDialog.open()
            }
        }
        
        // Active Jobs
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            icon: "qrc:/svgs/dashboard/zap.svg"
            title: "Active Operations"

            ScrollView {
                anchors.fill: parent
                
                Column {
                    width: parent.width
                    spacing: 16
                    
                    Repeater {
                        model: activeJobsModel
                    
                    Rectangle {
                        width: parent.width
                        height: 80
                        radius: 8
                        color: "#0f1419"
                        border.color: "#1e2328"
                        border.width: 1
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            anchors.rightMargin: 4
                            spacing: 16
                            
                            Column {
                                Layout.fillWidth: true
                                spacing: 4
                                
                                RowLayout {
                                    spacing: 8
                                    
                                    Text {
                                        text: model.type
                                        color: "#f8fafc"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }
                                    
                                    Badge {
                                        text: model.status
                                        variant: model.status === "running" ? "warning" : model.status === "completed" ? "success" : "destructive"
                                    }
                                }
                                
                                Text {
                                    text: "Target: " + model.target
                                    color: "#64748b"
                                    font.pixelSize: 12
                                }
                            }
                            
                            Progress {
                                Layout.preferredWidth: 128
                                value: model.progress
                            }
                            
                            Text {
                                text: model.progress + "%"
                                color: "#f8fafc"
                                font.pixelSize: 12
                            }
                            
                            Button {
                                Layout.alignment: Qt.AlignRight
                                // text: model.status === "running" ? "⏹️" : ""
                                icon: model.status === "running" ? "" : "qrc:/svgs/operation/square-x.svg"
                                variant: "ghost"
                                width: 32
                                Layout.preferredWidth:32
                                height: 32
                                Layout.preferredHeight: 32
                                onClicked: {
                                    if (model.status === "running") {
                                        remoteExecutor.stopExecution(model.id)
                                    } else {
                                        activeJobsModel.remove(index)
                                    }
                                }
                            }
                        }
                    }
                }
                }
            }
        }
        
        // Tabs
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 460
            color: "transparent"
            
            Column {
                anchors.fill: parent
                spacing: 3
                
                // Tab Bar
                Row {
                    width: parent.width
                    height: 40
                    
                    property int currentTab: 0
                    
                    Repeater {
                        model: ["⚡ Remote Execution", "📁 File Operations"]
                        
                        Rectangle {
                            width: parent.width / 2
                            height: parent.height
                            color: parent.currentTab === index ? "#3b82f6" : "#1e293b"
                            border.color: "#475569"
                            border.width: 1
                            
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: parent.parent.currentTab === index ? "#ffffff" : "#64748b"
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                onClicked: parent.parent.currentTab = index
                            }
                        }
                    }
                }
                
                // Tab Content
                Loader {
                    width: parent.width
                    height: parent.height - 64
                    
                    sourceComponent: {
                        switch(parent.children[0].currentTab) {
                            case 0: return executionTabComponent
                            case 1: return filesTabComponent
                            default: return executionTabComponent
                        }
                    }
                }
            }
        }
    }
    // Execution Tab Component
    Component {
        id: executionTabComponent
        
        Card {
            title: "Execute Commands"
            icon: "qrc:/svgs/terminal-white.svg"
            description: "Run commands on remote systems"
            
            Column {
                anchors.fill: parent
                spacing: 16
                
                Row {
                    width: parent.width
                    spacing: 16
                    
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 8
                        
                        Text {
                            text: "Target Hosts"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Input {
                            id: targetHostsInput
                            width: parent.width
                            placeholderText: "192.168.1.100-110 or host list"
                        }
                    }
                    
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 8
                        
                        Text {
                            text: "Protocol"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        ComboBox {
                            id: protocolCombo
                            width: parent.width
                            height: 40
                            model: ["SSH", "WinRM", "PowerShell", "WMI", "SCHTASKS", "Custom"]
                            
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
                        text: "Command"
                        color: "#f8fafc"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    
                    ScrollView {
                        width: parent.width
                        height: 120
                        
                        TextArea {
                            id: commandTextArea
                            placeholderText: "Enter command to execute..."
                            color: "#f8fafc"
                            selectionColor: "#3b82f6"
                            selectedTextColor: "#ffffff"
                            placeholderTextColor: "#64748b"
                            font.pixelSize: 14
                            
                            background: Rectangle {
                                radius: 6
                                color: "#1e293b"
                                border.color: "#475569"
                                border.width: 1
                            }
                        }
                    }
                }
                
                Button {
                    width: parent.width
                    icon: "qrc:/svgs/operation/send-horizontal.svg"
                    text: "Execute Command"
                    variant: "cyber"
                    enabled: targetHostsInput.text.length > 0 && commandTextArea.text.length > 0
                    onClicked: {
                        activityLogger.logActivity("execution", "Remote Command", targetHostsInput.text, "started")
                        remoteExecutor.executeCommand(
                            targetHostsInput.text,
                            commandTextArea.text,
                            protocolCombo.currentText
                        )
                    }
                }
            }
        }
    }
    
    // Files Tab Component
    Component {
        id: filesTabComponent
        
        Card {
            title: "File Transfer"
            icon: "qrc:/svgs/operation/file-text.svg"
            description: "Deploy or retrieve files from remote systems"
            
            Column {
                anchors.fill: parent
                spacing: 16
                
                Row {
                    width: parent.width
                    spacing: 16
                    
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 8
                        
                        Text {
                            text: "Source Path"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Input {
                            id: sourcePathInput
                            width: parent.width
                            placeholderText: "/local/path/file.txt"
                        }
                    }
                    
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 8
                        
                        Text {
                            text: "Destination Path"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Input {
                            id: destPathInput
                            width: parent.width
                            placeholderText: "/remote/path/file.txt"
                        }
                    }
                }
                
                Row {
                    width: parent.width
                    spacing: 16
                    
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 8
                        
                        Text {
                            text: "Target Hosts"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Input {
                            id: fileTargetHostsInput
                            width: parent.width
                            placeholderText: "192.168.1.100-110"
                        }
                    }
                    
                    Column {
                        width: (parent.width - 16) / 2
                        spacing: 8
                        
                        Text {
                            text: "Protocol"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        ComboBox {
                            id: fileProtocolCombo
                            width: parent.width
                            height: 40
                            model: ["SCP/SFTP", "SMB", "WinRM"]
                            
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
                
                Row {
                    width: parent.width
                    spacing: 8
                    
                    Button {
                        width: (parent.width - 8) / 2
                        icon: "qrc:/svgs/operation/upload.svg"
                        text: "Deploy Files"
                        variant: "cyber"
                        enabled: sourcePathInput.text.length > 0 && destPathInput.text.length > 0 && fileTargetHostsInput.text.length > 0
                        onClicked: {
                            activityLogger.logActivity("file", "File Deploy", fileTargetHostsInput.text, "started")
                            remoteExecutor.deployFile(
                                sourcePathInput.text,
                                destPathInput.text,
                                fileTargetHostsInput.text,
                                fileProtocolCombo.currentText
                            )
                        }
                    }
                    
                    Button {
                        width: (parent.width - 8) / 2
                        icon: "qrc:/svgs/operation/download.svg"
                        text: "Retrieve Files"
                        variant: "outline"
                        enabled: sourcePathInput.text.length > 0 && destPathInput.text.length > 0 && fileTargetHostsInput.text.length > 0
                        onClicked: {
                            activityLogger.logActivity("file", "File Retrieve", fileTargetHostsInput.text, "started")
                            remoteExecutor.retrieveFile(
                                sourcePathInput.text,
                                destPathInput.text,
                                fileTargetHostsInput.text,
                                fileProtocolCombo.currentText
                            )
                        }
                    }
                }
            }
        }
    }
    
    // Quick Execute Dialog
    Dialog {
        id: quickExecuteDialog
        width: 500
        height: 350
        anchors.centerIn: parent
        modal: true
        // flags: Qt.Dialog | Qt.FramelessWindowHint
        
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
                text: "Execute a command on multiple targets quickly"
                color: "#64748b"
                font.pixelSize: 14
            }
            
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Target Hosts"
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                
                Input {
                    id: quickTargetInput
                    width: parent.width
                    placeholderText: "192.168.1.100-110 or comma-separated IPs"
                }
            }
            
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Command"
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                
                ScrollView {
                    width: parent.width
                    height: 80
                    
                    TextArea {
                        id: quickCommandArea
                        placeholderText: "Enter command to execute..."
                        color: "#f8fafc"
                        selectionColor: "#3b82f6"
                        selectedTextColor: "#ffffff"
                        placeholderTextColor: "#64748b"
                        font.pixelSize: 14
                        
                        background: Rectangle {
                            radius: 6
                            color: "#1e293b"
                            border.color: "#475569"
                            border.width: 1
                        }
                    }
                }
            }
            
            Button {
                width: parent.width
                icon: "qrc:/svgs/network_discovery/play.svg"
                text: "Execute Now"
                variant: "cyber"
                enabled: quickTargetInput.text.length > 0 && quickCommandArea.text.length > 0
                onClicked: {
                    activityLogger.logActivity("execution", "Quick Command", quickTargetInput.text, "started")
                    remoteExecutor.executeQuickCommand(
                        quickTargetInput.text,
                        quickCommandArea.text
                    )
                    quickExecuteDialog.close()
                }
            }
        }
    }
    
    // Credential Prompt Dialog
    Dialog {
        id: credentialPrompt
        width: 400
        height: 300
        anchors.centerIn: parent
        // flags: Qt.Dialog | Qt.FramelessWindowHint
        modal: true
        
        property string host: ""
        property string protocol: ""
        property int jobId: 0
        
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
                text: "Enter credentials for " + credentialPrompt.host + " (" + credentialPrompt.protocol + ")"
                color: "#f8fafc"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                width: parent.width
            }
            
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Username"
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                
                Input {
                    id: promptUsernameInput
                    width: parent.width
                    placeholderText: "Enter username"
                }
            }
            
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Password"
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                
                TextField {
                    id: promptPasswordInput
                    width: parent.width
                    height: 40
                    placeholderText: "Enter password"
                    echoMode: TextInput.Password
                    
                    background: Rectangle {
                        radius: 6
                        color: "#1e293b"
                        border.color: parent.activeFocus ? "#3b82f6" : "#475569"
                        border.width: 1
                    }
                    
                    color: "#f8fafc"
                    font.pixelSize: 14
                    leftPadding: 12
                }
            }
            
            Row {
                width: parent.width
                spacing: 8
                
                Button {
                    width: (parent.width - 8) / 2
                    text: "Execute"
                    variant: "cyber"
                    enabled: promptUsernameInput.text.length > 0 && promptPasswordInput.text.length > 0
                    onClicked: {
                        // Save credential for future use
                        credentialManager.addCredential(
                            credentialPrompt.host + " (" + credentialPrompt.protocol + ")",
                            credentialPrompt.host,
                            promptUsernameInput.text,
                            promptPasswordInput.text,
                            credentialPrompt.protocol
                        )
                        
                        // Execute with credential
                        remoteExecutor.executeWithCredential(
                            credentialPrompt.jobId,
                            promptUsernameInput.text,
                            promptPasswordInput.text
                        )
                        
                        promptUsernameInput.text = ""
                        promptPasswordInput.text = ""
                        credentialPrompt.close()
                    }
                }
                
                Button {
                    width: (parent.width - 8) / 2
                    text: "Cancel"
                    variant: "outline"
                    onClicked: {
                        // Remove the job
                        for (var i = 0; i < activeJobsModel.count; i++) {
                            if (activeJobsModel.get(i).id === credentialPrompt.jobId) {
                                activeJobsModel.remove(i)
                                break
                            }
                        }
                        credentialPrompt.close()
                    }
                }
            }
        }
    }
}
