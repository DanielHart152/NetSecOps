import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NetSecOps 1.0
import "../components"

ScrollView {
    id: root
    
    property var discoveredHosts: []
    
    NetworkMapper {
        id: networkMapper
        onHostProfiled: function(ip, os, services, vendor) {
            console.log("\t-Host profiled:", ip, os, services, vendor)
        }
        onArpTableUpdated: function(entries) {
            arpModel.clear()
            for (var i = 0; i < entries.length; i++) {
                var parts = entries[i].split('|')
                if (parts.length >= 4) {
                    arpModel.append({
                                        ip: parts[0],
                                        mac: parts[1],
                                        vendor: parts[2],
                                        type: parts[3]
                                    })
                }
            }
        }
    }
    
    ListModel {
        id: arpModel
    }
    
    ListModel {
        id: profiledHosts
    }
    
    // Get discovered hosts from NetworkScanner
    NetworkScanner {
        id: discoveryScanner
        onHostDiscovered: function(ip, hostname, mac, ports) {
            if (discoveredHosts.indexOf(ip) === -1) {
                discoveredHosts.push(ip)
            }
        }
    }
    
    function updateTopology() {
        topologyNodes.clear()
        
        // Add gateway/router first (usually .1)
        var gatewayFound = false
        for (var i = 0; i < profiledHosts.count; i++) {
            var host = profiledHosts.get(i)
            if (host.ip.endsWith('.1')) {
                topologyNodes.append({
                                         ip: host.ip,
                                         name: "Gateway",
                                         os: host.os,
                                         icon: "🔀",
                                         x: 0.5,
                                         y: 0.5
                                     })
                gatewayFound = true
                break
            }
        }
        
        // Position other hosts in a circle around gateway
        var hostCount = 0
        var radius = 0.3
        
        for (var j = 0; j < profiledHosts.count; j++) {
            var host = profiledHosts.get(j)
            if (host.ip.endsWith('.1')) continue // Skip gateway
            
            var angle = (hostCount * 2 * Math.PI) / Math.max(1, profiledHosts.count - (gatewayFound ? 1 : 0))
            var x = 0.5 + radius * Math.cos(angle)
            var y = 0.5 + radius * Math.sin(angle)
            
            // Determine icon based on device type
            var icon = "🖥️"
            var deviceType = host.deviceType || "computer"
            
            switch(deviceType) {
            case "router": icon = "🔀"; break;
            case "switch": icon = "🔀"; break;
            case "printer": icon = "🖨️"; break;
            case "phone": icon = "📞"; break;
            case "audio": icon = "🔊"; break;
            case "iot": icon = "🏠"; break;
            case "camera": icon = "📹"; break;
            case "server": icon = "🖥️"; break;
            case "workstation": icon = "💻"; break;
            case "mac": icon = "🍎"; break;
            case "mobile": icon = "📱"; break;
            default: icon = "🖥️";
            }
            
            topologyNodes.append({
                                     ip: host.ip,
                                     name: host.ip,
                                     os: host.os,
                                     icon: icon,
                                     x: Math.max(0.1, Math.min(0.9, x)),
                                     y: Math.max(0.1, Math.min(0.9, y))
                                 })
            
            hostCount++
        }
    }
    
    Component.onCompleted: {
        networkMapper.hostProfiled.connect(function(ip, os, services, vendor) {
            // Get device type from the profile (would need to extend signal)
            profiledHosts.append({
                                     ip: ip,
                                     os: os,
                                     services: services,
                                     vendor: vendor,
                                     deviceType: "computer" // Default, would be passed from backend
                                 })
            updateTopology()
            redrawTimer.restart()
        })
    }
    
    ColumnLayout {
        anchors.fill: parent
        width: parent.width
        anchors.margins: 24
        spacing: 24
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Column {
                Layout.fillWidth: true
                spacing: 4
                
                Text {
                    text: "Network Map"
                    color: "#f8fafc"
                    font.pixelSize: 32
                    font.bold: true
                }
                
                Text {
                    text: "Visual representation of your network topology"
                    color: "#64748b"
                    font.pixelSize: 16
                }
            }
            
            Row {
                spacing: 8
                
                Button {
                    icon: "qrc:/svgs/dashboard/zap.svg"
                    text: networkMapper.isMapping ? "Mapping..." : "Quick Scan"
                    variant: "cyber"
                    enabled: !networkMapper.isMapping
                    onClicked: {
                        if (!networkMapper.isMapping) {
                            profiledHosts.clear()
                            networkMapper.startQuickMapping() // ARP table only
                        }
                    }
                }
                
                Button {
                    icon: "qrc:/svgs/search-white.svg"
                    text: networkMapper.isMapping ? "Mapping..." : "Full Scan"
                    variant: "outline"
                    enabled: !networkMapper.isMapping
                    onClicked: {
                        if (!networkMapper.isMapping) {
                            profiledHosts.clear()
                            networkMapper.startFullMapping("192.168.1.0/24") // Full subnet
                        }
                    }
                }
                
                // Button {
                //     text: networkMapper.isMapping ? "Mapping..." : "🎯 Discovered"
                //     variant: "secondary"
                //     enabled: !networkMapper.isMapping && root.discoveredHosts.length > 0
                //     onClicked: {
                //         if (!networkMapper.isMapping) {
                //             profiledHosts.clear()
                //             networkMapper.startMapping(root.discoveredHosts) // Previously discovered hosts
                //         }
                //     }
                // }
                
                Button {
                    text: "JSON"
                    icon: "qrc:/svgs/network_map/file-json.svg"
                    variant: "outline"
                    onClicked: {
                        networkMapper.exportMap("json", "network_map.json")
                    }
                }
                
                Button {
                    text: "CSV"
                    icon: "qrc:/svgs/network_map/sheet.svg"
                    variant: "outline"
                    onClicked: {
                        networkMapper.exportMap("csv", "network_map.csv")
                    }
                }
                
                Button {
                    text: "XML"
                    icon: "qrc:/svgs/network_map/file-code-2.svg"
                    variant: "outline"
                    onClicked: {
                        networkMapper.exportMap("xml", "network_map.xml")
                    }
                }
                // Button {
                //     text: "📥 Export"
                //     variant: "outline"
                // }
                
                // Button {
                //     text: "⚙️ Layout"
                //     variant: "outline"
                // }
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24
            
            // Left Column - Main Topology
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16
                
                // Network Topology Visualization
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "qrc:/svgs/lucide-map-white.svg"
                    title: "Network Topology"
                    description: "Interactive map of discovered network devices"

                    Rectangle {
                        anchors.fill: parent
                        color: "#0a0e1a"
                        radius: 8
                        border.color: "#1e2328"
                        border.width: 1

                        // Grid Background
                        Canvas {
                            anchors.fill: parent
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.strokeStyle = "#1e2328"
                                ctx.lineWidth = 0.5

                                for (var x = 0; x < width; x += 40) {
                                    ctx.beginPath()
                                    ctx.moveTo(x, 0)
                                    ctx.lineTo(x, height)
                                    ctx.stroke()
                                }

                                for (var y = 0; y < height; y += 40) {
                                    ctx.beginPath()
                                    ctx.moveTo(0, y)
                                    ctx.lineTo(width, y)
                                    ctx.stroke()
                                }
                            }
                        }

                        // Connection Lines - Dynamic based on topology
                        Canvas {
                            id: connectionCanvas
                            anchors.fill: parent

                            function redrawConnections() {
                                requestPaint()
                            }

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = "#3b82f6"
                                ctx.lineWidth = 2
                                ctx.globalAlpha = 0.6

                                // Find gateway position
                                var gatewayX = width * 0.5
                                var gatewayY = height * 0.5
                                var hasGateway = false

                                for (var i = 0; i < topologyNodes.count; i++) {
                                    var node = topologyNodes.get(i)
                                    if (node.ip.endsWith('.1')) {
                                        gatewayX = width * node.x
                                        gatewayY = height * node.y
                                        hasGateway = true
                                        break
                                    }
                                }

                                // Draw connections from gateway to all other nodes
                                if (hasGateway) {
                                    for (var j = 0; j < topologyNodes.count; j++) {
                                        var host = topologyNodes.get(j)
                                        if (!host.ip.endsWith('.1')) {
                                            ctx.beginPath()
                                            ctx.moveTo(gatewayX, gatewayY)
                                            ctx.lineTo(width * host.x, height * host.y)
                                            ctx.stroke()
                                        }
                                    }
                                }
                            }

                            Timer {
                                id: redrawTimer
                                interval: 500
                                onTriggered: connectionCanvas.redrawConnections()
                            }
                        }

                        // Network Nodes - Dynamic based on profiled hosts
                        Repeater {
                            model: ListModel {
                                id: topologyNodes
                            }

                            Item {
                                x: parent.width * model.x - 20
                                y: parent.height * model.y - 20
                                width: 40
                                height: 40

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 48
                                    height: 48
                                    radius: 24
                                    color: "#0f1419"
                                    border.color: nodeMouseArea.containsMouse ? "#3b82f6" : "#1e2328"
                                    border.width: 2

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.icon
                                        font.pixelSize: 20
                                    }

                                    // Status indicator
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: -2
                                        anchors.rightMargin: -2
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: "#16a34a"
                                        border.color: "#0a0e1a"
                                        border.width: 2

                                        SequentialAnimation on opacity {
                                            running: true
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.3; duration: 1000 }
                                            NumberAnimation { to: 1.0; duration: 1000 }
                                        }
                                    }
                                }

                                // Tooltip
                                Rectangle {
                                    visible: nodeMouseArea.containsMouse
                                    anchors.bottom: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 8
                                    width: tooltipText.width + 16
                                    height: tooltipText.height + 12
                                    color: "#1e293b"
                                    border.color: "#475569"
                                    border.width: 1
                                    radius: 6

                                    Column {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            text: model.name
                                            color: "#f8fafc"
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                        }

                                        Text {
                                            text: model.ip
                                            color: "#64748b"
                                            font.pixelSize: 10
                                        }

                                        Text {
                                            text: model.os || "Unknown"
                                            color: "#64748b"
                                            font.pixelSize: 10
                                        }
                                    }
                                }

                                MouseArea {
                                    id: nodeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }

                        // Scanning animation overlay
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"

                            Rectangle {
                                width: parent.width
                                height: 2
                                y: parent.height * 0.5
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: "#06b6d4" }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                                opacity: 0.3

                                SequentialAnimation on x {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { from: -parent.width; to: parent.width; duration: 3000 }
                                    PauseAnimation { duration: 2000 }
                                }
                            }
                        }
                    }
                }


                // Network Status - Compact
                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    icon: "qrc:/svgs/shield-white.svg"
                    title: "Network Status"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 16
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Text {
                                text: networkMapper.hostsProfiled.toString()
                                color: "#f8fafc"
                                font.pixelSize: 24
                                font.weight: Font.Bold
                            }
                            Text {
                                text: "Total Devices"
                                color: "#64748b"
                                font.pixelSize: 12
                            }
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Badge {
                                text: networkMapper.hostsProfiled.toString()
                                variant: "success"
                            }
                            Text {
                                text: "Online"
                                color: "#64748b"
                                font.pixelSize: 12
                            }
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            Badge {
                                text: "0"
                                variant: "destructive"
                            }
                            Text {
                                text: "Critical"
                                color: "#64748b"
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // Right Column - Device List and ARP
            ColumnLayout {
                Layout.preferredWidth: 350
                Layout.fillHeight: true
                spacing: 16
                
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: "qrc:/svgs/network-white.svg"
                    title: "Network Devices"
                    description: networkMapper.hostsProfiled + " devices profiled"

                    ScrollView {
                        anchors.fill: parent

                        Column {
                            width: parent.width
                            spacing: 12

                            Repeater {
                                model: profiledHosts

                                Rectangle {
                                    width: parent.width
                                    height: 40
                                    radius: 6
                                    color: deviceMouseArea.containsMouse ? "#1e293b" : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Text {
                                            text: model.os === "Windows" ? "💻" : model.os === "Linux" ? "🖥️" : "🔍"
                                            font.pixelSize: 16
                                            color: "#3b82f6"
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: model.ip + " (" + (model.os || "Unknown") + ")"
                                                color: "#f8fafc"
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                            }

                                            Text {
                                                text: model.services || "No services"
                                                color: "#64748b"
                                                font.pixelSize: 10
                                            }
                                        }

                                        Button {
                                            width: 24
                                            height: 24
                                            text: "👁️"
                                            variant: "ghost"
                                        }
                                    }

                                    MouseArea {
                                        id: deviceMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    icon: "qrc:/svgs/network_map/stretch-horizontal.svg"
                    title: "ARP Table"
                    description: "IP to MAC mappings"
                    
                    ScrollView {
                        anchors.fill: parent
                        
                        Column {
                            width: parent.width
                            spacing: 4
                            
                            Repeater {
                                model: arpModel
                                
                                Rectangle {
                                    width: parent.width
                                    height: 24
                                    radius: 2
                                    color: "#1e293b"
                                    opacity: 0.3
                                    
                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 8
                                        
                                        Text {
                                            text: model.ip
                                            color: "#f8fafc"
                                            font.pixelSize: 10
                                            font.family: "monospace"
                                            width: 80
                                        }
                                        
                                        Text {
                                            text: model.vendor
                                            color: "#3b82f6"
                                            font.pixelSize: 10
                                            width: 60
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
