#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>

struct ScanResult {
    QString ip;
    QString hostname;
    QString mac;
    QList<int> ports;
    QString status;
};

class ScanResultsModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT

public:
    enum Roles {
        IpRole = Qt::UserRole + 1,
        HostnameRole,
        MacRole,
        PortsRole,
        StatusRole
    };

    explicit ScanResultsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

public slots:
    void addResult(const QString &ip, const QString &hostname, const QString &mac, const QList<int> &ports);
    void clear();

private:
    QList<ScanResult> m_results;
};
