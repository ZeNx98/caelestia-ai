import QtQuick
import QtQuick.Templates
import Caelestia.Config
import qs.components
import qs.services

ScrollBar {
    id: root

    required property Flickable flickable
    property bool shouldBeActive
    property real nonAnimPosition
    property bool animating
    property bool _updatingFromFlickable: false
    property bool _updatingFromUser: false

    onHoveredChanged: {
        if (hovered)
            shouldBeActive = true;
        else
            shouldBeActive = flickable.moving;
    }

    onPositionChanged: {
        
        if (fullMouse.pressed) return;

        if (_updatingFromUser) {
            _updatingFromUser = false;
            return;
        }
        if (position === nonAnimPosition) {
            animating = false;
            return;
        }
        if (!animating && !_updatingFromFlickable) {
            nonAnimPosition = position;
        }
    }

    Component.onCompleted: {
        if (flickable) {
            const contentHeight = flickable.contentHeight;
            const height = flickable.height;
            if (contentHeight > height) {
                nonAnimPosition = Math.max(0, Math.min(1, flickable.contentY / (contentHeight - height)));
            }
        }
    }
    implicitWidth: 8

    contentItem: StyledRect {
        anchors.right: parent.right
        width: (root.hovered || fullMouse.pressed) ? 4 : 2
        opacity: {
            if (root.size === 1)
                return 0;
            if (fullMouse.pressed)
                return 1;
            if (root.hovered)
                return 0.8;
            if (root.policy === ScrollBar.AlwaysOn || root.shouldBeActive)
                return 0.6;
            return 0;
        }
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondary

        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Connections {
        function onContentYChanged() {
            
            if (fullMouse.pressed || root.animating) return;

            root._updatingFromFlickable = true;
            const contentHeight = root.flickable.contentHeight;
            const height = root.flickable.height;
            if (contentHeight > height) {
                root.nonAnimPosition = Math.max(0, Math.min(1, root.flickable.contentY / (contentHeight - height)));
            } else {
                root.nonAnimPosition = 0;
            }
            root._updatingFromFlickable = false;
        }

        target: root.flickable
    }

    Connections {
        function onMovingChanged(): void {
            if (root.flickable.moving)
                root.shouldBeActive = true;
            else
                hideDelay.restart();
        }

        target: root.flickable
    }

    Timer {
        id: hideDelay

        interval: 600
        onTriggered: root.shouldBeActive = root.flickable.moving || root.hovered
    }

    CustomMouseArea {
        id: fullMouse

        property real dragOffset: 0

        function onWheel(event: WheelEvent): void {
            root.animating = true;
            root._updatingFromUser = true;
            let newPos = root.nonAnimPosition;
            if (event.angleDelta.y > 0)
                newPos = Math.max(0, root.nonAnimPosition - 0.1);
            else if (event.angleDelta.y < 0)
                newPos = Math.min(1 - root.size, root.nonAnimPosition + 0.1);
            root.nonAnimPosition = newPos;
            if (root.flickable) {
                const contentHeight = root.flickable.contentHeight;
                const height = root.flickable.height;
                if (contentHeight > height) {
                    const maxContentY = contentHeight - height;
                    const maxPos = 1 - root.size;
                    const contentY = maxPos > 0 ? (newPos / maxPos) * maxContentY : 0;
                    root.flickable.contentY = Math.max(0, Math.min(maxContentY, contentY));
                }
            }
        }

        anchors.fill: parent
        preventStealing: true

        onPressed: event => {
            
            root.animating = false;
            const clickPos = event.y / root.height;
            const handleStart = root.position;
            if (clickPos >= handleStart && clickPos <= handleStart + root.size) {
                dragOffset = clickPos - handleStart;
            } else {
                dragOffset = root.size / 2;
            }
            
            _applyDragPos(event.y);
        }

        onPositionChanged: event => {
            _applyDragPos(event.y);
        }

        onReleased: event => {
            
            root.animating = false;
            if (root.flickable) {
                const contentHeight = root.flickable.contentHeight;
                const height = root.flickable.height;
                if (contentHeight > height) {
                    root.nonAnimPosition = Math.max(0, Math.min(1, root.flickable.contentY / (contentHeight - height)));
                }
            }
        }

        function _applyDragPos(mouseY: real): void {
            if (!root.flickable) return;
            const clickPos = mouseY / root.height;
            const newPos = Math.max(0, Math.min(1 - root.size, clickPos - dragOffset));
            const contentHeight = root.flickable.contentHeight;
            const height = root.flickable.height;
            if (contentHeight > height) {
                const maxContentY = contentHeight - height;
                const maxPos = 1 - root.size;
                root.flickable.contentY = maxPos > 0
                    ? Math.max(0, Math.min(maxContentY, (newPos / maxPos) * maxContentY))
                    : 0;
            }
        }
    }

    Behavior on position {
        enabled: !fullMouse.pressed && !root._updatingFromFlickable && (!root.flickable || (!root.flickable.moving && !root.flickable.flicking))

        Anim {}
    }
}
