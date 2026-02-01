import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankBitwarden"

    StyledText {
        width: parent.width
        text: "Dank Bitwarden Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Searches bitwarden passwords to copy or type."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        id: copyToClipboardToggle
        settingKey: "copyToClipboard"
        label: "Copy Password Instead of Typing"
        description: value ? "Copies passwords with wl-copy" : "Autotypes username and password with wtype"
        defaultValue: false
    }

    ToggleSetting {
        id: noTriggerToggle
        settingKey: "noTrigger"
        label: "Always Active"
        description: value ? "Type expressions directly" : "Use trigger prefix"
        defaultValue: false
        onValueChanged: {
            if (value)
                root.saveValue("trigger", "");
            else
                root.saveValue("trigger", triggerSetting.value || "[");
        }
    }

    StringSetting {
        id: triggerSetting
        visible: !noTriggerToggle.value
        settingKey: "trigger"
        label: "Trigger"
        description: "Prefix to activate bitwarden password search (e.g., [, pass, bw)"
        placeholder: "["
        defaultValue: "["
    }
}
