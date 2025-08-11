import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    id: window
    width: 1400
    height: 900
    visible: true
    title: "NetSecOps - Network Security Dashboard"
    
    // Dark cyber theme colors
    color: "#0a0e1a"
    
    property string currentPage: "dashboard"
    
    MainLayout {
        anchors.fill: parent
        currentPage: window.currentPage
        onPageChanged: function(page) { window.currentPage = page }
    }
}