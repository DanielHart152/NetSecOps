import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NetSecOps 1.0
import "../components"

ScrollView {
    id: root
    
    ActivityLogger {
        id: activityLogger
    }
    
    // property var networkScanner
    property var networkMapper
    property var arpModel
    property var profiledHosts
    property var topologyNodes
    
    /*
    // Connect to NetworkScanner for discovered hosts
    onNetworkScannerChanged: {
        console.log("NetworkMap: networkScanner changed:", networkScanner)
        if (networkScanner && profiledHosts) {
            console.log("NetworkMap: Connecting signals to networkScanner, profiledHosts count:", profiledHosts.count)
            try {
                networkScanner.hostDiscovered.connect(function(ip, hostname, mac, ports) {
                    console.log("NetworkMap: Host discovered signal received:", ip, hostname, mac, ports)
                    // Add to profiled hosts with basic info
                    profiledHosts.append({
                                             ip: ip,
                                             os: "Unknown",
                                             services: ports ? ports.join(",") : "No services",
                                             vendor: "Unknown",
                                             deviceType: "computer"
                                         })
                    console.log("NetworkMap: Added host to profiledHosts, count now:", profiledHosts.count)
                    updateTopology()
                    redrawTimer.restart()
                })
                console.log("NetworkMap: Successfully connected hostDiscovered signal")
            } catch(e) {
                console.log("NetworkMap: Error connecting signal:", e)
            }
        } else {
            console.log("NetworkMap: Missing networkScanner or profiledHosts:", !!networkScanner, !!profiledHosts)
        }
    }
    */
    
    onNetworkMapperChanged: {
        // if (networkMapper && profiledHosts && arpModel) {
            console.log("NetworkMap: Connecting signals to networkMapper")
            networkMapper.hostProfiled.connect(function(ip, os, services, vendor) {
                console.log("NetworkMap: Host profiled:", ip, os, services, vendor)
                if (profiledHosts) {
                    profiledHosts.append({
                                             ip: ip,
                                             os: os,
                                             services: services,
                                             vendor: vendor,
                                             deviceType: "computer"
                                         })
                    updateTopology()
                    redrawTimer.restart()
                }
            })
            networkMapper.arpTableUpdated.connect(function(entries) {
                console.log("NetworkMap: ARP table updated with", entries.length, "entries")
                if (arpModel) {
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
            })
        // }
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
                                         iconSource: "qrc:/svgs/types/network.svg",
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
            var iconSource = "qrc:/svgs/types/monitor.svg"
            var deviceType = host.deviceType || "computer"
            
            switch(deviceType) {
            case "router": iconSource = "qrc:/svgs/types/network.svg"; break;
            case "switch": iconSource = "qrc:/svgs/types/switch-camera.svg"; break;
            case "printer": iconSource = "qrc:/svgs/types/printer.svg"; break;
            case "phone": iconSource = "qrc:/svgs/types/smartphone.svg"; break;
            case "audio": iconSource = "qrc:/svgs/types/volume-1.svg"; break;
            case "iot": iconSource = "qrc:/svgs/types/monitor-dot.svg"; break;
            case "camera": iconSource = "qrc:/svgs/types/camera.svg"; break;
            case "server": iconSource = "qrc:/svgs/types/server.svg"; break;
            case "workstation": iconSource = "qrc:/svgs/types/monitor.svg"; break;
            case "mac": iconSource = "qrc:/svgs/types/app-window-mac.svg"; break;
            case "mobile": iconSource = "qrc:/svgs/types/smartphone.svg"; break;
            default: iconSource = "qrc:/svgs/types/monitor.svg";
            }
            
            topologyNodes.append({
                                     ip: host.ip,
                                     name: host.ip,
                                     os: host.os,
                                     iconSource: iconSource,
                                     x: Math.max(0.1, Math.min(0.9, x)),
                                     y: Math.max(0.1, Math.min(0.9, y))
                                 })
            
            hostCount++
        }
    }
    
    ColumnLayout {
        // anchors.fill: parent
        width: root.width-48
        x: 24
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
                    text: (networkMapper && networkMapper.isMapping) ? "Mapping..." : "Quick Scan"
                    variant: "cyber"
                    enabled:  networkMapper && !networkMapper.isMapping
                    onClicked: {
                        /*if (networkScanner && !networkScanner.isScanning) {
                            console.log("NetworkMap: Starting quick scan, clearing models")
                            if (profiledHosts) {
                                console.log("NetworkMap: Clearing profiledHosts, current count:", profiledHosts.count)
                                profiledHosts.clear()
                            }
                            if (topologyNodes) topologyNodes.clear()
                            console.log("NetworkMap: Starting networkScanner.startScan")
                            networkScanner.startScan("192.168.130.0/24", "22,80,443,3389,5900", 50)
                            
                            // Test: Add a dummy host to see if UI updates
                            console.log("NetworkMap: Adding test host to verify UI works")
                            profiledHosts.append({
                                ip: "192.168.130.999",
                                os: "Test",
                                services: "Test Service",
                                vendor: "Test Vendor",
                                deviceType: "computer"
                            })
                            console.log("NetworkMap: Test host added, profiledHosts count:", profiledHosts.count)
                            updateTopology()
                        }*/
                        if (networkMapper && !networkMapper.isMapping) {
                            if (profiledHosts) profiledHosts.clear()
                            if (topologyNodes) topologyNodes.clear()
                            activityLogger.logActivity("mapping", "Quick Network Mapping", "ARP Table", "started")
                            networkMapper.startQuickMapping() // Arp table only
                        }
                    }
                }
                
                Button {
                    icon: "qrc:/svgs/search-white.svg"
                    text: (networkMapper && networkMapper.isMapping) ? "Mapping..." : "Full Scan"
                    variant: "outline"
                    enabled: networkMapper && !networkMapper.isMapping
                    onClicked: {
                        if (networkMapper && !networkMapper.isMapping) {
                            if (profiledHosts) profiledHosts.clear()
                            if (topologyNodes) topologyNodes.clear()
                            activityLogger.logActivity("mapping", "Full Network Mapping", "192.168.130.0/24", "started")
                            networkMapper.startFullMapping("192.168.130.0/24") // Full subnet
                        }
                    }
                }
                
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
            }
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            
            // Network Topology Visualization
            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: 600
                icon: "qrc:/svgs/lucide-map-white.svg"
                title: "Network Topology"
                description: "Interactive map of discovered network devices"

                Rectangle {
                    anchors.fill: parent
                    color: "#0a0e1a"
                    radius: 8
                    border.color: "#1e2328"
                    border.width: 1
                    clip: true

                    Flickable {
                        id: topologyFlickable
                        anchors.fill: parent
                        contentWidth: topologyContent.width * topologyContent.scale
                        contentHeight: topologyContent.height * topologyContent.scale
                        boundsBehavior: Flickable.StopAtBounds

                        Item {
                            id: topologyContent
                            width: 2000
                            height: 2000
                            scale: 1.0
                            transformOrigin: Item.TopLeft

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
                                model: topologyNodes || []

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

                                Image {
                                    anchors.centerIn: parent
                                    source: model.iconSource
                                    width: 20
                                    height: 20
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
                        }

                        // Mouse wheel zoom
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function(wheel) {
                                var scaleFactor = wheel.angleDelta.y > 0 ? 1.1 : 0.9
                                var newScale = topologyContent.scale * scaleFactor
                                newScale = Math.max(0.5, Math.min(3.0, newScale))
                                topologyContent.scale = newScale
                                topologyFlickable.contentWidth = topologyContent.width * newScale
                                topologyFlickable.contentHeight = topologyContent.height * newScale
                            }
                        }
                    }

                // Zoom controls
                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    spacing: 4
                    z: 10
                    
                    Button {
                        width: 32
                        height: 32
                        icon: "qrc:/svgs/credential/plus.svg"
                        variant: "outline"
                        onClicked: {
                            var newScale = Math.min(3.0, topologyContent.scale * 1.2)
                            topologyContent.scale = newScale
                            topologyFlickable.contentWidth = topologyContent.width * newScale
                            topologyFlickable.contentHeight = topologyContent.height * newScale
                        }
                    }
                    
                    Button {
                        width: 32
                        height: 32
                        icon: "qrc:/svgs/network_map/minus.svg"
                        variant: "outline"
                        onClicked: {
                            var newScale = Math.max(0.5, topologyContent.scale * 0.8)
                            topologyContent.scale = newScale
                            topologyFlickable.contentWidth = topologyContent.width * newScale
                            topologyFlickable.contentHeight = topologyContent.height * newScale
                        }
                    }
                    
                    Button {
                        width: 32
                        height: 32
                        icon: "qrc:/svgs/network_map/house.svg"
                        variant: "outline"
                        onClicked: {
                            topologyContent.scale = 1.0
                            topologyFlickable.contentX = 0
                            topologyFlickable.contentY = 0
                            topologyFlickable.contentWidth = topologyContent.width
                            topologyFlickable.contentHeight = topologyContent.height
                        }
                    }
                }
            }
            }

            // Device List and Stats
            Column {
                Layout.alignment: Qt.AlignRight
                Layout.fillHeight: true
                Layout.preferredWidth: 400
                spacing: 14
                
                Card {
                    width: parent.width
                    height: 400
                    icon: "qrc:/svgs/network-white.svg"
                    title: "Network Devices"
                    description: (profiledHosts ? profiledHosts.count : 0) + " devices discovered"

                    ScrollView {
                        anchors.fill: parent

                        Column {
                            width: parent.width
                            spacing: 12

                            Repeater {
                                model: profiledHosts || []

                                Rectangle {
                                    width: parent.width
                                    height: 40
                                    radius: 6
                                    color: deviceMouseArea.containsMouse ? "#1e293b" : "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        anchors.leftMargin: 8
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

                                        // Button {
                                        //     Layout.alignment: Qt.AlignRight
                                        //     width: 24
                                        //     height: 24
                                        //     // text: "👁️"
                                        //     icon: "qrc:/svgs/network_map/eye.svg"
                                        //     variant: "ghost"
                                        // }
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
                    width: parent.width
                    height: root.height - 510
                    icon: "qrc:/svgs/network_map/stretch-horizontal.svg"
                    title: "ARP Table"
                    description: "IP to MAC mappings"
                    
                    ScrollView {
                        anchors.fill: parent
                        
                        Column {
                            width: parent.width
                            spacing: 4
                            
                            Repeater {
                                model: arpModel || []
                                
                                Rectangle {
                                    width: parent.width
                                    height: 24
                                    radius: 2
                                    color: "#1e293b50"
                                    opacity: 1
                                    
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
