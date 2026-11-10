#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QProcess>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QDir>
#include <QUrl>

class Backend : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
public:
  bool busy() const { return process.state() != QProcess::NotRunning; }
  Backend() {
    connect(&process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
      auto doc = QJsonDocument::fromJson(process.readAllStandardOutput());
      auto o = doc.object();
      if (code != 0 || doc.isNull()) emit result(false, {}, tr("VPN helper stopped unexpectedly."));
      else emit result(o.value("ok").toBool(), o.value("result").toObject().toVariantMap(), o.value("error").toString());
      emit busyChanged();
    });
    connect(&process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) { if (e == QProcess::FailedToStart) { emit result(false, {}, tr("Could not start the VPN helper.")); emit busyChanged(); } });
  }
  Q_INVOKABLE void request(const QVariantMap &fields) {
    if (busy()) return;
    QString exe = QCoreApplication::applicationDirPath() + "/sophosvpn-backend";
    process.start(exe);
    if (!process.waitForStarted(1000)) return;
    process.write(QJsonDocument(QJsonObject::fromVariantMap(fields)).toJson(QJsonDocument::Compact) + "\n");
    process.closeWriteChannel();
    emit busyChanged();
  }
  Q_INVOKABLE QString localPath(const QUrl &url) const { return url.isLocalFile() ? url.toLocalFile() : QString(); }
signals:
  void busyChanged();
  void result(bool ok, QVariantMap data, QString error);
private:
  QProcess process;
};
int main(int argc, char **argv) {
  QGuiApplication app(argc, argv); app.setApplicationName("Sophos VPN"); app.setDesktopFileName("sophosvpn");
  Backend backend; QQmlApplicationEngine engine; engine.rootContext()->setContextProperty("backend", &backend);
  engine.load(QUrl("qrc:/Main.qml")); if (engine.rootObjects().isEmpty()) return 1; return app.exec();
}
#include "main.moc"
