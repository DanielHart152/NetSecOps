#include "ScanResultsModel.h"
#include <QDebug>

ScanResultsModel::ScanResultsModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ScanResultsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_results.size();
}

QVariant ScanResultsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_results.size())
        return QVariant();

    const ScanResult &result = m_results[index.row()];

    switch (role) {
    case IpRole:
        return result.ip;
    case HostnameRole:
        return result.hostname;
    case MacRole:{
        return result.mac;
    }
    case PortsRole: {
        QVariantList list;
        for (int port : result.ports)
            list.append(port);
        return list;
    }
    case StatusRole:
        return result.status;
    }

    return QVariant();
}

QHash<int, QByteArray> ScanResultsModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IpRole] = "ip";
    roles[HostnameRole] = "hostname";
    roles[MacRole] = "mac";
    roles[PortsRole] = "ports";
    roles[StatusRole] = "status";
    return roles;
}

void ScanResultsModel::addResult(const QString &ip, const QString &hostname, const QString &mac, const QList<int> &ports)
{
    beginInsertRows(QModelIndex(), m_results.size(), m_results.size());
    
    ScanResult result;
    result.ip = ip;
    result.hostname = hostname;
    result.mac = mac;
    result.ports = ports;
    result.status = "online";
    
    qDebug() << "Adding result:" << ip << "with" << ports.size() << "ports:" << ports;
    
    m_results.append(result);
    endInsertRows();
}

void ScanResultsModel::clear()
{
    beginResetModel();
    m_results.clear();
    endResetModel();
}
