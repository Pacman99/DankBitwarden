import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string trigger: ""
    property bool copyToClipboard: false
    property var _passwords: []
    property string _prevPass: ""
    property bool _loading: false
    property int _pendingLoads: 0

    signal itemsChanged

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("dankBitwarden", "trigger", "[");
        copyToClipboard = pluginService.loadPluginData("dankBitwarden", "copyToClipboard", false);
        Qt.callLater(loadPasswords);
    }

    function loadPasswords() {
        const process = passwordsProcessComponent.createObject(root);
        process.running = true;
    }

    function syncPasswords() {
        const process = syncProcessComponent.createObject(root);
        process.running = true;
    }

    function getItems(query) {
        const lowerQuery = query ? query.toLowerCase().trim() : "";
        let results = [];

        for (let i = 0; i < _passwords.length; i++) {
            const pass = _passwords[i];
            const passLower = pass.name.toLowerCase();

            if (lowerQuery.length === 0 || passLower.includes(lowerQuery)) {
                results.push({
                    name: (pass.folder != null ? pass.folder + "/" : "") + pass.name,
                    icon: "material:password",
                    comment: pass.user,
                    action: "type:" + pass.id,
                    categories: ["Dank Bitwarden"],
                    _passName: pass.name,
                    _passId: pass.id,
                    _passUser: pass.user,
                    _passFolder: pass.folder,
                    _sortKey: pass.id == _prevPass ? 0 : 1 
                });
            }
        }

        const syncItem = {
            name: "Sync",
            icon: "material:sync",
            action: "sync:",
            categories: ["Dank Bitwarden"],
            _passName: "sync"
        };

        // Sync item should be sorted like any other item once typing starts
         if (lowerQuery.length !== 0 && "sync".includes(lowerQuery)) {
            results.push(syncItem);
        }

        results.sort((a, b) => {
            if (a._sortKey !== b._sortKey)
                return a._sortKey - b._sortKey;
            return a._passName.localeCompare(b._passName);
        });

        // If length is zero then add sync item to the beginning
        // so user knows its an option
        if (lowerQuery.length === 0) {
            results.unshift(syncItem);
        }

        return results.slice(0, 50);
    }

    function executeItem(item) {
        if (!item?.action)
            return;

        const actionParts = item.action.split(":");
        const actionType = actionParts[0];

        if (actionType === "sync") {
            syncPasswords();
            return;
        }

        if (actionType === "type") {
            if (copyToClipboard) {
                Quickshell.execDetached([
                    "sh",
                    "-c",
                    "rbw get --field password '" + item._passId + "' | wl-copy"
                ]);
                ToastService.showInfo("DankBitwarden", "Copied password for " + item._passName + " to clipboard");
            } else {
                Quickshell.execDetached([
                    "sh",
                    "-c",
                    "rbw get --field username '" + item._passId + "' | wtype - && " +
                    "rbw get --field password '" + item._passId + "' | wtype -"
                ]);
            }
        }
    }

    function copyItemField(item, field) {
        _prevPass = item._passId;
        Quickshell.execDetached(["sh", "-c", "rbw get --field '" + field + "' '" + item._passId + "' | dms cl copy -t 'x-kde-passwordManagerHint'"]);
        ToastService.showInfo("DankBitwarden", "Copied " + field + " of " + item._passName + " to clipboard");
    }

    function typeItemField(item, field) {
        _prevPass = item._passId;
        Quickshell.execDetached(["sh", "-c", "sleep 0.3 && rbw get --field '" + field + "' '" + item._passId + "' | wtype -"]);
    }

    function getContextMenuActions(item) {
        if (!item || !item._passId)
            return [];
        return [
            {
                icon: "content_copy",
                text: I18n.tr("Copy Username"),
                action: () => copyItemField(item, "username")
            },
            {
                icon: "content_copy",
                text: I18n.tr("Copy Password"),
                action: () => copyItemField(item, "password")
            },
            {
                icon: "content_copy",
                text: I18n.tr("Copy TOTP"),
                action: () => copyItemField(item, "totp")
            },
            {
                icon: "keyboard",
                text: I18n.tr("Type Username"),
                action: () => typeItemField(item, "username")
            },
            {
                icon: "keyboard",
                text: I18n.tr("Type Password"),
                action: () => typeItemField(item, "password")
            },
            {
                icon: "keyboard",
                text: I18n.tr("Type TOTP"),
                action: () => typeItemField(item, "totp")
            }
        ];
    }

    onTriggerChanged: {
        if (pluginService)
            pluginService.savePluginData("dankBitwarden", "trigger", trigger);
    }

    function onPasswordsLoaded(data) {
        if (!data?.length)
            return;
        _passwords = data;

        _pendingLoads--;
        if (_pendingLoads <= 0) {
            _loading = false;
            itemsChanged();
        }
    }

    property Component syncProcessComponent: Component {
        Process {
            id: syncProcess
            running: false
            command: ["rbw", "sync"]
            onExited: exitCode => {
                if (exitCode === 0) {
                    loadPasswords();
                } else {
                    console.warn("[DankBitwarden] Failed to sync passwords from rbw, make sure it is installed and you are logged in", "exit:", exitCode);
                }
                syncProcess.destroy();
            }
        }
        
    }

    property Component passwordsProcessComponent: Component {
        Process {
            id: passwordsProcess

            running: false
            command: ["rbw", "list", "--raw", ]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text);
                        root.onPasswordsLoaded(data);
                    } catch (e) {
                        console.error("[DankBitwarden] Failed to parse passwords:", e);
                    }
                    passwordsProcess.destroy();
                }
            }

            onExited: exitCode => {
                if (exitCode !== 0) {
                    console.warn("[DankBitwarden] Failed to load passwords from rbw, make sure it is installed and you are logged in", "exit:", exitCode);
                    root._pendingLoads--;
                    if (root._pendingLoads <= 0)
                      root._loading = false;
                    passwordsProcess.destroy();
                }
            }
        }
    }
}
