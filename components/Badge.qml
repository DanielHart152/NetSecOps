import QtQuick 2.15

Rectangle {
    id: root
    
    property string text: ""
    property string variant: "default" // default, success, warning, destructive, outline
    
    implicitWidth: badgeText.implicitWidth + 16
    implicitHeight: 24
    radius: 12
    
    color: {
        switch(variant) {
            case "success": return "#16a34a"
            case "warning": return "#eab308"
            case "destructive": return "#dc2626"
            case "outline": return "transparent"
            default: return "#475569"
        }
    }
    
    border.color: variant === "outline" ? "#475569" : "transparent"
    border.width: variant === "outline" ? 1 : 0
    
    Text {
        id: badgeText
        anchors.centerIn: parent
        text: root.text
        color: {
            switch(root.variant) {
                case "success": return "#ffffff"
                case "warning": return "#0a0e1a"
                case "destructive": return "#ffffff"
                case "outline": return "#f8fafc"
                default: return "#ffffff"
            }
        }
        font.pixelSize: 12
        font.weight: Font.Medium
    }
}