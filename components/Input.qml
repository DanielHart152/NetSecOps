import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    property alias text: textField.text
    property alias placeholderText: textField.placeholderText
    
    implicitHeight: 40
    
    TextField {
        id: textField
        anchors.fill: parent
    
        background: Rectangle {
            radius: 6
            color: "#1e293b"
            border.color: textField.activeFocus ? "#3b82f6" : "#475569"
            border.width: 1
        }
        
        color: "#f8fafc"
        selectionColor: "#3b82f6"
        selectedTextColor: "#ffffff"
        placeholderTextColor: "#64748b"
        font.pixelSize: 14
        
        leftPadding: 12
        rightPadding: 12
    }
}