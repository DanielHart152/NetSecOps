#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QQuickStyle>
#include "src/NetworkScanner.h"
#include "src/ScanResultsModel.h"
#include "src/NetworkMapper.h"
#include "src/RemoteExecutor.h"
#include "src/CredentialManager.h"
#include "src/ActivityLogger.h"

int main(int argc, char *argv[])
{

    QGuiApplication app(argc, argv);
    
    QQuickStyle::setStyle("Basic");
    
    qRegisterMetaType<QList<int>>("QList<int>");
    qmlRegisterType<NetworkScanner>("NetSecOps", 1, 0, "NetworkScanner");
    qmlRegisterType<ScanResultsModel>("NetSecOps", 1, 0, "ScanResultsModel");
    qmlRegisterType<NetworkMapper>("NetSecOps", 1, 0, "NetworkMapper");
    qmlRegisterType<RemoteExecutor>("NetSecOps", 1, 0, "RemoteExecutor");
    qmlRegisterType<CredentialManager>("NetSecOps", 1, 0, "CredentialManager");
    qmlRegisterType<ActivityLogger>("NetSecOps", 1, 0, "ActivityLogger");
    
    app.setApplicationName("NetSecOps");
    app.setApplicationVersion("1.0");
    app.setOrganizationName("NetSecOps");
    
    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    
    if (engine.rootObjects().isEmpty())
        return -1;
        
    return app.exec();
}
