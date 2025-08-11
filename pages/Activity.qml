import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NetSecOps 1.0
import "../components"

Item {
    id: root
    
    ActivityLogger {
        id: activityLogger
    }
    
    property var logs: [
        {id: 1, timestamp: "2024-01-15 14:30:25", type: "scan", action: "Network Discovery", target: "192.168.1.0/24", status: "success", user: "admin"},
        {id: 2, timestamp: "2024-01-15 14:28:15", type: "execution", action: "Remote Command", target: "192.168.1.100", status: "success", user: "admin"},
        {id: 3, timestamp: "2024-01-15 14:25:10", type: "file", action: "File Transfer", target: "192.168.1.101", status: "failed", user: "admin"},
        {id: 4, timestamp: "2024-01-15 14:20:05", type: "auth", action: "Login Attempt", target: "192.168.1.102", status: "failed", user: "admin"},
        {id: 5, timestamp: "2024-01-15 14:15:30", type: "scan", action: "Port Scan", target: "192.168.1.103", status: "success", user: "admin"},
        {id: 6, timestamp: "2024-01-15 14:30:25", type: "scan", action: "Network Discovery", target: "192.168.1.0/24", status: "success", user: "admin"},
        {id: 7, timestamp: "2024-01-15 14:28:15", type: "execution", action: "Remote Command", target: "192.168.1.100", status: "success", user: "admin"},
        {id: 8, timestamp: "2024-01-15 14:25:10", type: "file", action: "File Transfer", target: "192.168.1.101", status: "failed", user: "admin"},
        {id: 9, timestamp: "2024-01-15 14:20:05", type: "auth", action: "Login Attempt", target: "192.168.1.102", status: "failed", user: "admin"},
        {id: 10, timestamp: "2024-01-15 14:15:30", type: "scan", action: "Port Scan", target: "192.168.1.103", status: "success", user: "admin"}
    ]
    
    property var alerts: [
        {id: 1, severity: "high", message: "Failed authentication attempts detected", count: 5, target: "192.168.1.102"},
        {id: 2, severity: "medium", message: "Unusual port activity", count: 1, target: "192.168.1.105"},
        {id: 3, severity: "low", message: "Slow response time detected", count: 2, target: "192.168.1.107"}
    ]
    
    ColumnLayout {
        // x: 24
        // y: 24
        // width: root.width-48
        // spacing: 24
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 24
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Column {
                Layout.fillWidth: true
                spacing: 4
                
                Text {
                    text: "Activity Monitor"
                    color: "#f8fafc"
                    font.pixelSize: 32
                    font.bold: true
                }
                
                Text {
                    text: "Real-time monitoring and audit logs"
                    color: "#64748b"
                    font.pixelSize: 16
                }
            }
            
            Row {
                spacing: 8
                
                Button {
                    icon: "qrc:/svgs/activity/funnel.svg"
                    text: "Filter"
                    variant: "outline"
                }
                
                Button {
                    icon: "qrc:/svgs/search-white.svg"
                    text: "Search"
                    variant: "cyber"
                }
                
                Button {
                    icon: "qrc:/svgs/trash-2.svg"
                    text: "Clear History"
                    variant: "destructive"
                    onClicked: clearHistoryDialog.open()
                }
            }
        }
        
        // Tabs
        Rectangle {

            Layout.fillWidth: true
            // Layout.preferredHeight: 600
            Layout.fillHeight: true
            color: "transparent"
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 24
                
                // Tab Bar
                Row {
                    // width: parent.width
                    // height: 40
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40

                    property int currentTab: 0
                    
                    Repeater {
                        model: ["📊 Activity Logs", "⚠️ Security Alerts"]
                        
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
                                font.bold: true
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
                    // width: parent.width
                    // height: parent.height// - 64
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    sourceComponent: {
                        switch(parent.children[0].currentTab) {
                            case 0: return logsTabComponent
                            case 1: return alertsTabComponent
                            default: return logsTabComponent
                        }
                    }
                }
            }
        }
    }
    
    // Logs Tab Component
    Component {
        id: logsTabComponent
        
        Column {
            anchors.fill: parent
            spacing: 24
            
            // Search & Filter
            Card {
                width: parent.width
                height: 130
                title: "Search & Filter"
                
                Row {
                    anchors.fill: parent
                    spacing: 16
                    
                    Input {
                        width: 300
                        placeholderText: "Search logs..."
                    }
                    
                    ComboBox {
                        width: 160
                        height: 40
                        model: ["All Types", "Network Discovery", "Network Mapping", "Port Scan", "File Transfer", "Remote Execution", "Authentication", "Credential Management"]
                        
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
                    
                    ComboBox {
                        width: 128
                        height: 40
                        model: ["All Status", "Success", "Failed", "Pending"]
                        
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
            
            // Recent Activity
            Card {
                width: parent.width
                height: parent.height - 148
                title: "Recent Activity"
                description: "Last 100 operations"
                
                ScrollView {
                    anchors.fill: parent
                    
                    Column {
                        width: parent.width
                        spacing: 8
                        
                        Repeater {
                            model: activityLogger.activities
                            
                            Rectangle {
                                width: parent.width
                                height: 60
                                radius: 8
                                color: "#0f1419"
                                border.color: "#1e2328"
                                border.width: 1
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.topMargin: 6
                                    anchors.bottomMargin: 6
                                    anchors.rightMargin: 6

                                    spacing: 12
                                    
                                    // Text {
                                    //     text: {
                                    //         switch(modelData.status) {
                                    //             case "success": return "✅"
                                    //             case "failed": return "❌"
                                    //             default: return "⏱️"
                                    //         }
                                    //     }
                                    //     font.pixelSize: 16
                                    // }
                                    Image{
                                        width: 20
                                        height: 20
                                        source: {
                                            switch(modelData.type) {
                                                case "discovery": return "qrc:/svgs/search-white.svg"
                                                case "mapping": return "qrc:/svgs/network_map/map.svg"
                                                case "scan": return "qrc:/svgs/network_discovery/radar.svg"
                                                case "execution": return "qrc:/svgs/terminal-white.svg"
                                                case "file": return "qrc:/svgs/operation/file-text.svg"
                                                case "credential": return "qrc:/svgs/key.svg"
                                                default: {
                                                    switch(modelData.status) {
                                                        case "success": return "qrc:/svgs/activity/square-check-big.svg"
                                                        case "failed": return "qrc:/svgs/operation/square-x.svg"
                                                        default: return "qrc:/svgs/clock-white.svg"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        
                                        RowLayout {
                                            spacing: 8
                                            
                                            Text {
                                                text: modelData.action
                                                color: "#f8fafc"
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                            }
                                            
                                            Badge {
                                                text: modelData.status
                                                variant: {
                                                    switch(modelData.status) {
                                                        case "success": return "success"
                                                        case "failed": return "destructive"
                                                        default: return "warning"
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Text {
                                            text: modelData.timestamp + " • Target: " + modelData.target + " • User: " + modelData.user
                                            color: "#64748b"
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Button {
                                        Layout.preferredHeight: 26
                                        Layout.preferredWidth: 90
                                        Layout.alignment: Qt.AlignRight
                                        text: "View Details"
                                        variant: "ghost"
                                        onClicked: logDetailDialog.open()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Alerts Tab Component
    Component {
        id: alertsTabComponent
        
        Column {
            spacing: 16
            
            Repeater {
                model: root.alerts
                
                Card {
                    width: parent.width
                    height: 80
                    
                    RowLayout {
                        anchors.fill: parent
                        spacing: 12
                        
                        Text {
                            text: "⚠️"
                            font.pixelSize: 20
                            color: "#dc2626"
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 4
                            
                            RowLayout {
                                spacing: 8
                                
                                Text {
                                    text: modelData.message
                                    color: "#f8fafc"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                                
                                Badge {
                                    text: modelData.severity
                                    variant: {
                                        switch(modelData.severity) {
                                            case "high": return "destructive"
                                            case "medium": return "warning"
                                            default: return "outline"
                                        }
                                    }
                                }
                            }
                            
                            Text {
                                text: "Target: " + modelData.target + " • Count: " + modelData.count
                                color: "#64748b"
                                font.pixelSize: 12
                            }
                        }
                        
                        Row {
                            spacing: 8
                            
                            Button {
                                text: "Investigate"
                                variant: "outline"
                            }
                            
                            Button {
                                text: "Dismiss"
                                variant: "ghost"
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Log Details Dialog
    Dialog {
        id: logDetailDialog
        title: "Activity Details"
        width: 600
        height: 400
        
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
                text: "Detailed information about the selected activity"
                color: "#64748b"
                font.pixelSize: 14
            }
            
            Row {
                width: parent.width
                spacing: 32
                
                Column {
                    width: (parent.width - 32) / 2
                    spacing: 16
                    
                    Column {
                        width: parent.width
                        spacing: 4
                        
                        Text {
                            text: "Timestamp"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Text {
                            text: "2024-01-15 14:30:25"
                            color: "#64748b"
                            font.pixelSize: 12
                        }
                    }
                    
                    Column {
                        width: parent.width
                        spacing: 4
                        
                        Text {
                            text: "Target"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Text {
                            text: "192.168.1.100"
                            color: "#64748b"
                            font.pixelSize: 12
                        }
                    }
                }
                
                Column {
                    width: (parent.width - 32) / 2
                    spacing: 16
                    
                    Column {
                        width: parent.width
                        spacing: 4
                        
                        Text {
                            text: "Action"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Text {
                            text: "Network Discovery"
                            color: "#64748b"
                            font.pixelSize: 12
                        }
                    }
                    
                    Column {
                        width: parent.width
                        spacing: 4
                        
                        Text {
                            text: "Status"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Text {
                            text: "success"
                            color: "#64748b"
                            font.pixelSize: 12
                        }
                    }
                }
            }
            
            Column {
                width: parent.width
                spacing: 8
                
                Text {
                    text: "Additional Details"
                    color: "#f8fafc"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
                
                Rectangle {
                    width: parent.width
                    height: 120
                    radius: 6
                    color: "#1e293b"
                    
                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4
                        
                        Text {
                            text: "Command executed: whoami"
                            color: "#f8fafc"
                            font.pixelSize: 12
                        }
                        
                        Text {
                            text: "Protocol used: SSH"
                            color: "#f8fafc"
                            font.pixelSize: 12
                        }
                        
                        Text {
                            text: "Duration: 2.3 seconds"
                            color: "#f8fafc"
                            font.pixelSize: 12
                        }
                        
                        Text {
                            text: "Output: 134 bytes"
                            color: "#f8fafc"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
    
    // Clear History Dialog
    Dialog {
        id: clearHistoryDialog
        width: 400
        height: 200
        anchors.centerIn: parent
        modal: true
        
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
                text: "Clear Activity History"
                color: "#f8fafc"
                font.pixelSize: 18
                font.weight: Font.Medium
            }
            
            Text {
                text: "This will permanently delete all activity logs. This action cannot be undone."
                color: "#64748b"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                width: parent.width
            }
            
            Row {
                width: parent.width
                spacing: 8
                
                Button {
                    width: (parent.width - 8) / 2
                    text: "Clear History"
                    variant: "destructive"
                    onClicked: {
                        activityLogger.clearActivities()
                        clearHistoryDialog.close()
                    }
                }
                
                Button {
                    width: (parent.width - 8) / 2
                    text: "Cancel"
                    variant: "outline"
                    onClicked: clearHistoryDialog.close()
                }
            }
        }
    }
}
