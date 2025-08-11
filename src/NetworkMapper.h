#pragma once

#include <QObject>
#include <QTimer>
#include <QProcess>
#include <QStringList>
#include <QJsonObject>
#include <QJsonDocument>

struct HostProfile {
    QString ip;
    QString mac;
    QString hostname;
    QString osType;
    QString osVersion;
    QList<int> openPorts;
    QStringList services;
    QString vendor;
    QString deviceType;
    bool isOnline;
    qint64 responseTime;
};

struct ArpEntry {
    QString ip;
    QString mac;
    QString vendor;
    QString type;
};

class NetworkMapper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isMapping READ isMapping NOTIFY isMappingChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(int hostsProfiled READ hostsProfiled NOTIFY hostsProfiledChanged)
    Q_PROPERTY(QStringList networkTree READ networkTree NOTIFY networkTreeChanged)

public:
    explicit NetworkMapper(QObject *parent = nullptr);
    
    bool isMapping() const { return m_isMapping; }
    int progress() const { return m_progress; }
    int hostsProfiled() const { return m_hostsProfiled; }
    QStringList networkTree() const { return m_networkTree; }

    QHash<QString, QString> loadVendorDatabase(const QString &filePath);
    
private:
    bool m_isOnline;

public slots:
    void startMapping(const QStringList &targetIPs);
    void startQuickMapping(); // ARP table only
    void startFullMapping(const QString &subnet); // Full subnet scan
    void stopMapping();
    void exportMap(const QString &format, const QString &filePath);
    QStringList getArpTable();

signals:
    void isMappingChanged();
    void progressChanged();
    void hostsProfiledChanged();
    void networkTreeChanged();
    void hostProfiled(const QString &ip, const QString &os, const QString &services, const QString &vendor);
    void arpTableUpdated(const QStringList &entries);
    void mappingCompleted();
    void exportCompleted(const QString &filePath);

private slots:
    void onHostProfileCompleted(const HostProfile &profile);
    void updateProgress();

private:
    void profileHost(const QString &ip);
    QString detectOS(const QString &ip, const QList<int> &ports);
    QStringList detectServices(const QString &ip, const QList<int> &ports);
    QString getMacVendor(const QString &mac);
    QList<ArpEntry> parseArpTable();
    void buildNetworkTree();
    QStringList getSubnetIPs(const QString &subnet);
    
    bool m_isMapping;
    int m_progress;
    int m_hostsProfiled;
    int m_totalHosts;
    int m_completedHosts;
    
    QStringList m_targetIPs;
    QList<HostProfile> m_profiles;
    QTimer *m_progressTimer;
    QStringList m_networkTree;
    bool m_quickScan;
};

class HostProfiler : public QObject
{
    Q_OBJECT

public:
    explicit HostProfiler(const QString &ip, QObject *parent = nullptr);

public slots:
    void profile();

signals:
    void profileCompleted(const HostProfile &profile);

private:
    QString detectOperatingSystem(const QString &ip, const QList<int> &ports);
    QStringList enumerateServices(const QString &ip, const QList<int> &ports);
    QList<int> scanCommonPorts(const QString &ip);
    bool isPortOpen(const QString &ip, int port);
    QString detectDeviceType(const QString &ip, const QList<int> &ports, const QString &mac, const QString &vendor);
    
    QString m_ip;
};
