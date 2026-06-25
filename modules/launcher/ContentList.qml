pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property var content
    required property DrawerVisibilities visibilities
    required property var panels
    required property real maxHeight
    required property real screenWidth
    required property StyledTextField search
    required property int padding
    required property int rounding

    property bool chatActivated: false

    readonly property bool showChat: search.text.startsWith("?")
    readonly property bool showWallpapers: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}wallpaper `)
    readonly property var currentList: showChat ? (chatList.item ? chatList.item.currentList : null) : (showWallpapers ? wallpaperList.item : appList.item) // Can be either ListView or PathView, so can't type properly
    readonly property alias chatList: chatList

    onShowChatChanged: {
        if (showChat)
            chatActivated = true;
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    clip: true
    state: showChat ? "chat" : (showWallpapers ? "wallpapers" : "apps")

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.implicitWidth: root.Tokens.sizes.launcher.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, appList.implicitHeight > 0 ? appList.implicitHeight : empty.implicitHeight)
                appList.active: true
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "wallpapers"

            PropertyChanges {
                root.implicitWidth: Math.max(root.Tokens.sizes.launcher.itemWidth * 1.2, wallpaperList.implicitWidth)
                root.implicitHeight: root.Tokens.sizes.launcher.wallpaperHeight
                wallpaperList.active: true
            }
        },
        State {
            name: "chat"

            PropertyChanges {
                root.implicitWidth: (chatList.item && chatList.item.expanded) ? (chatList.item.agentFullScreen ? (root.screenWidth - root.padding * 2) : chatList.item.agentExpandedWidth) : (chatList.item ? chatList.item.agentDefaultWidth : Math.min(850, root.screenWidth - root.padding * 2))
                root.implicitHeight: (chatList.item && chatList.item.expanded) ? (chatList.item.agentFullScreen ? root.maxHeight : Math.min(root.maxHeight, chatList.item.agentExpandedHeight)) : (chatList.item ? Math.min(root.maxHeight, chatList.item.agentDefaultHeight) : Math.min(root.maxHeight, 600))
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        }
    ]

    Behavior on state {
        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                type: Anim.DefaultEffects
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: appList

        active: false

        anchors.fill: parent

        sourceComponent: AppList {
            search: root.search
            visibilities: root.visibilities
        }
    }

    Loader {
        id: wallpaperList

        asynchronous: true
        active: false

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        sourceComponent: WallpaperList {
            search: root.search
            visibilities: root.visibilities
            panels: root.panels
            content: root.content
        }
    }

    Loader {
        id: chatList

        active: root.chatActivated
        visible: root.state === "chat"

        anchors.fill: parent

        sourceComponent: ChatList {
            search: root.search
            visibilities: root.visibilities
            screenWidth: root.screenWidth
            maxHeight: root.maxHeight
        }
    }

    Row {
        id: empty

        opacity: root.state !== "chat" && root.currentList?.count === 0 ? 1 : 0
        scale: root.state !== "chat" && root.currentList?.count === 0 ? 1 : 0.5

        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: root.state === "wallpapers" ? "wallpaper_slideshow" : "manage_search"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.state === "wallpapers" ? qsTr("No wallpapers found") : qsTr("No results")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: root.state === "wallpapers" && Wallpapers.list.length === 0 ? qsTr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir)) : qsTr("Try searching for something else")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitWidth {
        enabled: root.visibilities.launcher

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: root.visibilities.launcher

        Anim {}
    }
}
