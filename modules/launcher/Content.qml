pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property var panels
    required property real maxHeight
    required property real screenWidth

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: searchWrapper.height + listWrapper.height + padding + searchWrapper.anchors.bottomMargin

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: searchWrapper.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight - searchWrapper.implicitHeight - root.padding * 3
            screenWidth: root.screenWidth
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    StyledRect {
        id: searchWrapper

        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Tokens.rounding.full

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        anchors.bottomMargin: CUtils.clamp(root.padding - Config.border.thickness, 0, root.padding)

        implicitHeight: Math.max(searchIcon.implicitHeight, search.implicitHeight, clearIcon.implicitHeight)

        MaterialIcon {
            id: searchIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.padding

            text: "search"
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledTextField {
            id: search

            property string prevText: ""
            property var chatHistory: []
            property int chatHistoryIndex: -1
            property string tempInput: ""

            function updateChatHistoryFromModel() {
                var newHistory = [];
                var chatItem = (list && list.chatList && list.chatList.item);
                if (chatItem && chatItem.chatModel) {
                    var model = chatItem.chatModel;
                    for (var i = 0; i < model.count; i++) {
                        var msg = model.get(i);
                        if (msg && msg.sender === "user" && msg.text) {
                            var fullText = "? " + msg.text.trim();
                            if (newHistory.length === 0 || newHistory[newHistory.length - 1] !== fullText) {
                                newHistory.push(fullText);
                            }
                        }
                    }
                }
                chatHistory = newHistory;
            }

            onTextChanged: {
                if (text === "?") {
                    if (prevText === "") {
                        text = "? ";
                    } else {
                        text = "";
                    }
                }
                prevText = text;
            }

            anchors.left: searchIcon.right
            anchors.right: clearIcon.left
            anchors.leftMargin: Tokens.spacing.small
            anchors.rightMargin: Tokens.spacing.small

            topPadding: Tokens.padding.medium
            bottomPadding: Tokens.padding.medium

            placeholderText: qsTr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

            onAccepted: {
                if (list.showChat) {
                    const chatItem = (list && list.chatList && list.chatList.item);
                    if (chatItem && chatItem.isGenerating) {
                        return;
                    }
                    const message = text.substring(1).trim();
                    if (message.length > 0 && chatItem) {
                        chatHistoryIndex = -1;
                        tempInput = "";
                        chatItem.sendMessage(message);
                        text = "? ";
                    }
                    return;
                }
                const currentItem = list.currentList?.currentItem;
                if (currentItem) {
                    if (list.showWallpapers) {
                        if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                            Wallpapers.previewColourLock = true;
                        Wallpapers.setWallpaper(currentItem.modelData.path);
                        root.visibilities.launcher = false;
                    } else if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                        if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `))
                            currentItem.onClicked();
                        else
                            currentItem.modelData.onClicked(list.currentList);
                    } else {
                        Apps.launch(currentItem.modelData);
                        root.visibilities.launcher = false;
                    }
                }
            }

            Keys.onUpPressed: {
                if (list.showChat) {
                    if (chatHistoryIndex === -1) {
                        updateChatHistoryFromModel();
                        tempInput = text;
                        chatHistoryIndex = chatHistory.length - 1;
                    } else if (chatHistoryIndex > 0) {
                        chatHistoryIndex--;
                    }
                    if (chatHistoryIndex >= 0 && chatHistoryIndex < chatHistory.length) {
                        text = chatHistory[chatHistoryIndex];
                        cursorPosition = text.length;
                    }
                } else {
                    list.currentList?.decrementCurrentIndex();
                }
            }
            Keys.onDownPressed: {
                if (list.showChat) {
                    if (chatHistoryIndex !== -1) {
                        if (chatHistoryIndex === chatHistory.length - 1) {
                            chatHistoryIndex = -1;
                            text = tempInput;
                            cursorPosition = text.length;
                        } else if (chatHistoryIndex < chatHistory.length - 1) {
                            chatHistoryIndex++;
                            text = chatHistory[chatHistoryIndex];
                            cursorPosition = text.length;
                        }
                    }
                } else {
                    list.currentList?.incrementCurrentIndex();
                }
            }

            Keys.onEscapePressed: root.visibilities.launcher = false

            Keys.onPressed: event => {
                if (!GlobalConfig.launcher.vimKeybinds)
                    return;

                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                        list.currentList?.incrementCurrentIndex();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                        list.currentList?.decrementCurrentIndex();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Tab) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Connections {
                function onLauncherChanged(): void {
                    if (root.visibilities.launcher) {
                        search.forceActiveFocus();
                    } else {
                        search.text = "";
                        search.chatHistoryIndex = -1;
                        search.tempInput = "";
                    }
                }

                function onSessionChanged(): void {
                    if (!root.visibilities.session)
                        search.forceActiveFocus();
                }

                target: root.visibilities
            }
        }

        MaterialIcon {
            id: clearIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: list.showChat ? (root.padding + sendBtn.width + Tokens.spacing.medium) : root.padding

            width: search.text ? implicitWidth : implicitWidth / 2
            opacity: {
                if (!search.text)
                    return 0;
                if (mouse.pressed)
                    return 0.7;
                if (mouse.containsMouse)
                    return 0.8;
                return 1;
            }

            text: "close"
            color: Colours.palette.m3onSurfaceVariant

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: search.text ? Qt.PointingHandCursor : undefined

                onClicked: search.text = ""
            }

            Behavior on width {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            Behavior on anchors.rightMargin {
                Anim {
                    type: Anim.StandardSmall
                }
            }
        }

        IconButton {
            id: sendBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: list.showChat ? root.padding : 0

            width: list.showChat ? 36 : 0
            height: list.showChat ? 36 : 0
            scale: list.showChat ? (disabled ? 0.85 : (hovered ? 1.08 : 1.0)) : 0
            opacity: list.showChat ? (disabled ? 0.35 : 1.0) : 0
            visible: opacity > 0

            isRound: true
            type: IconButton.Filled
            icon: {
                const chatItem = (list && list.chatList && list.chatList.item);
                return (chatItem && chatItem.isGenerating) ? "stop" : "rocket_launch";
            }
            label.rotation: {
                const chatItem = (list && list.chatList && list.chatList.item);
                return (chatItem && chatItem.isGenerating) ? 0 : 45;
            }
            disabled: {
                const chatItem = (list && list.chatList && list.chatList.item);
                if (chatItem && chatItem.isGenerating) {
                    return false;
                }
                return search.text.substring(1).trim().length === 0;
            }

            onClicked: {
                const chatItem = (list && list.chatList && list.chatList.item);
                if (chatItem && chatItem.isGenerating) {
                    chatItem.stopGeneration();
                } else {
                    const message = search.text.substring(1).trim();
                    if (message.length > 0 && chatItem) {
                        search.chatHistoryIndex = -1;
                        search.tempInput = "";
                        chatItem.sendMessage(message);
                        search.text = "? ";
                        search.forceActiveFocus();
                    }
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            Behavior on width {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            Behavior on height {
                Anim {
                    type: Anim.StandardSmall
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.StandardSmall
                }
            }
        }
    }
}

