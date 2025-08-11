#include "NetworkMapper.h"
#include <QThreadPool>
#include <QRunnable>
#include <QRegularExpression>
#include <QDebug>
#include <QJsonArray>
#include <QFile>
#include <QTextStream>
#include <QTcpSocket>
#include <QNetworkInterface>

NetworkMapper::NetworkMapper(QObject *parent)
    : QObject(parent)
    , m_isMapping(false)
    , m_progress(0)
    , m_hostsProfiled(0)
    , m_totalHosts(0)
    , m_completedHosts(0)
    , m_quickScan(false)
{
    m_progressTimer = new QTimer(this);
    connect(m_progressTimer, &QTimer::timeout, this, &NetworkMapper::updateProgress);
}

void NetworkMapper::startMapping(const QStringList &targetIPs)
{
    if (m_isMapping) return;
    
    qDebug() << "Starting network mapping for" << targetIPs.size() << "hosts";
    
    m_isMapping = true;
    m_progress = 0;
    m_hostsProfiled = 0;
    m_completedHosts = 0;
    m_targetIPs = targetIPs;
    m_totalHosts = targetIPs.size();
    m_profiles.clear();
    
    emit isMappingChanged();
    emit progressChanged();
    emit hostsProfiledChanged();
    
    // Get ARP table first
    QStringList arpEntries = getArpTable();
    emit arpTableUpdated(arpEntries);
    
    m_progressTimer->start(500);
    
    // Set thread pool size based on scan type
    int maxThreads = m_quickScan ? 10 : 50; // Fewer threads for quick scan
    QThreadPool::globalInstance()->setMaxThreadCount(maxThreads);
    qDebug() << "Using" << maxThreads << "threads for" << (m_quickScan ? "quick" : "full") << "scan";
    
    // Profile each host with threading
    for (const QString &ip : targetIPs) {
        HostProfiler *profiler = new HostProfiler(ip);
        connect(profiler, &HostProfiler::profileCompleted, this, &NetworkMapper::onHostProfileCompleted);
        
        QRunnable *task = QRunnable::create([profiler]() {
            QThread::currentThread()->setPriority(QThread::NormalPriority);
            profiler->profile();
            profiler->deleteLater();
        });
        task->setAutoDelete(true);
        
        QThreadPool::globalInstance()->start(task);
    }
}

void NetworkMapper::stopMapping()
{
    if (!m_isMapping) return;
    
    m_isMapping = false;
    m_progressTimer->stop();
    QThreadPool::globalInstance()->clear();
    
    emit isMappingChanged();
    emit mappingCompleted();
}

void NetworkMapper::onHostProfileCompleted(const HostProfile &profile)
{
    m_completedHosts++;
    m_profiles.append(profile);
    
    if (!profile.osType.isEmpty() || !profile.services.isEmpty()) {
        m_hostsProfiled++;
        
        QString services = profile.services.join(", ");
        emit hostProfiled(profile.ip, profile.osType, services, profile.vendor);
        emit hostsProfiledChanged();
    }
    
    qDebug() << "Host profiled:" << profile.ip << "OS:" << profile.osType << "Services:" << profile.services.size();
    
    if (m_completedHosts >= m_totalHosts) {
        m_isMapping = false;
        m_progress = 100;
        m_progressTimer->stop();
        
        buildNetworkTree();
        emit isMappingChanged();
        emit progressChanged();
        emit mappingCompleted();
    }
}

void NetworkMapper::updateProgress()
{
    if (m_totalHosts > 0) {
        m_progress = (m_completedHosts * 100) / m_totalHosts;
        emit progressChanged();
    }
}

QStringList NetworkMapper::getArpTable()
{
    QStringList entries;
    QList<ArpEntry> arpTable = parseArpTable();
    
    for (const ArpEntry &entry : arpTable) {
        QString entryStr = QString("%1|%2|%3|%4").arg(entry.ip, entry.mac, entry.vendor, entry.type);
        entries << entryStr;
        qDebug() << entry.ip<< entry.mac<< entry.vendor<< entry.type;
    }
    
    qDebug() << "Retrieved" << entries.size() << "ARP entries";
    return entries;
}

QList<ArpEntry> NetworkMapper::parseArpTable()
{
    QList<ArpEntry> entries;
    
#ifdef Q_OS_WIN
    QProcess process;
    process.start("arp", QStringList() << "-a");
    process.waitForFinished(5000);
    
    QString output = process.readAllStandardOutput();
    QStringList lines = output.split('\n', Qt::SkipEmptyParts);
    
    for (const QString &line : lines) {
        QRegularExpression regex(R"(\s*(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F-]{17})\s+(\w+))");
        QRegularExpressionMatch match = regex.match(line);
        
        if (match.hasMatch()) {
            ArpEntry entry;
            entry.ip = match.captured(1);
            entry.mac = match.captured(2).replace('-', ':');
            entry.type = match.captured(3);
            entry.vendor = getMacVendor(entry.mac);
            entries.append(entry);
        }
    }
#else
    QProcess process;
    process.start("arp", QStringList() << "-a");
    process.waitForFinished(5000);
    
    QString output = process.readAllStandardOutput();
    QStringList lines = output.split('\n', Qt::SkipEmptyParts);
    
    for (const QString &line : lines) {
        QRegularExpression regex(R"(\s*(\d+\.\d+\.\d+\.\d+)\s+.*\s+([0-9a-fA-F:]{17})\s+)");
        QRegularExpressionMatch match = regex.match(line);
        
        if (match.hasMatch()) {
            ArpEntry entry;
            entry.ip = match.captured(1);
            entry.mac = match.captured(2);
            entry.type = "dynamic";
            entry.vendor = getMacVendor(entry.mac);
            entries.append(entry);
        }
    }
#endif
    
    return entries;
}

QString NetworkMapper::getMacVendor(const QString &mac)
{
    QString oui = mac.left(8).toUpper();
    
    static QHash<QString, QString> vendors = loadVendorDatabase("vendors.csv");
    QString vendor = vendors.value(oui, "Unknown");
    
    // Try online OUI lookup if local lookup fails
    if (vendor == "Unknown" && !oui.isEmpty()) {
        // For production, you could implement IEEE OUI database lookup
        // For now, return manufacturer hint based on common patterns
        if (oui.startsWith("00:50:") || oui.startsWith("00:0C:")) {
            vendor = "VMware (likely)";
        } else if (oui.startsWith("08:00:")) {
            vendor = "VirtualBox (likely)";
        }
    }
    // qDebug() << "Vendor : "<< vendor;
    return vendor;
}

void NetworkMapper::exportMap(const QString &format, const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "Failed to open file for export:" << filePath;
        return;
    }
    
    QTextStream out(&file);
    
    if (format.toLower() == "json") {
        QJsonArray hostsArray;
        for (const HostProfile &profile : m_profiles) {
            QJsonObject hostObj;
            hostObj["ip"] = profile.ip;
            hostObj["mac"] = profile.mac;
            hostObj["hostname"] = profile.hostname;
            hostObj["os"] = profile.osType;
            hostObj["vendor"] = profile.vendor;
            
            QJsonArray portsArray;
            for (int port : profile.openPorts) {
                portsArray.append(port);
            }
            hostObj["ports"] = portsArray;
            
            QJsonArray servicesArray;
            for (const QString &service : profile.services) {
                servicesArray.append(service);
            }
            hostObj["services"] = servicesArray;
            
            hostsArray.append(hostObj);
        }
        
        QJsonObject rootObj;
        rootObj["hosts"] = hostsArray;
        rootObj["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
        
        out << QJsonDocument(rootObj).toJson();
        
    } else if (format.toLower() == "csv") {
        out << "IP,MAC,Hostname,OS,Vendor,Ports,Services\n";
        for (const HostProfile &profile : m_profiles) {
            QStringList portStrings;
            for (int port : profile.openPorts) {
                portStrings << QString::number(port);
            }
            
            out << QString("%1,%2,%3,%4,%5,\"%6\",\"%7\"\n")
                   .arg(profile.ip, profile.mac, profile.hostname, profile.osType, profile.vendor)
                   .arg(portStrings.join(";"), profile.services.join(";"));
        }
    } else if (format.toLower() == "xml") {
        out << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
        out << "<NetworkMap timestamp=\"" << QDateTime::currentDateTime().toString(Qt::ISODate) << "\">\n";
        out << "  <Hosts>\n";
        
        for (const HostProfile &profile : m_profiles) {
            out << "    <Host>\n";
            out << "      <IP>" << profile.ip << "</IP>\n";
            out << "      <MAC>" << profile.mac << "</MAC>\n";
            out << "      <Hostname>" << profile.hostname << "</Hostname>\n";
            out << "      <OS>" << profile.osType << "</OS>\n";
            out << "      <Vendor>" << profile.vendor << "</Vendor>\n";
            out << "      <Ports>\n";
            for (int port : profile.openPorts) {
                out << "        <Port>" << port << "</Port>\n";
            }
            out << "      </Ports>\n";
            out << "      <Services>\n";
            for (const QString &service : profile.services) {
                out << "        <Service>" << service << "</Service>\n";
            }
            out << "      </Services>\n";
            out << "    </Host>\n";
        }
        
        out << "  </Hosts>\n";
        out << "</NetworkMap>\n";
    }
    
    file.close();
    qDebug() << "Network map exported to:" << filePath;
    emit exportCompleted(filePath);
}

// HostProfiler Implementation
HostProfiler::HostProfiler(const QString &ip, QObject *parent)
    : QObject(parent), m_ip(ip)
{
}

void HostProfiler::profile()
{
    HostProfile profile;
    profile.ip = m_ip;
    profile.responseTime = 0;
    
    // Scan common ports
    profile.openPorts = scanCommonPorts(m_ip);
    
    // if (!profile.openPorts.isEmpty()) {
        // Detect OS based on open ports and behavior
        profile.osType = detectOperatingSystem(m_ip, profile.openPorts);
        
        // Enumerate services
        profile.services = enumerateServices(m_ip, profile.openPorts);
        
        qDebug() << "Profiled" << m_ip << "- OS:" << profile.osType << "Services:" << profile.services.size();
    // }
    
    // Determine if host is online based on open ports
    profile.isOnline = !profile.openPorts.isEmpty();
    
    // Get MAC and vendor for device type detection
    if (profile.isOnline) {
        // Get MAC from ARP (simplified)
        QProcess arpProcess;
#ifdef Q_OS_WIN
        arpProcess.start("arp", QStringList() << "-a" << m_ip);
#else
        arpProcess.start("arp", QStringList() << "-n" << m_ip);
#endif
        arpProcess.waitForFinished(3000);
        QString arpOutput = arpProcess.readAllStandardOutput();
        
        QRegularExpression macRegex(R"([0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2}[:-][0-9a-fA-F]{2})");
        QRegularExpressionMatch macMatch = macRegex.match(arpOutput);
        if (macMatch.hasMatch()) {
            profile.mac = macMatch.captured(0).replace('-', ':');
        }
        
        // Get vendor from MAC
        QString oui = profile.mac.left(8).toUpper();
        static QHash<QString, QString> vendors = {
            {"00:50:56", "VMware"}, {"08:00:27", "VirtualBox"}, {"00:0C:29", "VMware"},
            {"00:23:6C", "Apple"}, {"A4:C3:61", "Apple"}, {"00:1A:A0", "Dell"},
            {"00:15:17", "HP"}, {"00:1B:78", "HP"}, {"3C:4A:92", "HP"},
            {"00:1E:C9", "Cisco"}, {"00:26:99", "Cisco"}, {"00:50:E2", "Cisco"}
        };
        profile.vendor = vendors.value(oui, "Unknown");
        
        // Detect device type
        profile.deviceType = detectDeviceType(m_ip, profile.openPorts, profile.mac, profile.vendor);
    }
    
    emit profileCompleted(profile);
}

QList<int> HostProfiler::scanCommonPorts(const QString &ip)
{
    QList<int> openPorts;
    QList<int> commonPorts = {21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 993, 995, 1433, 3306, 3389, 5432, 5900, 8080};
    
    for (int port : commonPorts) {
        if (isPortOpen(ip, port)) {
            openPorts << port;
        }
    }
    
    return openPorts;
}

QString HostProfiler::detectOperatingSystem(const QString &ip, const QList<int> &ports)
{
    QProcess process;

    // QString nmapPath = "C:/Program Files (x86)/Nmap/nmap.exe";  // Adjust if installed elsewhere
    // process.start(nmapPath, QStringList() << "-O" << "--osscan-guess" << ip);

    process.start("nmap", QStringList() << "-O" << "--osscan-guess" << ip);

    if (!process.waitForFinished(30000)) {
        qDebug() << "Nmap process timed out!";
        process.kill();
    }
    QString output = QString::fromLocal8Bit(process.readAllStandardOutput());

    // QString stdoutOutput = QString::fromLocal8Bit(process.readAllStandardOutput());
    // qDebug() << ip << "Nmap stdout:\n" << stdoutOutput;
    // qDebug() << "Nmap stderr:\n" << stderrOutput;
    // QString stderrOutput = QString::fromLocal8Bit(process.readAllStandardError());
    // qDebug() << "Exit code:" << process.exitCode();
    // QString output = stdoutOutput;

    qDebug() << ip << "nmap output length:" << output.length();

    //Extract OS details via regex
    static const QRegularExpression osRegex("^OS details:\\s*(.+)$", QRegularExpression::MultilineOption);
    QRegularExpressionMatch match = osRegex.match(output);

    if (match.hasMatch()) {
        // QString osDetails = match.captured(1).trimmed();
        // return osDetails;

        QString osDetailsFull = match.captured(1).trimmed();

        // Option 1: Just first device/model before comma
        static const QRegularExpression firstDeviceRegex("^([^,]+)");
        auto deviceMatch = firstDeviceRegex.match(osDetailsFull);
        if (deviceMatch.hasMatch()) {
            return deviceMatch.captured(1).trimmed();
        }

        // fallback return full
        return osDetailsFull;
    }

    // QRegularExpression osRegex("^OS details: (.+)$", QRegularExpression::MultilineOption);

    //Try fallback fuzzy OS guesses (Running:)
    static const QRegularExpression runningRegex("^Running:\\s*(.+)$", QRegularExpression::MultilineOption);
    auto m2 = runningRegex.match(output);
    if (m2.hasMatch()) {
        return m2.captured(1).trimmed();
    }

        if (output.contains("Windows", Qt::CaseInsensitive)) {
            if (output.contains("Windows 11")) return "Windows 11";
            if (output.contains("Windows 10")) return "Windows 10";
            if (output.contains("Windows 7")) return "Windows 7";
            if (output.contains("Windows XP")) return "Windows XP";
            if (output.contains("Server 2016")) return "Windows Server 2016";
            if (output.contains("Server 2019")) return "Windows Server 2019";
            return "Windows";
        } else if (output.contains("Linux", Qt::CaseInsensitive)) {
            if (output.contains("Ubuntu")) return "Ubuntu Linux";
            if (output.contains("CentOS")) return "CentOS Linux";
            if (output.contains("Red Hat")) return "Red Hat Linux";
            return "Linux";
        } else if (output.contains("macOS", Qt::CaseInsensitive) || output.contains("Mac OS", Qt::CaseInsensitive)) {
            return "macOS";
        } else if (output.contains("FreeBSD", Qt::CaseInsensitive)) {
            return "FreeBSD";
        } else if (output.contains("Android", Qt::CaseInsensitive)) {
            return "Android";
        } else if (output.contains("iOS", Qt::CaseInsensitive)) {
            return "iOS";
        }

    // if (!ports.isEmpty()) {
        // Fallback to port-based detection if nmap fails
        if (ports.contains(3389)) return "Windows (RDP)";
        if (ports.contains(135) || ports.contains(445)) return "Windows";
        if (ports.contains(548)) return "macOS (AFP)";
        if (ports.contains(22) && ports.contains(111)) return "Linux (NFS)";
        if (ports.contains(22)) return "Linux";
    // }
    
    return "Unknown";
}

QStringList HostProfiler::enumerateServices(const QString &ip, const QList<int> &ports)
{
    QStringList services;
    
    // Use nmap for service detection
    QProcess process;
    QStringList portList;
    for (int port : ports) {
        portList << QString::number(port);
    }
    
    if (!portList.isEmpty()) {
        process.start("nmap", QStringList() << "-sV" << "-p" << portList.join(",") << ip);
        process.waitForFinished(15000);
        
        QString output = process.readAllStandardOutput();
        QStringList lines = output.split('\n');
        
        for (const QString &line : lines) {
            if (line.contains("/tcp") && line.contains("open")) {
                // QRegularExpression regex(R"(\d+/tcp\s+open\s+(\S+)\s*(.*))";
                QRegularExpression regex(R"(^(\d+)/tcp\s+open\s+(\S+)\s+(.*\S)?)",
                                         QRegularExpression::CaseInsensitiveOption);
                QRegularExpressionMatch match = regex.match(line);
                if (match.hasMatch()) {
                    QString service = match.captured(1);
                    QString version = match.captured(2).trimmed();
                    if (!version.isEmpty()) {
                        services << service + " (" + version + ")";
                    } else {
                        services << service;
                    }
                }
            }
        }
    }
    
    // Fallback to static mapping if nmap fails
    if (services.isEmpty()) {
        static QHash<int, QString> serviceMap = {
            {21, "FTP"}, {22, "SSH"}, {23, "Telnet"}, {25, "SMTP"},
            {53, "DNS"}, {80, "HTTP"}, {110, "POP3"}, {135, "RPC"},
            {139, "NetBIOS"}, {143, "IMAP"}, {443, "HTTPS"}, {445, "SMB"},
            {993, "IMAPS"}, {995, "POP3S"}, {1433, "MSSQL"}, {3306, "MySQL"},
            {3389, "RDP"}, {5432, "PostgreSQL"}, {5900, "VNC"}, {8080, "HTTP-Alt"}
        };
        
        for (int port : ports) {
            if (serviceMap.contains(port)) {
                services << serviceMap[port];
            }
        }
    }
    
    return services;
}

bool HostProfiler::isPortOpen(const QString &ip, int port)
{
    QTcpSocket socket;
    socket.connectToHost(ip, port);
    bool connected = socket.waitForConnected(1000);
    
    if (connected) {
        socket.disconnectFromHost();
        if (socket.state() != QAbstractSocket::UnconnectedState) {
            socket.waitForDisconnected(500);
        }
    }
    
    return connected;
}

QString HostProfiler::detectDeviceType(const QString &ip, const QList<int> &ports, const QString &mac, const QString &vendor)
{
    // Router/Gateway detection
    if (ip.endsWith(".1") || ip.endsWith(".254")) {
        if (ports.contains(80) || ports.contains(443) || ports.contains(23)) {
            return "router";
        }
    }
    
    // Switch detection (multiple management ports)
    if (ports.contains(23) && ports.contains(80) && !ports.contains(22)) {
        return "switch";
    }
    
    // Printer detection
    if (ports.contains(515) || ports.contains(631) || ports.contains(9100)) {
        return "printer";
    }
    if (vendor.contains("HP", Qt::CaseInsensitive) || vendor.contains("Canon", Qt::CaseInsensitive) || 
        vendor.contains("Epson", Qt::CaseInsensitive) || vendor.contains("Brother", Qt::CaseInsensitive)) {
        return "printer";
    }
    
    // Phone/VoIP detection
    if (ports.contains(5060) || ports.contains(5061) || ports.contains(2000)) {
        return "phone";
    }
    if (vendor.contains("Cisco", Qt::CaseInsensitive) && (ports.contains(80) || ports.contains(443))) {
        return "phone";
    }
    
    // Audio device detection
    if (ports.contains(554) || ports.contains(8080)) {
        if (vendor.contains("Sonos", Qt::CaseInsensitive) || vendor.contains("Bose", Qt::CaseInsensitive)) {
            return "audio";
        }
    }
    
    // IoT device detection
    if (ports.contains(1883) || ports.contains(8883)) { // MQTT
        return "iot";
    }
    if (vendor.contains("Nest", Qt::CaseInsensitive) || vendor.contains("Ring", Qt::CaseInsensitive) ||
        vendor.contains("Philips", Qt::CaseInsensitive)) {
        return "iot";
    }
    
    // Camera detection
    if (ports.contains(554) || ports.contains(8080) || ports.contains(80)) {
        if (vendor.contains("Hikvision", Qt::CaseInsensitive) || vendor.contains("Dahua", Qt::CaseInsensitive) ||
            vendor.contains("Axis", Qt::CaseInsensitive)) {
            return "camera";
        }
    }
    
    // Server detection (Linux/Unix with server ports)
    if (ports.contains(22) && (ports.contains(80) || ports.contains(443) || ports.contains(3306) || ports.contains(5432))) {
        return "server";
    }
    
    // Windows workstation
    if (ports.contains(3389) || ports.contains(135) || ports.contains(445)) {
        return "workstation";
    }
    
    // macOS detection
    if (ports.contains(548) || ports.contains(5900)) {
        return "mac";
    }
    
    // Mobile device detection
    if (vendor.contains("Apple", Qt::CaseInsensitive) && !ports.contains(22)) {
        return "mobile";
    }
    
    // Default computer
    return "computer";
}

void NetworkMapper::buildNetworkTree()
{
    m_networkTree.clear();
    
    // Group hosts by subnet
    QHash<QString, QStringList> subnets;
    
    for (const HostProfile &profile : m_profiles) {
        QStringList ipParts = profile.ip.split('.');
        if (ipParts.size() == 4) {
            QString subnet = QString("%1.%2.%3").arg(ipParts[0], ipParts[1], ipParts[2]);
            subnets[subnet].append(profile.ip);
        }
    }
    
    // Build tree structure
    for (auto it = subnets.begin(); it != subnets.end(); ++it) {
        QString subnet = it.key();
        QStringList hosts = it.value();
        
        // Add subnet node
        m_networkTree << QString("SUBNET|%1.0/24|%2 hosts").arg(subnet).arg(hosts.size());
        
        // Add host nodes
        for (const QString &hostIP : hosts) {
            // Find profile for this host
            for (const HostProfile &profile : m_profiles) {
                if (profile.ip == hostIP) {
                    QString nodeInfo = QString("HOST|%1|%2|%3|%4")
                                      .arg(profile.ip)
                                      .arg(profile.osType.isEmpty() ? "Unknown" : profile.osType)
                                      .arg(profile.vendor.isEmpty() ? "Unknown" : profile.vendor)
                                      .arg(profile.services.join(","));
                    m_networkTree << nodeInfo;
                    break;
                }
            }
        }
    }
    
    qDebug() << "Built network tree with" << m_networkTree.size() << "nodes";
    emit networkTreeChanged();
}

void NetworkMapper::startQuickMapping()
{
    if (m_isMapping) return;
    
    qDebug() << "Starting quick mapping (ARP table only)";
    m_quickScan = true;
    
    // Get IPs from ARP table
    QList<ArpEntry> arpEntries = parseArpTable();
    QStringList arpIPs;
    
    for (const ArpEntry &entry : arpEntries) {
        arpIPs << entry.ip;
    }
    
    if (!arpIPs.isEmpty()) {
        startMapping(arpIPs);
    } else {
        qDebug() << "No IPs found in ARP table";
    }
}

void NetworkMapper::startFullMapping(const QString &subnet)
{
    if (m_isMapping) return;
    
    qDebug() << "Starting full mapping for subnet:" << subnet;
    m_quickScan = false;
    
    QStringList subnetIPs = getSubnetIPs(subnet);
    
    if (!subnetIPs.isEmpty()) {
        startMapping(subnetIPs);
    } else {
        qDebug() << "No IPs generated for subnet:" << subnet;
    }
}

QStringList NetworkMapper::getSubnetIPs(const QString &subnet)
{
    QStringList ips;
    QRegularExpression cidrRegex(R"((\d+\.\d+\.\d+\.\d+)/(\d+))");
    QRegularExpressionMatch match = cidrRegex.match(subnet);
    
    if (match.hasMatch()) {
        QString baseIP = match.captured(1);
        int prefix = match.captured(2).toInt();
        
        QHostAddress addr(baseIP);
        quint32 ip = addr.toIPv4Address();
        quint32 mask = 0xFFFFFFFF << (32 - prefix);
        quint32 networkAddr = ip & mask;
        quint32 broadcastAddr = networkAddr | (~mask);
        
        // Generate all IPs in subnet (limit to 254 for /24)
        int maxHosts = qMin(254, (int)(broadcastAddr - networkAddr - 1));
        
        for (quint32 i = networkAddr + 1; i <= networkAddr + maxHosts; ++i) {
            ips << QHostAddress(i).toString();
        }
    }
    
    qDebug() << "Generated" << ips.size() << "IPs for subnet" << subnet;
    return ips;
}


QHash<QString, QString> NetworkMapper::loadVendorDatabase(const QString &filePath)
{
    QHash<QString, QString> vendors = {
        // Virtual machines
        {"00:50:56", "VMware"}, {"08:00:27", "VirtualBox"}, {"00:0C:29", "VMware"},
        {"00:1C:42", "Parallels"}, {"00:15:5D", "Microsoft Hyper-V"}, {"00:16:3E", "Xen"},
        {"52:54:00", "QEMU/KVM"}, {"00:03:FF", "Microsoft Virtual PC"},

        // Network equipment
        {"00:1B:21", "Intel"}, {"00:E0:4C", "Realtek"}, {"00:90:27", "Intel"},
        {"00:A0:C9", "Intel"}, {"00:13:72", "Dell"}, {"00:14:22", "Dell"},
        {"00:1E:C9", "Cisco"}, {"00:26:99", "Cisco"}, {"00:50:E2", "Cisco"},

        // Common manufacturers
        {"00:23:6C", "Apple"}, {"00:25:00", "Apple"}, {"A4:C3:61", "Apple"},
        {"00:1A:A0", "Dell"}, {"00:21:70", "Dell"}, {"B8:AC:6F", "Dell"},
        {"00:1F:16", "Dell"}, {"00:26:B9", "Dell"}, {"18:03:73", "Dell"},
        {"00:15:17", "HP"}, {"00:1B:78", "HP"}, {"00:21:5A", "HP"},
        {"00:23:7D", "HP"}, {"3C:4A:92", "HP"}, {"70:10:6F", "HP"},
        {"00:50:8D", "Compaq"}, {"00:80:5F", "Compaq"},
        {"00:02:B3", "Intel"}, {"00:07:E9", "Intel"}, {"00:13:02", "Intel"},
        {"00:15:00", "Intel"}, {"00:16:76", "Intel"}, {"00:19:D1", "Intel"},
        {"00:1E:67", "Intel"}, {"00:21:6A", "Intel"}, {"00:24:D7", "Intel"},
        {"3C:97:0E", "Intel"}, {"A0:36:9F", "Intel"},
        {"00:60:97", "3Com"}, {"00:A0:24", "3Com"}, {"00:50:04", "3Com"}
    };

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Could not open vendor file:" << filePath;
        return vendors;  // Return static fallback only
    }

    QTextStream in(&file);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty()) continue;

        QStringList parts = line.split(",");
        if (parts.size() >= 2) {
            QString oui = parts[0].toUpper();
            QString vendor = parts[1].trimmed();
            // Do not overwrite hardcoded entries
            if (!vendors.contains(oui)) {
                vendors.insert(oui, vendor);
            }
        }
    }

    return vendors;
}
