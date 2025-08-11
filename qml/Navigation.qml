import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#0f1419"
    border.color: "#1e2328"
    border.width: 1
    
    property string currentPage: "dashboard"
    signal pageSelected(string page)
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 32
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            Rectangle {
                width: 40
                height: 40
                radius: 8
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3b82f6" }
                    GradientStop { position: 1.0; color: "#06b6d4" }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "🛡️"
                    font.pixelSize: 20
                }
            }
            
            Column {
                Layout.fillWidth: true
                
                Text {
                    text: "NetSecOps"
                    color: "#f8fafc"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                Text {
                    text: "Network Security Dashboard"
                    color: "#64748b"
                    font.pixelSize: 12
                }
            }
        }
        
        // Navigation Items
        Column {
            Layout.fillWidth: true
            spacing: 8
            
            NavItem {
                width: parent.width
                text: "Dashboard"
                icon: "qrc:/svgs/activity.svg"
                page: "dashboard"
                active: root.currentPage === "dashboard"
                onClicked: function() { root.pageSelected("dashboard") }
            }
            
            NavItem {
                width: parent.width
                text: "Discovery"
                icon: "qrc:/svgs/search-white.svg"
                page: "discovery"
                active: root.currentPage === "discovery"
                onClicked: function() { root.pageSelected("discovery") }
            }
            
            NavItem {
                width: parent.width
                text: "Network Map"
                icon: "qrc:/svgs/lucide-map-white.svg"
                page: "map"
                active: root.currentPage === "map"
                onClicked: function() { root.pageSelected("map") }
            }
            
            NavItem {
                width: parent.width
                text: "Operations"
                icon: "qrc:/svgs/terminal-white.svg"
                page: "operations"
                active: root.currentPage === "operations"
                onClicked: function() { root.pageSelected("operations") }
            }
            
            NavItem {
                width: parent.width
                text: "Credentials"
                icon: "qrc:/svgs/shield-white.svg"
                page: "credentials"
                active: root.currentPage === "credentials"
                onClicked: function() { root.pageSelected("credentials") }
            }
            
            NavItem {
                width: parent.width
                text: "Activity"
                icon: "qrc:/svgs/folder-clock.svg"
                page: "activity"
                active: root.currentPage === "activity"
                onClicked: function() { root.pageSelected("activity") }
            }
        }
        
        Item { Layout.fillHeight: true }
    }
    
    component NavItem: Rectangle {
        property string text: ""
        property string icon: ""
        property string page: ""
        property bool active: false
        signal clicked()
        
        height: 40
        radius: 6
        color: active ? "#3b82f6" : (mouseArea.containsMouse ? "#1e293b" : "transparent")
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            
            Image {
                source: parent.parent.icon
                Layout.alignment: Qt.AlignVCenter
                opacity: parent.parent.active ? 1 : 0.4
            }
            
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: parent.parent.text
                color: parent.parent.active ? "#ffffff" : "#64748b"
                font.bold: parent.parent.active ? true : false
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: function() { parent.clicked() }
        }
    }
}
