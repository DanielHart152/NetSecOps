import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    
    property string variant: "default"
    property string icon: ""
    property string text: ""
    property bool enabled: true
    signal clicked()
    
    implicitWidth: Math.max(80, contentRow.implicitWidth + 32)
    implicitHeight: 40
    
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: {
            if (!root.enabled) return "#1e293b"
            if (mouseArea.pressed) {
                switch(root.variant) {
                    case "cyber": return "#1d4ed8"
                    case "outline": return "#1e293b"
                    case "ghost": return "#1e293b"
                    default: return "#1e293b"
                }
            }
            if (mouseArea.containsMouse) {
                switch(root.variant) {
                    case "cyber": return "#2563eb"
                    case "outline": return "#334155"
                    case "ghost": return "#334155"
                    default: return "#334155"
                }
            }
            switch(root.variant) {
                case "cyber": return "#3b82f6"
                case "outline": return "transparent"
                case "ghost": return "transparent"
                default: return "#475569"
            }
        }
        border.color: root.variant === "outline" ? "#475569" : "transparent"
        border.width: root.variant === "outline" ? 1 : 0
    }
    
    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8
        
        Image {
            visible: root.icon !== ""
            source: root.icon
            opacity: root.enabled ? 1 : 0.4
            anchors.verticalCenter: parent.verticalCenter
        }
        
        Text {
            visible: root.text !== ""
            text: root.text
            font.pixelSize: 14
            font.weight: Font.Medium
            color: root.enabled ? (root.variant === "cyber" ? "#ffffff" : "#f8fafc") : "#64748b"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
