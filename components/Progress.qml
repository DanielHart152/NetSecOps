import QtQuick 2.15

Rectangle {
    id: root
    
    property real value: 0 // 0-100
    property real maximum: 100
    
    implicitHeight: 8
    radius: 4
    color: "#1e293b"
    
    Rectangle {
        height: parent.height
        width: parent.width * (root.value / root.maximum)
        radius: parent.radius
        color: "#3b82f6"
        
        Behavior on width {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }
}