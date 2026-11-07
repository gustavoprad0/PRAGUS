#pragma once

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QTimer>
#include <QProcess>
#include <QVariantList>
#include <QJsonObject>

class DashboardClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString greeting READ greeting NOTIFY clockChanged)
    Q_PROPERTY(QString localDate READ localDate NOTIFY clockChanged)
    Q_PROPERTY(QString localTime READ localTime NOTIFY clockChanged)
    Q_PROPERTY(QString weatherLocation READ weatherLocation NOTIFY weatherChanged)
    Q_PROPERTY(bool weatherStale MEMBER m_weatherStale NOTIFY weatherChanged)
    Q_PROPERTY(QString weatherStatus READ weatherStatus NOTIFY weatherChanged)
    Q_PROPERTY(QString weatherSummary READ weatherSummary NOTIFY weatherChanged)
    Q_PROPERTY(QString weatherTemperature READ weatherTemperature NOTIFY weatherChanged)
    Q_PROPERTY(QStringList usbDevices READ usbDevices NOTIFY changed)
    Q_PROPERTY(QVariantList forecast READ forecast NOTIFY weatherChanged)
    Q_PROPERTY(QVariantList news READ news NOTIFY newsChanged)
    Q_PROPERTY(bool newsBusy MEMBER m_newsBusy NOTIFY newsChanged)
    Q_PROPERTY(QString newsStatus READ newsStatus NOTIFY newsChanged)
    Q_PROPERTY(double cpuUsage READ cpuUsage NOTIFY changed)
    Q_PROPERTY(double memoryUsedGiB MEMBER m_memoryUsedGiB NOTIFY changed)
    Q_PROPERTY(double memoryTotalGiB MEMBER m_memoryTotalGiB NOTIFY changed)
    Q_PROPERTY(double storageUsedGiB MEMBER m_storageUsedGiB NOTIFY changed)
    Q_PROPERTY(double storageTotalGiB MEMBER m_storageTotalGiB NOTIFY changed)
    Q_PROPERTY(QVariantList peripheralDevices READ peripheralDevices NOTIFY changed)
    Q_PROPERTY(double memoryUsage READ memoryUsage NOTIFY changed)
    Q_PROPERTY(double gpuUsage READ gpuUsage NOTIFY changed)
    Q_PROPERTY(double storageUsage READ storageUsage NOTIFY changed)
    Q_PROPERTY(double batteryPercent READ batteryPercent NOTIFY changed)
    Q_PROPERTY(QString batteryStatus READ batteryStatus NOTIFY changed)
    Q_PROPERTY(QString networkStatus READ networkStatus NOTIFY changed)
    Q_PROPERTY(QString metricsStatus READ metricsStatus NOTIFY changed)
    Q_PROPERTY(QString lastUpdated READ lastUpdated NOTIFY changed)
public:
    explicit DashboardClient(QObject *parent = nullptr);

    QString greeting() const { return m_greeting; }
    QString localDate() const { return m_date; }
    QString localTime() const { return m_time; }
    QString weatherLocation() const { return m_weatherLocation; }
    QString weatherStatus() const { return m_weatherStatus; }
    QString weatherSummary() const { return m_weatherSummary; }
    QString weatherTemperature() const { return m_weatherTemperature; }
    QStringList usbDevices() const { return m_usbDevices; }
    QVariantList forecast() const { return m_forecast; }
    QVariantList news() const { return m_news; }
    QString newsStatus() const { return m_newsStatus; }
    double cpuUsage() const { return m_cpuUsage; }
    double memoryUsage() const { return m_memoryUsage; }
    double gpuUsage() const { return m_gpuUsage; }
    double storageUsage() const { return m_storageUsage; }
    double batteryPercent() const { return m_batteryPercent; }
    QString batteryStatus() const { return m_batteryStatus; }
    QString networkStatus() const { return m_networkStatus; }
    QString metricsStatus() const { return m_metricsStatus; }
    QString lastUpdated() const { return m_lastUpdated; }

    QVariantList peripheralDevices() const;
    Q_INVOKABLE void start();
    Q_INVOKABLE void refresh();

signals:
    void clockChanged();
    void weatherChanged();
    void newsChanged();
    void changed();

private:
    void requestBatteries();
    void updateClock();
    void updateMetrics();
    void requestWeather();
    void requestLocation();
    void requestLocationProvider(int provider);
    void loadWeatherCache();
    void saveWeatherCache();
    void requestNews();
    void parseWeather(const QByteArray &data, bool fromCache = false);
    void parseNews(const QByteArray &data);
    void failWeather(const QString &message);
    void failNews(const QString &message);
    QNetworkReply *get(const QUrl &url);

    QNetworkAccessManager m_network;
    QTimer m_batteryTimer;
    QVariantList m_upowerDevices, m_bluetoothDevices;
    double m_memoryUsedGiB = -1, m_memoryTotalGiB = -1;
    double m_storageUsedGiB = -1, m_storageTotalGiB = -1;
    QTimer m_clockTimer;
    QTimer m_metricsTimer;
    QTimer m_weatherTimer;
    QTimer m_weatherRetry;
    bool m_locationBusy = false, m_weatherBusy = false, m_weatherStale = false;
    qint64 m_locationUpdatedAt = 0, m_weatherUpdatedAt = 0;
    QJsonObject m_lastWeatherData;
    QTimer m_newsTimer;
    QProcess m_gpuProcess;
    QString m_greeting;
    QString m_date;
    QString m_time;
    QString m_weatherLocation = QStringLiteral("Localizando…");
    QString m_weatherLatitude = QString();
    QString m_weatherLongitude = QString();
    QString m_weatherStatus = QStringLiteral("Carregando clima real");
    QString m_weatherSummary;
    QString m_weatherTemperature;
    QVariantList m_forecast;
    QVariantList m_news;
    bool m_newsBusy = false;
    QString m_newsStatus = QStringLiteral("Carregando notícias reais");
    double m_cpuUsage = -1;
    double m_memoryUsage = -1;
    double m_gpuUsage = -1;
    double m_storageUsage = -1;
    double m_batteryPercent = -1;
    QString m_batteryStatus = QStringLiteral("Indisponível");
    QStringList m_usbDevices;
    QString m_networkStatus = QStringLiteral("Indisponível");
    QString m_metricsStatus = QStringLiteral("Carregando métricas");
    QString m_lastUpdated;
    quint64 m_cpuTotal = 0;
    quint64 m_cpuIdle = 0;
    bool m_started = false;
};
