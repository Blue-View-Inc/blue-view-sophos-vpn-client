import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
  id: window
  width: 760; height: 780; minimumWidth: 460; minimumHeight: 500
  visible: true; title: qsTr("Blue View VPN")
  color: "#071321"
  Material.theme: Material.Dark
  Material.accent: "#429ded"
  property bool connected: false
  property string details: ""
  property string selectedPath: ""
  property var profiles: []
  property string selectedUuid: ""
  function chooseProfile(index) {
    if (index < 0 || index >= profiles.length || profiles[index].id === selectedUuid) return
    username.text = ""; password.text = ""; lastAction = "select"
    backend.request({action: "select", uuid: profiles[index].id})
  }
  property real oldRx: -1
  property real oldTx: -1
  property real sampledAt: 0
  property string speed: ""
  property string lastAction: ""
  property string notice: ""
  property bool setupVisible: false
  function formatRate(n) { return n < 1024 ? Math.round(n) + " B/s" : n < 1048576 ? (n/1024).toFixed(1) + " KB/s" : (n/1048576).toFixed(1) + " MB/s" }
  function send(action) {
    lastAction = action
    backend.request({action: action, file: selectedPath, username: username.text, password: password.text, save: remember.checked})
    if (action === "connect") password.text = ""
  }
  Component.onCompleted: send("status")
  Timer { interval: 5000; repeat: true; running: window.visible && !backend.busy; onTriggered: { window.lastAction = "status"; backend.request({action:"status"}) } }
  Connections {
    target: backend
    function onResult(ok, data, error) {
      if (!ok) { window.notice = error || qsTr("The VPN action failed."); return }
      if (window.lastAction === "status") {
        window.connected = data.connected
        window.profiles = data.profiles || []
        window.selectedUuid = data.selected || ""
        let index = -1
        for (let i = 0; i < window.profiles.length; i++) if (window.profiles[i].id === window.selectedUuid) index = i
        profilePicker.currentIndex = index
        window.details = data.details || ""
        let now = Date.now(), seconds = (now - window.sampledAt) / 1000
        if (data.connected && window.sampledAt > 0 && seconds > 0 && data.rx >= window.oldRx && data.tx >= window.oldTx)
          window.speed = qsTr("↓ %1   ↑ %2").arg(window.formatRate((data.rx - window.oldRx) / seconds)).arg(window.formatRate((data.tx - window.oldTx) / seconds))
        else window.speed = ""
        window.oldRx = data.rx; window.oldTx = data.tx; window.sampledAt = now
        if (!username.activeFocus && username.text === "" && data.username) username.text = data.username
      } else {
        window.notice = data.message || ""
        window.lastAction = "status"
        Qt.callLater(function() { backend.request({action:"status"}) })
      }
    }
  }
  FileDialog { id: picker; title: qsTr("Choose an OpenVPN configuration"); nameFilters: [qsTr("OpenVPN configurations (*.ovpn)")]; onAccepted: window.selectedPath = backend.localPath(selectedFile) }
  ScrollView {
    anchors.fill: parent; clip: true
    contentWidth: availableWidth
    ColumnLayout {
      width: Math.max(0, window.width - 56); x: 28
      spacing: 18
      Item { Layout.preferredHeight: 8 }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 5
        RowLayout {
          Layout.fillWidth: true; spacing: 11
          Image { source: "qrc:/sophos.svg"; Layout.preferredWidth: 46; Layout.preferredHeight: 46; fillMode: Image.PreserveAspectFit }
          Label { text: qsTr("SOPHOS VPN"); font.pixelSize: 20; font.bold: true; font.letterSpacing: 1; color: "#eef6ff"; Layout.fillWidth: true }
        }
        RowLayout {
          Layout.leftMargin: 4; spacing: 7
          Image { source: "qrc:/blueview-oval.svg"; Layout.preferredWidth: 19; Layout.preferredHeight: 20; fillMode: Image.PreserveAspectFit }
          Label { text: qsTr("By Blue View Intelligence"); font.pixelSize: 11; color: "#91b9da" }
        }
      }
      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#1d3349" }
      ColumnLayout {
        spacing: 3; Layout.topMargin: 2
        Label { text: qsTr("Your connection"); font.pixelSize: 26; font.bold: true; color: "#f2f8ff" }
        Label { text: qsTr("Manage secure access to your work network."); font.pixelSize: 13; color: "#9db5c9"; wrapMode: Text.Wrap; Layout.fillWidth: true }
      }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 3
        Label { text: qsTr("VPN PROFILE"); font.pixelSize: 10; font.letterSpacing: 1; color: "#83a6c3" }
        ComboBox {
          id: profilePicker; Layout.fillWidth: true; model: window.profiles; textRole: "name"
          enabled: !backend.busy && !window.connected && window.profiles.length > 0
          onActivated: function(index) { window.chooseProfile(index) }
          displayText: currentIndex < 0 ? qsTr("Import a VPN configuration to get started") : currentText
        }
        Label { visible: window.connected && window.profiles.length > 1; text: qsTr("Disconnect to switch profiles."); color: "#93abc0"; font.pixelSize: 11 }
      }
      Rectangle {
        Layout.fillWidth: true; implicitHeight: statusContent.implicitHeight + 32
        radius: 14; color: "#10243a"; border.color: "#24445f"
        ColumnLayout {
          id: statusContent; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16; spacing: 13
          RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle { width: 11; height: 11; radius: 6; color: window.connected ? "#50d6a2" : "#e3a967" }
            ColumnLayout {
              spacing: 1; Layout.fillWidth: true
              Label { text: window.connected ? qsTr("Connected") : qsTr("Disconnected"); font.bold: true; font.pixelSize: 18; color: "#f3f8ff" }
              Label { text: qsTr("Sophos / OpenVPN · Split tunnel"); color: "#a6bdd1"; font.pixelSize: 12 }
            }
            BusyIndicator { running: backend.busy; visible: running; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
          }
          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#29455d" }
          ColumnLayout {
            Layout.fillWidth: true; visible: window.connected; spacing: 10
            ColumnLayout {
              Layout.fillWidth: true; spacing: 3
              Label { text: qsTr("VPN ADDRESS & DNS"); font.pixelSize: 10; font.letterSpacing: 1; color: "#83a6c3" }
              Label { text: window.details || "—"; textFormat: Text.PlainText; color: "#e1edf8"; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
            ColumnLayout {
              spacing: 3; Layout.fillWidth: true
              Label { text: qsTr("LIVE TRAFFIC"); font.pixelSize: 10; font.letterSpacing: 1; color: "#83a6c3" }
              Label { text: window.speed || "—"; color: "#e1edf8"; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
            }
          }
          Button {
            Layout.fillWidth: true; highlighted: !window.connected; enabled: !backend.busy && window.selectedUuid !== ""
            text: window.connected ? qsTr("Disconnect VPN") : qsTr("Connect VPN")
            onClicked: window.send(window.connected ? "disconnect" : "connect")
          }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 5; visible: !window.connected
        Label { text: qsTr("Sign in"); font.pixelSize: 17; font.bold: true; color: "#edf5fc" }
        Label { text: qsTr("Use your work VPN credentials. A saved password can be used here."); color: "#93abc0"; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
        TextField { id: username; placeholderText: qsTr("VPN username (optional)"); Layout.fillWidth: true; enabled: !backend.busy }
        TextField { id: password; placeholderText: qsTr("Password (or use saved password)"); echoMode: TextInput.Password; Layout.fillWidth: true; enabled: !backend.busy; onAccepted: if (!backend.busy) window.send("connect") }
        CheckBox { id: remember; text: qsTr("Save password in keyring"); checked: true; enabled: !backend.busy }
      }
      Button {
        Layout.fillWidth: true; flat: true; enabled: !backend.busy && !window.connected
        text: window.setupVisible ? qsTr("Hide profile setup  −") : qsTr("Import VPN configuration  +")
        onClicked: window.setupVisible = !window.setupVisible
      }
      ColumnLayout {
        visible: window.setupVisible; Layout.fillWidth: true; spacing: 8
        Label { text: qsTr("Choose the .ovpn file provided by your organization."); color: "#a6bdd1"; wrapMode: Text.Wrap; Layout.fillWidth: true }
        RowLayout {
          Layout.fillWidth: true
          Button { text: qsTr("Choose file…"); enabled: !backend.busy && !window.connected; onClicked: picker.open() }
          Label { text: window.selectedPath || qsTr("No file selected"); textFormat: Text.PlainText; elide: Text.ElideMiddle; color: "#a6bdd1"; Layout.fillWidth: true }
        }
        Button { text: qsTr("Import profile"); enabled: window.selectedPath !== "" && !backend.busy && !window.connected; onClicked: window.send("import") }
      }
      Label { visible: text !== ""; text: window.notice; textFormat: Text.PlainText; wrapMode: Text.Wrap; Layout.fillWidth: true; color: "#c6d9e9" }
      Item { Layout.fillHeight: true; Layout.minimumHeight: 8 }
      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#1d3349" }
      Label { text: qsTr("Powered by BvOs Intelligence  ·  © 2026 The Blue View Group Corporation"); font.pixelSize: 11; color: "#7596af"; wrapMode: Text.Wrap; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; bottomPadding: 16 }
    }
  }
  Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
}
