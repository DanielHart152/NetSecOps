import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../components"

ScrollView {
    id: root
    
    Flickable {
        contentWidth: width
        contentHeight: mainColumn.height
        
        Column {
            id: mainColumn
            width: parent.width
            spacing: 24
            topPadding: 24
            leftPadding: 24
            rightPadding: 24
            bottomPadding: 24
            
            // Header
            Item {
                width: parent.width - 48
                height: 80
                
                Column {
                    width: parent.width - 300
                    spacing: 4
                    
                    Text {
                        text: "Network Security Dashboard"
                        color: "#f8fafc"
                        font.pixelSize: 32
                        font.bold: true
                    }
                    
                    Text {
                        text: "Monitor and manage your network security operations"
                        color: "#64748b"
                        font.pixelSize: 16
                    }
                }
                
                Row {
                    spacing: 12
                    x: parent.width - width
                    
                    Button {
                        text: "Quick Scan"
                        icon: "qrc:/svgs/dashboard/zap.svg"
                        variant: "cyber"
                    }
                    
                    Button {
                        text: "Deep Scan"
                        icon: "qrc:/svgs/search-white.svg"
                        variant: "cyber"
                    }
                }
            }
            
            // Stats Grid
            Grid {
                width: parent.width - 48
                columns: 4
                spacing: 24
                
                Repeater {
                    model: [
                        {title: "Active Hosts", value: "247", icon: "🖥️", color: "#3b82f6"},
                        {title: "Total Networks", value: "12", icon: "🌐", color: "#06b6d4"},
                        {title: "Open Ports", value: "1,342", icon: "📡", color: "#16a34a"},
                        {title: "Vulnerabilities", value: "18", icon: "⚠️", color: "#eab308"}
                    ]
                    
                    Card {
                        width: (parent.width - 72) / 4
                        height: 120
                        
                        Column {
                            anchors.fill: parent
                            spacing: 8
                            
                            Row {
                                width: parent.width
                                
                                Text {
                                    width: parent.width - 24
                                    text: modelData.title
                                    color: "#64748b"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                                
                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 16
                                    color: modelData.color
                                }
                            }
                            
                            Text {
                                text: modelData.value
                                color: "#f8fafc"
                                font.pixelSize: 32
                                font.bold: true
                            }
                            
                            Rectangle {
                                width: parent.width
                                height: 4
                                radius: 2
                                color: modelData.color
                                opacity: 0.2
                            }
                        }
                    }
                }
            }
            
            // Activity Section
            Row {
                width: parent.width - 48
                spacing: 24
                
                // Recent Scans
                Card {
                    width: (parent.width - 24) / 2
                    height: 400
                    icon: "qrc:/svgs/activity.svg"
                    title: "Recent Scans"
                    description: "Latest network discovery and scanning activities"
                    
                    Column {
                        anchors.fill: parent
                        spacing: 16
                        
                        Repeater {
                            model: [
                                {target: "192.168.1.0/24", status: "completed", time: "2 minutes ago", hosts: 23},
                                {target: "10.0.0.0/16", status: "running", time: "5 minutes ago", hosts: 156},
                                {target: "172.16.0.0/12", status: "completed", time: "15 minutes ago", hosts: 89},
                                {target: "179.18.0.0/12", status: "failed", time: "16 minutes ago", hosts: 89}
                            ]
                            
                            Rectangle {
                                width: parent.width
                                height: 60
                                radius: 8
                                color: "#1e293b"
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    anchors.leftMargin: 12
                                    spacing: 12
                                    
                                    Image {
                                        source: modelData.status === "completed" ? "qrc:/svgs/circle-check-big-white.svg" :
                                              modelData.status === "running" ? "qrc:/svgs/clock-white" : "qrc:/svgs/triangle-alert-white.svg"
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Layout.alignment: Qt.AlignVCenter
                                        
                                        Text {
                                            text: modelData.target
                                            color: "#f8fafc"
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                        }
                                        
                                        Text {
                                            text: modelData.time
                                            color: "#64748b"
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Column {
                                        spacing: 4
                                        Layout.fillHeight: true
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                        
                                        Text {
                                            anchors.right: dashboard_history_badge.right
                                            anchors.rightMargin: 3
                                            text: modelData.hosts + " hosts"
                                            color: "#64748b"
                                            font.pixelSize: 12
                                        }
                                        
                                        Badge {
                                            id: dashboard_history_badge
                                            text: modelData.status
                                            variant: modelData.status === "completed" ? "success" : 
                                                    modelData.status === "running" ? "warning" : "destructive"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Security Status
                Card {
                    width: (parent.width - 24) / 2
                    height: 400
                    icon: "qrc:/svgs/shield-white.svg"
                    title: "Security Status"
                    description: "Current security posture and alerts"
                    
                    Column {
                        anchors.fill: parent
                        spacing: 16
                        
                        Repeater {
                            model: [
                                {title: "Network Secured", desc: "No critical vulnerabilities", badge: "Good", color: "#16a34a", icon: "qrc:/svgs/circle-check-big.svg"},
                                {title: "18 Medium Risks", desc: "Require attention", badge: "Review", color: "#eab308", icon: "qrc:/svgs/triangle-alert.svg"},
                                {title: "Network Coverage", desc: "95% of assets mapped", badge: "Excellent", color: "#06b6d4", icon: "qrc:/svgs/network.svg"}
                            ]
                            
                            Rectangle {
                                width: parent.width
                                height: 60
                                radius: 8
                                color: Qt.rgba(
                                           Qt.color(modelData.color).r,
                                           Qt.color(modelData.color).g,
                                           Qt.color(modelData.color).b,
                                           0.1  // ← Desired opacity (0.0 = transparent, 1.0 = fully opaque)
                                       )//"#0f1419"
                                border.color: modelData.color
                                border.width: 0.5
                                
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    anchors.rightMargin: 16
                                    spacing: 12
                                    
                                    // Text {
                                    //     text: modelData.icon
                                    //     font.pixelSize: 16
                                    //     anchors.verticalCenter: parent.verticalCenter
                                    // }
                                    Image {
                                        source: modelData.icon
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    
                                    Column {
                                        width: parent.width - 100
                                        spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        Text {
                                            text: modelData.title
                                            color: "#f8fafc"
                                            font.pixelSize: 14
                                            font.bold: true
                                            font.weight: Font.Medium
                                        }
                                        
                                        Text {
                                            text: modelData.desc
                                            color: "#64748b"
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Badge {
                                        text: modelData.badge
                                        variant: index === 0 ? "success" : index === 1 ? "warning" : "default"
                                        anchors.verticalCenter: parent.verticalCenter
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
