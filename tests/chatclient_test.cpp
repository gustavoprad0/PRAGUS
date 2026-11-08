#include <QtTest>
#include <QtQml>
#include <QAbstractItemModel>
#include <QGuiApplication>
#include <memory>

class ChatClientTest : public QObject {
    Q_OBJECT
    QTemporaryDir m_data;
    QString m_log;
    std::unique_ptr<QQmlEngine> m_engine;
    std::unique_ptr<QObject> m_client;

    QObject *createClient() {
        QQmlComponent component(m_engine.get());
        const auto base = QUrl::fromLocalFile(QStringLiteral(PRAGUS_PROJECT_ROOT) + "/package/contents/ui/chatclient-test.qml");
        component.setData("import QtQml\nimport \"bridge\" as Backend\nBackend.CodexClient {}\n", base);
        QObject *client = component.create();
        if (!client) qWarning() << component.errors();
        if (client) client->setProperty("executable", QStringLiteral(PRAGUS_PROJECT_ROOT) + "/tests/fake_codex.py");
        return client;
    }
    bool flag(const char *property) const { return m_client->property(property).toBool(); }
    QString threadId() const { return m_client->property("threadId").toString(); }
    QAbstractItemModel *messages() const { return m_client->property("messages").value<QAbstractItemModel *>(); }
    QVariantList history() const { return m_client->property("history").toList(); }
    bool invoke(const char *method) const { return QMetaObject::invokeMethod(m_client.get(), method); }
    bool load(const QString &id) const {
        bool accepted = false;
        const bool invoked = QMetaObject::invokeMethod(m_client.get(), "loadConversation", Q_RETURN_ARG(bool, accepted), Q_ARG(QString, id));
        return invoked && accepted;
    }
    bool send(const QString &text) const {
        bool accepted = false;
        const bool invoked = QMetaObject::invokeMethod(m_client.get(), "send", Q_RETURN_ARG(bool, accepted), Q_ARG(QString, text));
        return invoked && accepted;
    }
    bool import(const QUrl &url) const {
        bool accepted = false;
        const bool invoked = QMetaObject::invokeMethod(m_client.get(), "importConversation", Q_RETURN_ARG(bool, accepted), Q_ARG(QUrl, url));
        return invoked && accepted;
    }
    QList<QJsonObject> requests(const QString &method = {}) const {
        QFile file(m_log);
        if (!file.open(QIODevice::ReadOnly)) return {};
        QList<QJsonObject> rows;
        while (!file.atEnd()) {
            const auto object = QJsonDocument::fromJson(file.readLine()).object();
            if (method.isEmpty() || object["method"].toString() == method) rows.append(object);
        }
        return rows;
    }
    void resetLog() const { QFile file(m_log); QVERIFY(file.open(QIODevice::WriteOnly | QIODevice::Truncate)); }
    QString allBodies() const {
        QStringList bodies;
        auto *model = messages();
        for (int i = 0; i < model->rowCount(); ++i) bodies.append(model->data(model->index(i, 0), Qt::UserRole + 2).toString());
        return bodies.join('\n');
    }
private slots:
    void init() {
        QVERIFY(m_data.isValid());
        m_client.reset();
        m_engine.reset();
        QDir(m_data.path() + "/data").removeRecursively();
        m_log = m_data.path() + "/rpc.jsonl";
        qputenv("XDG_DATA_HOME", (m_data.path() + "/data").toUtf8());
        qputenv("PRAGUS_TEST_RPC_LOG", m_log.toUtf8());
        resetLog();
        m_engine = std::make_unique<QQmlEngine>();
        m_client.reset(createClient());
        QVERIFY(m_client);
        QVERIFY(invoke("start"));
        QTRY_VERIFY_WITH_TIMEOUT(flag("ready"), 5000);
        QTRY_VERIFY_WITH_TIMEOUT(!flag("historyBusy"), 5000);
    }
    void cleanup() { m_client.reset(); m_engine.reset(); }

    void listIncludesDesktopAndCliAndPaginates() {
        QVERIFY(invoke("refreshHistory"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("historyBusy"), 5000);
        QCOMPARE(history().size(), 1);
        QVERIFY(flag("historyHasMore"));
        const auto params = requests("thread/list").last()["params"].toObject();
        const auto sources = params["sourceKinds"].toArray();
        QVERIFY(sources.contains("cli"));
        QVERIFY(sources.contains("appServer"));
        QVERIFY(!params.contains("cwd"));
        QVERIFY(params["modelProviders"].isArray());
        QVERIFY(params["modelProviders"].toArray().isEmpty());
        QVERIFY(invoke("loadMoreHistory"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("historyBusy"), 5000);
        QCOMPARE(history().size(), 2);
        QVERIFY(!flag("historyHasMore"));
    }
    void resumeRestoresMessagesAndContinuesSameContext() {
        QVERIFY(load("saved-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QCOMPARE(threadId(), QString("saved-chat"));
        QCOMPARE(messages()->rowCount(), 4);
        QVERIFY(allBodies().contains("Minha cor preferida é azul."));
        const auto resume = requests("thread/resume").last()["params"].toObject();
        QCOMPARE(resume["sandbox"].toString(), QString("read-only"));
        QCOMPARE(resume["approvalPolicy"].toString(), QString("never"));
        QVERIFY(resume["excludeTurns"].toBool());
        QVERIFY(resume["developerInstructions"].toString().contains("Pragus"));
        QCOMPARE(requests("thread/turns/list").size(), 2);
        resetLog();
        QVERIFY(send("Qual é minha cor preferida?"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("busy"), 5000);
        const auto turns = requests("turn/start");
        QCOMPARE(turns.size(), 1);
        QCOMPARE(turns.last()["params"].toObject()["threadId"].toString(), QString("saved-chat"));
        QCOMPARE(requests("thread/start").size(), 0);
    }
    void failedRecoveryPreservesCurrentConversation() {
        QVERIFY(load("saved-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        const auto previous = allBodies();
        QVERIFY(load("missing-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QCOMPARE(threadId(), QString("saved-chat"));
        QCOMPARE(allBodies(), previous);
        QVERIFY(!m_client->property("historyError").toString().isEmpty());
        QVERIFY(load("broken-history"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QCOMPARE(threadId(), QString("saved-chat"));
        QCOMPARE(allBodies(), previous);
    }
    void activeExternalConversationKeepsCurrentChatAvailable() {
        QVERIFY(load("saved-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        const auto previous = allBodies();
        resetLog();
        QVERIFY(load("active-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QCOMPARE(threadId(), QString("saved-chat"));
        QCOMPARE(allBodies(), previous);
        QVERIFY(m_client->property("historyError").toString().contains("respondendo"));
        QCOMPARE(requests("thread/turns/list").size(), 0);
        QCOMPARE(requests("turn/start").size(), 0);
        QVERIFY(send("Continue a conversa anterior."));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("busy"), 5000);
        QCOMPARE(requests("turn/start").last()["params"].toObject()["threadId"].toString(), QString("saved-chat"));
    }
    void newConversationKeepsStoredHistory() {
        QVERIFY(load("saved-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QVERIFY(invoke("refreshHistory"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("historyBusy"), 5000);
        QVERIFY(!history().isEmpty());
        QVERIFY(invoke("newChat"));
        QVERIFY(threadId().isEmpty());
        QCOMPARE(messages()->rowCount(), 0);
        QVERIFY(!history().isEmpty());
        QCOMPARE(requests("thread/delete").size(), 0);
        QCOMPARE(requests("thread/archive").size(), 0);
    }
    void importedHistoryIsSentAsContext() {
        const QString path = m_data.path() + "/browser.json";
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(R"({"messages":[{"role":"user","content":"Minha cor preferida é azul."},{"role":"assistant","content":"Entendido: azul."}]})");
        file.close();
        QVERIFY(import(QUrl::fromLocalFile(path)));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QCOMPARE(messages()->rowCount(), 2);
        resetLog();
        QVERIFY(send("Qual é minha cor preferida?"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("busy"), 5000);
        QCOMPARE(requests("thread/start").size(), 1);
        QVERIFY(requests("thread/start").last()["params"].toObject()["developerInstructions"].toString().contains("Pragus"));
        const auto input = requests("turn/start").last()["params"].toObject()["input"].toArray();
        QStringList text;
        for (const auto value : input) text.append(value.toObject()["text"].toString());
        const QString context = text.join('\n');
        QVERIFY(context.contains("Minha cor preferida é azul."));
        QVERIFY(context.contains("Entendido: azul."));
        QVERIFY(context.contains("Qual é minha cor preferida?"));
    }
    void malformedImportPreservesCurrentConversation() {
        QVERIFY(load("saved-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        const auto previous = allBodies();
        const QString path = m_data.path() + "/invalid.json";
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("{invalid}");
        file.close();
        QVERIFY(!import(QUrl::fromLocalFile(path)));
        QCOMPARE(threadId(), QString("saved-chat"));
        QCOMPARE(allBodies(), previous);
        QVERIFY(!import(QUrl("https://example.invalid/history.json")));
        QCOMPARE(threadId(), QString("saved-chat"));
        QCOMPARE(allBodies(), previous);
    }
    void loadingBlocksInterleavedConversationChanges() {
        QVERIFY(load("saved-chat"));
        QVERIFY(flag("conversationLoading"));
        QVERIFY(!load("older-chat"));
        QVERIFY(!send("Mensagem durante recuperação"));
        QVERIFY(invoke("newChat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QCOMPARE(threadId(), QString("saved-chat"));
        QCOMPARE(messages()->rowCount(), 4);
        QCOMPARE(requests("turn/start").size(), 0);
    }
    void restartRecoversLastConversation() {
        QVERIFY(load("saved-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        m_client.reset();
        resetLog();
        m_client.reset(createClient());
        QVERIFY(m_client);
        QVERIFY(invoke("start"));
        QTRY_COMPARE_WITH_TIMEOUT(threadId(), QString("saved-chat"), 5000);
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QCOMPARE(messages()->rowCount(), 4);
        QVERIFY(!requests("thread/resume").isEmpty());
    }
    void restartAfterNewConversationDoesNotRestorePreviousChat() {
        QVERIFY(load("saved-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QVERIFY(invoke("newChat"));
        m_client.reset();
        resetLog();
        m_client.reset(createClient());
        QVERIFY(m_client);
        QVERIFY(invoke("start"));
        QTRY_VERIFY_WITH_TIMEOUT(flag("ready"), 5000);
        QVERIFY(threadId().isEmpty());
        QCOMPARE(messages()->rowCount(), 0);
        QCOMPARE(requests("thread/resume").size(), 0);
    }
    void reconnectKeepsOriginalWorkspaceAndThreadContext() {
        QVERIFY(load("saved-chat"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        resetLog();
        QVERIFY(invoke("reconnect"));
        QTRY_VERIFY_WITH_TIMEOUT(flag("ready"), 5000);
        QCOMPARE(threadId(), QString("saved-chat"));
        QCOMPARE(messages()->rowCount(), 4);
        QVERIFY(send("Continue com o contexto anterior."));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("busy"), 5000);
        const auto resume = requests("thread/resume").last()["params"].toObject();
        QCOMPARE(resume["threadId"].toString(), QString("saved-chat"));
        QCOMPARE(resume["cwd"].toString(), QString("/tmp/pragus-source-workspace"));
        QCOMPARE(requests("thread/start").size(), 0);
    }
    void importedContextSurvivesRestartBeforeFirstQuestion() {
        const QString path = m_data.path() + "/pending-browser.json";
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(R"({"messages":[{"role":"user","content":"Meu projeto usa Qt."},{"role":"assistant","content":"Vou considerar Qt nas respostas."}]})");
        file.close();
        QVERIFY(import(QUrl::fromLocalFile(path)));
        m_client.reset();
        resetLog();
        m_client.reset(createClient());
        QVERIFY(m_client);
        QVERIFY(invoke("start"));
        QTRY_VERIFY_WITH_TIMEOUT(flag("ready"), 5000);
        QCOMPARE(messages()->rowCount(), 2);
        QVERIFY(allBodies().contains("Meu projeto usa Qt."));
        QVERIFY(send("Qual ferramenta estamos usando?"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("busy"), 5000);
        const auto input = requests("turn/start").last()["params"].toObject()["input"].toArray();
        QStringList text;
        for (const auto value : input) text.append(value.toObject()["text"].toString());
        QVERIFY(text.join('\n').contains("Meu projeto usa Qt."));
        QVERIFY(text.join('\n').contains("Vou considerar Qt nas respostas."));
    }
    void olderCliUsesFullHistoryFallback() {
        QVERIFY(load("legacy-history"));
        QTRY_VERIFY_WITH_TIMEOUT(!flag("conversationLoading"), 5000);
        QCOMPARE(threadId(), QString("legacy-history"));
        QCOMPARE(messages()->rowCount(), 2);
        QVERIFY(allBodies().contains("Minha cor preferida é azul."));
        const auto reads = requests("thread/read");
        QCOMPARE(reads.size(), 1);
        QVERIFY(reads.last()["params"].toObject()["includeTurns"].toBool());
        QVERIFY(m_client->property("historyError").toString().isEmpty());
    }
};

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    ChatClientTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "chatclient_test.moc"
