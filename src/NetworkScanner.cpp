#include "NetworkScanner.h"
#include <QThreadPool>
#include <QRunnable>
#include <QHostInfo>
#include <QNetworkInterface>
#include <QProcess>
#include <QRegularExpression>
#include <QElapsedTimer>
#include <QDebug>
#include <QSet>

NetworkScanner::NetworkScanner(QObject *parent)
    : QObject(parent)
    , m_isScanning(false)
    , m_progress(0)
    , m_hostsFound(0)
    , m_portsFound(0)
    , m_currentIP("")
    , m_totalHosts(0)
    , m_completedHosts(0)
    , m_maxThreads(50)
{
    m_progressTimer = new QTimer(this);
    connect(m_progressTimer, &QTimer::timeout, this, &NetworkScanner::updateProgress);
}

void NetworkScanner::startScan(const QString &network, const QString &portRange, int threads)
{
    if (m_isScanning) return;
    
    qDebug() << "Starting scan:" << network << portRange << threads;
    
    m_isScanning = true;
    m_progress = 0;
    m_hostsFound = 0;
    m_portsFound = 0;
    m_completedHosts = 0;
    
    emit scanStarted(network, portRange);
    m_currentIP = "";
    m_maxThreads = threads;
    
    emit isScanningChanged();
    emit progressChanged();
    emit hostsFoundChanged();
    emit portsFoundChanged();
    emit currentIPChanged();
    
    parsePortRange(portRange);
    m_targetIPs = generateIPList(network);
    m_totalHosts = m_targetIPs.size();
    
    qDebug() << "Generated" << m_totalHosts << "IPs to scan";
    qDebug() << "Port list:" << m_targetPorts;
    
    m_progressTimer->start(500);
    
    // Limit concurrent threads
    QThreadPool::globalInstance()->setMaxThreadCount(qMin(m_maxThreads, 100));
    qDebug() << "Using" << QThreadPool::globalInstance()->maxThreadCount() << "threads";
    
    for (const QString &ip : m_targetIPs) {
        HostScanner *scanner = new HostScanner(ip, m_targetPorts);
        connect(scanner, &HostScanner::scanCompleted, this, &NetworkScanner::onHostScanCompleted);
        connect(scanner, &HostScanner::scanStarted, this, [this](const QString &ip) {
            m_currentIP = ip;
            emit currentIPChanged();
        });
        
        QRunnable *task = QRunnable::create([scanner]() {
            QThread::currentThread()->setPriority(QThread::NormalPriority);
            scanner->scan();
            scanner->deleteLater();
        });
        task->setAutoDelete(true);
        
        QThreadPool::globalInstance()->start(task);
    }
}

void NetworkScanner::stopScan()
{
    if (!m_isScanning) return;
    
    m_isScanning = false;
    m_progressTimer->stop();
    QThreadPool::globalInstance()->clear();
    
    emit isScanningChanged();
    emit scanCompleted();
}

void NetworkScanner::onHostScanCompleted(const HostInfo &host)
{
    QMutexLocker locker(&m_mutex);
    
    m_completedHosts++;
    
    qDebug() << "Host scan completed:" << host.ip << "Online:" << host.isOnline << "Ports:" << host.openPorts.size();
    
    if (host.isOnline) {
        m_hostsFound++;
        m_portsFound += host.openPorts.size();
        
        emit hostDiscovered(host.ip, host.hostname, host.mac, host.openPorts);
        emit hostsFoundChanged();
        emit portsFoundChanged();
    }
    
    if (m_completedHosts >= m_totalHosts) {
        m_isScanning = false;
        m_progress = 100;
        m_progressTimer->stop();
        
        qDebug() << "Scan completed. Found" << m_hostsFound << "hosts with" << m_portsFound << "open ports";
        
        emit isScanningChanged();
        emit progressChanged();
        emit scanCompleted();
    }
}

void NetworkScanner::updateProgress()
{
    if (m_totalHosts > 0) {
        m_progress = (m_completedHosts * 100) / m_totalHosts;
        emit progressChanged();
    }
}

QStringList NetworkScanner::generateIPList(const QString &network)
{
    QStringList ips;
    QRegularExpression cidrRegex(R"((\d+\.\d+\.\d+\.\d+)/(\d+))");
    QRegularExpressionMatch match = cidrRegex.match(network);
    
    if (match.hasMatch()) {
        QString baseIP = match.captured(1);
        int prefix = match.captured(2).toInt();
        
        QHostAddress addr(baseIP);
        quint32 ip = addr.toIPv4Address();
        quint32 mask = 0xFFFFFFFF << (32 - prefix);
        quint32 networkAddr = ip & mask;
        quint32 broadcastAddr = networkAddr | (~mask);
        
        // Limit to reasonable range for testing
        int maxHosts = qMin(254, (int)(broadcastAddr - networkAddr - 1));
        
        for (quint32 i = networkAddr + 1; i <= networkAddr + maxHosts; ++i) {
            ips << QHostAddress(i).toString();
        }
    } else {
        // Single IP
        ips << network;
    }
    
    return ips;
}

void NetworkScanner::parsePortRange(const QString &portRange)
{
    m_targetPorts.clear();
    
    // Split by comma, semicolon, or space
    QStringList parts = portRange.split(QRegularExpression("[,;\\s]+"), Qt::SkipEmptyParts);
    
    for (const QString &part : parts) {
        QString trimmed = part.trimmed();
        
        if (trimmed.contains('-')) {
            // Handle range like "1-100"
            QStringList rangeParts = trimmed.split('-');
            if (rangeParts.size() == 2) {
                bool ok1, ok2;
                int start = rangeParts[0].trimmed().toInt(&ok1);
                int end = rangeParts[1].trimmed().toInt(&ok2);
                
                if (ok1 && ok2 && start > 0 && end > 0 && start <= end && end <= 65535) {
                    for (int port = start; port <= end; ++port) {
                        m_targetPorts << port;
                    }
                    qDebug() << "Added port range:" << start << "-" << end;
                }
            }
        } else {
            // Handle single port like "80"
            bool ok;
            int port = trimmed.toInt(&ok);
            if (ok && port > 0 && port <= 65535) {
                m_targetPorts << port;
                qDebug() << "Added single port:" << port;
            }
        }
    }
    
    // Remove duplicates and sort
    QSet<int> seen(m_targetPorts.begin(), m_targetPorts.end());
    m_targetPorts = QList<int>(seen.begin(), seen.end());
    std::sort(m_targetPorts.begin(), m_targetPorts.end());
    
    qDebug() << "Final port list:" << m_targetPorts;
}

// HostScanner Implementation
HostScanner::HostScanner(const QString &ip, const QList<int> &ports, QObject *parent)
    : QObject(parent), m_ip(ip), m_ports(ports)
{
}

void HostScanner::scan()
{
    emit scanStarted(m_ip);
    
    HostInfo host;
    host.ip = m_ip;
    host.responseTime = 0;
    
    // Try multiple ping methods
    host.isOnline = pingHost(m_ip);
    
    // Always scan ports if host is online OR if we find any open ports
    if (host.isOnline || !m_ports.isEmpty()) {
        host.openPorts = scanPorts(m_ip, m_ports);
        
        // If host wasn't detected as online but has open ports, mark as online
        if (!host.isOnline && !host.openPorts.isEmpty()) {
            host.isOnline = true;
            qDebug() << "Host" << m_ip << "detected via open ports:" << host.openPorts;
        }
    }
    
    if (host.isOnline) {
        host.hostname = resolveHostname(m_ip);
        host.mac = getMacAddress(m_ip);
        qDebug() << "Host" << m_ip << "is online with" << host.openPorts.size() << "open ports";
    } else {
        qDebug() << "Host" << m_ip << "is offline";
    }
    
    emit scanCompleted(host);
}

bool HostScanner::pingHost(const QString &ip)
{
    // Method 1: ICMP ping first (most reliable)
#ifdef Q_OS_WIN
    QProcess process;
    process.start("ping", QStringList() << "-n" << "1" << "-w" << "500" << ip);
    process.waitForFinished(1000);
    
    QString output = process.readAllStandardOutput();
    if (output.contains("TTL=") && !output.contains("Request timed out")) {
        qDebug() << "ICMP ping successful for" << ip;
        return true;
    }
#else
    QProcess process;
    process.start("ping", QStringList() << "-c" << "1" << "-W" << "1" << ip);
    process.waitForFinished(1000);
    
    if (process.exitCode() == 0) {
        qDebug() << "ICMP ping successful for" << ip;
        return true;
    }
#endif
    
    // Method 2: TCP connect to very common ports
    QList<int> commonPorts = {80, 443, 22, 135, 139, 445};
    
    for (int port : commonPorts) {
        if (isPortOpen(ip, port)) {
            qDebug() << "TCP connect successful for" << ip << "on port" << port;
            return true;
        }
    }
    
    return false;
}

QString HostScanner::resolveHostname(const QString &ip)
{
    QHostInfo info = QHostInfo::fromName(ip);
    if (!info.hostName().isEmpty() && info.hostName() != ip) {
        return info.hostName();
    }
    
    // Try reverse DNS lookup
    QHostAddress addr(ip);
    QHostInfo reverseInfo = QHostInfo::fromName(addr.toString());
    if (!reverseInfo.hostName().isEmpty()) {
        return reverseInfo.hostName();
    }
    
    return ip;
}

QString HostScanner::getMacAddress(const QString &ip)
{
#ifdef Q_OS_WIN
    QProcess process;
    process.start("arp", QStringList() << "-a" << ip);
    process.waitForFinished(3000);
    
    QString output = process.readAllStandardOutput();
    QRegularExpression macRegex(R"([0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2}-[0-9a-fA-F]{2})");
    QRegularExpressionMatch match = macRegex.match(output);
    
    if (match.hasMatch()) {
        return match.captured(0).replace('-', ':');
    }
#else
    QProcess process;
    process.start("arp", QStringList() << "-n" << ip);
    process.waitForFinished(3000);
    
    QString output = process.readAllStandardOutput();
    QRegularExpression macRegex(R"([0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2})");
    QRegularExpressionMatch match = macRegex.match(output);
    
    if (match.hasMatch()) {
        return match.captured(0);
    }
#endif
    return "Unknown";
}

QList<int> HostScanner::scanPorts(const QString &ip, const QList<int> &ports)
{
    QList<int> openPorts;
    
    qDebug() << "Scanning" << ports.size() << "ports on" << ip;
    
    for (int port : ports) {
        if (isPortOpen(ip, port)) {
            openPorts << port;
            qDebug() << "Port" << port << "is OPEN on" << ip;
        }
    }
    
    qDebug() << "Found" << openPorts.size() << "open ports on" << ip << ":" << openPorts;
    return openPorts;
}

bool HostScanner::isPortOpen(const QString &ip, int port)
{
    QTcpSocket socket;
    socket.connectToHost(ip, port);
    
    bool connected = socket.waitForConnected(800); // Faster timeout
    
    if (connected) {
        socket.disconnectFromHost();
        if (socket.state() != QAbstractSocket::UnconnectedState) {
            socket.waitForDisconnected(500);
        }
        return true;
    }
    
    return false;
}
