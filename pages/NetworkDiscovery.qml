import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NetSecOps 1.0
import "../components"

ScrollView {
    id: root
    
    property string currentScanTarget: ""
    property string currentScanPorts: ""
    property int currentScanThreads: 50

    function toArray(qtList) {
        if (Array.isArray(qtList)) return qtList;
        if (qtList === null || qtList === undefined) return [];

        // Force conversion by copying
        var arr = [];
        for (var i = 0; i < qtList.length; ++i) {
            arr.push(qtList[i]);
        }
        return arr;
    }
    
    ActivityLogger {
        id: activityLogger
    }
    
    property var networkScanner
    property var scanResults
    
    onNetworkScannerChanged: {
        if (networkScanner) {
            networkScanner.hostDiscovered.connect(function(ip, hostname, mac, ports) {
                if (scanResults) {
                    scanResults.addResult(ip, hostname, mac, ports)
                }
                activityLogger.logActivity("discovery", "Host Discovered", ip, "success")
            })
            networkScanner.scanCompleted.connect(function() {
                scanHistory.append({
                                       target: root.currentScanTarget,
                                       time: "Just now",
                                       hosts: networkScanner.hostsFound,
                                       status: "completed"
                                   })
                activityLogger.logActivity("discovery", "Network Discovery", root.currentScanTarget, "success")
            })
        }
    }
    
    ListModel {
        id: scanHistory
        ListElement { target: "10.0.0.0/16"; time: "1 day ago"; hosts: 156; status: "completed" }
        ListElement { target: "172.16.0.0/12"; time: "3 days ago"; hosts: 89; status: "completed" }
    }
    
    ColumnLayout {
        x: 24
        y: 24
        width: root.width-48
        spacing: 24
        anchors.margins: 24
        
        // Header
        RowLayout {
            id: networkdiscovery_header
            Layout.fillWidth: true
            
            Column {
                Layout.fillWidth: true
                spacing: 4
                
                Text {
                    text: "Network Discovery"
                    color: "#f8fafc"
                    font.pixelSize: 32
                    font.bold: true
                }
                
                Text {
                    text: "Discover and enumerate hosts across your network"
                    color: "#64748b"
                    font.pixelSize: 16
                }
            }
        }
        
        // Tabs
        Rectangle {
            Layout.fillWidth: true
            // Layout.preferredHeight: 600
            Layout.preferredHeight: root.height - networkdiscovery_header.height - 70
            color: "transparent"
            
            Column {
                anchors.fill: parent
                spacing: 24
                
                // Tab Bar
                Row {
                    width: parent.width
                    height: 40
                    
                    property int currentTab: 0
                    
                    Repeater {
                        model: ["Network Scan", "Scan Results", "Scan History"]
                        
                        Rectangle {
                            width: parent.width / 3
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
                        case 0: return scanTabComponent
                        case 1: return resultsTabComponent
                        case 2: return historyTabComponent
                        default: return scanTabComponent
                        }
                    }
                }
            }
        }
    }
    
    // Scan Tab Component
    Component {
        id: scanTabComponent
        
        RowLayout {
            spacing: 24
            
            // Scan Configuration
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "qrc:/svgs/search-white.svg"
                title: "Scan Configuration"
                description: "Configure your network discovery parameters"
                
                Column {
                    anchors.fill: parent
                    spacing: 16
                    
                    Column {
                        width: parent.width
                        spacing: 8
                        
                        Text {
                            text: "Target Network"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Input {
                            id: targetNetworkInput
                            width: parent.width
                            placeholderText: "192.168.1.0/24 or 127.0.0.1"
                            text: "127.0.0.1"
                        }
                    }
                    
                    Column {
                        width: parent.width
                        spacing: 8
                        
                        Text {
                            text: "Port Range"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Input {
                            id: portRangeInput
                            width: parent.width
                            placeholderText: "1-100, 80, 443 or 22,80,443"
                            text: "22,80,443,3389,5900"
                        }
                    }
                    
                    Column {
                        width: parent.width
                        spacing: 8
                        
                        Text {
                            text: "Threads"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Input {
                            id: threadsInput
                            width: parent.width
                            placeholderText: "50"
                            text: "50"
                        }
                    }
                    
                    Row {
                        width: parent.width
                        spacing: 8
                        
                        Button {
                            width: parent.width - 48
                            text: networkScanner.isScanning ? "Scanning..." : "Start Scan"
                            icon: networkScanner.isScanning ? "qrc:/svgs/network_discovery/pause.svg" : "qrc:/svgs/network_discovery/play.svg"
                            variant: "cyber"
                            enabled: !networkScanner.isScanning
                            onClicked: {
                                if (networkScanner.isScanning) {
                                    networkScanner.stopScan()
                                } else {
                                    // Capture user inputs
                                    root.currentScanTarget = targetNetworkInput.text
                                    root.currentScanPorts = portRangeInput.text
                                    root.currentScanThreads = parseInt(threadsInput.text) || 50
                                    
                                    // Clear previous results
                                    scanResults.clear()
                                    
                                    // Log scan start
                                    activityLogger.logActivity("discovery", "Network Scan Started", root.currentScanTarget, "started")
                                    
                                    // Start scan with user inputs
                                    networkScanner.startScan(
                                                root.currentScanTarget,
                                                root.currentScanPorts,
                                                root.currentScanThreads
                                                )
                                }
                            }
                        }
                        
                        Button {
                            width: 40
                            icon: "qrc:/svgs/network_discovery/rotate-ccw.svg"
                            variant: "outline"
                        }
                    }
                }
            }
            
            // Scan Progress
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "qrc:/svgs/activity.svg"
                title: "Scan Progress"
                description: "Real-time scanning status and progress"
                
                Column {
                    anchors.fill: parent
                    spacing: 16
                    
                    Column {
                        width: parent.width
                        spacing: 10
                        
                        RowLayout {
                            width: parent.width
                            
                            Text {
                                text: "Overall Progress"
                                color: "#f8fafc"
                                Layout.fillWidth: true
                                font.pixelSize: 14
                            }
                            
                            Text {
                                Layout.alignment: Qt.AlignRight
                                text: Math.round(networkScanner.progress) + "%"
                                color: "#f8fafc"
                                font.pixelSize: 14
                            }
                        }
                        
                        Progress {
                            width: parent.width
                            value: networkScanner.progress
                        }
                    }
                    
                    Row {
                        width: parent.width
                        spacing: 16
                        
                        Rectangle {
                            width: (parent.width - 16) / 2
                            height: 80
                            radius: 8
                            color: "#1e293b90"
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: networkScanner.hostsFound.toString()
                                    color: "#3b82f6"
                                    font.pixelSize: 32
                                    font.bold: true
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Hosts Found"
                                    color: "#64748b"
                                    font.pixelSize: 12
                                }
                            }
                        }
                        
                        Rectangle {
                            width: (parent.width - 16) / 2
                            height: 80
                            radius: 8
                            color: "#1e293b90"
                            // opacity: 0.8
                            
                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: networkScanner.portsFound.toString()
                                    color: "#06b6d4"
                                    font.pixelSize: 32
                                    font.bold: true
                                }
                                
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Open Ports"
                                    color: "#64748b"
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                    
                    Column {
                        width: parent.width
                        visible: networkScanner.isScanning
                        spacing: 8
                        
                        Text {
                            text: "Current Status:"
                            color: "#f8fafc"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        
                        Row {
                            spacing: 8
                            
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: "#3b82f6"
                                
                                anchors.verticalCenter: statusText_.verticalCenter

                                SequentialAnimation on opacity {
                                    running: networkScanner.isScanning
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 500 }
                                    NumberAnimation { to: 1.0; duration: 500 }
                                }
                            }
                            
                            Text {
                                id: statusText_
                                text: "Scanning " + root.currentScanTarget + " (" + Math.round(networkScanner.progress) + "% complete)"
                                color: "#f8fafc"
                                font.pixelSize: 14
                            }
                        }
                        
                        Text {
                            text: "Threads: " + root.currentScanThreads + " | Ports: " + root.currentScanPorts
                            color: "#64748b"
                            font.pixelSize: 12
                        }
                        
                        Text {
                            text: "Currently scanning: " + (networkScanner.currentIP || "Initializing...")
                            color: "#3b82f6"
                            font.pixelSize: 12
                            font.family: "monospace"
                            visible: networkScanner.isScanning
                        }
                    }
                }
            }
        }
    }
    
    // Results Tab Component
    Component {
        id: resultsTabComponent
        
        Card {
            title: "Discovered Hosts"
            icon: "qrc:/svgs/network_discovery/server.svg"
            anchors.fill: parent
            description: networkScanner.hostsFound + " hosts discovered in the last scan"
            
            ScrollView {
                anchors.fill: parent
                
                Column {
                    width: parent.width
                    spacing: 16
                    
                    Repeater {
                        model: scanResults
                        
                        Rectangle {

                            id: hostItem

                            width: parent.width
                            height: 100
                            radius: 8
                            color: "#0f1419"
                            border.color: "#1e2328"
                            border.width: 1

                            property var cachedPorts: model.ports || []  // ✅ Safe

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                RowLayout {
                                    width: parent.width

                                    Row {
                                        spacing: 12

                                        Rectangle {
                                            width: 32
                                            height: 32
                                            radius: 8
                                            color: "transparent"//"#3b82f600"
                                            border.width: 1
                                            border.color: "#1e2328"
                                            // opacity: 0.1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "🖥️"
                                                font.pixelSize: 16
                                            }
                                        }

                                        Column {
                                            spacing: 4

                                            Text {
                                                text: (typeof model !== 'undefined' && model.ip) ? model.ip : ""
                                                color: "#f8fafc"
                                                font.pixelSize: 14
                                                font.weight: Font.Medium
                                            }

                                            Text {
                                                text: (typeof model !== 'undefined' && model.hostname) ? model.hostname : ""
                                                color: "#64748b"
                                                font.pixelSize: 12
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Badge {
                                        text: "✅ " + ((typeof model !== 'undefined' && model.status) ? model.status : "online")
                                        variant: "success"
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: 32

                                    Column {
                                        spacing: 4

                                        Text {
                                            text: "MAC Address: " + ((typeof model !== 'undefined' && model.mac) ? model.mac : "Unknown")
                                            color: "#64748b"
                                            font.pixelSize: 12
                                            font.family: "monospace"
                                        }
                                    }

                                    Row {
                                        spacing: 4

                                        Text {
                                            id: open_port_text
                                            text: "Open Ports:"
                                            color: "#64748b"
                                            font.pixelSize: 12
                                        }

                                        Flow {
                                            width: 200
                                            spacing: 4
                                            anchors.verticalCenter: open_port_text.verticalCenter

                                            // Display port badges
                                            Repeater {
                                                id: portRepeater
                                                // model: model.ports//[22, 34]
                                                model : toArray(hostItem.cachedPorts)

                                                Badge {
                                                    text: modelData.toString()  // modelData = individual port number
                                                    variant: "outline"
                                                }
                                            }

                                            // Show "No open ports" if no ports
                                            Text {
                                                visible: portRepeater.count === 0
                                                text: "No open ports"
                                                color: "#64748b"
                                                font.pixelSize: 12
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // History Tab Component
    Component {
        id: historyTabComponent
        
        Card {
            title: "Scan History"
            icon: "qrc:/svgs/clock-white.svg"
            description: "Previous network discovery scans"
            
            ScrollView {
                anchors.fill: parent
                
                Column {
                    width: parent.width
                    spacing: 16
                    
                    Repeater {
                        model: scanHistory
                        
                        Rectangle {
                            width: parent.width
                            height: 60
                            radius: 8
                            color: "#1e293b90"
                            opacity: 0.8

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12

                                Text {
                                    text: "🌐"
                                    font.pixelSize: 16
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: model.target
                                        color: "#f8fafc"
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    Text {
                                        text: model.time
                                        color: "#64748b"
                                        font.pixelSize: 12
                                    }
                                }

                                Text {
                                    text: model.hosts + " hosts"
                                    color: "#64748b"
                                    font.pixelSize: 12
                                }

                                Badge {
                                    text: model.status
                                    variant: "success"
                                }

                                Button {
                                    text: "View"
                                    variant: "ghost"
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    Timer {
        id: progressTimer
        interval: 500
        repeat: true
        onTriggered: {
            root.progress += 10
            if (root.progress >= 100) {
                root.progress = 100
                root.isScanning = false
                stop()
            }
        }
    }
}
