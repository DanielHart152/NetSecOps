import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import NetSecOps 1.0
import NetSecOps 1.0

Item {
    id: root
    
    property string currentPage: "dashboard"
    signal pageChanged(string page)
    
    // Persistent models that survive page switches
    NetworkScanner {
        id: persistentNetworkScanner
    }
    
    ScanResultsModel {
        id: persistentScanResults
    }
    
    NetworkMapper {
        id: persistentNetworkMapper
    }
    
    ListModel {
        id: persistentArpModel
    }
    
    ListModel {
        id: persistentProfiledHosts
    }
    
    ListModel {
        id: persistentTopologyNodes
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Navigation Sidebar
        Navigation {
            Layout.preferredWidth: 256
            Layout.fillHeight: true
            currentPage: root.currentPage
            onPageSelected: function(page) { root.pageChanged(page) }
        }
        
        // Main Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0a0e1a"
            
            Loader {
                id: pageLoader
                anchors.fill: parent
                anchors.topMargin: 24
                anchors.bottomMargin: 24
                anchors.leftMargin: 0
                anchors.rightMargin: 0
                
                source: {
                    switch(root.currentPage) {
                        case "dashboard": return "../pages/Dashboard.qml"
                        case "discovery": return "../pages/NetworkDiscovery.qml"
                        case "map": return "../pages/NetworkMap.qml"
                        case "operations": return "../pages/Operations.qml"
                        case "credentials": return "../pages/Credentials.qml"
                        case "activity": return "../pages/Activity.qml"
                        default: return "../pages/Dashboard.qml"
                    }
                }
                
                onLoaded: {
                    if (item) {
                        // Pass persistent models to loaded pages
                        if ('networkScanner' in item) {
                            item.networkScanner = persistentNetworkScanner
                        }
                        if ('scanResults' in item) {
                            item.scanResults = persistentScanResults
                        }
                        if ('networkMapper' in item) {
                            item.networkMapper = persistentNetworkMapper
                        }
                        if ('arpModel' in item) {
                            item.arpModel = persistentArpModel
                        }
                        if ('profiledHosts' in item) {
                            item.profiledHosts = persistentProfiledHosts
                        }
                        if ('topologyNodes' in item) {
                            item.topologyNodes = persistentTopologyNodes
                        }
                    }
                }
            }
        }
    }
}
