#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QUrl>
#include <QVariantMap>

namespace ChatHistory {
QVariantMap summary(const QJsonObject &thread, const QString &pragusWorkspace);
QJsonArray messagesFromTurns(const QJsonArray &turns);
QJsonArray importMessages(const QUrl &url, QString *error);
QString transcript(const QJsonArray &messages);
QString contextInput(const QJsonArray &messages);
}
