import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

ApplicationWindow {
  id: window
  width: 420; height: 600; minimumWidth: 360; minimumHeight: 400
  visible: true; title: qsTr("Blue View VPN")
  Settings { id: preferences; category: "appearance"; property bool darkTheme: false }
  readonly property bool darkTheme: preferences.darkTheme
  readonly property color ink: darkTheme ? "#e6e8df" : "#1d2f14"
  readonly property color muted: darkTheme ? "#9fab99" : "#55644c"
  readonly property color lineColor: darkTheme ? "#31402f" : "#d6d2c8"
  color: darkTheme ? "#141a16" : "#f6f5f1"
  font.family: "Inter"
  Material.theme: darkTheme ? Material.Dark : Material.Light
  Material.accent: darkTheme ? "#9fc57e" : "#356b19"
  FontLoader { id: sophosHeadingFont; source: "qrc:/LexendExa.ttf" }
  FontLoader { id: signatureFont; source: "qrc:/Caveat.ttf" }
  component LineIcon: Canvas {
    id: icon
    property string kind: "key"
    property color strokeColor: window.darkTheme ? "#a9c79b" : "#547847"
    implicitWidth: 18; implicitHeight: 18
    onStrokeColorChanged: requestPaint()
    onPaint: {
      const c = getContext("2d"); c.reset(); c.strokeStyle = strokeColor
      c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round"
      if (kind === "key") {
        c.beginPath(); c.arc(6, 7, 3, 0, 2 * Math.PI); c.stroke()
        c.beginPath(); c.moveTo(8.5, 9.5); c.lineTo(14, 15); c.moveTo(11.5, 12.5); c.lineTo(13, 11); c.moveTo(13, 14); c.lineTo(14.5, 12.5); c.stroke()
      } else {
        c.beginPath(); c.moveTo(3, 3); c.lineTo(11, 3); c.lineTo(15, 7); c.lineTo(15, 15); c.lineTo(3, 15); c.closePath(); c.stroke()
        c.beginPath(); c.moveTo(10.5, 3.5); c.lineTo(10.5, 7.5); c.lineTo(14.5, 7.5); c.moveTo(6, 11); c.lineTo(12, 11); c.moveTo(9, 8.5); c.lineTo(9, 13.5); c.stroke()
      }
    }
  }
  component CredentialField: TextField {
    id: field
    Layout.fillWidth: true; Layout.preferredHeight: 40
    leftPadding: 11; rightPadding: 11; topPadding: 4; bottomPadding: 4
    color: window.ink
    placeholderTextColor: window.darkTheme ? "#87998a" : "#879484"
    font.pixelSize: 12
    background: Rectangle {
      radius: 8
      gradient: Gradient {
        GradientStop { position: 0; color: window.darkTheme ? "#27372d" : "#ffffff" }
        GradientStop { position: 1; color: window.darkTheme ? "#1b261f" : "#f7f8f5" }
      }
      border.width: field.activeFocus ? 2 : 1
      border.color: field.activeFocus ? (window.darkTheme ? "#a9c79b" : "#356b19") : window.lineColor
    }
  }
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
        if (window.lastAction === "import") importDialog.close()
        window.lastAction = "status"
        Qt.callLater(function() { backend.request({action:"status"}) })
      }
    }
  }
  FileDialog { id: picker; title: qsTr("Choose an OpenVPN configuration"); nameFilters: [qsTr("OpenVPN configurations (*.ovpn)")]; onAccepted: window.selectedPath = backend.localPath(selectedFile) }
  Dialog {
    id: importDialog
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(window.width - 32, 380)
    modal: true
    title: qsTr("Import VPN configuration")
    standardButtons: Dialog.Close
    contentItem: ColumnLayout {
      spacing: 8
      Label { text: qsTr("Choose the .ovpn file provided by your organization."); color: window.muted; wrapMode: Text.Wrap; Layout.fillWidth: true }
      Button { text: qsTr("Choose file…"); Layout.fillWidth: true; enabled: !backend.busy && !window.connected; onClicked: picker.open() }
      Label { text: window.selectedPath || qsTr("No file selected"); textFormat: Text.PlainText; elide: Text.ElideMiddle; color: window.muted; Layout.fillWidth: true }
      Button { text: qsTr("Import profile"); Layout.fillWidth: true; enabled: window.selectedPath !== "" && !backend.busy && !window.connected; onClicked: window.send("import") }
      Label { visible: text !== ""; text: window.notice; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: window.ink; Layout.fillWidth: true }
    }
  }
  ScrollView {
    anchors.fill: parent; clip: true
    contentWidth: availableWidth
    ColumnLayout {
      width: Math.max(0, window.width - 32); height: Math.max(window.height, implicitHeight); x: 16
      spacing: 5
      Item { Layout.preferredHeight: 2 }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 0
        RowLayout {
          Layout.fillWidth: true; spacing: 11
          Item {
            Layout.fillWidth: true; Layout.preferredHeight: 48
            Accessible.role: Accessible.Graphic
            Accessible.name: qsTr("Sophos VPN")
            // The official artwork remains unchanged; layered light gives it depth.
            Rectangle {
              x: -6; y: 3; width: Math.min(parent.width, 248); height: 40; radius: 12
              gradient: Gradient {
                GradientStop { position: 0; color: window.darkTheme ? "#263e56" : "#e0edff" }
                GradientStop { position: 1; color: window.darkTheme ? "#142321" : "#f6f5f1" }
              }
              opacity: 0.6
            }
            Image {
              x: 1; y: 13; width: Math.min(parent.width - 32, 205); height: 23
              source: window.darkTheme ? "qrc:/sophos-wordmark-dark.svg" : "qrc:/sophos-wordmark-light.svg"
              fillMode: Image.PreserveAspectFit; opacity: window.darkTheme ? 0.18 : 0.12
            }
            Image {
              x: 0; y: 11; width: Math.min(parent.width - 32, 205); height: 23
              source: window.darkTheme ? "qrc:/sophos-wordmark-dark.svg" : "qrc:/sophos-wordmark-light.svg"
              fillMode: Image.PreserveAspectFit
            }
            Text {
              x: Math.min(parent.width - 27, 212); y: 16
              text: "VPN"; color: window.muted; font.family: sophosHeadingFont.name
              font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 0.7
            }
          }
          ToolButton {
            id: themeButton
            Accessible.name: window.darkTheme ? qsTr("Switch to light theme") : qsTr("Switch to dark theme")
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name
            contentItem: Text {
              text: window.darkTheme ? "☀" : "☾"
              color: window.ink; font.pixelSize: 24
              horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            onClicked: preferences.darkTheme = !preferences.darkTheme
          }
        }
        RowLayout {
          Layout.leftMargin: 4; spacing: 7
          ToolButton {
            Layout.preferredWidth: 38; Layout.preferredHeight: 38
            padding: 2
            Accessible.name: qsTr("Visit BvOs")
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Visit bvos.blueview.ai")
            background: Item {}
            contentItem: Item {
              Rectangle {
                anchors.fill: parent; anchors.margins: 1; radius: 10; opacity: 0.6
                gradient: Gradient {
                  GradientStop { position: 0; color: window.darkTheme ? "#394b3a" : "#e8f0dd" }
                  GradientStop { position: 1; color: window.darkTheme ? "#1c2820" : "#f6f5f1" }
                }
              }
              Image { anchors.centerIn: parent; anchors.verticalCenterOffset: 2; width: 31; height: 31; opacity: 0.2; source: window.darkTheme ? "qrc:/blueview-oval.svg" : "qrc:/blueview-oval-light.svg"; fillMode: Image.PreserveAspectFit }
              Image { anchors.centerIn: parent; width: 31; height: 31; source: window.darkTheme ? "qrc:/blueview-oval.svg" : "qrc:/blueview-oval-light.svg"; fillMode: Image.PreserveAspectFit }
            }
            onClicked: Qt.openUrlExternally("https://bvos.blueview.ai")
          }
          ColumnLayout {
            spacing: -2
            Label {
              textFormat: Text.RichText
              text: '<a href="https://blueview.ai" style="color:' + (window.darkTheme ? '#a9b9a1' : '#356b19') + '">' + qsTr("Powered by BvOs Intelligence") + '</a>'
              font.pixelSize: 11
              onLinkActivated: function(link) { Qt.openUrlExternally(link) }
            }
            Label { text: qsTr("Naturally Yours"); font.family: signatureFont.name; font.pixelSize: 17; color: window.darkTheme ? "#b5cda8" : "#557748" }
          }
        }
      }
      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: window.lineColor }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 3
        Label { text: qsTr("VPN PROFILE"); font.pixelSize: 10; font.letterSpacing: 1; color: window.muted }
        ComboBox {
          id: profilePicker; Layout.fillWidth: true; Layout.preferredHeight: 36; topPadding: 2; bottomPadding: 2; model: window.profiles; textRole: "name"
          enabled: !backend.busy && !window.connected && window.profiles.length > 0
          onActivated: function(index) { window.chooseProfile(index) }
          displayText: currentIndex < 0 ? qsTr("Import a VPN configuration to get started") : currentText
        }
        Label { visible: window.connected && window.profiles.length > 1; text: qsTr("Disconnect to switch profiles."); color: window.muted; font.pixelSize: 11 }
      }
      Rectangle {
        Layout.fillWidth: true; implicitHeight: statusContent.implicitHeight + 16
        radius: 14; border.color: window.darkTheme ? "#405244" : "#d5d8cb"
        gradient: Gradient {
          GradientStop { position: 0; color: window.darkTheme ? "#26352c" : "#ffffff" }
          GradientStop { position: 1; color: window.darkTheme ? "#1b261f" : "#ecefe8" }
        }
        Rectangle {
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.leftMargin: 13; anchors.rightMargin: 13; anchors.topMargin: 1
          height: 1; color: window.darkTheme ? "#557060" : "#ffffff"; opacity: 0.75
        }
        ColumnLayout {
          id: statusContent; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; spacing: 4
          RowLayout {
            Layout.fillWidth: true; spacing: 10
            Rectangle { width: 11; height: 11; radius: 6; color: window.connected ? "#50d6a2" : "#e3a967" }
            ColumnLayout {
              spacing: 1; Layout.fillWidth: true
              Label { text: window.connected ? qsTr("Connected") : qsTr("Disconnected"); font.bold: true; font.pixelSize: 16; color: window.ink }
              Label { text: qsTr("Sophos / OpenVPN · Split tunnel"); color: window.muted; font.pixelSize: 12 }
            }
            BusyIndicator { running: backend.busy; visible: running; Layout.preferredWidth: 32; Layout.preferredHeight: 32 }
          }
          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: window.lineColor }
          ColumnLayout {
            Layout.fillWidth: true; visible: window.connected; spacing: 3
            ColumnLayout {
              Layout.fillWidth: true; spacing: 3
              Label { text: qsTr("VPN ADDRESS & DNS"); font.pixelSize: 10; font.letterSpacing: 1; color: window.muted }
              Label { text: window.details || "—"; textFormat: Text.PlainText; color: window.ink; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
            }
            ColumnLayout {
              spacing: 3; Layout.fillWidth: true
              Label { text: qsTr("LIVE TRAFFIC"); font.pixelSize: 10; font.letterSpacing: 1; color: window.muted }
              Label { text: window.speed || "—"; color: window.ink; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
            }
          }
          Button {
            id: connectionButton
            Layout.fillWidth: true; Layout.preferredHeight: 38; enabled: !backend.busy && window.selectedUuid !== ""
            text: window.connected ? qsTr("Disconnect VPN") : qsTr("Connect VPN")
            ToolTip.visible: hovered
            ToolTip.text: window.connected ? qsTr("Disconnect this VPN profile") : qsTr("Connect using the selected profile")
            background: Rectangle {
              radius: 8
              color: !connectionButton.enabled ? (window.darkTheme ? "#303c33" : "#d9ddd5") : window.connected
                     ? (connectionButton.down ? (window.darkTheme ? "#33483a" : "#d7e0d2") : (window.darkTheme ? "#26372d" : "#e5ebe1"))
                     : (connectionButton.down ? "#285814" : (connectionButton.hovered ? "#427d27" : "#356b19"))
              border.width: connectionButton.activeFocus ? 2 : 1
              border.color: connectionButton.activeFocus ? (window.darkTheme ? "#c0e3ad" : "#356b19") : (window.connected ? window.lineColor : "transparent")
            }
            contentItem: Text {
              text: connectionButton.text; font.family: window.font.family; font.pixelSize: 13; font.weight: Font.DemiBold
              color: !connectionButton.enabled ? window.muted : (window.connected ? window.ink : "white")
              horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            onClicked: window.send(window.connected ? "disconnect" : "connect")
          }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 2; visible: !window.connected
        Label { text: qsTr("Sign in"); font.family: "Manrope"; font.pixelSize: 14; font.bold: true; color: window.ink }
        CredentialField { id: username; placeholderText: qsTr("VPN username (optional)"); enabled: !backend.busy; ToolTip.visible: hovered; ToolTip.text: qsTr("Username supplied by your VPN administrator") }
        CredentialField { id: password; placeholderText: qsTr("Password (or use saved password)"); echoMode: TextInput.Password; enabled: !backend.busy; ToolTip.visible: hovered; ToolTip.text: qsTr("Leave blank to use a password saved in your keyring"); onAccepted: if (!backend.busy) window.send("connect") }
        Switch {
          id: remember
          Layout.fillWidth: true; Layout.preferredHeight: 40
          checked: true; enabled: !backend.busy
          text: qsTr("Save password")
          Accessible.name: qsTr("Save password in system keyring")
          ToolTip.visible: hovered
          ToolTip.text: qsTr("Store the password in your system keyring after connecting successfully")
          padding: 0; leftPadding: 8; rightPadding: 8
          background: Rectangle {
            radius: 8
            color: remember.hovered ? (window.darkTheme ? "#26362b" : "#e4eadf") : (window.darkTheme ? "#1c241e" : "#f0f1eb")
            border.color: remember.activeFocus ? (window.darkTheme ? "#a9c79b" : "#356b19") : window.lineColor
            border.width: remember.activeFocus ? 2 : 1
          }
          contentItem: Row {
            spacing: 8
            LineIcon { anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18 }
            Text { anchors.verticalCenter: parent.verticalCenter; text: remember.text; font.family: window.font.family; font.pixelSize: 12; font.weight: Font.Medium; color: window.ink }
          }
          indicator: Rectangle {
            implicitWidth: 34; implicitHeight: 20
            x: remember.width - width - 10; y: (remember.height - height) / 2
            radius: height / 2
            color: remember.checked ? (window.darkTheme ? "#9fc57e" : "#356b19") : (window.darkTheme ? "#506052" : "#adb6aa")
            Rectangle { width: 14; height: 14; radius: 7; y: 3; x: remember.checked ? parent.width - width - 3 : 3; color: "#ffffff" }
          }
        }
      }
      Button {
        id: importButton
        Layout.fillWidth: true; Layout.preferredHeight: 40; enabled: !backend.busy && !window.connected
        text: qsTr("Import VPN configuration")
        ToolTip.visible: hovered
        ToolTip.text: qsTr("Add a profile from an OpenVPN configuration file")
        padding: 0; leftPadding: 8; rightPadding: 8
        background: Rectangle {
          radius: 8
          color: importButton.hovered ? (window.darkTheme ? "#26362b" : "#e4eadf") : "transparent"
          border.color: importButton.activeFocus ? (window.darkTheme ? "#a9c79b" : "#356b19") : window.lineColor
          border.width: importButton.activeFocus ? 2 : 1
          opacity: importButton.enabled ? 1 : 0.55
        }
        contentItem: Item {
          opacity: importButton.enabled ? 1 : 0.55
          Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 8
            LineIcon { kind: "file"; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18 }
            Text { text: importButton.text; anchors.verticalCenter: parent.verticalCenter; font.family: window.font.family; font.pixelSize: 12; font.weight: Font.Medium; color: window.ink }
          }
          Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "›"; font.pixelSize: 20; color: window.muted }
        }
        onClicked: importDialog.open()
      }
      Label { visible: text !== ""; text: window.notice; textFormat: Text.PlainText; wrapMode: Text.Wrap; Layout.fillWidth: true; color: window.ink }
      Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: window.lineColor }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 2
        Label { text: qsTr("An independent, free-to-use community application. Not affiliated with or endorsed by Sophos."); font.pixelSize: 9; color: window.muted; wrapMode: Text.Wrap; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
        Label { text: qsTr("This app collects and sends no telemetry."); font.pixelSize: 9; color: window.muted; wrapMode: Text.Wrap; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
        Label { text: qsTr("Powered by BvOs Intelligence  ·  © 2026 The Blue View Group Corporation"); font.pixelSize: 9; color: window.muted; wrapMode: Text.Wrap; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
        Label {
          Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; bottomPadding: 2; font.pixelSize: 9
          textFormat: Text.RichText
          text: '<a href="https://github.com/Blue-View-Inc/blueview-vpn/blob/master/LEGAL.md" style="color:' + (window.darkTheme ? '#81c4ff' : '#2861b8') + '">' + qsTr("Legal and license information") + '</a>'
          onLinkActivated: function(link) { Qt.openUrlExternally(link) }
        }
      }
    }
  }
  Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
}
