#pragma once

#include <QObject>
#include <QSettings>
#include <QCryptographicHash>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QCoreApplication>
#include <QFile>

struct Credential {
    int id;
    QString name;
    QString host;
    QString username;
    QString password;
    QString privateKey;
    QString type; // SSH, Password, Windows, Domain
    QString lastUsed;
    bool isDefault;
};

class CredentialManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int credentialCount READ credentialCount NOTIFY credentialCountChanged)

public:
    explicit CredentialManager(QObject *parent = nullptr);
    
    int credentialCount() const { return m_credentials.size(); }

public slots:
    void addCredential(const QString &name, const QString &host, const QString &username, 
                      const QString &password, const QString &type);
    void addSSHKey(const QString &name, const QString &host, const QString &username, 
                   const QString &privateKey);
    void removeCredential(int id);
    void updateCredential(int id, const QString &name, const QString &host, 
                         const QString &username, const QString &password, const QString &type);
    
    // Get credentials for specific host
    QJsonObject getCredentialForHost(const QString &host);
    QJsonObject getCredentialById(int id);
    QJsonArray getAllCredentials();
    
    // Test credential
    bool testCredential(int id);
    
    // Auto-credential selection
    void setDefaultCredentialForHost(const QString &host, int credentialId);

signals:
    void credentialCountChanged();
    void credentialAdded(int id, const QString &name, const QString &host, const QString &type);
    void credentialRemoved(int id);
    void credentialUpdated(int id);
    void credentialNotFound(const QString &host);
    void credentialPromptRequired(const QString &host, const QString &protocol);

private:
    void loadCredentials();
    void saveCredentials();
    void generateEncryptionKey();
    QString encryptPassword(const QString &password);
    QString decryptPassword(const QString &encryptedPassword);
    int generateId();
    
    QList<Credential> m_credentials;
    QHash<QString, int> m_hostDefaults; // host -> credential ID mapping
    QSettings *m_settings;
    QString m_encryptionKey;
    int m_nextId;
};
