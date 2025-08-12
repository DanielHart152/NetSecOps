cmake_minimum_required(VERSION 3.16)

project(NetSecOps VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickControls2 Sql Network)

qt_standard_project_setup()

# Set Qt policies
qt_policy(SET QTP0001 NEW)
qt_policy(SET QTP0004 NEW)

set(SOURCES
    main.cpp
    src/ActivityLogger.cpp
    src/CredentialManager.cpp
    src/NetworkMapper.cpp
    src/NetworkScanner.cpp
    src/RemoteExecutor.cpp
    src/ScanResultsModel.cpp
)

set(HEADERS
    src/ActivityLogger.h
    src/CredentialManager.h
    src/NetworkMapper.h
    src/NetworkScanner.h
    src/RemoteExecutor.h
    src/ScanResultsModel.h
)

qt_add_executable(NetSecOps ${SOURCES} ${HEADERS})

qt_add_resources(NetSecOps "qml_resources"
    PREFIX "/"
    BASE .
    FILES
        qml/main.qml
        qml/MainLayout.qml
        qml/Navigation.qml
        pages/Activity.qml
        pages/Credentials.qml
        pages/Dashboard.qml
        pages/NetworkDiscovery.qml
        pages/NetworkMap.qml
        pages/Operations.qml
        components/Badge.qml
        components/Button.qml
        components/Card.qml
        components/Input.qml
        components/Progress.qml
        svgs/circle-check-big.svg
        svgs/network.svg
        svgs/triangle-alert.svg
        svgs/circle-check-big-white.svg
        svgs/clock-white.svg
        svgs/network-white.svg
        svgs/triangle-alert-white.svg
        svgs/lucide-map-white.svg
        svgs/search-white.svg
        svgs/shield-white.svg
        svgs/terminal-white.svg
        svgs/activity.svg
        svgs/folder-clock.svg
        svgs/shield-check.svg
        svgs/key.svg
        svgs/square-pen.svg
        svgs/trash-2.svg
        svgs/activity/funnel.svg
        svgs/dashboard/zap.svg
        svgs/dashboard/search-code.svg
        svgs/network_discovery/pause.svg
        svgs/network_discovery/play.svg
        svgs/network_discovery/rotate-ccw.svg
        svgs/network_discovery/server.svg
        svgs/credential/plus.svg
        svgs/operation/file-text.svg
        svgs/operation/download.svg
        svgs/operation/upload.svg
        svgs/operation/send-horizontal.svg
        svgs/operation/square-x.svg
        svgs/network_map/file-code-2.svg
        svgs/network_map/file-json.svg
        svgs/network_map/sheet.svg
        svgs/network_map/stretch-horizontal.svg
        svgs/network_map/eye.svg
        svgs/network_map/house.svg
        svgs/network_map/minus.svg
        svgs/network_map/map.svg
        svgs/types/app-window.svg
        svgs/types/app-window-mac.svg
        svgs/types/camera.svg
        svgs/types/monitor.svg
        svgs/types/monitor-dot.svg
        svgs/types/network.svg
        svgs/types/printer.svg
        svgs/types/server.svg
        svgs/types/smartphone.svg
        svgs/types/switch-camera.svg
        svgs/types/volume-1.svg
        svgs/activity/square-check-big.svg
)

target_link_libraries(NetSecOps PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
    Qt6::Network
)

# Register C++ types with QML
target_compile_definitions(NetSecOps PRIVATE
    QT_QML_DEBUG
)

# Platform-specific configurations
if(MSVC)
    target_compile_options(NetSecOps PRIVATE /Zc:__cplusplus)
endif()

if(APPLE)
    set_target_properties(NetSecOps PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_GUI_IDENTIFIER com.netsecops.app
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
        MACOSX_BUNDLE_BUNDLE_NAME "NetSecOps"
    )
endif()