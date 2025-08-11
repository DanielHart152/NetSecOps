import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    
    property string title: ""
    property string icon: ""
    property string description: ""
    default property alias content: contentArea.data
    
    color: "#0f1419"
    border.color: "#1e2328"
    border.width: 1
    radius: 12
    
    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16
        
        // Header
        Column {
            width: parent.width
            visible: title !== "" || description !== ""
            spacing: 4
            
            Row{
                spacing: 8

                Image {
                    visible: root.icon !== ""
                    source: root.icon
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    visible: title !== ""
                    text: title
                    color: "#f8fafc"
                    font.pixelSize: 18
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
            Text {
                visible: description !== ""
                text: description
                color: "#64748b"
                font.pixelSize: 14
            }
        }
        
        // Content Area
        Item {
            id: contentArea
            width: parent.width
            height: parent.height - (title !== "" || description !== "" ? 60 : 0)
        }
    }
}
