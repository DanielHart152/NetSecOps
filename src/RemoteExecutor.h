#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QStringList>
#include <QHash>
#include <QJsonObject>
#include <QJsonArray>

class CredentialManager;

struct ExecutionJob {
    int id;
    QString type;
    QString target;
    QString command;
    QString protocol;
    QString status;
    int progress;
    QString output;
    QProcess *process;
};

class RemoteExecutor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isExecuting READ isExecuting NOTIFY isExecutingChanged)
    Q_PROPERTY(int activeJobs READ activeJobs NOTIFY activeJobsChanged)

public:
    explicit RemoteExecutor(QObject *parent = nullptr);
    Q_INVOKABLE void setCredentialManager(CredentialManager *credManager);
    
    bool isExecuting() const { return m_isExecuting; }
    int activeJobs() const { return m_activeJobs.size(); }

    void transferSMB(const QString &source, const QString &dest, const QString &target, bool upload, int jobId);

    void executeWinRM(const QString &target, const QString &command, int jobId);
    void executePowerShell(const QString &target, const QString &command, int jobId);

    void transferSCP(const QString &source, const QString &dest, const QString &target, bool upload, int jobId);

public slots:
    void executeCommand(const QString &targets, const QString &command, const QString &protocol);
    void executeQuickCommand(const QString &targets, const QString &command);
    void stopExecution(int jobId);
    void deployFile(const QString &sourcePath, const QString &destPath, const QString &targets, const QString &protocol);
    void retrieveFile(const QString &sourcePath, const QString &destPath, const QString &targets, const QString &protocol);
    Q_INVOKABLE void executeWithCredential(int jobId, const QString &username, const QString &password);

signals:
    void isExecutingChanged();
    void activeJobsChanged();
    void jobStarted(int jobId, const QString &type, const QString &target);
    void jobProgress(int jobId, int progress);
    void jobCompleted(int jobId, const QString &output);
    void jobFailed(int jobId, const QString &error);
    void outputReceived(int jobId, const QString &output);
    void credentialRequired(const QString &host, const QString &protocol, int jobId);

private slots:
    void onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessOutput();

private:
    void executeSSH(const QString &target, const QString &command, int jobId, const QJsonObject &credential);
    void executeWinRM(const QString &target, const QString &command, int jobId, const QJsonObject &credential);
    void executePowerShell(const QString &target, const QString &command, int jobId, const QJsonObject &credential);
    void executeWMI(const QString &target, const QString &command, int jobId, const QJsonObject &credential);
    void executeSCHTASKS(const QString &target, const QString &command, int jobId, const QJsonObject &credential);
    void executeCustom(const QString &target, const QString &command, int jobId, const QJsonObject &credential);
    void transferSCP(const QString &source, const QString &dest, const QString &target, bool upload, int jobId, const QJsonObject &credential);
    void transferSMB(const QString &source, const QString &dest, const QString &target, bool upload, int jobId, const QJsonObject &credential);
    QJsonObject getOrPromptCredential(const QString &host, const QString &protocol);
    QStringList parseTargets(const QString &targets);
    int generateJobId();
    
    bool m_isExecuting;
    QHash<int, ExecutionJob> m_activeJobs;
    QHash<QProcess*, int> m_processJobs;
    int m_nextJobId;
    CredentialManager *m_credentialManager;
};
