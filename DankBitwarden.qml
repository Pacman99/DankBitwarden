import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string trigger: ""
    property string loginAction: "autotype"
    property string cardAction: "type:number"
    property string identityAction: "copy:name"
    property string sshKeyAction: "copy:public_key"
    property var _passwords: []
    property string _prevPass: ""
    property bool _loading: false
    property int _pendingLoads: 0
    property var _fieldsCache: ({})
    property FuzzyMatcher _fuzzy: FuzzyMatcher {}

    readonly property var _typeMeta: ({
        "Login":    { icon: "material:password",    primary: "password",   base: ["username", "password", "totp"] },
        "Card":     { icon: "material:credit_card", primary: "number",     base: ["cardholder", "number", "cvv", "brand"] },
        "Identity": { icon: "material:badge",       primary: "name",       base: [] },
        "Note":     { icon: "material:sticky_note_2", primary: null,       base: [] },
        "SSH Key":  { icon: "material:key",         primary: "public_key", base: ["public_key", "fingerprint"] }
    })

    signal itemsChanged

    Component.onCompleted: {
        if (!pluginService)
            return;
        _reloadSettings();
        Qt.callLater(loadPasswords);
    }

    function _reloadSettings() {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("dankBitwarden", "trigger", "[");
        loginAction = pluginService.loadPluginData("dankBitwarden", "loginAction", "autotype");
        cardAction = pluginService.loadPluginData("dankBitwarden", "cardAction", "type:number");
        identityAction = pluginService.loadPluginData("dankBitwarden", "identityAction", "copy:name");
        sshKeyAction = pluginService.loadPluginData("dankBitwarden", "sshKeyAction", "copy:public_key");
    }

    property var _pluginDataConn: Connections {
        target: pluginService
        enabled: pluginService !== null
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === "dankBitwarden")
                _reloadSettings();
        }
    }

    function loadPasswords() {
        const process = passwordsProcessComponent.createObject(root);
        process.running = true;
    }

    function _metaFor(type) {
        return _typeMeta[type] || { icon: "material:lock", primary: null, base: [] };
    }

    function _makeItem(pass) {
        const meta = _metaFor(pass.type);
        return {
            name: (pass.folder != null ? pass.folder + "/" : "") + pass.name,
            icon: meta.icon,
            comment: pass.user,
            action: "default:" + pass.id,
            categories: ["Dank Bitwarden"],
            _passName: pass.name,
            _passId: pass.id,
            _passUser: pass.user,
            _passFolder: pass.folder,
            _passType: pass.type
        };
    }

    function _defaultActionForType(type) {
        switch (type) {
            case "Login": return loginAction;
            case "Card": return cardAction;
            case "Identity": return identityAction;
            case "SSH Key": return sshKeyAction;
            default: return "";
        }
    }

    function _autotypeLogin(item) {
        Quickshell.execDetached([
            "sh",
            "-c",
            "rbw get --field username '" + item._passId + "' | tr -d '\\n' | wtype - && " +
            "wtype -k Tab && " +
            "rbw get --field password '" + item._passId + "' | tr -d '\\n' | wtype -"
        ]);
    }

    function _fieldsFor(item) {
        const cached = _fieldsCache[item._passId];
        const base = _metaFor(item._passType).base;
        if (!cached)
            return base;
        const merged = base.slice();
        for (let i = 0; i < cached.length; i++) {
            if (merged.indexOf(cached[i]) === -1)
                merged.push(cached[i]);
        }
        return merged;
    }

    function _humanizeField(f) {
        const s = f.replace(/_/g, " ");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function loadFields(item) {
        if (!item || !item._passId)
            return;
        if (_fieldsCache[item._passId])
            return;
        const process = fieldsProcessComponent.createObject(root, { passId: item._passId });
        process.running = true;
    }

    function syncPasswords() {
        const process = syncProcessComponent.createObject(root);
        process.running = true;
    }

    function getItems(query) {
        // Cap length so a pasted blob can't make the per-keystroke fuzzy scan
        // do unbounded work over a large vault.
        const raw = (query ? query.toLowerCase().trim() : "").slice(0, 128);

        const syncItem = {
            name: "Sync",
            icon: "material:sync",
            action: "sync:",
            categories: ["Dank Bitwarden"],
            _passName: "sync"
        };

        let results = [];

        if (raw.length === 0) {
            for (let i = 0; i < _passwords.length; i++) {
                const pass = _passwords[i];
                const item = _makeItem(pass);
                item._sortKey = pass.id == _prevPass ? 0 : 1;
                results.push(item);
            }
            results.sort((a, b) => {
                if (a._sortKey !== b._sortKey)
                    return a._sortKey - b._sortKey;
                return a._passName.localeCompare(b._passName);
            });
            // Keep the previously-used entry at the very top; sync sits just below it.
            const insertAt = (results.length > 0 && results[0]._sortKey === 0) ? 1 : 0;
            results.splice(insertAt, 0, syncItem);
        } else {
            // Fuzzy multi-token match across name, username and folder.
            const tokens = raw.split(/\s+/).filter(t => t.length > 0);
            for (let i = 0; i < _passwords.length; i++) {
                const pass = _passwords[i];
                const score = _fuzzy.matchAll(tokens, pass._search);
                if (score === null)
                    continue;
                const item = _makeItem(pass);
                item._score = score;
                item._mru = pass.id == _prevPass;
                results.push(item);
            }
            const syncScore = _fuzzy.matchAll(tokens, "sync");
            if (syncScore !== null) {
                syncItem._score = syncScore;
                syncItem._mru = false;
                results.push(syncItem);
            }
            // Rank by match quality; previously-used entry wins ties.
            results.sort((a, b) => {
                if (b._score !== a._score)
                    return b._score - a._score;
                if (a._mru !== b._mru)
                    return a._mru ? -1 : 1;
                return a._passName.localeCompare(b._passName);
            });
        }

        const top = results.slice(0, 50);
        for (let i = 0; i < top.length; i++) {
            top[i]._preScored = 100000 - i;
        }
        return top;
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

        if (actionType === "default") {
            let defaultAction = _defaultActionForType(item._passType);
            if (!defaultAction) {
                const primary = _metaFor(item._passType).primary;
                if (!primary)
                    return;
                defaultAction = "type:" + primary;
            }
            if (defaultAction === "autotype") {
                _autotypeLogin(item);
                _prevPass = item._passId;
                return;
            }
            const sep = defaultAction.indexOf(":");
            if (sep === -1)
                return;
            const mode = defaultAction.substring(0, sep);
            const field = defaultAction.substring(sep + 1);
            if (mode === "copy")
                copyItemField(item, field);
            else if (mode === "type")
                typeItemField(item, field);
        }
    }

    function copyItemField(item, field) {
        _prevPass = item._passId;
        Quickshell.execDetached([
            "sh", "-c",
            "rbw get --field '" + field + "' '" + item._passId + "' | tr -d '\\n' | dms cl copy && sleep 0.3 && " +
            'dms cl delete $(dms cl history --json | awk \'/"id":/{print $2+0; exit}\')'
        ]);
        ToastService.showInfo("DankBitwarden", "Copied " + field + " of " + item._passName + " to clipboard");
    }

    function typeItemField(item, field) {
        _prevPass = item._passId;
        Quickshell.execDetached(["sh", "-c", "sleep 0.3 && rbw get --field '" + field + "' '" + item._passId + "' | tr -d '\\n' | wtype -"]);
    }

    function getContextMenuActions(item) {
        if (!item || !item._passId)
            return [];
        loadFields(item);
        const fields = _fieldsFor(item);
        const actions = [];
        for (let i = 0; i < fields.length; i++) {
            const f = fields[i];
            const label = _humanizeField(f);
            actions.push({
                icon: "content_copy",
                text: I18n.tr("Copy ") + label,
                action: (function(field) { return () => copyItemField(item, field); })(f)
            });
        }
        for (let i = 0; i < fields.length; i++) {
            const f = fields[i];
            const label = _humanizeField(f);
            actions.push({
                icon: "keyboard",
                text: I18n.tr("Type ") + label,
                action: (function(field) { return () => typeItemField(item, field); })(f)
            });
        }
        return actions;
    }

    onTriggerChanged: {
        if (pluginService)
            pluginService.savePluginData("dankBitwarden", "trigger", trigger);
    }

    function onPasswordsLoaded(data) {
        if (!data?.length)
            return;
        for (let i = 0; i < data.length; i++) {
            const p = data[i];
            p._search = (p.name + " " + (p.user || "") + " " + (p.folder || "")).toLowerCase();
        }
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

    property Component fieldsProcessComponent: Component {
        Process {
            id: fieldsProcess
            property string passId: ""
            running: false
            command: ["rbw", "get", "-l", passId]

            stdout: StdioCollector {
                onStreamFinished: {
                    const fields = text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                    const cache = root._fieldsCache;
                    cache[fieldsProcess.passId] = fields;
                    root._fieldsCache = cache;
                    fieldsProcess.destroy();
                }
            }

            onExited: exitCode => {
                if (exitCode !== 0) {
                    console.warn("[DankBitwarden] Failed to load fields for", fieldsProcess.passId, "exit:", exitCode);
                    fieldsProcess.destroy();
                }
            }
        }
    }

    property Component passwordsProcessComponent: Component {
        Process {
            id: passwordsProcess

            running: false
            command: ["rbw", "list", "--fields", "id,name,user,folder,type"]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const lines = text.split("\n");
                        const data = [];
                        for (let i = 0; i < lines.length; i++) {
                            const line = lines[i];
                            if (!line)
                                continue;
                            const parts = line.split("\t");
                            const id = parts[0] || "";
                            const name = parts[1] || "";
                            const user = parts[2] || "";
                            const folder = parts[3] || "";
                            const type = parts[4] || "";
                            if (!id)
                                continue;
                            data.push({
                                id: id,
                                name: name,
                                user: user,
                                folder: folder || null,
                                type: type
                            });
                        }
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
