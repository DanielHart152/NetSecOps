QT += quick quickcontrols2 network
QT += core
QT += sql

CONFIG += c++17

TARGET = NetSecOps

SOURCES += \
    main.cpp \
    src/ActivityLogger.cpp \
    src/NetworkScanner.cpp \
    src/ScanResultsModel.cpp \
    src/NetworkMapper.cpp \
    src/RemoteExecutor.cpp \
    src/CredentialManager.cpp

HEADERS += \
    src/ActivityLogger.h \
    src/NetworkScanner.h \
    src/ScanResultsModel.h \
    src/NetworkMapper.h \
    src/RemoteExecutor.h \
    src/CredentialManager.h

# Enable MOC for Qt objects
CONFIG += moc

RESOURCES += qml.qrc

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

DISTFILES += \
    svgs/network_map/eye.svg \
    svgs/network_map/file-code-2.svg \
    svgs/network_map/file-json.svg \
    svgs/network_map/house.svg \
    svgs/network_map/minus.svg \
    svgs/network_map/sheet.svg \
    svgs/network_map/stretch-horizontal.svg
