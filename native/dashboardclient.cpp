#include "dashboardclient.h"

#include <QDateTime>
#include <QtDBus>
#include <memory>
#include <cmath>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QHostInfo>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QSaveFile>
#include <QStorageInfo>
#include <QUrlQuery>
#include <QXmlStreamReader>

using DBusInterfaces = QMap<QString, QVariantMap>;
using DBusObjects = QMap<QDBusObjectPath, DBusInterfaces>;
Q_DECLARE_METATYPE(DBusInterfaces)
Q_DECLARE_METATYPE(DBusObjects)

namespace {
QString machineName() {
    auto read = [](const QString &path) {
        QFile file(path);
        return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()).trimmed() : QString();
    };
    const auto model = read(QStringLiteral("/sys/class/dmi/id/product_name"));
    const QStringList placeholders = {"System Product Name", "To Be Filled By O.E.M.", "Default string", "Not Specified"};
    if (!model.isEmpty() && !placeholders.contains(model, Qt::CaseInsensitive)) return model;
    const auto hostname = QHostInfo::localHostName();
    return hostname.isEmpty() ? QStringLiteral("Computador") : hostname;
}

QString weatherText(int code) {
    if (code == 0) return QStringLiteral("Céu limpo");
    if (code == 1) return QStringLiteral("Predominantemente limpo");
    if (code == 2) return QStringLiteral("Parcialmente nublado");
    if (code == 3) return QStringLiteral("Encoberto");
    if (code == 45 || code == 48) return QStringLiteral("Neblina");
    if (code >= 51 && code <= 57) return QStringLiteral("Garoa");
    if (code >= 61 && code <= 67) return QStringLiteral("Chuva");
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) return QStringLiteral("Neve");
    if (code >= 80 && code <= 82) return QStringLiteral("Pancadas de chuva");
    if (code >= 95 && code <= 99) return QStringLiteral("Trovoada");
    return QStringLiteral("Condição indisponível");
}
QString portugueseDate(const QDate &date) {
    static const QStringList weekdays = {QStringLiteral("domingo"), QStringLiteral("segunda-feira"), QStringLiteral("terça-feira"), QStringLiteral("quarta-feira"), QStringLiteral("quinta-feira"), QStringLiteral("sexta-feira"), QStringLiteral("sábado")};
    static const QStringList months = {QStringLiteral("janeiro"), QStringLiteral("fevereiro"), QStringLiteral("março"), QStringLiteral("abril"), QStringLiteral("maio"), QStringLiteral("junho"), QStringLiteral("julho"), QStringLiteral("agosto"), QStringLiteral("setembro"), QStringLiteral("outubro"), QStringLiteral("novembro"), QStringLiteral("dezembro")};
    return weekdays.value(date.dayOfWeek() % 7) + QStringLiteral(", ") + QString::number(date.day()) + QStringLiteral(" de ") + months.value(date.month() - 1);
}
}

DashboardClient::DashboardClient(QObject *parent) : QObject(parent) {
    qDBusRegisterMetaType<DBusInterfaces>();
    qDBusRegisterMetaType<DBusObjects>();
    m_batteryTimer.setInterval(5000);
    connect(&m_batteryTimer, &QTimer::timeout, this, &DashboardClient::requestBatteries);
    m_clockTimer.setInterval(1000);
    m_metricsTimer.setInterval(2000);
    m_weatherTimer.setInterval(600000);
    m_newsTimer.setInterval(300000);
    m_weatherRetry.setSingleShot(true); m_weatherRetry.setInterval(60000);
    connect(&m_weatherRetry, &QTimer::timeout, this, &DashboardClient::requestLocation);
    connect(&m_clockTimer, &QTimer::timeout, this, &DashboardClient::updateClock);
    connect(&m_metricsTimer, &QTimer::timeout, this, &DashboardClient::updateMetrics);
    connect(&m_weatherTimer, &QTimer::timeout, this, &DashboardClient::requestLocation);
    connect(&m_newsTimer, &QTimer::timeout, this, &DashboardClient::requestNews);
    connect(&m_gpuProcess, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this, [this] {
        const auto value = QString::fromUtf8(m_gpuProcess.readAllStandardOutput()).trimmed().split('\n').value(0).trimmed().toDouble();
        if (m_gpuProcess.exitStatus() == QProcess::NormalExit && !m_gpuProcess.readAllStandardError().size() && value >= 0) {
            m_gpuUsage = qBound(0.0, value, 100.0);
            emit changed();
        }
    });
}

void DashboardClient::start() {
    if (m_started) return;
    m_started = true;
    loadWeatherCache();
    updateClock();
    updateMetrics();
    requestBatteries();
    m_batteryTimer.start();
    requestLocation();
    requestNews();
    m_clockTimer.start();
    m_metricsTimer.start();
    m_weatherTimer.start();
    m_newsTimer.start();
}

void DashboardClient::refresh() {
    requestLocation();
    requestNews();
    updateMetrics();
}

void DashboardClient::updateClock() {
    const auto now = QDateTime::currentDateTime();
    m_time = now.toString(QStringLiteral("HH:mm:ss"));
    m_date = portugueseDate(now.date());
    const auto hour = now.time().hour();
    m_greeting = hour < 12 ? QStringLiteral("Bom dia") : hour < 18 ? QStringLiteral("Boa tarde") : QStringLiteral("Boa noite");
    emit clockChanged();
}

void DashboardClient::updateMetrics() {
    QFile cpuFile(QStringLiteral("/proc/stat"));
    if (cpuFile.open(QIODevice::ReadOnly)) {
        const auto line = QString::fromUtf8(cpuFile.readLine());
        const auto parts = line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
        if (parts.size() >= 5) {
            quint64 idle = parts[4].toULongLong();
            quint64 total = 0;
            for (int i = 1; i < parts.size(); ++i) total += parts[i].toULongLong();
            if (m_cpuTotal > 0 && total > m_cpuTotal) {
                m_cpuUsage = 100.0 * (1.0 - double(idle - m_cpuIdle) / double(total - m_cpuTotal));
            }
            m_cpuTotal = total;
            m_cpuIdle = idle;
        }
    }

    QFile memFile(QStringLiteral("/proc/meminfo"));
    if (memFile.open(QIODevice::ReadOnly)) {
        quint64 total = 0;
        quint64 available = 0;
        while (true) {
            const auto raw = memFile.readLine();
            if (raw.isEmpty()) break;
            const auto line = QString::fromUtf8(raw);
            const auto match = QRegularExpression(QStringLiteral("^(MemTotal|MemAvailable):\\s+(\\d+)")).match(line);
            if (!match.hasMatch()) continue;
            if (match.captured(1) == QStringLiteral("MemTotal")) total = match.captured(2).toULongLong();
            if (match.captured(1) == QStringLiteral("MemAvailable")) available = match.captured(2).toULongLong();
        }
        if (total) {
            m_memoryUsage = 100.0 * (1.0 - double(available) / double(total));
            m_memoryUsedGiB = double(total - available) / 1048576.0;
            m_memoryTotalGiB = double(total) / 1048576.0;
        }
    }

        QDir drm(QStringLiteral("/sys/class/drm"));
        for (const auto &card : drm.entryList(QStringList() << "card*", QDir::Dirs | QDir::NoDotAndDotDot)) {
            QFile busy(drm.filePath(card + QStringLiteral("/device/gpu_busy_percent")));
            if (busy.open(QIODevice::ReadOnly)) {
                m_gpuUsage = qBound(0.0, QString::fromUtf8(busy.readAll()).trimmed().toDouble(), 100.0);
                break;
            }
        }
        if (m_gpuProcess.state() == QProcess::NotRunning && QStandardPaths::findExecutable(QStringLiteral("nvidia-smi")).isEmpty() == false)
            m_gpuProcess.start(QStringLiteral("nvidia-smi"), {"--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"});

        m_usbDevices.clear();
        auto read = [](const QString &path) { QFile f(path); return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()).trimmed() : QString(); };
        QDir inputs(QStringLiteral("/sys/class/input"));
        for (const auto &input : inputs.entryList({"event*"}, QDir::Dirs)) {
            const auto path = inputs.filePath(input + "/device/");
            const auto name = read(path + "name");
            if (read(path + "id/bustype") != "0003" && read(path + "id/bustype") != "0005") continue;
            if (QFileInfo::exists(path + "capabilities/rel") && read(path + "capabilities/rel") != "0") m_usbDevices.append(QStringLiteral("Mouse"));
            else if (name.contains("keyboard", Qt::CaseInsensitive)) {
                const bool aula = read(path + "id/vendor") == "3554" && read(path + "id/product") == "fa09";
                m_usbDevices.append(aula ? QStringLiteral("AULA F75") : QStringLiteral("Teclado"));
            }
        }
        QDir usb(QStringLiteral("/sys/bus/usb/devices"));
        for (const auto &device : usb.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            const auto name = read(usb.filePath(device + "/product"));
            if (name.contains(QRegularExpression("phone|android|iphone|pixel|galaxy|mtp|motorola|redmi", QRegularExpression::CaseInsensitiveOption))) m_usbDevices.append(QStringLiteral("Celular · ") + name);
            else if (read(usb.filePath(device + "/removable")) == "removable" && !name.contains(QRegularExpression("hub|receiver|webcam|controller|bluetooth", QRegularExpression::CaseInsensitiveOption)) && !name.isEmpty()) m_usbDevices.append(name);
        }
        m_usbDevices.removeDuplicates();

    const auto storage = QStorageInfo::root();
    if (storage.isValid() && storage.bytesTotal() > 0) {
        m_storageUsage = 100.0 * double(storage.bytesTotal() - storage.bytesAvailable()) / double(storage.bytesTotal());
        m_storageUsedGiB = double(storage.bytesTotal() - storage.bytesAvailable()) / 1073741824.0;
        m_storageTotalGiB = double(storage.bytesTotal()) / 1073741824.0;
    }

    m_batteryPercent = -1;
    QDir batteries(QStringLiteral("/sys/class/power_supply"));
    for (const auto &name : batteries.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        QFile type(batteries.filePath(name + "/type"));
        if (!type.open(QIODevice::ReadOnly) || type.readAll().trimmed() != "Battery") continue;
        QFile scope(batteries.filePath(name + "/scope"));
        if (scope.open(QIODevice::ReadOnly) && scope.readAll().trimmed() == "Device") continue;
        QFile capacity(batteries.filePath(name + QStringLiteral("/capacity")));
        QFile status(batteries.filePath(name + QStringLiteral("/status")));
        if (capacity.open(QIODevice::ReadOnly)) {
            m_batteryPercent = capacity.readAll().trimmed().toDouble();
            if (status.open(QIODevice::ReadOnly)) m_batteryStatus = QString::fromUtf8(status.readAll()).trimmed();
            break;
        }
    }

    QFile net(QStringLiteral("/proc/net/dev"));
    quint64 received = 0;
    quint64 transmitted = 0;
    if (net.open(QIODevice::ReadOnly)) {
        while (!net.atEnd()) {
            const auto line = QString::fromUtf8(net.readLine()).trimmed();
            if (!line.contains(':')) continue;
            const auto values = line.section(':', 1).split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
            if (values.size() >= 9) {
                received += values[0].toULongLong();
                transmitted += values[8].toULongLong();
            }
        }
        m_networkStatus = (received || transmitted) ? QStringLiteral("Conectada") : QStringLiteral("Sem tráfego detectado");
    }
    m_metricsStatus = QStringLiteral("Atualizado agora");
    m_lastUpdated = QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss"));
    emit changed();
}

QNetworkReply *DashboardClient::get(const QUrl &url) {
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Pragus/1.0"));
    request.setTransferTimeout(15000);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    return m_network.get(request);
}

void DashboardClient::requestWeather() {
    if (m_weatherLatitude.isEmpty() || m_weatherLongitude.isEmpty() || m_weatherBusy) return;
    if (!m_weatherTemperature.isEmpty() && QDateTime::currentSecsSinceEpoch() - m_weatherUpdatedAt < 60) return;
    m_weatherBusy = true;
    m_weatherStatus = QStringLiteral("Buscando clima real…");
    emit weatherChanged();
    QUrl url(QStringLiteral("https://api.open-meteo.com/v1/forecast"));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("latitude"), m_weatherLatitude);
    query.addQueryItem(QStringLiteral("longitude"), m_weatherLongitude);
    query.addQueryItem(QStringLiteral("current"), QStringLiteral("temperature_2m,relative_humidity_2m,weather_code"));
    query.addQueryItem(QStringLiteral("daily"), QStringLiteral("temperature_2m_max,temperature_2m_min,weather_code"));
    query.addQueryItem(QStringLiteral("timezone"), QStringLiteral("auto"));
    query.addQueryItem(QStringLiteral("forecast_days"), QStringLiteral("7"));
    url.setQuery(query);
    const auto requestedLatitude = m_weatherLatitude, requestedLongitude = m_weatherLongitude;
    auto *reply = get(url);
    connect(reply, &QNetworkReply::finished, this, [this, reply, requestedLatitude, requestedLongitude] {
        m_weatherBusy = false;
        if (requestedLatitude != m_weatherLatitude || requestedLongitude != m_weatherLongitude) { reply->deleteLater(); requestWeather(); return; }
        const auto data = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) { failWeather(reply->errorString()); reply->deleteLater(); return; }
        parseWeather(data);
        reply->deleteLater();
        emit weatherChanged();
    });
}

void DashboardClient::requestLocation() {
    if (m_locationBusy) return;
    if (!m_weatherLatitude.isEmpty() && QDateTime::currentSecsSinceEpoch() - m_locationUpdatedAt < 600) { requestWeather(); return; }
    m_locationBusy = true;
    if (!m_weatherLatitude.isEmpty()) requestWeather();
    requestLocationProvider(0);
}

void DashboardClient::requestLocationProvider(int provider) {
    const QStringList urls = {"https://ipwho.is/", "https://ipinfo.io/json", "https://ipapi.co/json/"};
    if (provider >= urls.size()) {
        m_locationBusy = false;
        if (m_weatherLatitude.isEmpty()) {
            m_weatherLocation = QStringLiteral("Localização indisponível");
            failWeather(QStringLiteral("Não foi possível localizar pela rede"));
        } else requestWeather();
        m_weatherRetry.start();
        return;
    }
    auto *reply = get(QUrl(urls[provider]));
    QTimer::singleShot(6000, reply, [reply] { if (reply->isRunning()) reply->abort(); });
    connect(reply, &QNetworkReply::finished, this, [this, reply, provider] {
        const auto object = QJsonDocument::fromJson(reply->error() == QNetworkReply::NoError ? reply->readAll() : QByteArray()).object();
        bool valid = reply->error() == QNetworkReply::NoError && !object.value("error").toBool()
            && (!object.contains("success") || object.value("success").toBool());
        double latitude = 0, longitude = 0;
        if (object.contains("loc")) {
            const auto pair = object["loc"].toString().split(','); bool a = false, b = false;
            latitude = pair.value(0).toDouble(&a); longitude = pair.value(1).toDouble(&b); valid = valid && a && b;
        } else {
            valid = valid && object["latitude"].isDouble() && object["longitude"].isDouble();
            latitude = object["latitude"].toDouble(); longitude = object["longitude"].toDouble();
        }
        const auto city = object["city"].toString().trimmed();
        valid = valid && !city.isEmpty() && std::isfinite(latitude) && std::isfinite(longitude) && qAbs(latitude) <= 90 && qAbs(longitude) <= 180;
        reply->deleteLater();
        if (!valid) { requestLocationProvider(provider + 1); return; }
        m_locationBusy = false;
        if (!m_weatherLatitude.isEmpty() && (qAbs(m_weatherLatitude.toDouble() - latitude) > .1 || qAbs(m_weatherLongitude.toDouble() - longitude) > .1)) {
            m_weatherTemperature.clear(); m_weatherSummary.clear(); m_forecast.clear(); m_lastWeatherData = {}; m_weatherUpdatedAt = 0;
        }
        m_weatherLatitude = QString::number(latitude, 'f', 6); m_weatherLongitude = QString::number(longitude, 'f', 6);
        m_weatherLocation = city; m_locationUpdatedAt = QDateTime::currentSecsSinceEpoch();
        saveWeatherCache(); requestWeather(); emit weatherChanged();
    });
}

void DashboardClient::loadWeatherCache() {
    QFile file(QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + "/pragus/weather.json");
    if (!file.open(QIODevice::ReadOnly) || file.size() > 1048576) return;
    const auto cached = QJsonDocument::fromJson(file.readAll()).object();
    const auto now = QDateTime::currentSecsSinceEpoch();
    const auto locatedAt = cached["locationUpdatedAt"].toInteger();
    if (locatedAt <= 0 || locatedAt > now || now - locatedAt > 604800 || !cached["latitude"].isDouble() || !cached["longitude"].isDouble() || cached["city"].toString().isEmpty()) return;
    if (qAbs(cached["latitude"].toDouble()) > 90 || qAbs(cached["longitude"].toDouble()) > 180) return;
    m_weatherLocation = cached["city"].toString(); m_weatherLatitude = QString::number(cached["latitude"].toDouble(), 'f', 6); m_weatherLongitude = QString::number(cached["longitude"].toDouble(), 'f', 6);
    m_locationUpdatedAt = locatedAt;
    m_weatherUpdatedAt = cached["weatherUpdatedAt"].toInteger();
    if (m_weatherUpdatedAt > 0 && m_weatherUpdatedAt <= now && now - m_weatherUpdatedAt <= 3600) {
        parseWeather(QJsonDocument(cached["weather"].toObject()).toJson(), true);
        m_weatherStale = now - m_weatherUpdatedAt >= 600;
    }
    emit weatherChanged();
}

void DashboardClient::saveWeatherCache() {
    const auto folder = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + "/pragus";
    if (!QDir().mkpath(folder)) return;
    QSaveFile file(folder + "/weather.json");
    if (!file.open(QIODevice::WriteOnly)) return;
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    file.write(QJsonDocument(QJsonObject{{"city", m_weatherLocation}, {"latitude", m_weatherLatitude.toDouble()}, {"longitude", m_weatherLongitude.toDouble()},
        {"locationUpdatedAt", m_locationUpdatedAt}, {"weatherUpdatedAt", m_weatherUpdatedAt}, {"weather", m_lastWeatherData}}).toJson(QJsonDocument::Compact));
    file.commit();
}

void DashboardClient::parseWeather(const QByteArray &data, bool fromCache) {
    const auto root = QJsonDocument::fromJson(data).object();
    const auto current = root["current"].toObject();
    if (!current["temperature_2m"].isDouble() || !current["weather_code"].isDouble()) { failWeather(QStringLiteral("Resposta inválida")); return; }
    m_weatherTemperature = QString::number(qRound(current["temperature_2m"].toDouble())) + QStringLiteral("°C");
    m_weatherSummary = weatherText(current["weather_code"].toInt()) + QStringLiteral(" · ") + (current["temperature_2m"].toDouble() < 18 ? QStringLiteral("Frio") : current["temperature_2m"].toDouble() >= 27 ? QStringLiteral("Calor") : QStringLiteral("Ameno"));
    m_forecast.clear();
    const auto daily = root["daily"].toObject();
    const auto dates = daily["time"].toArray();
    const auto highs = daily["temperature_2m_max"].toArray();
    const auto lows = daily["temperature_2m_min"].toArray();
    const auto codes = daily["weather_code"].toArray();
    if (dates.size() < 7 || highs.size() < 7 || lows.size() < 7 || codes.size() < 7) { failWeather(QStringLiteral("Previsão incompleta")); return; }
    const QStringList days = {"Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"};
    m_weatherStatus = QStringLiteral("Open-Meteo · atualizado agora");
    for (int i = 0; i < 7; ++i) {
        QVariantMap item;
        item.insert(QStringLiteral("day"), days.value(QDate::fromString(dates[i].toString(), Qt::ISODate).dayOfWeek() % 7));
        item.insert(QStringLiteral("isToday"), i == 0);
        item.insert(QStringLiteral("code"), codes[i].toInt());
        item.insert(QStringLiteral("date"), dates[i].toString().mid(5).replace('-', '/'));
        item.insert(QStringLiteral("high"), QString::number(qRound(highs.at(i).toDouble())) + QStringLiteral("°"));
        item.insert(QStringLiteral("low"), QString::number(qRound(lows.at(i).toDouble())) + QStringLiteral("°"));
        item.insert(QStringLiteral("summary"), weatherText(codes.at(i).toInt()));
        m_forecast.append(item);
    }
    m_lastWeatherData = root;
    if (!fromCache) { m_weatherUpdatedAt = QDateTime::currentSecsSinceEpoch(); m_weatherStale = false; m_weatherRetry.stop(); saveWeatherCache(); }
    m_weatherStatus = QStringLiteral("Atualizado às ") + QDateTime::fromSecsSinceEpoch(m_weatherUpdatedAt).toString("HH:mm");
}

void DashboardClient::requestNews() {
    if (m_newsBusy) return;
    m_newsBusy = true;
    m_newsStatus = QStringLiteral("Buscando notícias reais…");
    emit newsChanged();
    auto *reply = get(QUrl(QStringLiteral("https://news.google.com/rss?hl=pt-BR&gl=BR&ceid=BR:pt-419")));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        m_newsBusy = false;
        if (reply->error() != QNetworkReply::NoError) failNews(reply->errorString());
        else parseNews(reply->readAll());
        reply->deleteLater();
    });
}

void DashboardClient::parseNews(const QByteArray &data) {
    QXmlStreamReader xml(data);
    m_news.clear();
    while (!xml.atEnd() && m_news.size() < 8) {
        xml.readNext();
        if (!xml.isStartElement() || xml.name() != QStringLiteral("item")) continue;
        QVariantMap item;
        while (!xml.atEnd()) {
            xml.readNext();
            if (xml.isEndElement() && xml.name() == QStringLiteral("item")) break;
            if (!xml.isStartElement()) continue;
            const auto name = xml.name().toString();
            if (name == QStringLiteral("title") || name == QStringLiteral("link") ||
                name == QStringLiteral("pubDate") || name == QStringLiteral("source"))
                item[name] = xml.readElementText(QXmlStreamReader::SkipChildElements);
        }
        if (!item.isEmpty()) m_news.append(item);
    }
    if (xml.hasError() && m_news.isEmpty()) { failNews(QStringLiteral("Resposta de notícias inválida")); return; }
    m_newsStatus = QStringLiteral("Fonte: Google News RSS · atualizado agora");
    emit newsChanged();
}

void DashboardClient::failWeather(const QString &message) {
    m_weatherStale = true;
    if (!m_weatherTemperature.isEmpty() && QDateTime::currentSecsSinceEpoch() - m_weatherUpdatedAt <= 3600) {
        m_weatherStatus = QStringLiteral("Última atualização às ") + QDateTime::fromSecsSinceEpoch(m_weatherUpdatedAt).toString("HH:mm") + QStringLiteral(" · reconectando");
    } else {
        m_weatherStatus = QStringLiteral("Clima indisponível: ") + message;
        m_weatherTemperature.clear(); m_weatherSummary.clear(); m_forecast.clear();
    }
    m_weatherRetry.start(); emit weatherChanged();
}

void DashboardClient::failNews(const QString &message) {
    m_newsStatus = QStringLiteral("Notícias indisponíveis: ") + message;
    m_news.clear();
    emit newsChanged();
}

QVariantList DashboardClient::peripheralDevices() const {
    QVariantList result;
    static const QString computerName = machineName();
    if (m_batteryPercent >= 0) result.append(QVariantMap{{"name", computerName}, {"percent", m_batteryPercent}});
    auto key = [](QString name) {
        name = name.toLower().remove(QRegularExpression("[^a-z0-9]"));
        return name.contains("aulaf75") ? QStringLiteral("aulaf75") : name;
    };
    auto append = [&result, &key](const QVariantList &list) {
        for (const auto &v : list) {
            bool found = false;
            for (int i = 0; i < result.size(); ++i) {
                if (key(result[i].toMap()["name"].toString()) != key(v.toMap()["name"].toString())) continue;
                if (result[i].toMap()["percent"].toDouble() < 0 && v.toMap()["percent"].toDouble() >= 0) result[i] = v;
                found = true; break;
            }
            if (!found) result.append(v);
        }
    };
    append(m_upowerDevices); append(m_bluetoothDevices);
    for (const auto &name : m_usbDevices) {
        bool covered = false;
        for (const auto &v : result) {
            const auto d = v.toMap();
            if (d["kind"].toString().compare(name, Qt::CaseInsensitive) == 0 || key(d["name"].toString()) == key(name) || d["name"].toString().contains(name, Qt::CaseInsensitive)) covered = true;
        }
        if (!covered) result.append(QVariantMap{{"name", name}, {"percent", -1}});
    }
    return result;
}

void DashboardClient::requestBatteries() {
    const auto bus = QDBusConnection::systemBus();
    auto message = QDBusMessage::createMethodCall("org.freedesktop.UPower", "/org/freedesktop/UPower", "org.freedesktop.UPower", "EnumerateDevices");
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(message, 2500), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, bus](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QList<QDBusObjectPath>> reply = *w;
        w->deleteLater();
        if (reply.isError() || reply.value().isEmpty()) { m_upowerDevices.clear(); emit changed(); return; }
        auto result = std::make_shared<QVariantList>();
        auto remaining = std::make_shared<int>(reply.value().size());
        for (const auto &path : reply.value()) {
            auto msg = QDBusMessage::createMethodCall("org.freedesktop.UPower", path.path(), "org.freedesktop.DBus.Properties", "GetAll");
            msg << "org.freedesktop.UPower.Device";
            auto *detail = new QDBusPendingCallWatcher(bus.asyncCall(msg, 2500), this);
            connect(detail, &QDBusPendingCallWatcher::finished, this, [this, result, remaining](QDBusPendingCallWatcher *d) {
                QDBusPendingReply<QVariantMap> r = *d; d->deleteLater();
                const auto p = r.isError() ? QVariantMap() : r.value();
                const int type = p.value("Type").toInt();
                if (!p.value("PowerSupply").toBool() && p.value("IsPresent").toBool() && p.contains("Percentage") && type >= 5) {
                    QString kind = type == 5 ? "Mouse" : type == 6 ? "Teclado" : type == 8 ? "Celular" :
                        (type == 16 || type == 17 || type == 21) ? "Fone" : "Periférico";
                    QString name = p.value("Model").toString().trimmed();
                    if (name.isEmpty()) name = kind;
                    result->append(QVariantMap{{"name", name}, {"kind", kind}, {"percent", p.value("Percentage").toDouble()}});
                }
                if (--*remaining == 0) { m_upowerDevices = *result; emit changed(); }
            });
        }
    });
    auto msg = QDBusMessage::createMethodCall("org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects");
    auto *bluez = new QDBusPendingCallWatcher(bus.asyncCall(msg, 2500), this);
    connect(bluez, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<DBusObjects> reply = *w; w->deleteLater();
        m_bluetoothDevices.clear();
        if (!reply.isError()) {
            for (const auto &interfaces : reply.value()) {
                const auto device = interfaces.value("org.bluez.Device1");
                if (!device.value("Connected").toBool()) continue;
                const auto battery = interfaces.value("org.bluez.Battery1");
                const auto icon = device.value("Icon").toString();
                const QString kind = icon == "input-keyboard" ? "Teclado" : icon == "input-mouse" ? "Mouse" : icon.startsWith("audio") ? "Fone" : icon == "phone" ? "Celular" : "Bluetooth";
                m_bluetoothDevices.append(QVariantMap{{"name", device.value("Alias", "Bluetooth")}, {"kind", kind}, {"percent", battery.contains("Percentage") ? battery.value("Percentage").toInt() : -1}});
            }
        }
        emit changed();
    });
}
