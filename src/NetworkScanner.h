#pragma once

#include <QObject>
#include <QThread>
#include <QTimer>
#include <QTcpSocket>
#include <QHostAddress>
#include <QStringList>
#include <QMutex>
#include <QAtomicInt>

struct HostInfo {
    QString ip;
    QString hostname;
    QString mac;
    QList<int> openPorts;
    bool isOnline;
    qint64 responseTime;
};

class NetworkScanner : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isScanning READ isScanning NOTIFY isScanningChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(int hostsFound READ hostsFound NOTIFY hostsFoundChanged)
    Q_PROPERTY(int portsFound READ portsFound NOTIFY portsFoundChanged)
    Q_PROPERTY(QString currentIP READ currentIP NOTIFY currentIPChanged)

public:
    explicit NetworkScanner(QObject *parent = nullptr);
    
    bool isScanning() const { return m_isScanning; }
    int progress() const { return m_progress; }
    int hostsFound() const { return m_hostsFound; }
    int portsFound() const { return m_portsFound; }
    QString currentIP() const { return m_currentIP; }

public slots:
    void startScan(const QString &network, const QString &portRange, int threads);
    void stopScan();

signals:
    void isScanningChanged();
    void progressChanged();
    void hostsFoundChanged();
    void portsFoundChanged();
    void currentIPChanged();
    void hostDiscovered(const QString &ip, const QString &hostname, const QString &mac, const QList<int> &ports);
    void scanCompleted();
    void scanStarted(const QString &network, const QString &ports);
    void scanFailed(const QString &error);

private slots:
    void onHostScanCompleted(const HostInfo &host);
    void updateProgress();

private:
    void parseNetworkRange(const QString &network);
    void parsePortRange(const QString &portRange);
    QStringList generateIPList(const QString &network);
    
    bool m_isScanning;
    int m_progress;
    int m_hostsFound;
    int m_portsFound;
    QString m_currentIP;
    int m_totalHosts;
    int m_completedHosts;
    
    QStringList m_targetIPs;
    QList<int> m_targetPorts;
    int m_maxThreads;
    
    QMutex m_mutex;
    QTimer *m_progressTimer;
};

class HostScanner : public QObject
{
    Q_OBJECT

public:
    explicit HostScanner(const QString &ip, const QList<int> &ports, QObject *parent = nullptr);

public slots:
    void scan();

signals:
    void scanCompleted(const HostInfo &host);
    void scanStarted(const QString &ip);

private:
    bool pingHost(const QString &ip);
    QString resolveHostname(const QString &ip);
    QString getMacAddress(const QString &ip);
    QList<int> scanPorts(const QString &ip, const QList<int> &ports);
    bool isPortOpen(const QString &ip, int port);
    
    QString m_ip;
    QList<int> m_ports;
};