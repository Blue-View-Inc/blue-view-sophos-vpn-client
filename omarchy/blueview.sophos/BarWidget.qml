import QtQuick
import Quickshell.Io
import qs.Ui

BarIconButton {
  id: root
  property string moduleName: "blueview.sophos"
  property var settings
  property bool known: false
  property bool connected: false
  tooltipText: !known ? "Sophos VPN status unavailable" : (connected ? "Sophos VPN connected · open app" : "Sophos VPN disconnected · open app")
  iconComponent: Component {
    Item {
      width: 16; height: 16
      Image { anchors.fill: parent; source: "sophos.svg"; fillMode: Image.PreserveAspectFit; smooth: true }
      Rectangle {
        visible: root.known && root.connected
        width: 5; height: 5; radius: 3
        anchors.right: parent.right; anchors.bottom: parent.bottom
        color: "#50d6a2"; border.color: "#183a2a"; border.width: 1
      }
    }
  }
  onPressed: function(button) {
    if (bar && button === Qt.LeftButton) bar.run("sophosvpn")
  }
  Process {
    id: statusProcess
    command: ["sophosvpn-backend"]
    stdinEnabled: true
    onStarted: write('{"action":"status"}\n')
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const result = JSON.parse(text)
          root.known = result.ok === true && result.result !== undefined
          root.connected = root.known && result.result.connected === true
        } catch (error) { root.known = false; root.connected = false }
      }
    }
    onExited: function(exitCode) { if (exitCode !== 0) { root.known = false; root.connected = false } }
  }
  Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: if (!statusProcess.running) statusProcess.running = true }
}
