#include "ActivityLogger.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>
#include <QJsonObject>
#include <QJsonArray>

ActivityLogger::ActivityLogger(QObject *parent)
    : QObject(parent)
{
    initDatabase();
    loadActivities();
}

void ActivityLogger::initDatabase()
{
    QString dataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataPath);
    
    QString connectionName = QString("ActivityDB_%1").arg(reinterpret_cast<quintptr>(this));
    m_database = QSqlDatabase::addDatabase("QSQLITE", connectionName);
    m_database.setDatabaseName(dataPath + "/activities.db");
    
    if (!m_database.open()) {
        qWarning() << "Failed to open activity database:" << m_database.lastError().text();
        return;
    }
    
    QSqlQuery query(m_database);
    query.exec("CREATE TABLE IF NOT EXISTS activities ("
               "id INTEGER PRIMARY KEY AUTOINCREMENT, "
               "timestamp TEXT NOT NULL, "
               "type TEXT NOT NULL, "
               "action TEXT NOT NULL, "
               "target TEXT NOT NULL, "
               "status TEXT NOT NULL, "
               "user TEXT NOT NULL)");
}

void ActivityLogger::logActivity(const QString &type, const QString &action, const QString &target, const QString &status, const QString &user)
{
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss");
    
    // Save to database
    saveActivity(timestamp, type, action, target, status, user);
    
    // Add to current activities array
    QJsonObject activity;
    activity["timestamp"] = timestamp;
    activity["type"] = type;
    activity["action"] = action;
    activity["target"] = target;
    activity["status"] = status;
    activity["user"] = user;
    
    m_activities.prepend(activity);
    
    // Keep only last 100 activities in memory
    if (m_activities.size() > 100) {
        QJsonArray newArray;
        for (int i = 0; i < 100; ++i) {
            newArray.append(m_activities[i]);
        }
        m_activities = newArray;
    }
    
    emit activitiesChanged();
}

void ActivityLogger::saveActivity(const QString &timestamp, const QString &type, const QString &action, const QString &target, const QString &status, const QString &user)
{
    QSqlQuery query(m_database);
    query.prepare("INSERT INTO activities (timestamp, type, action, target, status, user) VALUES (?, ?, ?, ?, ?, ?)");
    query.addBindValue(timestamp);
    query.addBindValue(type);
    query.addBindValue(action);
    query.addBindValue(target);
    query.addBindValue(status);
    query.addBindValue(user);
    
    if (!query.exec()) {
        qWarning() << "Failed to save activity:" << query.lastError().text();
    }
}

void ActivityLogger::loadActivities()
{
    m_activities = QJsonArray();
    
    QSqlQuery query(m_database);
    query.exec("SELECT timestamp, type, action, target, status, user FROM activities ORDER BY timestamp DESC LIMIT 100");
    
    while (query.next()) {
        QJsonObject activity;
        activity["timestamp"] = query.value(0).toString();
        activity["type"] = query.value(1).toString();
        activity["action"] = query.value(2).toString();
        activity["target"] = query.value(3).toString();
        activity["status"] = query.value(4).toString();
        activity["user"] = query.value(5).toString();
        
        m_activities.append(activity);
    }
    
    emit activitiesChanged();
}

ActivityLogger::~ActivityLogger()
{
    if (m_database.isOpen()) {
        m_database.close();
    }
    QSqlDatabase::removeDatabase(m_database.connectionName());
}

void ActivityLogger::clearActivities()
{
    QSqlQuery query(m_database);
    query.exec("DELETE FROM activities");
    
    m_activities = QJsonArray();
    emit activitiesChanged();
}
