#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QJsonArray>
#include <QDateTime>

class ActivityLogger : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QJsonArray activities READ activities NOTIFY activitiesChanged)

public:
    explicit ActivityLogger(QObject *parent = nullptr);
    ~ActivityLogger();
    
    QJsonArray activities() const { return m_activities; }

public slots:
    void logActivity(const QString &type, const QString &action, const QString &target, const QString &status, const QString &user = "admin");
    void loadActivities();
    void clearActivities();

signals:
    void activitiesChanged();

private:
    void initDatabase();
    void saveActivity(const QString &timestamp, const QString &type, const QString &action, const QString &target, const QString &status, const QString &user);
    
    QSqlDatabase m_database;
    QJsonArray m_activities;
};