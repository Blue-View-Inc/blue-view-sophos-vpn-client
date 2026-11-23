import QtQuick
import Quickshell
import qs.Ui

BarWidget {
    id: root
    moduleName: "blueview.sophos-vpn"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        iconComponent: Component {
            Image {
                width: 24
                height: 24
                fillMode: Image.PreserveAspectFit
                source: Qt.resolvedUrl("src/blueviewvpn.svg")
            }
        }
        Accessible.name: "Open Blue View Sophos VPN Client"
        onPressed: function(mouseButton) {
            if (mouseButton === Qt.LeftButton)
                Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/sophosvpn"])
        }
    }
}
