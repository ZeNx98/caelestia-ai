pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.LocalStorage 2.0 as Sql
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property StyledTextField search
    required property DrawerVisibilities visibilities
    required property real screenWidth
    required property real maxHeight

    implicitHeight: 600
    implicitWidth: parent ? parent.width : 850

    property bool expanded: false
    property bool userScrolledUp: false
    property bool isAutoScrolling: false
    property string hoverLinkUrl: ""
    property alias chatModel: chatModel

    property bool isResizing: false
    property string ollamaHost: "http://127.0.0.1:11435"

    onWidthChanged: {
        isResizing = true;
        resizeTimer.restart();
    }

    Timer {
        id: resizeTimer
        interval: 200
        onTriggered: root.isResizing = false
    }

    ListModel {
        id: chatModel
    }

    ListModel {
        id: historyModel
    }

    FileView {
        id: systemPromptReader
        path: "/home/zen/.config/quickshell/caelestia/modules/launcher/system_prompt.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.systemPromptText = text().trim();
            if (!root.hasUnsavedPromptChanges) {
                promptTextEdit.text = root.systemPromptText;
            }
        }
    }

    property bool showHistory: false
    property var conversationsList: []
    property string activeConversationId: ""
    property var availableModels: ["qwen2.5:0.5b"]
    property string activeModel: "qwen2.5:0.5b"
    onActiveModelChanged: {
        saveAgentSetting("activeModel", activeModel);
    }
    readonly property alias currentList: listView

    property bool showSettings: false
    property bool hasUnsavedPromptChanges: false
    property string systemPromptText: ""
    property var activeXhr: null
    property bool isGenerating: false
    property bool generationStopped: false
    property var activeProcesses: []
property bool agentFullScreen: false
property bool agentWebSearch: true
property bool agentDateTime: true
property bool agentLocation: false
property int contextWindow: 8192
property bool historyGridView: true

onHistoryGridViewChanged: {
    saveAgentSetting("historyGridView", historyGridView);
}

onContextWindowChanged: {
    saveAgentSetting("contextWindow", contextWindow);
}

onAgentWebSearchChanged: {
    saveAgentSetting("agentWebSearch", agentWebSearch);
}

onAgentDateTimeChanged: {
    saveAgentSetting("agentDateTime", agentDateTime);
}

onAgentLocationChanged: {
    saveAgentSetting("agentLocation", agentLocation);
}

onIsGeneratingChanged: {
    if (!isGenerating) {
        if (root.visibilities && !root.visibilities.launcher) {
            Quickshell.execDetached(["notify-send", "Caelestia AI", root.activeModel + " finished generating response."]);
        }
    }
}
property int agentExpandedWidth: Math.min(850, screenWidth - 32)
property int agentExpandedHeight: maxHeight
property int agentDefaultWidth: Math.min(850, screenWidth - 32)
property int agentDefaultHeight: Math.min(600, maxHeight)

    onShowHistoryChanged: {
        if (!showHistory) {
            showSettings = false;
        }
    }

    onShowSettingsChanged: {
        if (showSettings) {
            promptTextEdit.text = loadSystemPrompt();
            hasUnsavedPromptChanges = false;
        }
    }

    function smartScroll() {
    }

    function saveAgentSetting(key, value) {

        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS Settings(key TEXT UNIQUE, value TEXT)');
                tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', [key, value.toString()]);
            });
        } catch(e) {
            console.log("Error saving agent setting " + key + ":", e.toString());
        }
    }

    Component {
        id: menuItemComponent
        MenuItem {}
    }

    Component {
        id: textBlockComponent
        TextEdit {
            id: textEdit
            property var blockData: null
            property bool isUserMsg: false
            property string processedText: ""
            property bool loading: false

            text: processedText
            color: isUserMsg ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            selectedTextColor: isUserMsg ? Colours.palette.m3primaryContainer : Colours.palette.m3onPrimary
            selectionColor: isUserMsg ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
            wrapMode: TextEdit.WordWrap
            width: parent ? parent.width : 0

            textFormat: loading ? TextEdit.MarkdownText : TextEdit.RichText
            font: Tokens.font.body.medium
            readOnly: true
            selectByMouse: true
            cursorVisible: false

            onLinkActivated: (link) => Qt.openUrlExternally(link)
            onLinkHovered: (link) => { root.hoverLinkUrl = link; }

            function updateText() {
                if (!blockData || !blockData.content) {
                    processedText = "";
                    return;
                }
                var content = blockData.content;
                if (loading) {
                    processedText = content;
                    return;
                }
                var colorStr = isUserMsg ? (Colours.palette.m3onPrimaryContainer + "") : (Colours.palette.m3onSurface + "");

                var html = root.markdownToHtml(content, colorStr);
                processedText = root.processInlineMathHtml(html, colorStr, isUserMsg, function() {
                    if (textEdit) {
                        textEdit.updateText();
                    }
                });
            }

            onBlockDataChanged: updateText()
            onLoadingChanged: updateText()
            Component.onCompleted: updateText()

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
            }
        }
    }

    Component {
        id: codeBlockComponent
        StyledRect {
            property var blockData: null

            readonly property string lang: blockData ? (blockData.language || "code").toLowerCase() : "code"

            implicitWidth: 10000
            width: parent ? parent.width : 0
            height: codeHeader.height + codeBody.height

            color: Qt.tint(Colours.palette.m3surfaceContainerLowest,
                           Qt.rgba(Colours.palette.m3primary.r,
                                   Colours.palette.m3primary.g,
                                   Colours.palette.m3primary.b, 0.08))
            radius: Tokens.rounding.medium
            clip: true

            Rectangle {
                id: codeHeader
                width: parent.width
                height: 32
                color: Qt.tint(Colours.palette.m3surfaceContainerLow,
                               Qt.rgba(Colours.palette.m3primary.r,
                                       Colours.palette.m3primary.g,
                                       Colours.palette.m3primary.b, 0.13))
                radius: Tokens.rounding.medium

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.extraSmall

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: Colours.palette.m3primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (lang === "code" ? "plaintext" : lang).toUpperCase()
                        font.pixelSize: Tokens.font.label.small.pixelSize
                        font.family: "monospace"
                        font.weight: Font.Medium

                        color: Colours.palette.m3primary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                IconButton {
                    id: codeCopyBtn
                    property bool copied: false
                    icon: copied ? "check" : "content_copy"
                    type: IconButton.Text
                    width: 24; height: 24
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacing.small
                    anchors.verticalCenter: parent.verticalCenter
                    
                    activeOnColour: Colours.palette.m3primary
                    inactiveOnColour: Colours.palette.m3onSurfaceVariant

                    onClicked: {
                        if (blockData) {
                            Quickshell.clipboardText = blockData.content;
                            Toaster.toast("Code copied", "Snippet copied to clipboard", "content_copy");
                            copied = true;
                            codeRevertTimer.start();
                        }
                    }

                    Timer {
                        id: codeRevertTimer
                        interval: 1500
                        onTriggered: codeCopyBtn.copied = false
                    }
                }
            }

            Item {
                id: codeBody
                width: parent.width
                anchors.top: codeHeader.bottom
                height: codeText.implicitHeight + Tokens.padding.medium * 2

                TextEdit {
                    id: codeText
                    text: blockData ? highlightCode(blockData.content, lang) : ""
                    textFormat: TextEdit.RichText
                    font.family: "monospace"
                    font.pixelSize: Tokens.font.body.small.pixelSize

                    color: Colours.palette.m3onSurface
                    selectedTextColor: Colours.palette.m3onPrimary
                    selectionColor: Colours.palette.m3primary
                    wrapMode: TextEdit.WrapAnywhere
                    readOnly: true
                    selectByMouse: true
                    cursorVisible: false
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium

                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                    onLinkHovered: (link) => { root.hoverLinkUrl = link; }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
                    }
                }
            }
        }
    }

    Component {
        id: mathBlockComponent
        Item {
            id: mathBlock
            property var blockData: null
            property bool isUserMsg: false
            property string imagePath: ""
            property bool rendering: true
            property string lastCacheKey: ""
            property bool loading: false

            implicitWidth: mathImage.visible ? mathImage.implicitWidth + 16 : 120
            width: parent ? parent.width : 0
            readonly property int vGap: 6
            height: loading
                ? Math.max(30, rawMathText.implicitHeight) + vGap * 2
                : (rendering ? 40 + vGap * 2 : Math.max(30, mathImage.implicitHeight + 16) + vGap * 2)

            function updateMath() {
                if (!blockData || !blockData.content) {
                    imagePath = "";
                    rendering = false;
                    lastCacheKey = "";
                    return;
                }

                if (loading) {
                    imagePath = "";
                    rendering = false;
                    lastCacheKey = "";
                    return;
                }

                var colorStr = isUserMsg ? (Colours.palette.m3onPrimaryContainer + "") : (Colours.palette.m3onSurface + "");
                var currentLatex = blockData.content;
                var cacheKey = currentLatex + "|" + colorStr;

                if (cacheKey === lastCacheKey) {
                    if (imagePath !== "") {
                        rendering = false;
                    }
                    return;
                }

                imagePath = "";
                rendering = true;
                lastCacheKey = cacheKey;

                var scriptPath = "/home/zen/.config/quickshell/caelestia/utils/scripts/render_math.py";

                runCommand([scriptPath, currentLatex, colorStr, "9"], function(stdout) {
                    if (!mathBlock) return;
                    var path = stdout.trim();
                    if (path.indexOf("/tmp") === 0) {
                        mathBlock.imagePath = "file://" + path;
                        mathBlock.rendering = false;
                    } else {
                        console.log("Math rendering error: " + stdout);
                        mathBlock.rendering = false;
                    }
                });
            }

            onBlockDataChanged: updateMath()
            onLoadingChanged: updateMath()
            Component.onCompleted: updateMath()

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: mathBlock.vGap
                anchors.bottomMargin: mathBlock.vGap
                color: "transparent"

                Text {
                    id: rawMathText
                    anchors.centerIn: parent
                    text: blockData ? "$$" + blockData.content + "$$" : ""
                    color: isUserMsg ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                    font: Tokens.font.body.medium
                    visible: mathBlock.loading
                    wrapMode: Text.WordWrap
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    id: loadingText
                    anchors.centerIn: parent
                    text: "Rendering expression..."
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    visible: !mathBlock.loading && mathBlock.rendering
                }

                Image {
                    id: mathImage
                    anchors.centerIn: parent
                    source: mathBlock.imagePath
                    visible: !mathBlock.loading && !mathBlock.rendering && mathBlock.imagePath !== ""
                    fillMode: Image.PreserveAspectFit
                    cache: true
                    asynchronous: true
                }
            }
        }
    }

    Component {
        id: processComponent
        Process {
            id: proc
            property var callback: null
            stdout: StdioCollector {
                onStreamFinished: {
                    if (proc.callback) {
                        proc.callback(text);
                        proc.callback = null;
                    }
                    var arr = root.activeProcesses;
                    var idx = arr.indexOf(proc);
                    if (idx !== -1) {
                        arr.splice(idx, 1);
                        root.activeProcesses = arr;
                    }
                    proc.destroy();
                }
            }
        }
    }

    property var modelMenuItems: []
    property var activeMenuItem: null

    property int connectionRetries: 0

    Timer {
        id: retryTimer
        interval: 1000
        repeat: false
        onTriggered: {
            updateModel();
        }
    }

    function savePromptNow() {
        console.log("Saving system prompt to file...");
        Quickshell.execDetached(["python3", "-c", "import sys; open(sys.argv[1], 'w').write(sys.argv[2])", "/home/zen/.config/quickshell/caelestia/modules/launcher/system_prompt.txt", promptTextEdit.text]);
        hasUnsavedPromptChanges = false;
    }

    function ensureOllamaRunning() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.ollamaHost, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 0) {
                    console.log("Ollama server not detected. Starting...");
                    Quickshell.execDetached(["env", "OLLAMA_HOST=127.0.0.1:11435", "ollama", "serve"]);
                    connectionRetries = 0;
                    retryTimer.start();
                } else {
                    console.log("Ollama server detected. Status: " + xhr.status);
                    if (availableModels.length <= 1) {
                        updateModel();
                    }
                }
            }
        };
        xhr.send();
    }

    Component.onCompleted: {
        ensureOllamaRunning();
        initializeDefaultModel();
        connectionRetries = 0;
        updateModel();
        reloadConversations();
    }

    function initializeDefaultModel() {
        if (modelMenuItems.length === 0) {
            var item = menuItemComponent.createObject(root, {
                "text": "qwen2.5:0.5b",
                "icon": "smart_toy"
            });
            modelMenuItems = [item];
            activeMenuItem = item;
        }
    }

    function getDatabase() {
        return Sql.LocalStorage.openDatabaseSync("CaelestiaAIChatDB", "1.0", "Caelestia AI Chat Local Storage", 1000000);
    }

    function updateModel() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.ollamaHost + "/api/tags", true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res.models && res.models.length > 0) {
                            var modelsList = [];
                            var menuItemsList = [];
                            for (var i = 0; i < res.models.length; i++) {
                                var modelName = res.models[i].name;
                                modelsList.push(modelName);

                                var item = menuItemComponent.createObject(root, {
                                    "text": modelName,
                                    "icon": "smart_toy"
                                });
                                menuItemsList.push(item);
                            }
                            availableModels = modelsList;
                            modelMenuItems = menuItemsList;
                            updateActiveMenuItem();
                        }
                    } catch(e) {
                        console.log("Error reading Ollama models:", e.toString());
                    }
                } else {
                    if (connectionRetries < 20) {
                        connectionRetries++;
                        retryTimer.start();
                    }
                }
            }
        };
        xhr.send();
    }

    function updateActiveMenuItem() {
        if (modelMenuItems.length === 0) return;
        var found = null;
        for (var i = 0; i < modelMenuItems.length; i++) {
            if (modelMenuItems[i].text === activeModel) {
                found = modelMenuItems[i];
                break;
            }
        }
        if (found) {
            activeMenuItem = found;
        } else {

            activeMenuItem = null;
        }
    }

    function parseStreamingBlocks(raw) {
        if (!raw || raw === "Thinking...") return { committed: "", tail: "" };

        var committed = "";
        var tail = raw;
        var i = 0;

        while (i < tail.length) {

            var fenceOpen = tail.indexOf("```", i);
            var mathOpen = tail.indexOf("$$", i);

            var firstOpen = -1;
            var isMath = false;
            var markerLength = 3;

            if (fenceOpen !== -1 && mathOpen !== -1) {
                if (fenceOpen < mathOpen) {
                    firstOpen = fenceOpen;
                    isMath = false;
                    markerLength = 3;
                } else {
                    firstOpen = mathOpen;
                    isMath = true;
                    markerLength = 2;
                }
            } else if (fenceOpen !== -1) {
                firstOpen = fenceOpen;
                isMath = false;
                markerLength = 3;
            } else if (mathOpen !== -1) {
                firstOpen = mathOpen;
                isMath = true;
                markerLength = 2;
            }

            if (firstOpen !== -1) {

                var closeIndex = -1;
                if (isMath) {
                    closeIndex = tail.indexOf("$$", firstOpen + 2);
                } else {
                    closeIndex = tail.indexOf("```", firstOpen + 3);
                }

                if (closeIndex !== -1) {

                    var blockEnd = closeIndex + (isMath ? 2 : 3);

                    if (blockEnd < tail.length && tail[blockEnd] === "\n") blockEnd++;
                    committed += tail.substring(0, blockEnd);
                    tail = tail.substring(blockEnd);
                    i = 0;
                    continue;
                } else {

                    var beforeBlock = tail.substring(0, firstOpen);

                    var lastPara = beforeBlock.lastIndexOf("\n\n");
                    if (lastPara !== -1) {
                        committed += beforeBlock.substring(0, lastPara + 2);
                        tail = beforeBlock.substring(lastPara + 2) + tail.substring(firstOpen);
                    }
                    break;
                }
            }

            var lastDouble = tail.lastIndexOf("\n\n");
            if (lastDouble !== -1) {
                committed += tail.substring(0, lastDouble + 2);
                tail = tail.substring(lastDouble + 2);
            }
            break;
        }

        var headingRe = /^(#{1,6} .+)\n/m;
        var hm;
        while ((hm = headingRe.exec(tail)) !== null) {
            if (hm.index === 0) {
                committed += hm[0];
                tail = tail.substring(hm[0].length);
            } else {
                break;
            }
        }

        return { committed: committed.trim(), tail: tail };
    }

    function parseMessageBlocks(raw) {
        var blocks = [];
        var pattern = /(```([\w]*)?\n?([\s\S]*?)```)|(\$\$([\s\S]*?)\$\$)/g;
        var last = 0;
        var match;
        while ((match = pattern.exec(raw)) !== null) {
            if (match.index > last) {
                var txt = raw.substring(last, match.index).trim();
                if (txt.length > 0)
                    blocks.push({ type: "text", content: txt, language: "" });
            }
            if (match[1]) {
                blocks.push({ type: "code", content: match[3] || "", language: match[2] || "code" });
            } else if (match[4]) {
                blocks.push({ type: "math", content: match[5] || "", language: "" });
            }
            last = match.index + match[0].length;
        }
        if (last < raw.length) {
            var rest = raw.substring(last).trim();
            if (rest.length > 0)
                blocks.push({ type: "text", content: rest, language: "" });
        }
        return blocks.length > 0 ? blocks : [{ type: "text", content: raw, language: "" }];
    }

    function highlightCode(code, lang) {
        var l = (lang || "").toLowerCase();

        function bright(c, f) { return Qt.lighter(c, f || 2.0) + ""; }
        var C = {
            keyword:  bright(Colours.palette.m3primary,   2.0),
            builtin:  bright(Colours.palette.m3primary,   1.7),
            string:   bright(Colours.palette.m3tertiary,  2.0),
            number:   bright(Colours.palette.m3error,     2.2),
            comment:  Colours.palette.m3onSurfaceVariant + "",
            operator: bright(Colours.palette.m3secondary, 2.0),
            func:     bright(Colours.palette.m3primary,   1.85),
            normal:   Colours.palette.m3onSurface + ""
        };

        var keywords = {
            python:     ["False","None","True","and","as","assert","async","await","break","class","continue","def","del","elif","else","except","finally","for","from","global","if","import","in","is","lambda","nonlocal","not","or","pass","raise","return","try","while","with","yield"],
            javascript: ["async","await","break","case","catch","class","const","continue","debugger","default","delete","do","else","export","extends","finally","for","function","if","import","in","instanceof","let","new","of","return","static","super","switch","this","throw","try","typeof","var","void","while","with","yield","true","false","null","undefined"],
            typescript: ["abstract","any","as","async","await","boolean","break","case","catch","class","const","constructor","continue","declare","default","delete","do","else","enum","export","extends","false","finally","for","from","function","if","implements","import","in","instanceof","interface","let","module","namespace","new","null","number","of","private","protected","public","readonly","return","static","string","super","switch","this","throw","true","try","type","typeof","undefined","var","void","while","yield"],
            rust:       ["as","async","await","break","const","continue","crate","dyn","else","enum","extern","false","fn","for","if","impl","in","let","loop","match","mod","move","mut","pub","ref","return","self","Self","static","struct","super","trait","true","type","union","unsafe","use","where","while"],
            go:         ["break","case","chan","const","continue","default","defer","else","fallthrough","for","func","go","goto","if","import","interface","map","package","range","return","select","struct","switch","type","var","true","false","nil"],
            java:       ["abstract","assert","boolean","break","byte","case","catch","char","class","const","continue","default","do","double","else","enum","extends","final","finally","float","for","goto","if","implements","import","instanceof","int","interface","long","native","new","null","package","private","protected","public","return","short","static","strictfp","super","switch","synchronized","this","throw","throws","transient","true","try","void","volatile","while"],
            kotlin:     ["abstract","actual","annotation","as","break","by","catch","class","companion","const","constructor","continue","crossinline","data","do","dynamic","else","enum","expect","external","false","field","final","finally","for","fun","get","if","import","in","infix","init","inline","inner","interface","internal","is","it","lateinit","noinline","null","object","open","operator","out","override","package","private","protected","public","reified","return","sealed","set","super","suspend","tailrec","this","throw","true","try","typealias","typeof","val","var","vararg","when","where","while"],
            swift:      ["as","break","case","catch","class","continue","default","defer","deinit","do","else","enum","extension","fallthrough","false","fileprivate","final","for","func","guard","if","import","in","init","inout","internal","is","lazy","let","mutating","nil","open","operator","override","private","protocol","public","repeat","required","rethrows","return","self","Self","static","struct","subscript","super","switch","throw","throws","true","try","typealias","var","weak","where","while"],
            bash:       ["if","then","else","elif","fi","for","while","do","done","case","esac","in","function","return","export","local","readonly","unset","shift","break","continue","exit","echo","source","alias","declare","typeset","true","false"],
            cpp:        ["alignas","alignof","and","and_eq","asm","auto","bitand","bitor","bool","break","case","catch","char","char8_t","char16_t","char32_t","class","compl","concept","const","consteval","constexpr","constinit","const_cast","continue","co_await","co_return","co_yield","decltype","default","delete","do","double","dynamic_cast","else","enum","explicit","export","extern","false","float","for","friend","goto","if","inline","int","long","mutable","namespace","new","noexcept","not","not_eq","nullptr","operator","or","or_eq","private","protected","public","reinterpret_cast","requires","return","short","signed","sizeof","static","static_assert","static_cast","struct","switch","template","this","thread_local","throw","true","try","typedef","typeid","typename","union","unsigned","using","virtual","void","volatile","wchar_t","while","xor","xor_eq"],
            sql:        ["SELECT","FROM","WHERE","INSERT","UPDATE","DELETE","CREATE","DROP","ALTER","TABLE","INDEX","VIEW","TRIGGER","PROCEDURE","FUNCTION","DATABASE","SCHEMA","JOIN","INNER","LEFT","RIGHT","FULL","OUTER","ON","AS","GROUP","BY","ORDER","HAVING","LIMIT","OFFSET","UNION","ALL","DISTINCT","AND","OR","NOT","IN","IS","NULL","LIKE","BETWEEN","CASE","WHEN","THEN","ELSE","END","EXISTS","PRIMARY","KEY","FOREIGN","REFERENCES","UNIQUE","CHECK","DEFAULT","AUTO_INCREMENT","SET","VALUES","INTO","BEGIN","COMMIT","ROLLBACK","TRANSACTION","INT","VARCHAR","TEXT","BOOLEAN","FLOAT","DOUBLE","DATETIME","DATE","TIMESTAMP"]
        };

        var kw = keywords[l] || keywords[l === "js" ? "javascript" : l === "ts" ? "typescript" : l === "sh" || l === "shell" ? "bash" : l === "c" || l === "c++" ? "cpp" : l === "kt" ? "kotlin" : ""] || [];
        var kwSet = {};
        for (var ki = 0; ki < kw.length; ki++) kwSet[kw[ki]] = true;

        function esc(s) {
            return s.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
        }
        function span(color, text) {
            return '<font color="' + color + '">' + esc(text) + '</font>';
        }

        var lines = code.split("\n");
        var out = [];

        var lineComment = "//";
        var blockCommentStart = "/*"; var blockCommentEnd = "*/";
        if (l === "python" || l === "py" || l === "bash" || l === "sh" || l === "shell" || l === "ruby" || l === "rb") {
            lineComment = "#"; blockCommentStart = ""; blockCommentEnd = "";
        } else if (l === "sql") {
            lineComment = "--";
        } else if (l === "html" || l === "xml") {
            lineComment = ""; blockCommentStart = "<!--"; blockCommentEnd = "-->";
        }

        var inBlockComment = false;

        for (var li = 0; li < lines.length; li++) {
            var line = lines[li];
            var result = "";
            var i = 0;

            while (i < line.length) {

                if (inBlockComment) {
                    var endIdx = blockCommentEnd ? line.indexOf(blockCommentEnd, i) : -1;
                    if (endIdx !== -1) {
                        result += span(C.comment, line.substring(i, endIdx + blockCommentEnd.length));
                        i = endIdx + blockCommentEnd.length;
                        inBlockComment = false;
                    } else {
                        result += span(C.comment, line.substring(i));
                        i = line.length;
                    }
                    continue;
                }

                if (blockCommentStart && line.startsWith(blockCommentStart, i)) {
                    var bcEnd = blockCommentEnd ? line.indexOf(blockCommentEnd, i + blockCommentStart.length) : -1;
                    if (bcEnd !== -1) {
                        result += span(C.comment, line.substring(i, bcEnd + blockCommentEnd.length));
                        i = bcEnd + blockCommentEnd.length;
                    } else {
                        result += span(C.comment, line.substring(i));
                        i = line.length;
                        inBlockComment = true;
                    }
                    continue;
                }

                if (lineComment && line.startsWith(lineComment, i)) {
                    result += span(C.comment, line.substring(i));
                    i = line.length;
                    continue;
                }

                var ch = line[i];
                if (ch === '"' || ch === "'") {
                    var quote = ch;
                    var j = i + 1;
                    while (j < line.length) {
                        if (line[j] === '\\') { j += 2; continue; }
                        if (line[j] === quote) { j++; break; }
                        j++;
                    }
                    result += span(C.string, line.substring(i, j));
                    i = j;
                    continue;
                }

                if (ch === '`' && (l === "javascript" || l === "js" || l === "typescript" || l === "ts")) {
                    var j2 = i + 1;
                    while (j2 < line.length) {
                        if (line[j2] === '\\') { j2 += 2; continue; }
                        if (line[j2] === '`') { j2++; break; }
                        j2++;
                    }
                    result += span(C.string, line.substring(i, j2));
                    i = j2;
                    continue;
                }

                if (/[0-9]/.test(ch) || (ch === '.' && /[0-9]/.test(line[i+1] || ''))) {
                    var j3 = i;
                    while (j3 < line.length && /[0-9a-fA-FxXoObB_\.]/.test(line[j3])) j3++;
                    result += span(C.number, line.substring(i, j3));
                    i = j3;
                    continue;
                }

                if (/[a-zA-Z_$]/.test(ch)) {
                    var j4 = i;
                    while (j4 < line.length && /[\w$]/.test(line[j4])) j4++;
                    var word = line.substring(i, j4);

                    var rest2 = line.substring(j4).replace(/^\s+/, "");
                    if (kwSet[word]) {
                        result += span(C.keyword, word);
                    } else if (rest2[0] === '(') {
                        result += span(C.func, word);
                    } else {
                        result += span(C.normal, word);
                    }
                    i = j4;
                    continue;
                }

                if (/[+\-*/%=<>!&|^~?:;,\.\[\]{}()]/.test(ch)) {
                    result += span(C.operator, ch);
                    i++;
                    continue;
                }

                result += esc(ch);
                i++;
            }

            out.push(result);
        }

        return out.join("<br/>");
    }

    function createNewChat() {
        saveHistory();
        loadFromDB();

        var newId = "conv-" + Date.now() + "-" + Math.floor(Math.random() * 1000);
        var newConv = {
            id: newId,
            title: "New Chat",
            messages: []
        };

        var list = conversationsList.slice();
        list.unshift(newConv);
        conversationsList = list;
        activeConversationId = newId;

        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS Settings(key TEXT UNIQUE, value TEXT)');
                tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['conversationsJson', JSON.stringify(conversationsList)]);
                tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['activeConversationId', activeConversationId]);
            });
        } catch(e) {
            console.log("Error saving to database:", e.toString());
        }

        reloadConversations();
    }

    function selectConversation(convId) {
        saveHistory();
        activeConversationId = convId;

        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS Settings(key TEXT UNIQUE, value TEXT)');
                tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['activeConversationId', activeConversationId]);
            });
        } catch(e) {
            console.log("Error saving active conversation:", e.toString());
        }

        reloadConversations();
    }

    function deleteConversation(convId) {
        var list = conversationsList.slice();
        var idx = -1;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === convId) {
                idx = i;
                break;
            }
        }
        if (idx !== -1) {
            list.splice(idx, 1);
            conversationsList = list;
            if (activeConversationId === convId) {
                if (conversationsList.length > 0) {
                    activeConversationId = conversationsList[0].id;
                } else {
                    activeConversationId = "";
                }
            }

            try {
                var db = getDatabase();
                db.transaction(function(tx) {
                    tx.executeSql('CREATE TABLE IF NOT EXISTS Settings(key TEXT UNIQUE, value TEXT)');
                    tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['conversationsJson', JSON.stringify(conversationsList)]);
                    tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['activeConversationId', activeConversationId]);
                });
            } catch(e) {
                console.log("Error saving to database:", e.toString());
            }

            reloadConversations();
            Toaster.toast("Chat deleted", "Conversation history updated", "delete");
        }
    }

    function loadFromDB() {
        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS Settings(key TEXT UNIQUE, value TEXT)');

                var rs = tx.executeSql('SELECT value FROM Settings WHERE key=?', ['conversationsJson']);
                if (rs.rows.length > 0) {
                    conversationsList = JSON.parse(rs.rows.item(0).value) || [];
                } else {
                    conversationsList = [];
                }

                var rs2 = tx.executeSql('SELECT value FROM Settings WHERE key=?', ['activeConversationId']);
                if (rs2.rows.length > 0) {
                    activeConversationId = rs2.rows.item(0).value || "";
                } else {
                    activeConversationId = "";
                }

                var rsModel = tx.executeSql('SELECT value FROM Settings WHERE key=?', ['activeModel']);
                if (rsModel.rows.length > 0) {
                    activeModel = rsModel.rows.item(0).value || "qwen2.5:0.5b";
                }
                var rsWeb = tx.executeSql('SELECT value FROM Settings WHERE key=?', ['agentWebSearch']);
                agentWebSearch = rsWeb.rows.length > 0 ? (rsWeb.rows.item(0).value === "true") : false;

                var rsDT = tx.executeSql('SELECT value FROM Settings WHERE key=?', ['agentDateTime']);
                agentDateTime = rsDT.rows.length > 0 ? (rsDT.rows.item(0).value === "true") : true;

                var rsLoc = tx.executeSql('SELECT value FROM Settings WHERE key=?', ['agentLocation']);
                agentLocation = rsLoc.rows.length > 0 ? (rsLoc.rows.item(0).value === "true") : false;

                var rsGrid = tx.executeSql('SELECT value FROM Settings WHERE key=?', ['historyGridView']);
                historyGridView = rsGrid.rows.length > 0 ? (rsGrid.rows.item(0).value === "true") : true;

                var rsCtx = tx.executeSql('SELECT value FROM Settings WHERE key=?', ['contextWindow']);
                if (rsCtx.rows.length > 0) {
                    contextWindow = parseInt(rsCtx.rows.item(0).value) || 8192;
                } else {
                    contextWindow = 8192;
                }
            });
        } catch(e) {
            console.log("Error loading from database:", e.toString());
            conversationsList = [];
            activeConversationId = "";
            agentDefaultWidth = Math.min(850, screenWidth - 32);
            agentDefaultHeight = Math.min(600, maxHeight);
            activeModel = "qwen2.5:0.5b";
            contextWindow = 8192;
            historyGridView = true;

            expanded = false;
        }
    }

    function reloadConversations() {
        loadFromDB();

        if (conversationsList.length === 0) {
            var newId = "conv-" + Date.now() + "-" + Math.floor(Math.random() * 1000);
            conversationsList = [{
                id: newId,
                title: "New Chat",
                messages: []
            }];
            activeConversationId = newId;
            chatModel.clear();
            try {
                var db = getDatabase();
                db.transaction(function(tx) {
                    tx.executeSql('CREATE TABLE IF NOT EXISTS Settings(key TEXT UNIQUE, value TEXT)');
                    tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['conversationsJson', JSON.stringify(conversationsList)]);
                    tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['activeConversationId', activeConversationId]);
                });
            } catch(e) {
                console.log("Error saving to database:", e.toString());
            }
        }

        if (!activeConversationId || activeConversationId === "") {
            activeConversationId = conversationsList[0].id;
        }

        historyModel.clear();
        for (var i = 0; i < conversationsList.length; i++) {
            var conv = conversationsList[i];
            var lastResp = "";
            if (conv.messages && conv.messages.length > 0) {
                for (var m = 0; m < conv.messages.length; m++) {
                    if (conv.messages[m].sender === "ai") {
                        lastResp = conv.messages[m].text || "";
                        break;
                    }
                }
                if (lastResp === "" && conv.messages.length > 0) {
                    lastResp = conv.messages[0].text || "";
                }
            }
            lastResp = lastResp.replace(/\r?\n/g, " ").trim();
            if (lastResp === "") {
                lastResp = "New conversation";
            }
            historyModel.append({
                convId: conv.id,
                title: conv.title,
                subtitle: lastResp
            });
        }

        var activeConv = null;
        for (var j = 0; j < conversationsList.length; j++) {
            if (conversationsList[j].id === activeConversationId) {
                activeConv = conversationsList[j];
                break;
            }
        }

        chatModel.clear();
        if (activeConv && activeConv.messages) {
            for (var k = 0; k < activeConv.messages.length; k++) {
                chatModel.append(activeConv.messages[k]);
            }
        }

        Qt.callLater(function() {
            var lastUserIndex = -1;
            for (var i = chatModel.count - 1; i >= 0; i--) {
                var msg = chatModel.get(i);
                if (msg && msg.sender === "user") {
                    lastUserIndex = i;
                    break;
                }
            }
            if (lastUserIndex !== -1) {
                listView.positionViewAtIndex(lastUserIndex, ListView.Beginning);
            } else {
                listView.positionViewAtEnd();
            }
        });
    }

    function reloadHistoryList() {
        loadFromDB();

        historyModel.clear();
        for (var i = 0; i < conversationsList.length; i++) {
            var conv = conversationsList[i];
            var lastResp = "";
            if (conv.messages && conv.messages.length > 0) {
                for (var m = 0; m < conv.messages.length; m++) {
                    if (conv.messages[m].sender === "ai") {
                        lastResp = conv.messages[m].text || "";
                        break;
                    }
                }
                if (lastResp === "" && conv.messages.length > 0) {
                    lastResp = conv.messages[0].text || "";
                }
            }
            lastResp = lastResp.replace(/\r?\n/g, " ").trim();
            if (lastResp === "") {
                lastResp = "New conversation";
            }
            historyModel.append({
                convId: conv.id,
                title: conv.title,
                subtitle: lastResp
            });
        }
    }

    function calculateFooterHeight() {
        if (!listView || !listView.contentItem) return 0;
        var lastUserIndex = -1;
        for (var i = chatModel.count - 1; i >= 0; i--) {
            var item = chatModel.get(i);
            if (item && item.sender === "user") {
                lastUserIndex = i;
                break;
            }
        }
        if (lastUserIndex === -1) return 0;

        var heightBelowUser = 0;
        for (var c = 0; c < listView.contentItem.children.length; c++) {
            var child = listView.contentItem.children[c];
            if (child && child.hasOwnProperty("index")) {
                if (child.index >= lastUserIndex) {
                    heightBelowUser += child.height + listView.spacing;
                }
            }
        }
        if (heightBelowUser > 0) {
            heightBelowUser -= listView.spacing;
        }
        return Math.max(0, listView.height - heightBelowUser);
    }

    function saveHistory() {
        var list = conversationsList.slice();
        var found = false;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === activeConversationId) {
                var messages = [];
                for (var j = 0; j < chatModel.count; j++) {
                    var item = chatModel.get(j);
                    if (item.loading) continue;
                    messages.push({
                        sender: item.sender,
                        text: item.text,
                        loading: false,
                        thinking: item.thinking || "",
                        modelUsed: item.modelUsed || ""
                    });
                }

                var titleText = list[i].title;
                if (titleText === "New Chat" && messages.length > 0) {
                    for (var k = 0; k < messages.length; k++) {
                        if (messages[k].sender === "user") {
                            var promptText = messages[k].text || "";
                            var firstLine = promptText.split("\n")[0].trim();
                            if (firstLine.length > 100) {
                                firstLine = firstLine.substring(0, 97).trim() + "...";
                            }
                            titleText = firstLine || "New Chat";
                            break;
                        }
                    }
                }

                list[i] = {
                    id: list[i].id,
                    title: titleText,
                    messages: messages
                };
                found = true;
                break;
            }
        }

        if (found) {
            conversationsList = list;
        }

        try {
            var db = getDatabase();
            db.transaction(function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS Settings(key TEXT UNIQUE, value TEXT)');
                tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['conversationsJson', JSON.stringify(conversationsList)]);
                tx.executeSql('INSERT OR REPLACE INTO Settings(key, value) VALUES(?, ?)', ['activeConversationId', activeConversationId]);
            });
        } catch(e) {
            console.log("Error saving to database:", e.toString());
        }
    }

    function parseToolCalls(text) {
        if (!text) return [];
        var regex = /CALL:(\w+)\(([^)]*)\)/g;
        var matches = [];
        var match;

        while ((match = regex.exec(text)) !== null) {
            var tool = match[1];
            var argsStr = match[2].trim();

            var args = [];
            var current = "";
            var inQuotes = false;
            var quoteChar = "";

            for (var i = 0; i < argsStr.length; i++) {
                var c = argsStr[i];
                if ((c === '"' || c === "'") && (i === 0 || argsStr[i-1] !== '\\')) {
                    if (!inQuotes) {
                        inQuotes = true;
                        quoteChar = c;
                    } else if (c === quoteChar) {
                        inQuotes = false;
                    } else {
                        current += c;
                    }
                } else if (c === ',' && !inQuotes) {
                    args.push(current.trim());
                    current = "";
                } else {
                    if (c === '\\' && i + 1 < argsStr.length && (argsStr[i+1] === '"' || argsStr[i+1] === "'" || argsStr[i+1] === '\\')) {
                        current += argsStr[i+1];
                        i++;
                    } else {
                        current += c;
                    }
                }
            }
            args.push(current.trim());

            args = args.map(function(a) {
                if ((a.startsWith('"') && a.endsWith('"')) || (a.startsWith("'") && a.endsWith("'"))) {
                    return a.substring(1, a.length - 1);
                }
                return a;
            });

            if (args.length === 1 && args[0] === "") {
                args = [];
            }

            matches.push({ tool: tool, args: args });
        }

        return matches;
    }

    function runCommand(cmdArgs, callback) {
        var proc = processComponent.createObject(root, {
            command: cmdArgs,
            callback: callback,
            running: true
        });
        var arr = root.activeProcesses;
        arr.push(proc);
        root.activeProcesses = arr;
    }

    function executeTool(toolCall, callback) {
        if (toolCall.tool === "web_search") {
            if (!root.agentWebSearch) {
                callback("Error: Web search is disabled by the user.");
                return;
            }
            var query = toolCall.args[0] || "";
            if (!query) {
                callback("Error: search query is empty");
                return;
            }
            var scriptPath = "/home/zen/.config/quickshell/caelestia/utils/scripts/web_search.py";
            runCommand([scriptPath, query], callback);
        }
        else if (toolCall.tool === "fetch_webpage") {
            if (!root.agentWebSearch) {
                callback("Error: Web fetching is disabled by the user.");
                return;
            }
            var url = toolCall.args[0] || "";
            if (!url) {
                callback("Error: URL is empty");
                return;
            }
            var scriptPath = "/home/zen/.config/quickshell/caelestia/utils/scripts/fetch_url.py";
            runCommand([scriptPath, url], callback);
        }
        else if (toolCall.tool === "run_command") {
            var cmd = toolCall.args[0] || "";
            if (!cmd) {
                callback("Error: Command is empty");
                return;
            }
            runCommand(["sh", "-c", cmd], callback);
        }
        else if (toolCall.tool === "read_file") {
            var path = toolCall.args[0] || "";
            if (!path) {
                callback("Error: File path is empty");
                return;
            }
            runCommand(["cat", path], callback);
        }
        else if (toolCall.tool === "write_file") {
            var path = toolCall.args[0] || "";
            var content = toolCall.args[1] || "";
            if (!path) {
                callback("Error: File path is empty");
                return;
            }
            runCommand(["python3", "-c", "import sys; open(sys.argv[1], 'w').write(sys.argv[2])", path, content], function(stdout) {
                callback("File written successfully to " + path);
            });
        }
        else {
            callback("Error: Unknown tool: " + toolCall.tool);
        }
    }

    function queryOllama(aiIndex, iteration, messages, thinkingText, resetCount) {
        if (resetCount === undefined) resetCount = 0;
        if (iteration > 8) {
            chatModel.setProperty(aiIndex, "text", "Error: Agent reached maximum tool execution limit (8 iterations).");
            chatModel.setProperty(aiIndex, "thinking", thinkingText);
            chatModel.setProperty(aiIndex, "loading", false);
            smartScroll();
            saveHistory();
            reloadHistoryList();
            return;
        }

        function parseOllamaStream(responseText) {
            var lines = responseText.split("\n");
            var fullText = "";
            var currentReasoning = "";
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line === "") continue;
                try {
                    var data = JSON.parse(line);
                    if (data.message) {
                        if (data.message.reasoning_content) {
                            currentReasoning += data.message.reasoning_content;
                        }
                        if (data.message.content) {
                            fullText += data.message.content;
                        }
                    }
                } catch(e) {}
            }
            return { text: fullText, reasoning: currentReasoning };
        }

        function processStreamText(fullText, accumulatedReasoning) {
            var text = fullText;
            var thinking = accumulatedReasoning;

            var thinkStart = text.indexOf("<think>");
            if (thinkStart !== -1) {
                var thinkEnd = text.indexOf("</think>", thinkStart);
                if (thinkEnd !== -1) {
                    thinking += (thinking !== "" ? "\n" : "") + text.substring(thinkStart + 7, thinkEnd).trim();
                    text = text.substring(0, thinkStart) + text.substring(thinkEnd + 8);
                } else {
                    thinking += (thinking !== "" ? "\n" : "") + text.substring(thinkStart + 7).trim();
                    text = text.substring(0, thinkStart);
                }
            }
            return { text: text, thinking: thinking };
        }

        var tempThinking = thinkingText;
        if (tempThinking !== "") {
            tempThinking += "\n";
        }
        tempThinking += "- **Thinking (Step " + iteration + ")**: Querying LLM...";
        chatModel.setProperty(aiIndex, "thinking", tempThinking);

        var xhr = new XMLHttpRequest();
        root.activeXhr = xhr;
        xhr.open("POST", root.ollamaHost + "/api/chat", true);
        xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = function() {
            
            if (root.generationStopped) return;
            if (xhr.readyState === 3 || xhr.readyState === 4) {
                if (xhr.status === 200) {
                    try {
                        var parsed = parseOllamaStream(xhr.responseText);
                        var processed = processStreamText(parsed.text, parsed.reasoning);

                        var currentThinkingOutput = thinkingText;
                        if (processed.thinking !== "") {
                            if (currentThinkingOutput !== "") currentThinkingOutput += "\n";
                            currentThinkingOutput += processed.thinking;
                        } else {
                            if (currentThinkingOutput !== "") currentThinkingOutput += "\n";
                            currentThinkingOutput += "- **Thinking (Step " + iteration + ")**: Querying LLM...";
                        }

                        chatModel.setProperty(aiIndex, "thinking", currentThinkingOutput);

                        if (xhr.readyState === 3) {
                            if (processed.text !== "") {
                                chatModel.setProperty(aiIndex, "text", processed.text);
                            } else {
                                chatModel.setProperty(aiIndex, "text", "Thinking...");
                            }
                            smartScroll();
                        }
                    } catch(e) {
                        console.log("Stream parsing error:", e.toString());
                    }
                }
            }

            if (xhr.readyState === XMLHttpRequest.DONE) {
                xhr.onreadystatechange = null;
                if (root.activeXhr === xhr) {
                    root.activeXhr = null;
                }
                
                if (root.generationStopped) return;
                if (xhr.status === 200) {
                    try {
                        var parsed = parseOllamaStream(xhr.responseText);
                        var processed = processStreamText(parsed.text, parsed.reasoning);
                        var finalReply = processed.text;

                        var finalThinking = thinkingText;
                        if (processed.thinking !== "") {
                            if (finalThinking !== "") finalThinking += "\n";
                            finalThinking += processed.thinking;
                        }

                        if (!finalReply || finalReply.trim() === "") {
                            if (iteration < 7) {

                                var nudge = iteration < 3
                                    ? "Please answer the user's question directly."
                                    : "Output your answer now. Do not include any preamble, apology, or mention of previous responses.";
                                messages.push({ role: "user", content: nudge });
                                queryOllama(aiIndex, iteration + 1, messages, finalThinking, resetCount);
                                return;
                            } else if (resetCount < 3) {

                                var lastUserMsg = "";
                                for (var ri = messages.length - 1; ri >= 0; ri--) {
                                    if (messages[ri].role === "user") { lastUserMsg = messages[ri].content; break; }
                                }
                                var freshMsgs = [messages[0]];
                                if (lastUserMsg) {
                                    var cleanUserMsg = lastUserMsg;
                                    if (cleanUserMsg.indexOf("=== SYSTEM INSTRUCTIONS ===") === -1 && messages[0]) {
                                        var systemPrompt = messages[0].content;
                                        cleanUserMsg = "=== SYSTEM INSTRUCTIONS ===\n" + systemPrompt + "\n===========================\n\n" + cleanUserMsg;
                                    }
                                    freshMsgs.push({ role: "user", content: cleanUserMsg });
                                }
                                queryOllama(aiIndex, 1, freshMsgs, finalThinking, resetCount + 1);
                                return;
                            } else {

                                chatModel.remove(aiIndex);
                                saveHistory();
                                reloadHistoryList();
                                root.isGenerating = false;
                                return;
                            }
                        }

                        var toolCalls = parseToolCalls(finalReply);
                        if (toolCalls.length > 0) {
                            var stepText = "";
                            for (var ti = 0; ti < toolCalls.length; ti++) {
                                var tc = toolCalls[ti];
                                if (tc.tool === "web_search") {
                                    stepText += "- **Web Search**: \"" + tc.args[0] + "\"\n";
                                } else if (tc.tool === "fetch_webpage") {
                                    stepText += "- **Fetch Webpage**: \"" + tc.args[0] + "\"\n";
                                } else if (tc.tool === "run_command") {
                                    stepText += "- **Run Command**: `" + tc.args[0] + "`\n";
                                } else if (tc.tool === "read_file") {
                                    stepText += "- **Read File**: `" + tc.args[0] + "`\n";
                                } else if (tc.tool === "write_file") {
                                    stepText += "- **Write File**: `" + tc.args[0] + "`\n";
                                } else {
                                    stepText += "- **Tool Call**: " + tc.tool + "(" + tc.args.join(", ") + ")\n";
                                }
                            }

                            if (toolCalls.length === 1) {
                                var tc = toolCalls[0];
                                if (tc.tool === "web_search") {
                                    chatModel.setProperty(aiIndex, "text", "🔍 Searching the web for: \"" + tc.args[0] + "\"...");
                                } else if (tc.tool === "fetch_webpage") {
                                    chatModel.setProperty(aiIndex, "text", "🌐 Fetching webpage: \"" + tc.args[0] + "\"...");
                                } else if (tc.tool === "run_command") {
                                    chatModel.setProperty(aiIndex, "text", "💻 Running command: `" + tc.args[0] + "`...");
                                } else if (tc.tool === "read_file") {
                                    chatModel.setProperty(aiIndex, "text", "📖 Reading file: `" + tc.args[0] + "`...");
                                } else if (tc.tool === "write_file") {
                                    chatModel.setProperty(aiIndex, "text", "✍️ Writing file: `" + tc.args[0] + "`...");
                                } else {
                                    chatModel.setProperty(aiIndex, "text", "⚙️ Executing tool: " + tc.tool + "...");
                                }
                            } else {
                                chatModel.setProperty(aiIndex, "text", "⚙️ Running " + toolCalls.length + " operations in parallel...");
                            }

                            chatModel.setProperty(aiIndex, "thinking", finalThinking + stepText + "  > *Executing tools in parallel...*");
                            chatModel.setProperty(aiIndex, "loading", true);
                            smartScroll();

                            messages.push({
                                role: "assistant",
                                content: finalReply
                            });

                            var completedCount = 0;
                            var results = [];

                            function runParallelTool(index) {
                                executeTool(toolCalls[index], function(toolResult) {
                                    
                                    if (root.generationStopped) return;
                                    results[index] = {
                                        tool: toolCalls[index].tool,
                                        query: toolCalls[index].args[0],
                                        result: toolResult
                                    };
                                    completedCount++;
                                    if (completedCount === toolCalls.length) {
                                        var combinedResultContent = "";
                                        var cleanSummary = "";
                                        var hasWebSearch = false;
                                        var hasFetch = false;

                                        for (var ri = 0; ri < results.length; ri++) {
                                            var resObj = results[ri];
                                            if (results.length > 1) {
                                                combinedResultContent += "### Result " + (ri + 1) + " [" + resObj.tool + " for \"" + resObj.query + "\"]:\n" + resObj.result + "\n\n";
                                            } else {
                                                combinedResultContent += "Tool result:\n" + resObj.result;
                                            }

                                            if (resObj.tool === "web_search") hasWebSearch = true;
                                            if (resObj.tool === "fetch_webpage") hasFetch = true;

                                            var snippet = resObj.result.trim();
                                            if (snippet.length > 200) {
                                                snippet = snippet.substring(0, 200) + "...";
                                            }
                                            cleanSummary += (cleanSummary !== "" ? " | " : "") + resObj.tool + ": " + snippet;
                                        }

                                        var combinedUserInstruction = "";
                                        if (hasWebSearch && !hasFetch) {
                                            combinedUserInstruction = "\n\nAnalyze the search results above carefully. If you have enough detailed information to answer the user's question, output your final response now. If you need more specific details (such as game scores, full schedules, or precise facts) that are not fully visible in the snippets above, you MUST call `CALL:fetch_webpage(\"URL\")` now on the most promising URL. Do not speculate.";
                                        } else {
                                            combinedUserInstruction = "\n\nSynthesize the fetched content above to answer the user's query. Output your final response directly, precisely, and factually. Do not include any apologies, preamble, or metadata.";
                                        }

                                        messages.push({
                                            role: "user",
                                            content: combinedResultContent + combinedUserInstruction
                                        });

                                        var updatedThinking = finalThinking + stepText + "  > Completed " + toolCalls.length + " operations: " + cleanSummary.replace(/\n/g, " ") + "\n\n";
                                        queryOllama(aiIndex, iteration + 1, messages, updatedThinking);
                                    }
                                });
                            }

                            for (var ti = 0; ti < toolCalls.length; ti++) {
                                runParallelTool(ti);
                            }
                        } else {
                            chatModel.setProperty(aiIndex, "text", finalReply);
                            chatModel.setProperty(aiIndex, "thinking", finalThinking);
                            chatModel.setProperty(aiIndex, "loading", false);
                            smartScroll();
                            saveHistory();
                            reloadHistoryList();
                            root.isGenerating = false;
                        }
                    } catch(e) {
                        chatModel.setProperty(aiIndex, "text", "Error parsing response: " + e.toString());
                        chatModel.setProperty(aiIndex, "thinking", thinkingText);
                        chatModel.setProperty(aiIndex, "loading", false);
                        smartScroll();
                        saveHistory();
                        reloadHistoryList();
                        root.isGenerating = false;
                    }
                } else {
                    chatModel.setProperty(aiIndex, "text", "Error: Could not connect to Ollama. Make sure the server is running and " + activeModel + " is loaded.");
                    chatModel.setProperty(aiIndex, "thinking", thinkingText);
                    chatModel.setProperty(aiIndex, "loading", false);
                    smartScroll();
                    saveHistory();
                    reloadHistoryList();
                    root.isGenerating = false;
                }
            }
        };

        var requestData = {
            model: activeModel,
            messages: messages,
            stream: true,
            options: {
                num_ctx: root.contextWindow
            }
        };

        xhr.send(JSON.stringify(requestData));
    }

    function loadSystemPrompt() {
        return root.systemPromptText;
    }

    function stopGeneration() {
        
        root.generationStopped = true;

        if (root.activeXhr) {
            console.log("Aborting active Ollama generation request...");
            var xhrToAbort = root.activeXhr;
            root.activeXhr = null;
            xhrToAbort.onreadystatechange = null;
            xhrToAbort.abort();
        }

        var procs = root.activeProcesses;
        if (procs && procs.length > 0) {
            console.log("Aborting " + procs.length + " active subprocesses...");
            for (var p = 0; p < procs.length; p++) {
                var proc = procs[p];
                if (proc) {
                    proc.callback = null;
                    proc.destroy();
                }
            }
            root.activeProcesses = [];
        }

        if (root.activeModel) {
            console.log("Force-killing llama-server to free GPU immediately");
            
            
            
            Quickshell.execDetached(["bash", "-c", "pkill -SIGKILL -f 'llama-server' 2>/dev/null; pkill -SIGKILL -f 'ollama_llama_server' 2>/dev/null; true"]);
            
            var unloadXhr = new XMLHttpRequest();
            unloadXhr.open("POST", root.ollamaHost + "/api/generate", true);
            unloadXhr.setRequestHeader("Content-Type", "application/json");
            unloadXhr.send(JSON.stringify({ model: root.activeModel, keep_alive: 0 }));
        }

        root.isGenerating = false;

        for (var i = chatModel.count - 1; i >= 0; i--) {
            var msg = chatModel.get(i);
            if (msg && msg.sender === "ai" && msg.loading) {
                chatModel.setProperty(i, "loading", false);
                var currentText = msg.text || "";
                if (currentText === "Thinking..." || currentText.startsWith("🔍") || currentText.startsWith("🌐") || currentText.startsWith("💻") || currentText.startsWith("📖") || currentText.startsWith("✍️") || currentText.startsWith("⚙️")) {
                    chatModel.setProperty(i, "text", "Generation stopped.");
                }
                
                else if (currentText.trim() !== "") {
                    chatModel.setProperty(i, "text", currentText + "\n\n*— stopped*");
                }
            }
        }
        saveHistory();
        reloadHistoryList();

        
        Qt.callLater(function() { root.generationStopped = false; });
    }

    function sendMessage(text) {
        if (!text || text.trim() === "") return;

        root.isGenerating = true;
        userScrolledUp = false;
        ensureOllamaRunning();

        chatModel.append({
            sender: "user",
            text: text,
            loading: false,
            thinking: ""
        });

        var userIndex = chatModel.count - 1;

        saveHistory();

        chatModel.append({
            sender: "ai",
            text: "Thinking...",
            loading: true,
            thinking: "",
            modelUsed: root.activeModel
        });

        const aiIndex = chatModel.count - 1;

        Qt.callLater(function() {
            listView.positionViewAtIndex(userIndex, ListView.Beginning);
        });

        var messages = [];
        var systemContent = loadSystemPrompt();
        if (root.agentDateTime) {
            systemContent += "\n\nThe current local date and time is: " + new Date().toString() + ". ";
        }
        if (root.agentLocation) {
            var locCity = Weather.city || "";
            var locCoords = Weather.loc || "";
            if (locCity || locCoords) {
                systemContent += "\n\nThe user's current location is: "
                    + (locCity ? locCity : "")
                    + (locCoords ? " (" + locCoords + ")" : "") + ". ";
            }
        }
        if (root.agentWebSearch) {
            systemContent += "\n\nYou can search the web using: `CALL:web_search(\"query\")` and fetch/read the full content of a webpage using: `CALL:fetch_webpage(\"url\")`. ";
            systemContent += "Important: For any query that requires updated, real-time, or current information (such as news, weather, stocks, sports, recent developments, or specific facts/details), you MUST search the internet using `CALL:web_search` to retrieve the latest data. Do not guess or rely on your training data. ";
            systemContent += "If the user query is about dynamic events, sports matchups, schedules, or results, you MUST search the web first. ";
            systemContent += "Critical: If you search the web but the search result snippets do not contain enough detailed information to answer the user's question fully (for example, if the snippet only lists dates but not match details or scores), you MUST fetch and read the contents of the most promising search result URLs using `CALL:fetch_webpage` before giving your final response. ";
        }

        systemContent += "\n\nTo use a tool, output ONLY the tool call line (e.g., `CALL:web_search(\"search term\")` or `CALL:run_command(\"echo hello\")`) as the last line of your response and DO NOT write anything else after it. Wait for the tool output. ";
        systemContent += "If you ever receive a nudge about an empty/blank response or need to regenerate a reply, do NOT apologize, acknowledge, or mention that the previous response was empty/blank. Just directly output the final answer or summary of the tool output.";

        messages.push({
            role: "system",
            content: systemContent
        });

        var firstUserMsgIndex = -1;
        for (var i = 0; i < chatModel.count - 1; i++) {
            var msg = chatModel.get(i);
            if (msg.sender === "ai" && (msg.text === "Thinking..." || msg.text.startsWith("🔍") || msg.text.startsWith("💻") || msg.text.startsWith("📖") || msg.text.startsWith("✍️") || msg.text.startsWith("⚙️") || msg.text.startsWith("🌐"))) {
                continue;
            }
            var roleStr = msg.sender === "user" ? "user" : "assistant";
            messages.push({
                role: roleStr,
                content: msg.text
            });
            if (roleStr === "user" && firstUserMsgIndex === -1) {
                firstUserMsgIndex = messages.length - 1;
            }
        }

        if (firstUserMsgIndex !== -1) {
            messages[firstUserMsgIndex].content = "=== SYSTEM INSTRUCTIONS ===\n" + systemContent + "\n===========================\n\n" + messages[firstUserMsgIndex].content;
        }

        queryOllama(aiIndex, 1, messages, "", 0);
    }

    function switchOllamaModel(oldModel, newModel) {

        console.log("Switching active model from " + oldModel + " to " + newModel);
    }

    Item {
        id: headerBar
        anchors.top: parent.top
        anchors.topMargin: Tokens.spacing.extraSmall / 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.small
        anchors.rightMargin: Tokens.spacing.small
        height: 50

        StyledRect {
            id: segmentControl
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: {
                var w = modelSplitButton.width > 0 ? modelSplitButton.width : 188;
                return w % 2 === 0 ? w : w + 1;
            }
            height: modelSplitButton.height > 0 ? modelSplitButton.height : 38
            radius: Tokens.rounding.full
            color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
            border.width: 0
            border.color: "transparent"

            StyledRect {
                id: activeIndicator
                x: !root.showHistory ? 3 : (parent.width / 2 + 3)
                y: 3
                width: parent.width / 2 - 6
                height: parent.height - 6
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                Behavior on x {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }

            Row {
                anchors.fill: parent
                spacing: 0

                Item {
                    width: parent.width / 2
                    height: parent.height

                    Row {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            text: "chat"
                            fontStyle: Tokens.font.icon.small
                            color: !root.showHistory ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "Chat"
                            font: Tokens.font.label.medium
                            color: !root.showHistory ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showHistory = false;
                        }
                    }
                }

                Item {
                    width: parent.width / 2
                    height: parent.height

                    Row {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.extraSmall

                        MaterialIcon {
                            text: "history"
                            fontStyle: Tokens.font.icon.small
                            color: root.showHistory ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: "History"
                            font: Tokens.font.label.medium
                            color: root.showHistory ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showHistory = true;
                        }
                    }
                }
            }
        }

        IconButton {
            id: expandBtn
            anchors.left: segmentControl.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            icon: root.expanded ? "close_fullscreen" : "open_in_full"
            width: 38
            height: 38
            isRound: true

            activeColour: Colours.palette.m3primary
            inactiveColour: Colours.layer(Colours.palette.m3surfaceContainer, 1)
            activeOnColour: Colours.palette.m3onPrimary
            inactiveOnColour: Colours.palette.m3onSurfaceVariant

            checked: root.expanded
            isToggle: false

            onClicked: root.expanded = !root.expanded
        }

        Row {
            id: modelsRowWrapper
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.medium
            visible: opacity > 0
            opacity: !root.showHistory ? 1 : 0

            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            StyledText {
                text: "Agent"
                anchors.verticalCenter: parent.verticalCenter
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurfaceVariant
            }

            SplitButton {
                id: modelSplitButton
                anchors.verticalCenter: parent.verticalCenter
                type: SplitButton.Tonal
                fallbackIcon: "smart_toy"
                fallbackText: root.activeModel
                minLeftWidth: 150

                menuItems: root.modelMenuItems
                active: root.activeMenuItem

                menu.onItemSelected: item => {
                    var oldModel = root.activeModel;
                    var newModel = item.text;
                    if (oldModel !== newModel) {
                        root.activeModel = newModel;
                        root.activeMenuItem = item;
                        root.switchOllamaModel(oldModel, newModel);
                    }
                }
            }

        }

        Row {
            id: historyHeaderControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.medium
            visible: opacity > 0
            opacity: root.showHistory && !root.showSettings ? 1 : 0

            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            StyledRect {
                id: viewTogglePill
                width: 76
                height: 38
                radius: Tokens.rounding.full
                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                border.width: 0
                border.color: "transparent"
                anchors.verticalCenter: parent.verticalCenter

                StyledRect {
                    id: viewActiveIndicator
                    x: root.historyGridView ? 3 : 39
                    y: 3
                    width: 34
                    height: 32
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3secondaryContainer

                    Behavior on x {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        width: 38
                        height: 38

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "grid_view"
                            fontStyle: Tokens.font.icon.small
                            color: root.historyGridView ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.historyGridView = true
                        }
                    }

                    Item {
                        width: 38
                        height: 38

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "view_list"
                            fontStyle: Tokens.font.icon.small
                            color: !root.historyGridView ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.historyGridView = false
                        }
                    }
                }
            }
        }

        IconButton {
            id: settingsBtn
            anchors.right: newChatBtn.left
            anchors.rightMargin: Tokens.spacing.medium
            anchors.verticalCenter: parent.verticalCenter
            icon: "settings"
            width: 38
            height: 38
            isRound: true

            activeColour: Colours.palette.m3primary
            inactiveColour: Colours.layer(Colours.palette.m3surfaceContainer, 1)
            activeOnColour: Colours.palette.m3onPrimary
            inactiveOnColour: Colours.palette.m3onSurfaceVariant

            checked: root.showSettings
            isToggle: false

            visible: opacity > 0
            opacity: root.showHistory ? 1 : 0

            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            onClicked: {
                root.showSettings = !root.showSettings;
            }
        }

        IconTextButton {
            id: newChatBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            icon: "add"
            text: "New Chat"
            isRound: true
            type: ButtonBase.Filled
            visible: opacity > 0
            opacity: root.showHistory ? 1 : 0

            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            onClicked: {
                root.createNewChat();
                root.showHistory = false;
            }
        }
    }

    Item {
        id: chatView
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: opacity > 0
        opacity: root.showHistory ? 0 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        StyledListView {
            id: listView
            cacheBuffer: 2000

            anchors.fill: parent
            anchors.leftMargin: Tokens.spacing.medium
            anchors.topMargin: Tokens.spacing.medium
            anchors.bottomMargin: Tokens.spacing.medium
            anchors.rightMargin: 4

            model: chatModel
            spacing: Tokens.spacing.medium
            clip: true
            footer: Item {
                width: listView.width
                height: {
                    var lh = listView.height;
                    var ch = listView.contentHeight;
                    var c = chatModel.count;
                    return root.calculateFooterHeight();
                }
            }

            onContentYChanged: {
                if (!root.isAutoScrolling) {
                    var dist = contentHeight - contentY - height;
                    if (dist > 30) {
                        root.userScrolledUp = true;
                    } else {
                        root.userScrolledUp = false;
                    }
                }
            }

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
            }


            delegate: Item {
                id: delegateItem
                width: listView.width
                height: column.implicitHeight

                required property string sender
                required property string text
                required property bool loading
                required property int index

                readonly property bool isUser: sender === "user"
                readonly property bool isStatusText: text === "Thinking..." || text.startsWith("🔍") || text.startsWith("🌐") || text.startsWith("💻") || text.startsWith("📖") || text.startsWith("✍️") || text.startsWith("⚙️")
                property string messageThinking: model.thinking || ""
                property string messageModelUsed: (index >= 0 && index < chatModel.count && chatModel.get(index)) ? (chatModel.get(index).modelUsed || "") : ""

                Column {
                    id: column
                    width: parent.width
                    spacing: Tokens.spacing.extraSmall

                    Row {
                        width: parent.width
                        layoutDirection: delegateItem.isUser ? Qt.RightToLeft : Qt.LeftToRight

                        StyledRect {
                            id: bubbleWrapper
                            color: delegateItem.isUser ? Colours.palette.m3primaryContainer : Colours.layer(Colours.palette.m3surfaceContainer, 1)
                            radius: Tokens.rounding.large
                            border.width: 0
                            border.color: "transparent"

                            width: {
                                var maxW = 120;
                                for (var i = 0; i < bubbleColumn.children.length; i++) {
                                    var child = bubbleColumn.children[i];
                                    if (child.visible && child.hasOwnProperty("blockWidth")) {
                                        var bw = child.blockWidth;
                                        if (bw > maxW) maxW = bw;
                                    }
                                }
                                if (delegateItem.loading) {
                                    for (var j = 0; j < streamingView.children.length; j++) {
                                        var schild = streamingView.children[j];
                                        if (schild.visible) {
                                            if (schild.hasOwnProperty("blockWidth")) {
                                                var sbw = schild.blockWidth;
                                                if (sbw > maxW) maxW = sbw;
                                            } else if (schild.hasOwnProperty("text")) {
                                                var stw = schild.implicitWidth;
                                                if (stw > maxW) maxW = stw;
                                            }
                                        }
                                    }
                                }
                                var paddedWidth = maxW + Tokens.padding.medium * 2 + (delegateItem.loading ? 24 : 0);
                                return Math.min(listView.width * 0.85, Math.max(120, paddedWidth));
                            }
                            height: bubbleColumn.implicitHeight + (delegateItem.loading ? Tokens.padding.small * 2 : Tokens.padding.medium * 2)

                            Behavior on width {
                                enabled: !root.isResizing && chatView.opacity === 1
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on height {
                                enabled: chatView.opacity === 1
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }

                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            Column {
                                id: bubbleColumn
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.topMargin: delegateItem.loading ? Tokens.padding.small : Tokens.padding.medium
                                anchors.leftMargin: Tokens.padding.medium
                                anchors.rightMargin: Tokens.padding.medium + 20 + (delegateItem.loading ? 24 : 0)
                                anchors.bottomMargin: delegateItem.loading ? Tokens.padding.small : Tokens.padding.medium
                                topPadding: 0

                                Row {
                                    id: thinkingRow
                                    visible: delegateItem.loading && (delegateItem.text.trim() === "" || delegateItem.isStatusText)
                                    spacing: Tokens.spacing.medium
                                    height: 20
                                    readonly property real blockWidth: implicitWidth

                                    LoadingIndicator {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: thinkingRow.visible
                                        animated: thinkingRow.visible
                                        color: Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        text: (delegateItem.text.trim() === "" || delegateItem.text === "Thinking...") ? "Thinking..." : delegateItem.text
                                        font: Tokens.font.body.medium
                                        color: Colours.palette.m3onSurfaceVariant
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    SequentialAnimation {
                                        running: thinkingRow.visible
                                        loops: Animation.Infinite
                                        NumberAnimation { target: thinkingRow; property: "opacity"; from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutSine }
                                        NumberAnimation { target: thinkingRow; property: "opacity"; from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                        onRunningChanged: {
                                            if (!running) {
                                                thinkingRow.opacity = 1.0;
                                            }
                                        }
                                    }
                                }

                                LoadingIndicator {
                                    width: 16
                                    height: 16
                                    visible: delegateItem.loading === true && delegateItem.text.trim() !== "" && !delegateItem.isStatusText
                                    animated: delegateItem.loading === true && delegateItem.text.trim() !== "" && !delegateItem.isStatusText
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                Repeater {
                                    model: delegateItem.loading ? [] : parseMessageBlocks(delegateItem.text)

                                    Item {
                                        id: blockHolder
                                        required property var modelData
                                        readonly property bool isUserMsg: delegateItem.isUser
                                        readonly property real blockWidth: blockLoader.item ? blockLoader.item.implicitWidth : 0
                                        width: bubbleColumn.width
                                        height: blockLoader.item ? blockLoader.item.height : 0

                                        Loader {
                                            id: blockLoader
                                            width: parent.width
                                            sourceComponent: blockHolder.modelData.type === "code" ? codeBlockComponent : (blockHolder.modelData.type === "math" ? mathBlockComponent : textBlockComponent)
                                            onLoaded: {
                                                item.blockData = blockHolder.modelData;
                                                if (item.hasOwnProperty("isUserMsg"))
                                                    item.isUserMsg = blockHolder.isUserMsg;
                                                if (item.hasOwnProperty("loading"))
                                                    item.loading = Qt.binding(function() { return delegateItem.loading; });
                                            }
                                        }
                                    }
                                }

                                Column {
                                    id: streamingView
                                    visible: delegateItem.loading && !delegateItem.isStatusText
                                    width: parent.width
                                    spacing: Tokens.spacing.small

                                    property var streamSplit: delegateItem.loading
                                        ? parseStreamingBlocks(delegateItem.text)
                                        : { committed: "", tail: "" }

                                    Repeater {
                                        model: streamingView.streamSplit.committed !== ""
                                            ? parseMessageBlocks(streamingView.streamSplit.committed)
                                            : []

                                        Item {
                                            id: committedHolder
                                            required property var modelData
                                            readonly property bool isUserMsg: delegateItem.isUser
                                            readonly property real blockWidth: committedLoader.item ? committedLoader.item.implicitWidth : 0
                                            width: streamingView.width
                                            height: committedLoader.item ? committedLoader.item.height : 0

                                            Loader {
                                                id: committedLoader
                                                width: parent.width
                                                sourceComponent: committedHolder.modelData.type === "code" ? codeBlockComponent : (committedHolder.modelData.type === "math" ? mathBlockComponent : textBlockComponent)
                                                onLoaded: {
                                                    item.blockData = committedHolder.modelData;
                                                    if (item.hasOwnProperty("isUserMsg"))
                                                        item.isUserMsg = committedHolder.isUserMsg;
                                                    if (item.hasOwnProperty("loading"))
                                                        item.loading = false;
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        id: streamTail
                                        visible: streamingView.streamSplit.tail !== ""
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        font: Tokens.font.body.medium
                                        color: delegateItem.isUser
                                            ? Colours.palette.m3onPrimaryContainer
                                            : Colours.palette.m3onSurface
                                        text: streamingView.streamSplit.tail + (cursorBlink.cursorVisible ? "▌" : " ")

                                        property bool cursorVisible: true
                                        Timer {
                                            id: cursorBlink
                                            property bool cursorVisible: true
                                            interval: 530
                                            repeat: true
                                            running: delegateItem.loading
                                            onTriggered: cursorVisible = !cursorVisible
                                        }
                                    }
                                }
                            }

                            IconButton {
                                id: copyBtn
                                property bool copied: false
                                icon: copied ? "check" : "content_copy"
                                type: IconButton.Filled
                                width: 28
                                height: 28
                                isRound: true
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: Tokens.spacing.extraSmall
                                visible: opacity > 0
                                opacity: (hoverArea.containsMouse || copyBtn.hovered) && !delegateItem.loading ? 1 : 0
                                
                                activeColour: delegateItem.isUser ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3primary
                                inactiveColour: delegateItem.isUser ? Qt.rgba(Colours.palette.m3onPrimaryContainer.r, Colours.palette.m3onPrimaryContainer.g, Colours.palette.m3onPrimaryContainer.b, 0.15) : Qt.rgba(Colours.palette.m3onSurface.r, Colours.palette.m3onSurface.g, Colours.palette.m3onSurface.b, 0.08)
                                activeOnColour: delegateItem.isUser ? Colours.palette.m3primaryContainer : Colours.palette.m3onPrimary
                                inactiveOnColour: delegateItem.isUser ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface

                                Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                                
                                onClicked: {
                                    Quickshell.clipboardText = delegateItem.text;
                                    Toaster.toast("Copied", "Message copied to clipboard", "content_copy");
                                    copied = true;
                                    revertTimer.start();
                                }

                                Timer {
                                    id: revertTimer
                                    interval: 1500
                                    onTriggered: copyBtn.copied = false
                                }
                            }
                        }
                    }

                    StyledText {
                        id: timeText
                        text: delegateItem.isUser ? "You" : (delegateItem.messageModelUsed !== "" ? ("AI (" + delegateItem.messageModelUsed + ")") : "AI")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        horizontalAlignment: delegateItem.isUser ? Text.AlignRight : Text.AlignLeft
                        width: parent.width
                    }
                }

                Component.onCompleted: {
                    fadeInAnim.start();
                }

                ParallelAnimation {
                    id: fadeInAnim
                    NumberAnimation { target: delegateItem; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutQuad }
                    NumberAnimation { target: column; property: "y"; from: 10; to: 0; duration: 250; easing.type: Easing.OutQuad }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: chatModel.count === 0
                spacing: Tokens.spacing.medium
                width: parent.width - Tokens.padding.large * 2

                MaterialIcon {
                    text: "forum"
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).weight(Font.Medium).build()
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "AI Assistant Chat"
                    font: Tokens.font.title.builders.medium.weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: "Type your query and press Enter."
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Item {
        id: historyView
        anchors.top: headerBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        visible: opacity > 0
        opacity: root.showHistory ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        GridView {
            id: historyGrid
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            opacity: root.historyGridView && !root.showSettings ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            readonly property real baseMargin: Tokens.spacing.medium
            readonly property real availableWidth: parent.width - baseMargin * 2
            readonly property int cols: Math.floor(availableWidth / cellWidth)
            readonly property real extraSpace: availableWidth - (cols * cellWidth)

            anchors.leftMargin: baseMargin + extraSpace / 2
            anchors.rightMargin: baseMargin + extraSpace / 2
            anchors.topMargin: baseMargin
            anchors.bottomMargin: baseMargin

            cellWidth: 270
            cellHeight: 120
            clip: true

            model: historyModel


            delegate: Item {
                width: 270
                height: 120

                required property string convId
                required property string title
                required property string subtitle
                required property int index

                StyledRect {
                    id: card
                    width: 250
                    height: 100
                    anchors.centerIn: parent
                    radius: Tokens.rounding.large
                    color: hoverArea.containsMouse ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                    border.width: 0
                    border.color: "transparent"

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.selectConversation(convId);
                            root.showHistory = false;
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        StyledRect {
                            width: 40
                            height: 40
                            radius: Tokens.rounding.full
                            color: hoverArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
                            anchors.verticalCenter: parent.verticalCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "chat_bubble"
                                color: hoverArea.containsMouse ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                                fontStyle: Tokens.font.icon.small
                            }
                        }

                        Column {
                            width: card.width - 40 - Tokens.spacing.medium - Tokens.padding.medium * 2 - 30
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            StyledText {
                                text: title
                                color: hoverArea.containsMouse ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            StyledText {
                                text: subtitle
                                color: hoverArea.containsMouse ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    IconButton {
                        id: deleteBtn
                        icon: "close"
                        type: IconButton.Text
                        width: 24
                        height: 24
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Tokens.spacing.extraSmall
                        visible: opacity > 0
                        opacity: hoverArea.containsMouse || deleteBtn.hovered ? 1 : 0
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                        onClicked: {
                            root.deleteConversation(convId);
                        }
                    }
                }
            }
        }

        ListView {
            id: historyList
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.spacing.medium

            opacity: !root.historyGridView && !root.showSettings ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }

            spacing: Tokens.spacing.small
            clip: true

            model: historyModel


            delegate: Item {
                id: listDelegateItem
                width: historyList.width
                height: 76

                required property string convId
                required property string title
                required property string subtitle
                required property int index

                StyledRect {
                    id: listCard
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Tokens.rounding.medium
                    color: listHoverArea.containsMouse ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                    border.width: 0
                    border.color: "transparent"

                    MouseArea {
                        id: listHoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.selectConversation(convId);
                            root.showHistory = false;
                        }
                    }

                    StyledRect {
                        id: bubbleIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: Tokens.rounding.full
                        color: listHoverArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "chat_bubble"
                            color: listHoverArea.containsMouse ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.small
                        }
                    }

                    IconButton {
                        id: listDeleteBtn
                        icon: "close"
                        type: IconButton.Text
                        width: 24
                        height: 24
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        visible: opacity > 0
                        opacity: listHoverArea.containsMouse || listDeleteBtn.hovered ? 1 : 0
                        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                        onClicked: {
                            root.deleteConversation(convId);
                        }
                    }

                    Column {
                        anchors.left: bubbleIcon.right
                        anchors.leftMargin: Tokens.spacing.medium
                        anchors.right: parent.right
                        anchors.rightMargin: (listHoverArea.containsMouse || listDeleteBtn.hovered) ? (listDeleteBtn.width + Tokens.spacing.medium + Tokens.padding.medium) : Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Behavior on anchors.rightMargin {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }

                        StyledText {
                            text: title
                            color: listHoverArea.containsMouse ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        StyledText {
                            text: subtitle
                            color: listHoverArea.containsMouse ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }
            }
        }

        Item {
            id: settingsView
            anchors.fill: parent
            opacity: root.showSettings ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Row {
                id: settingsTitleBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.large
                anchors.topMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                IconButton {
                    icon: "arrow_back"
                    type: IconButton.Text
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        root.showSettings = false;
                    }
                }

                StyledText {
                    text: "Agent Settings"
                    font: Tokens.font.title.builders.medium.weight(Font.Bold).build()
                    color: Colours.palette.m3onSurface
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Flickable {
                id: settingsList
                anchors.top: settingsTitleBar.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Tokens.padding.medium
                clip: true

                contentHeight: settingsColumn.implicitHeight
                contentWidth: width


                Column {
                    id: settingsColumn
                    width: Math.min(600, parent.width - Tokens.padding.large * 2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Tokens.spacing.medium
                    bottomPadding: Tokens.padding.large

                    Item {
                        width: parent.width
                        height: 36
                        
                        StyledText {
                            text: "INTERFACE & FEATURES"
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3primary
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Tokens.spacing.extraSmall
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                        }
                    }


                    StyledRect {
                        width: parent.width
                        height: 80
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        Row {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: "fullscreen"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - 40 - 60
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: "Default Full Screen"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                }
                                StyledText {
                                    text: "Open chat in full screen mode by default"
                                    font: Tokens.font.body.small
                                    color: Colours.palette.m3onSurfaceVariant
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }

                            StyledSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.agentFullScreen
                                onToggled: {
                                    root.agentFullScreen = checked;
                                    root.expanded = checked;
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 80
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        Row {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: "grid_view"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - 40 - 80
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: "History View Style"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                }
                                StyledText {
                                    text: "Choose between grid and list layouts for chat history"
                                    font: Tokens.font.body.small
                                    color: Colours.palette.m3onSurfaceVariant
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }

                            StyledRect {
                                id: settingsViewTogglePill
                                width: 76
                                height: 38
                                radius: Tokens.rounding.full
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                                border.width: 0
                                border.color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                StyledRect {
                                    id: settingsViewActiveIndicator
                                    x: root.historyGridView ? 3 : 39
                                    y: 3
                                    width: 34
                                    height: 32
                                    radius: Tokens.rounding.full
                                    color: Colours.palette.m3secondaryContainer

                                    Behavior on x {
                                        Anim {
                                            type: Anim.DefaultEffects
                                        }
                                    }
                                }

                                Row {
                                    anchors.fill: parent
                                    spacing: 0

                                    Item {
                                        width: 38
                                        height: 38

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "grid_view"
                                            fontStyle: Tokens.font.icon.small
                                            color: root.historyGridView ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.historyGridView = true
                                        }
                                    }

                                    Item {
                                        width: 38
                                        height: 38

                                        MaterialIcon {
                                            anchors.centerIn: parent
                                            text: "view_list"
                                            fontStyle: Tokens.font.icon.small
                                            color: !root.historyGridView ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.historyGridView = false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 96
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        MaterialIcon {
                            id: defaultHeightIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: "swap_vert"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        Column {
                            anchors.left: defaultHeightIcon.right
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.spacing.medium
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.large

                            Item {
                                width: parent.width
                                height: 20

                                StyledText {
                                    anchors.left: parent.left
                                    text: "Default Height"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    text: root.agentDefaultHeight + "px"
                                    font: Tokens.font.label.medium
                                    color: Colours.palette.m3onSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledSlider {
                                id: defaultHeightSlider
                                width: parent.width
                                from: 400
                                to: root.maxHeight
                                value: root.agentDefaultHeight
                                onInteraction: v => {
                                    root.agentDefaultHeight = Math.round(defaultHeightSlider.from + v * (defaultHeightSlider.to - defaultHeightSlider.from));
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 96
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        MaterialIcon {
                            id: defaultWidthIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: "swap_horiz"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        Column {
                            anchors.left: defaultWidthIcon.right
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.spacing.medium
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.large

                            Item {
                                width: parent.width
                                height: 20

                                StyledText {
                                    anchors.left: parent.left
                                    text: "Default Width"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    text: root.agentDefaultWidth + "px"
                                    font: Tokens.font.label.medium
                                    color: Colours.palette.m3onSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledSlider {
                                id: defaultWidthSlider
                                width: parent.width
                                from: 630
                                to: root.screenWidth - 32
                                value: root.agentDefaultWidth
                                onInteraction: v => {
                                    root.agentDefaultWidth = Math.round(defaultWidthSlider.from + v * (defaultWidthSlider.to - defaultWidthSlider.from));
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 96
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0
                        opacity: root.agentFullScreen ? 0.5 : 1

                        MaterialIcon {
                            id: expandedHeightIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: "swap_vert"
                            color: root.agentFullScreen ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        Column {
                            anchors.left: expandedHeightIcon.right
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.spacing.medium
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.large

                            Item {
                                width: parent.width
                                height: 20

                                StyledText {
                                    anchors.left: parent.left
                                    text: "Expanded Height"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    text: root.agentExpandedHeight + "px"
                                    font: Tokens.font.label.medium
                                    color: Colours.palette.m3onSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledSlider {
                                id: expandedHeightSlider
                                width: parent.width
                                from: 400
                                to: root.maxHeight
                                value: root.agentExpandedHeight
                                enabled: !root.agentFullScreen
                                onInteraction: v => {
                                    root.agentExpandedHeight = Math.round(expandedHeightSlider.from + v * (expandedHeightSlider.to - expandedHeightSlider.from));
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 96
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0
                        opacity: root.agentFullScreen ? 0.5 : 1

                        MaterialIcon {
                            id: expandedWidthIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: "swap_horiz"
                            color: root.agentFullScreen ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        Column {
                            anchors.left: expandedWidthIcon.right
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.spacing.medium
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.large

                            Item {
                                width: parent.width
                                height: 20

                                StyledText {
                                    anchors.left: parent.left
                                    text: "Expanded Width"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    text: root.agentExpandedWidth + "px"
                                    font: Tokens.font.label.medium
                                    color: Colours.palette.m3onSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledSlider {
                                id: expandedWidthSlider
                                width: parent.width
                                from: 630
                                to: root.screenWidth - 32
                                value: root.agentExpandedWidth
                                enabled: !root.agentFullScreen
                                onInteraction: v => {
                                    root.agentExpandedWidth = Math.round(expandedWidthSlider.from + v * (expandedWidthSlider.to - expandedWidthSlider.from));
                                }
                            }
                        }
                    }



                    Item {
                        width: parent.width
                        height: 56
                        
                        StyledText {
                            text: "AI ENGINE & MODEL"
                            font: Tokens.font.label.medium
                            color: Colours.palette.m3primary
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Tokens.spacing.extraSmall
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 80
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        Row {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: "public"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - 40 - 60
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: "Web Search"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                }
                                StyledText {
                                    text: "Query the web for real-time and latest news"
                                    font: Tokens.font.body.small
                                    color: Colours.palette.m3onSurfaceVariant
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }

                            StyledSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.agentWebSearch
                                onToggled: {
                                    root.agentWebSearch = checked;
                                }
                            }
                        }
                    }

                    
                    StyledRect {
                        width: parent.width
                        height: 80
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        Row {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: "schedule"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - 40 - 60
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: "Date & Time"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                }
                                StyledText {
                                    text: "Inject current date and time into context"
                                    font: Tokens.font.body.small
                                    color: Colours.palette.m3onSurfaceVariant
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }

                            StyledSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.agentDateTime
                                onToggled: {
                                    root.agentDateTime = checked;
                                }
                            }
                        }
                    }

                    
                    StyledRect {
                        width: parent.width
                        height: 80
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        Row {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: "location_on"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.medium
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - 40 - 60
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                StyledText {
                                    text: "Location"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                }
                                StyledText {
                                    text: Weather.city ? Weather.city : "Inject your city & coordinates into context"
                                    font: Tokens.font.body.small
                                    color: Colours.palette.m3onSurfaceVariant
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }

                            StyledSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: root.agentLocation
                                onToggled: {
                                    root.agentLocation = checked;
                                    if (checked) Weather.reload();
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: 96
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        MaterialIcon {
                            id: contextWindowIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: "settings_overscan"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        Column {
                            anchors.left: contextWindowIcon.right
                            anchors.right: parent.right
                            anchors.leftMargin: Tokens.spacing.medium
                            anchors.rightMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.large

                            Item {
                                width: parent.width
                                height: 20

                                StyledText {
                                    anchors.left: parent.left
                                    text: "Context Window"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    text: (root.contextWindow >= 1024 ? Math.round(root.contextWindow / 1024) + "k" : root.contextWindow) + " tokens"
                                    font: Tokens.font.label.medium
                                    color: Colours.palette.m3onSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledSlider {
                                id: contextWindowSlider
                                width: parent.width
                                from: 2048
                                to: 131072
                                value: root.contextWindow
                                onInteraction: v => {
                                    var val = contextWindowSlider.from + v * (contextWindowSlider.to - contextWindowSlider.from);
                                    root.contextWindow = Math.round(val / 2048) * 2048;
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        implicitHeight: promptColumn.implicitHeight + Tokens.padding.medium * 2
                        radius: Tokens.rounding.large
                        color: Colours.layer(Colours.palette.m3surfaceContainerLow, 1)
                        border.width: 0

                        Column {
                            id: promptColumn
                            width: parent.width - Tokens.padding.medium * 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.spacing.small

                            Row {
                                width: parent.width
                                spacing: Tokens.spacing.medium

                                MaterialIcon {
                                    text: "description"
                                    color: Colours.palette.m3primary
                                    fontStyle: Tokens.font.icon.medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: "System Prompt"
                                    font: Tokens.font.body.builders.medium.weight(Font.Bold).build()
                                    color: Colours.palette.m3onSurface
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledText {
                                text: "Customize the rules and persona for the AI assistant."
                                font: Tokens.font.body.small
                                color: Colours.palette.m3onSurfaceVariant
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }

                            StyledRect {
                                width: parent.width
                                height: 180
                                radius: Tokens.rounding.medium
                                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                                border.width: 1
                                border.color: Colours.palette.m3outlineVariant

                                Flickable {
                                    id: promptFlickable
                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.small
                                    clip: true
                                    contentHeight: promptTextEdit.implicitHeight
                                    contentWidth: width

                                    TextEdit {
                                        id: promptTextEdit
                                        width: promptFlickable.width
                                        wrapMode: TextEdit.Wrap
                                        font: Tokens.font.body.medium
                                        color: Colours.palette.m3onSurface
                                        selectionColor: Colours.palette.m3primary
                                        selectedTextColor: Colours.palette.m3onPrimary
                                        selectByMouse: true
                                        text: loadSystemPrompt()

                                        onTextChanged: {
                                            if (activeFocus) {
                                                root.hasUnsavedPromptChanges = true;
                                            }
                                        }
                                    }

                                }
                            }

                            Item {
                                width: parent.width
                                height: 40

                                StyledText {
                                    id: promptSaveStatusText
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.hasUnsavedPromptChanges ? "Unsaved changes" : "Saved to file"
                                    font: Tokens.font.body.small
                                    color: root.hasUnsavedPromptChanges ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                                }

                                IconTextButton {
                                    id: saveButton
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Save"
                                    icon: "save"
                                    type: ButtonBase.Filled
                                    onClicked: {
                                        root.savePromptNow();
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
    }

    StyledRect {
        id: linkStatusHover
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacing.medium
        height: 28

        property string displayUrl: ""

        onOpacityChanged: {
            if (opacity === 0) {
                displayUrl = "";
            }
        }

        Connections {
            target: root
            function onHoverLinkUrlChanged() {
                if (root.hoverLinkUrl !== "") {
                    linkStatusHover.displayUrl = root.hoverLinkUrl;
                }
            }
        }

        width: Math.min(parent.width - Tokens.spacing.medium * 2, statusText.implicitWidth + Tokens.padding.medium * 2 + (statusIcon.visible ? 24 : 0))
        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        z: 99999
        opacity: root.hoverLinkUrl !== "" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        clip: true

        Row {
            x: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small
            width: parent.width - Tokens.padding.medium * 2

            MaterialIcon {
                id: statusIcon
                text: "link"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                id: statusText
                text: linkStatusHover.displayUrl
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                width: parent.width - Tokens.padding.medium * 2 - (statusIcon.visible ? 24 : 0)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    property var renderingInlineMath: ({})
    property var compiledInlineMath: ({})



    function markdownToHtml(md, colorStr) {
        if (!md) return "";

        function esc(s) {
            return s.replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;");
        }

        function inlineHtml(line) {

            var codePlaceholders = [];
            line = line.replace(/`([^`]+)`/g, function(m, code) {
                var idx = codePlaceholders.length;
                codePlaceholders.push("<code>" + esc(code) + "</code>");
                return "\x00CODE" + idx + "\x00";
            });

            var mathPlaceholders = [];
            line = line.replace(/\$([^\$\n]+)\$/g, function(m, formula) {
                var idx = mathPlaceholders.length;
                mathPlaceholders.push(m); // Keep original, will be processed by processInlineMathHtml
                return "\x00MATH" + idx + "\x00";
            });
            line = line.replace(/\\\([\s\S]*?\\\)/g, function(m) {
                var idx = mathPlaceholders.length;
                mathPlaceholders.push(m);
                return "\x00MATH" + idx + "\x00";
            });

            line = esc(line);

            line = line.replace(/\*\*\*(.+?)\*\*\*/g, "<b><i>$1</i></b>");
            line = line.replace(/___(.+?)___/g, "<b><i>$1</i></b>");
            line = line.replace(/\*\*(.+?)\*\*/g, "<b>$1</b>");
            line = line.replace(/__(.+?)__/g, "<b>$1</b>");
            line = line.replace(/\*([^\*]+?)\*/g, "<i>$1</i>");
            line = line.replace(/_([^_]+?)_/g, "<i>$1</i>");
            line = line.replace(/~~(.+?)~~/g, "<s>$1</s>");
            line = line.replace(/\[([^\]]+)\]\(([^\)]+)\)/g, '<a href="$2">$1</a>');

            line = line.replace(/\x00MATH(\d+)\x00/g, function(m, idx) {
                return mathPlaceholders[parseInt(idx)];
            });
            line = line.replace(/\x00CODE(\d+)\x00/g, function(m, idx) {
                return codePlaceholders[parseInt(idx)];
            });
            return line;
        }

        var lines = md.split("\n");
        var html = "";
        var inList = false;   // unordered
        var inOList = false;  // ordered
        var inTable = false;
        var tableHeaderActive = false;
        var listDepth = 0;

        function closeList() {
            if (inList)  { html += "</ul>"; inList = false; }
            if (inOList) { html += "</ol>"; inOList = false; }
        }

        function closeTable() {
            if (inTable) {
                html += "</table>";
                inTable = false;
                tableHeaderActive = false;
            }
        }

        for (var i = 0; i < lines.length; i++) {
            var raw = lines[i];
            var line = raw.replace(/^\s+/, "");

            // Table Row Check
            var isTableRow = (line.startsWith("|") && line.endsWith("|")) || (line.includes("|") && inTable);
            if (isTableRow) {
                closeList();
                
                var isSeparator = /^\|?([\s\-\:\*\|]+)\|?$/.test(line) && line.indexOf("-") !== -1;
                if (isSeparator) {
                    continue;
                }

                if (!inTable) {
                    html += "<table border='1' style='border-collapse: collapse; margin: 8px 0;'>";
                    inTable = true;
                    tableHeaderActive = true;
                }

                var cells = line.split("|");
                if (cells[0] === "") cells.shift();
                if (cells[cells.length - 1] === "") cells.pop();

                html += "<tr>";
                for (var c = 0; c < cells.length; c++) {
                    var cellText = inlineHtml(cells[c].trim());
                    if (tableHeaderActive) {
                        html += "<th>" + cellText + "</th>";
                    } else {
                        html += "<td>" + cellText + "</td>";
                    }
                }
                html += "</tr>";
                tableHeaderActive = false;
                continue;
            } else {
                closeTable();
            }

            var hm = line.match(/^(#{1,6})\s+(.*)$/);
            if (hm) {
                closeList();
                var level = hm[1].length;
                html += "<h" + level + ">" + inlineHtml(hm[2]) + "</h" + level + ">";
                continue;
            }

            if (/^[-*_]{3,}\s*$/.test(line)) {
                closeList();
                html += "<hr/>";
                continue;
            }

            if (line.startsWith("> ")) {
                closeList();
                html += "<blockquote>" + inlineHtml(line.substring(2)) + "</blockquote>";
                continue;
            }

            var ulm = line.match(/^[-*+]\s+(.*)$/);
            if (ulm) {
                if (!inList) { closeList(); html += "<ul>"; inList = true; }
                html += "<li>" + inlineHtml(ulm[1]) + "</li>";
                continue;
            }

            var olm = line.match(/^\d+\.\s+(.*)$/);
            if (olm) {
                if (!inOList) { closeList(); html += "<ol>"; inOList = true; }
                html += "<li>" + inlineHtml(olm[1]) + "</li>";
                continue;
            }

            if (line === "") {
                closeList();
                html += "<br/>";
                continue;
            }

            closeList();
            html += "<p style='margin:0'>" + inlineHtml(line) + "</p>";
        }
        closeList();
        closeTable();
        return html;
    }

    function processInlineMathHtml(html, colorStr, isUserMsg, callback) {
        if (!html) return "";

        var fg = colorStr;
        if (fg.startsWith("#") && fg.length === 9) {
            fg = "#" + fg.substring(3, 9) + fg.substring(1, 3);
        }

        var size = "18";
        var processed = html;

        processed = processed.replace(/\\\(([^\)]*?)\\\)/g, function(match, formula) {
            formula = formula.trim();
            if (formula.length === 0) return match;

            var cacheKey = formula + "|" + fg + "|" + size;

            if (root.compiledInlineMath[cacheKey]) {
                return '<img src="file://' + root.compiledInlineMath[cacheKey] + '" height="22" align="middle" style="vertical-align:middle;margin:0 1px" />';
            } else {
                if (!root.renderingInlineMath[cacheKey]) {
                    root.renderingInlineMath[cacheKey] = true;
                    var scriptPath = "/home/zen/.config/quickshell/caelestia/utils/scripts/render_math.py";
                    runCommand([scriptPath, formula, colorStr, size], function(stdout) {
                        var path = stdout.trim();
                        if (root) {
                            if (root.renderingInlineMath) delete root.renderingInlineMath[cacheKey];
                            if (root.compiledInlineMath) root.compiledInlineMath[cacheKey] = path;
                        }
                        if (callback) callback();
                    });
                }
                return match;
            }
        });

        processed = processed.replace(/\$([^\$\n]+)\$/g, function(match, formula) {
            formula = formula.trim();
            if (formula.length === 0) return match;
            if (/^[0-9.,\s+\-*\/=()]+$/.test(formula) && !/[\^\\_{]/.test(formula)) {
                return match;
            }

            var cacheKey = formula + "|" + fg + "|" + size;

            if (root.compiledInlineMath[cacheKey]) {
                return '<img src="file://' + root.compiledInlineMath[cacheKey] + '" height="22" align="middle" style="vertical-align:middle;margin:0 1px" />';
            } else {
                if (!root.renderingInlineMath[cacheKey]) {
                    root.renderingInlineMath[cacheKey] = true;
                    var scriptPath = "/home/zen/.config/quickshell/caelestia/utils/scripts/render_math.py";
                    runCommand([scriptPath, formula, colorStr, size], function(stdout) {
                        var path = stdout.trim();
                        if (root) {
                            if (root.renderingInlineMath) delete root.renderingInlineMath[cacheKey];
                            if (root.compiledInlineMath) root.compiledInlineMath[cacheKey] = path;
                        }
                        if (callback) callback();
                    });
                }
                return match;
            }
        });

        return processed;
    }

    function processInlineMath(content, colorStr, isUserMsg, callback) {
        if (!content) return "";

        var fg = colorStr;
        if (fg.startsWith("#") && fg.length === 9) {
            fg = "#" + fg.substring(3, 9) + fg.substring(1, 3);
        }

        var size = "18";
        var processed = content;

        processed = processed.replace(/\\\(([\s\S]*?)\\\)/g, function(match, formula) {
            formula = formula.trim();
            if (formula.length === 0) return match;

            var cacheKey = formula + "|" + fg + "|" + size;

            if (root.compiledInlineMath[cacheKey]) {
                return '<img src="file://' + root.compiledInlineMath[cacheKey] + '" height="22" align="middle" style="vertical-align:middle;margin:0 1px" />';
            } else {
                if (!root.renderingInlineMath[cacheKey]) {
                    root.renderingInlineMath[cacheKey] = true;
                    var scriptPath = "/home/zen/.config/quickshell/caelestia/utils/scripts/render_math.py";
                    runCommand([scriptPath, formula, colorStr, size], function(stdout) {
                        var path = stdout.trim();
                        if (root) {
                            if (root.renderingInlineMath) delete root.renderingInlineMath[cacheKey];
                            if (root.compiledInlineMath) root.compiledInlineMath[cacheKey] = path;
                        }
                        if (callback) callback();
                    });
                }
                return match;
            }
        });

        processed = processed.replace(/\$([^\$\n]+)\$/g, function(match, formula) {
            formula = formula.trim();
            if (formula.length === 0) return match;
            if (/^[0-9.,\s+\-*\/=()]+$/.test(formula) && !/[\^\\_]/.test(formula)) {
                return match;
            }

            var cacheKey = formula + "|" + fg + "|" + size;

            if (root.compiledInlineMath[cacheKey]) {
                return '<img src="file://' + root.compiledInlineMath[cacheKey] + '" height="22" align="middle" style="vertical-align:middle;margin:0 1px" />';
            } else {
                if (!root.renderingInlineMath[cacheKey]) {
                    root.renderingInlineMath[cacheKey] = true;
                    var scriptPath = "/home/zen/.config/quickshell/caelestia/utils/scripts/render_math.py";
                    runCommand([scriptPath, formula, colorStr, size], function(stdout) {
                        var path = stdout.trim();
                        if (root) {
                            if (root.renderingInlineMath) delete root.renderingInlineMath[cacheKey];
                            if (root.compiledInlineMath) root.compiledInlineMath[cacheKey] = path;
                        }
                        if (callback) callback();
                    });
                }
                return match;
            }
        });

        return processed;
    }
}
