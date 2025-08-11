#include "CredentialManager.h"
#include <QDebug>
#include <QStandardPaths>
#include <QDir>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>

#include <QRandomGenerator>

CredentialManager::CredentialManager(QObject *parent)
    : QObject(parent)
    , m_nextId(1)
{
    // Initialize settings in secure location
    QString configPath = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    QDir().mkpath(configPath);
    m_settings = new QSettings(configPath + "/credentials.conf", QSettings::IniFormat, this);
    
    // Generate secure encryption key from system entropy
    generateEncryptionKey();
    
    loadCredentials();
}

void CredentialManager::addCredential(const QString &name, const QString &host, const QString &username, 
                                     const QString &password, const QString &type)
{
    Credential cred;
    cred.id = generateId();
    cred.name = name;
    cred.host = host;
    cred.username = username;
    cred.password = encryptPassword(password);
    cred.type = type;
    cred.lastUsed = QDateTime::currentDateTime().toString(Qt::ISODate);
    cred.isDefault = false;
    
    m_credentials.append(cred);
    saveCredentials();
    
    qDebug() << "Added credential:" << name << "for host:" << host;
    qDebug() << "Activity: Credential added -" << name << "for" << host << "type" << type;
    emit credentialAdded(cred.id, name, host, type);
    emit credentialCountChanged();
}

void CredentialManager::addSSHKey(const QString &name, const QString &host, const QString &username, 
                                 const QString &privateKey)
{
    Credential cred;
    cred.id = generateId();
    cred.name = name;
    cred.host = host;
    cred.username = username;
    cred.privateKey = encryptPassword(privateKey); // Encrypt SSH key too
    cred.type = "SSH Key";
    cred.lastUsed = QDateTime::currentDateTime().toString(Qt::ISODate);
    cred.isDefault = false;
    
    m_credentials.append(cred);
    saveCredentials();
    
    emit credentialAdded(cred.id, name, host, "SSH Key");
    emit credentialCountChanged();
}

void CredentialManager::removeCredential(int id)
{
    for (int i = 0; i < m_credentials.size(); ++i) {
        if (m_credentials[i].id == id) {
            QString removedName = m_credentials[i].name;
            QString removedHost = m_credentials[i].host;
            m_credentials.removeAt(i);
            saveCredentials();
            
            qDebug() << "Activity: Credential removed -" << removedName << "for" << removedHost;
            emit credentialRemoved(id);
            emit credentialCountChanged();
            break;
        }
    }
}

QJsonObject CredentialManager::getCredentialForHost(const QString &host)
{
    // First check if there's a default credential for this host
    if (m_hostDefaults.contains(host)) {
        int defaultId = m_hostDefaults[host];
        QJsonObject defaultCred = getCredentialById(defaultId);
        if (!defaultCred.isEmpty()) {
            return defaultCred;
        }
    }
    
    // Look for exact host match
    for (const Credential &cred : m_credentials) {
        if (cred.host == host) {
            QJsonObject obj;
            obj["id"] = cred.id;
            obj["name"] = cred.name;
            obj["host"] = cred.host;
            obj["username"] = cred.username;
            obj["password"] = decryptPassword(cred.password);
            obj["privateKey"] = decryptPassword(cred.privateKey);
            obj["type"] = cred.type;
            
            // Update last used
            const_cast<Credential&>(cred).lastUsed = QDateTime::currentDateTime().toString(Qt::ISODate);
            saveCredentials();
            
            return obj;
        }
    }
    
    // Look for wildcard or subnet match
    for (const Credential &cred : m_credentials) {
        if (cred.host.contains("*") || cred.host.contains("/")) {
            // Simple wildcard matching (could be enhanced)
            if (host.startsWith(cred.host.left(cred.host.indexOf('*')))) {
                QJsonObject obj;
                obj["id"] = cred.id;
                obj["username"] = cred.username;
                obj["password"] = decryptPassword(cred.password);
                obj["privateKey"] = decryptPassword(cred.privateKey);
                obj["type"] = cred.type;
                return obj;
            }
        }
    }
    
    qDebug() << "No credential found for host:" << host;
    emit credentialNotFound(host);
    return QJsonObject();
}

QJsonObject CredentialManager::getCredentialById(int id)
{
    for (const Credential &cred : m_credentials) {
        if (cred.id == id) {
            QJsonObject obj;
            obj["id"] = cred.id;
            obj["name"] = cred.name;
            obj["host"] = cred.host;
            obj["username"] = cred.username;
            obj["password"] = decryptPassword(cred.password);
            obj["privateKey"] = decryptPassword(cred.privateKey);
            obj["type"] = cred.type;
            obj["lastUsed"] = cred.lastUsed;
            return obj;
        }
    }
    return QJsonObject();
}

QJsonArray CredentialManager::getAllCredentials()
{
    QJsonArray array;
    for (const Credential &cred : m_credentials) {
        QJsonObject obj;
        obj["id"] = cred.id;
        obj["name"] = cred.name;
        obj["host"] = cred.host;
        obj["username"] = cred.username;
        obj["type"] = cred.type;
        obj["lastUsed"] = cred.lastUsed;
        // Don't include password/key in list view
        array.append(obj);
    }
    return array;
}

void CredentialManager::setDefaultCredentialForHost(const QString &host, int credentialId)
{
    m_hostDefaults[host] = credentialId;
    
    // Save host defaults
    m_settings->beginGroup("HostDefaults");
    m_settings->setValue(host, credentialId);
    m_settings->endGroup();
    m_settings->sync();
    
    qDebug() << "Set default credential" << credentialId << "for host" << host;
}

bool CredentialManager::testCredential(int id)
{
    // This would test the credential by attempting a connection
    // For now, just return true if credential exists
    return !getCredentialById(id).isEmpty();
}

void CredentialManager::loadCredentials()
{
    m_credentials.clear();
    
    int size = m_settings->beginReadArray("Credentials");
    for (int i = 0; i < size; ++i) {
        m_settings->setArrayIndex(i);
        
        Credential cred;
        cred.id = m_settings->value("id").toInt();
        cred.name = m_settings->value("name").toString();
        cred.host = m_settings->value("host").toString();
        cred.username = m_settings->value("username").toString();
        cred.password = m_settings->value("password").toString();
        cred.privateKey = m_settings->value("privateKey").toString();
        cred.type = m_settings->value("type").toString();
        cred.lastUsed = m_settings->value("lastUsed").toString();
        cred.isDefault = m_settings->value("isDefault").toBool();
        
        m_credentials.append(cred);
        m_nextId = qMax(m_nextId, cred.id + 1);
    }
    m_settings->endArray();
    
    // Load host defaults
    m_settings->beginGroup("HostDefaults");
    QStringList hosts = m_settings->childKeys();
    for (const QString &host : hosts) {
        m_hostDefaults[host] = m_settings->value(host).toInt();
    }
    m_settings->endGroup();
    
    qDebug() << "Loaded" << m_credentials.size() << "credentials";
}

void CredentialManager::saveCredentials()
{
    m_settings->beginWriteArray("Credentials");
    for (int i = 0; i < m_credentials.size(); ++i) {
        m_settings->setArrayIndex(i);
        const Credential &cred = m_credentials[i];
        
        m_settings->setValue("id", cred.id);
        m_settings->setValue("name", cred.name);
        m_settings->setValue("host", cred.host);
        m_settings->setValue("username", cred.username);
        m_settings->setValue("password", cred.password);
        m_settings->setValue("privateKey", cred.privateKey);
        m_settings->setValue("type", cred.type);
        m_settings->setValue("lastUsed", cred.lastUsed);
        m_settings->setValue("isDefault", cred.isDefault);
    }
    m_settings->endArray();
    m_settings->sync();
}

QString CredentialManager::encryptPassword(const QString &password)
{
    if (password.isEmpty()) return QString();
    
    // Simple XOR encryption (in production, use proper AES encryption)
    QByteArray data = password.toUtf8();
    QByteArray key = m_encryptionKey.toUtf8();
    
    for (int i = 0; i < data.size(); ++i) {
        data[i] = data[i] ^ key[i % key.size()];
    }
    
    return data.toBase64();
}

QString CredentialManager::decryptPassword(const QString &encryptedPassword)
{
    if (encryptedPassword.isEmpty()) return QString();
    
    QByteArray data = QByteArray::fromBase64(encryptedPassword.toUtf8());
    QByteArray key = m_encryptionKey.toUtf8();
    
    for (int i = 0; i < data.size(); ++i) {
        data[i] = data[i] ^ key[i % key.size()];
    }
    
    return QString::fromUtf8(data);
}

void CredentialManager::updateCredential(int id, const QString &name, const QString &host, 
                                         const QString &username, const QString &password, const QString &type)
{
    for (Credential &cred : m_credentials) {
        if (cred.id == id) {
            cred.name = name;
            cred.host = host;
            cred.username = username;
            if (!password.isEmpty()) {
                cred.password = encryptPassword(password);
            }
            cred.type = type;
            cred.lastUsed = QDateTime::currentDateTime().toString(Qt::ISODate);
            
            saveCredentials();
            emit credentialUpdated(id);
            break;
        }
    }
}

void CredentialManager::generateEncryptionKey()
{
    // Generate secure 32-byte key from system entropy
    QByteArray entropy;
    QFile urandom("/dev/urandom");
    if (urandom.open(QIODevice::ReadOnly)) {
        entropy = urandom.read(32);
        urandom.close();
    } else {
        // Fallback for Windows - use current time + process ID
        entropy = QByteArray::number(QDateTime::currentMSecsSinceEpoch());
        entropy += QByteArray::number(QCoreApplication::applicationPid());
        entropy += QByteArray::number(QRandomGenerator::global()->bounded(100));
    }
    
    m_encryptionKey = entropy.toBase64().left(32);
}

int CredentialManager::generateId()
{
    return m_nextId++;
}
