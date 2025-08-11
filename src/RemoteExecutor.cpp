#include "RemoteExecutor.h"
#include "CredentialManager.h"
#include <QDebug>
#include <QRegularExpression>
#include <QHostAddress>
#include <QJsonObject>
#include <QFileInfo>

RemoteExecutor::RemoteExecutor(QObject *parent)
    : QObject(parent)
    , m_isExecuting(false)
    , m_nextJobId(1)
    , m_credentialManager(nullptr)
{
}

void RemoteExecutor::setCredentialManager(CredentialManager *credManager)
{
    m_credentialManager = credManager;
}

void RemoteExecutor::executeCommand(const QString &targets, const QString &command, const QString &protocol)
{
    QStringList targetList = parseTargets(targets);
    
    for (const QString &target : targetList) {
        int jobId = generateJobId();
        
        ExecutionJob job;
        job.id = jobId;
        job.type = "Command Execution";
        job.target = target;
        job.command = command;
        job.protocol = protocol;
        job.status = "running";
        job.progress = 0;
        job.process = nullptr;
        
        m_activeJobs[jobId] = job;
        
        qDebug() << "Starting command execution on" << target << "via" << protocol;
        emit jobStarted(jobId, job.type, target);
        
        // Log activity for audit trail
        qDebug() << "Activity: Command execution started -" << protocol << "on" << target;
        
        // Get credential for target
        QJsonObject credential = getOrPromptCredential(target, protocol);
        if (credential.isEmpty()) {
            emit credentialRequired(target, protocol, jobId);
            continue; // Don't remove job, wait for credential
        }
        
        // Execute based on protocol
        if (protocol == "SSH") {
            executeSSH(target, command, jobId, credential);
        } else if (protocol == "WinRM") {
            executeWinRM(target, command, jobId, credential);
        } else if (protocol == "PowerShell") {
            executePowerShell(target, command, jobId, credential);
        } else if (protocol == "WMI") {
            executeWMI(target, command, jobId, credential);
        } else if (protocol == "SCHTASKS") {
            executeSCHTASKS(target, command, jobId, credential);
        } else if (protocol == "Custom") {
            executeCustom(target, command, jobId, credential);
        }
    }
    
    m_isExecuting = !m_activeJobs.isEmpty();
    emit isExecutingChanged();
    emit activeJobsChanged();
}

void RemoteExecutor::executeQuickCommand(const QString &targets, const QString &command)
{
    // Auto-detect protocol based on target OS or use SSH as default
    executeCommand(targets, command, "SSH");
}

void RemoteExecutor::stopExecution(int jobId)
{
    if (m_activeJobs.contains(jobId)) {
        ExecutionJob &job = m_activeJobs[jobId];
        if (job.process) {
            job.process->kill();
            job.process->waitForFinished(3000);
        }
        job.status = "stopped";
        job.progress = 100;
        
        emit jobCompleted(jobId, "Execution stopped by user");
        m_activeJobs.remove(jobId);
        
        m_isExecuting = !m_activeJobs.isEmpty();
        emit isExecutingChanged();
        emit activeJobsChanged();
    }
}

void RemoteExecutor::deployFile(const QString &sourcePath, const QString &destPath, const QString &targets, const QString &protocol)
{
    qDebug() << "=== FILE DEPLOY INPUT ===";
    qDebug() << "Source Path:" << sourcePath;
    qDebug() << "Dest Path:" << destPath;
    qDebug() << "Targets:" << targets;
    qDebug() << "Protocol:" << protocol;
    
    QStringList targetList = parseTargets(targets);
    qDebug() << "Parsed Targets:" << targetList;
    
    for (const QString &target : targetList) {
        int jobId = generateJobId();
        
        ExecutionJob job;
        job.id = jobId;
        job.type = "File Deploy";
        job.target = target;
        job.command = QString("Deploy %1 to %2").arg(sourcePath, destPath);
        job.protocol = protocol;
        job.status = "running";
        job.progress = 0;
        job.process = nullptr;
        
        m_activeJobs[jobId] = job;
        
        emit jobStarted(jobId, job.type, target);
        
        QJsonObject credential = getOrPromptCredential(target, protocol);
        if (credential.isEmpty()) {
            emit jobFailed(jobId, "No credential available for " + target);
            m_activeJobs.remove(jobId);
            continue;
        }
        
        if (protocol == "SCP/SFTP") {
            transferSCP(sourcePath, destPath, target, true, jobId, credential);
        } else if (protocol == "SMB") {
            transferSMB(sourcePath, destPath, target, true, jobId, credential);
        }
    }
    
    m_isExecuting = !m_activeJobs.isEmpty();
    emit isExecutingChanged();
    emit activeJobsChanged();
}

void RemoteExecutor::retrieveFile(const QString &sourcePath, const QString &destPath, const QString &targets, const QString &protocol)
{
    qDebug() << "=== FILE RETRIEVE INPUT ===";
    qDebug() << "Source Path:" << sourcePath;
    qDebug() << "Dest Path:" << destPath;
    qDebug() << "Targets:" << targets;
    qDebug() << "Protocol:" << protocol;
    
    QStringList targetList = parseTargets(targets);
    qDebug() << "Parsed Targets:" << targetList;
    
    for (const QString &target : targetList) {
        int jobId = generateJobId();
        
        ExecutionJob job;
        job.id = jobId;
        job.type = "File Retrieve";
        job.target = target;
        job.command = QString("Retrieve %1 to %2").arg(sourcePath, destPath);
        job.protocol = protocol;
        job.status = "running";
        job.progress = 0;
        job.process = nullptr;
        
        m_activeJobs[jobId] = job;
        
        emit jobStarted(jobId, job.type, target);
        
        QJsonObject credential = getOrPromptCredential(target, protocol);
        if (credential.isEmpty()) {
            emit jobFailed(jobId, "No credential available for " + target);
            m_activeJobs.remove(jobId);
            continue;
        }
        
        if (protocol == "SCP/SFTP") {
            transferSCP(sourcePath, destPath, target, false, jobId, credential);
        } else if (protocol == "SMB") {
            transferSMB(sourcePath, destPath, target, false, jobId, credential);
        }
    }
    
    m_isExecuting = !m_activeJobs.isEmpty();
    emit isExecutingChanged();
    emit activeJobsChanged();
}

void RemoteExecutor::executeSSH(const QString &target, const QString &command, int jobId, const QJsonObject &credential)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    connect(process, &QProcess::readyReadStandardError, this, &RemoteExecutor::onProcessOutput);
    
    QStringList args;
    args << "-o" << "StrictHostKeyChecking=no"
         << "-o" << "ConnectTimeout=10";
    
    QString username = credential["username"].toString();
    QString password = credential["password"].toString();
    QString privateKey = credential["privateKey"].toString();
    
    if (!privateKey.isEmpty()) {
        // Use SSH key authentication
        QString keyFile = "/tmp/ssh_key_" + QString::number(jobId);
        QFile file(keyFile);
        if (file.open(QIODevice::WriteOnly)) {
            file.write(privateKey.toUtf8());
            file.close();
            file.setPermissions(QFile::ReadOwner);
        }
        args << "-i" << keyFile;
    }
    
    if (!username.isEmpty()) {
        args << "-l" << username;
    }
    
    args << target;
    
    // Sanitize command to prevent injection
    QString sanitizedCommand = command;
    sanitizedCommand.replace(QRegularExpression("[;&|`$(){}\[\]<>\"'\\\\]"), "");
    args << sanitizedCommand;
    
    if (!password.isEmpty() && privateKey.isEmpty()) {
        // Use sshpass for password authentication
        QStringList sshpassArgs;
        sshpassArgs << "-p" << password << "ssh" << args;
        qDebug() << "SSH Command:" << "sshpass" << sshpassArgs.join(" ");
        process->start("sshpass", sshpassArgs);
    } else {
        qDebug() << "SSH Command:" << "ssh" << args.join(" ");
        process->start("ssh", args);
    }
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start SSH process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::executeWinRM(const QString &target, const QString &command, int jobId)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
#ifdef Q_OS_WIN
    // Use winrs for WinRM
    QStringList args;
    args << "-r:" + target << command;
    
    qDebug() << "WinRM Command:" << "winrs" << args.join(" ");
    process->start("winrs", args);
#else
    // Use PowerShell Core with WinRM on Linux/macOS
    QStringList args;
    args << "-Command" 
         << QString("Invoke-Command -ComputerName %1 -ScriptBlock {%2}").arg(target, command);
    
    process->start("pwsh", args);
#endif
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start WinRM process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::executePowerShell(const QString &target, const QString &command, int jobId)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    // PowerShell remoting
    QStringList args;
    // Sanitize command to prevent injection
    QString sanitizedCommand = command;
    sanitizedCommand.replace(QRegularExpression("[;&|`$(){}\[\]<>\"'\\\\]"), "");
    
    args << "-Command" 
         << QString("Invoke-Command -ComputerName %1 -ScriptBlock {%2}").arg(target, sanitizedCommand);
    
    qDebug() << "Executing PowerShell:" << "powershell" << args.join(" ");
    
#ifdef Q_OS_WIN
    process->start("powershell", args);
#else
    process->start("pwsh", args); // PowerShell Core
#endif
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start PowerShell process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::transferSCP(const QString &source, const QString &dest, const QString &target, bool upload, int jobId)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    QStringList args;
    args << "-o" << "StrictHostKeyChecking=no";
    
    if (upload) {
        // Upload: local -> remote
        args << source << target + ":" + dest;
    } else {
        // Download: remote -> local
        args << target + ":" + source << dest;
    }
    
    qDebug() << "Executing SCP:" << "scp" << args.join(" ");
    process->start("scp", args);
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start SCP process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::transferSMB(const QString &source, const QString &dest, const QString &target, bool upload, int jobId)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
#ifdef Q_OS_WIN
    // Use robocopy for Windows SMB transfers
    QStringList args;
    if (upload) {
        args << QFileInfo(source).path() << "\\\\" + target + "\\" + QFileInfo(dest).path() 
             << QFileInfo(source).fileName();
    } else {
        args << "\\\\" + target + "\\" + QFileInfo(source).path() << QFileInfo(dest).path()
             << QFileInfo(source).fileName();
    }
    
    process->start("robocopy", args);
#else
    // Use smbclient on Linux/macOS
    QStringList args;
    args << "//" + target + "/share";
    
    if (upload) {
        args << "-c" << "put " + source + " " + dest;
    } else {
        args << "-c" << "get " + source + " " + dest;
    }
    
    process->start("smbclient", args);
#endif
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start SMB transfer");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::onProcessFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    QProcess *process = qobject_cast<QProcess*>(sender());
    if (!process || !m_processJobs.contains(process)) return;
    
    int jobId = m_processJobs[process];
    m_processJobs.remove(process);
    
    if (m_activeJobs.contains(jobId)) {
        ExecutionJob &job = m_activeJobs[jobId];
        job.progress = 100;
        
        if (exitCode == 0 && exitStatus == QProcess::NormalExit) {
            job.status = "completed";
            emit jobCompleted(jobId, job.output);
        } else {
            job.status = "failed";
            QString error = process->readAllStandardError();
            emit jobFailed(jobId, error.isEmpty() ? "Process failed" : error);
        }
        
        m_activeJobs.remove(jobId);
    }
    
    process->deleteLater();
    
    m_isExecuting = !m_activeJobs.isEmpty();
    emit isExecutingChanged();
    emit activeJobsChanged();
}

void RemoteExecutor::onProcessOutput()
{
    QProcess *process = qobject_cast<QProcess*>(sender());
    if (!process || !m_processJobs.contains(process)) return;
    
    int jobId = m_processJobs[process];
    QString output = process->readAllStandardOutput();
    
    if (m_activeJobs.contains(jobId)) {
        m_activeJobs[jobId].output += output;
        m_activeJobs[jobId].progress = qMin(90, m_activeJobs[jobId].progress + 10);
        
        emit outputReceived(jobId, output);
        emit jobProgress(jobId, m_activeJobs[jobId].progress);
    }
}

QStringList RemoteExecutor::parseTargets(const QString &targets)
{
    QStringList result;
    
    // Handle range format: 192.168.1.100-110
    QRegularExpression rangeRegex(R"((\d+\.\d+\.\d+\.)(\d+)-(\d+))");
    QRegularExpressionMatch rangeMatch = rangeRegex.match(targets);
    
    if (rangeMatch.hasMatch()) {
        QString baseIP = rangeMatch.captured(1);
        int startHost = rangeMatch.captured(2).toInt();
        int endHost = rangeMatch.captured(3).toInt();
        
        for (int i = startHost; i <= endHost; ++i) {
            result << baseIP + QString::number(i);
        }
    } else {
        // Handle comma-separated list
        QStringList parts = targets.split(QRegularExpression("[,;\\s]+"), Qt::SkipEmptyParts);
        for (const QString &part : parts) {
            QString trimmed = part.trimmed();
            if (!trimmed.isEmpty()) {
                result << trimmed;
            }
        }
    }
    
    return result;
}

QJsonObject RemoteExecutor::getOrPromptCredential(const QString &host, const QString &protocol)
{
    if (!m_credentialManager) {
        qWarning() << "No credential manager available";
        return QJsonObject();
    }
    
    // Try to get existing credential for host
    QJsonObject credential = m_credentialManager->getCredentialForHost(host);
    
    if (credential.isEmpty()) {
        qDebug() << "No credential found for host:" << host << "protocol:" << protocol;
        // In a real implementation, this would trigger a credential prompt dialog
        // For now, emit signal to request credential input
        emit m_credentialManager->credentialPromptRequired(host, protocol);
    }
    
    return credential;
}

void RemoteExecutor::executeWinRM(const QString &target, const QString &command, int jobId, const QJsonObject &credential)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    QString username = credential["username"].toString();
    QString password = credential["password"].toString();
    
#ifdef Q_OS_WIN
    QStringList args;
    args << "-r:" + target << "-u:" + username << "-p:" + password << command;
    process->start("winrs", args);
#else
    QStringList args;
    args << "-Command" << QString("Invoke-Command -ComputerName %1 -Credential (New-Object PSCredential('%2', (ConvertTo-SecureString '%3' -AsPlainText -Force))) -ScriptBlock {%4}")
                           .arg(target, username, password, command);
    process->start("pwsh", args);
#endif
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start WinRM process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::executePowerShell(const QString &target, const QString &command, int jobId, const QJsonObject &credential)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    QString username = credential["username"].toString();
    QString password = credential["password"].toString();
    
    QStringList args;
    // Sanitize command to prevent injection
    QString sanitizedCommand = command;
    sanitizedCommand.replace(QRegularExpression("[;&|`$(){}\[\]<>\"'\\\\]"), "");
    
    args << "-Command" << QString("Invoke-Command -ComputerName %1 -Credential (New-Object PSCredential('%2', (ConvertTo-SecureString '%3' -AsPlainText -Force))) -ScriptBlock {%4}")
                         .arg(target, username, password, sanitizedCommand);
    
#ifdef Q_OS_WIN
    process->start("powershell", args);
#else
    process->start("pwsh", args);
#endif
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start PowerShell process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::transferSCP(const QString &source, const QString &dest, const QString &target, bool upload, int jobId, const QJsonObject &credential)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    QString username = credential["username"].toString();
    QString password = credential["password"].toString();
    
    QStringList args;
    args << "-o" << "StrictHostKeyChecking=no";
    
    if (upload) {
        args << source << username + "@" + target +":" + dest;
    } else {
        args << username + "@" + target +":" + source << dest;
    }
    
    if (!password.isEmpty()) {
        QStringList sshpassArgs;
        sshpassArgs << "-p" << password << "scp" << args;
        qDebug() << "SCP Command:" << "sshpass" << sshpassArgs.join(" ");
        process->start("sshpass", sshpassArgs);
    } else {
        qDebug() << "SCP Command:" << "scp" << args.join(" ");
        process->start("scp", args);
    }
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start SCP process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::transferSMB(const QString &source, const QString &dest, const QString &target, bool upload, int jobId, const QJsonObject &credential)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    QString username = credential["username"].toString();
    QString password = credential["password"].toString();
    
#ifdef Q_OS_WIN
    QString netCommand;
    if (upload) {
        // Upload: local -> remote
        netCommand = QString("net use \\\\%1\\C$ /user:%2 %3 && copy %4 \\\\%1\\C$\\%5 && net use \\\\%1\\C$ /delete")
                    .arg(target, username, password, source, dest);
    } else {
        // Download: remote -> local  
        netCommand = QString("net use \\\\%1\\C$ /user:%2 %3 && copy \\\\%1\\C$\\%4 %5 && net use \\\\%1\\C$ /delete")
                    .arg(target, username, password, source, dest);
    }
    
    qDebug() << "SMB Command:" << "cmd /c" << netCommand;
    
    QStringList args;
    args << "/c" << netCommand;
    process->start("cmd", args);
#else
    QStringList args;
    args << "//" + target + "/C$" << "-U" << username + "%" + password;
    if (upload) {
        args << "-c" << "put " + source + " " + dest;
    } else {
        args << "-c" << "get " + source + " " + dest;
    }
    process->start("smbclient", args);
#endif
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start SMB transfer");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::executeWithCredential(int jobId, const QString &username, const QString &password)
{
    if (!m_activeJobs.contains(jobId)) return;
    
    ExecutionJob &job = m_activeJobs[jobId];
    
    QJsonObject credential;
    credential["username"] = username;
    credential["password"] = password;
    credential["type"] = "Password";
    
    if (job.protocol == "SSH") {
        executeSSH(job.target, job.command, jobId, credential);
    } else if (job.protocol == "WinRM") {
        executeWinRM(job.target, job.command, jobId, credential);
    } else if (job.protocol == "PowerShell") {
        executePowerShell(job.target, job.command, jobId, credential);
    } else if (job.protocol == "WMI") {
        executeWMI(job.target, job.command, jobId, credential);
    } else if (job.protocol == "SCHTASKS") {
        executeSCHTASKS(job.target, job.command, jobId, credential);
    } else if (job.protocol == "Custom") {
        executeCustom(job.target, job.command, jobId, credential);
    } else if (job.protocol == "SCHTASKS") {
        executeSCHTASKS(job.target, job.command, jobId, credential);
    }
}

void RemoteExecutor::executeWMI(const QString &target, const QString &command, int jobId, const QJsonObject &credential)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    QString username = credential["username"].toString();
    QString password = credential["password"].toString();
    
    QStringList args;
    args << "/node:" + target
         << "/user:" + username
         << "/password:" + password
         << "process" << "call" << "create"
         << "\"cmd.exe /c " + command + "\"";
    
    qDebug() << "Executing WMI:" << "wmic" << args.join(" ");
    process->start("wmic", args);
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start WMI process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

void RemoteExecutor::executeSCHTASKS(const QString &target, const QString &command, int jobId, const QJsonObject &credential)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    QString username = credential["username"].toString();
    QString password = credential["password"].toString();
    QString taskName = "NetSecOps_" + QString::number(jobId);
    
    // Use raw command without any processing
    QString batchCommand = QString(
        "schtasks /Create /S %1 /U %2 /P %3 /TN %4 /TR \"%5\" /SC ONCE /ST 00:00 /RL HIGHEST /F && "
        "schtasks /Run /S %1 /U %2 /P %3 /TN %4"
    ).arg(target, username, password, taskName, command);
    
    qDebug() << "Executing SCHTASKS:" << batchCommand;
    process->start("cmd", QStringList() << "/c" << batchCommand);
    
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start SCHTASKS process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}

int RemoteExecutor::generateJobId()
{
    return m_nextJobId++;
}

void RemoteExecutor::executeCustom(const QString &target, const QString &command, int jobId, const QJsonObject &credential)
{
    QProcess *process = new QProcess(this);
    m_processJobs[process] = jobId;
    m_activeJobs[jobId].process = process;
    
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &RemoteExecutor::onProcessFinished);
    connect(process, &QProcess::readyReadStandardOutput, this, &RemoteExecutor::onProcessOutput);
    
    qDebug() << "Executing Custom:" << command;
    process->start("cmd", QStringList() << "/c" << command);
    
    if (!process->waitForStarted(5000)) {
        emit jobFailed(jobId, "Failed to start Custom process");
        m_activeJobs.remove(jobId);
        process->deleteLater();
    }
}
