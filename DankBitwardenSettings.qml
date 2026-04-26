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

    SelectionSetting {
        settingKey: "loginAction"
        label: "Login Default Action"
        description: "Action when activating a Login entry"
        defaultValue: "autotype"
        options: [
            { label: "Autotype (User + Tab + Pass)", value: "autotype" },
            { label: "Type Username", value: "type:username" },
            { label: "Type Password", value: "type:password" },
            { label: "Type TOTP", value: "type:totp" },
            { label: "Copy Username", value: "copy:username" },
            { label: "Copy Password", value: "copy:password" },
            { label: "Copy TOTP", value: "copy:totp" }
        ]
    }

    SelectionSetting {
        settingKey: "cardAction"
        label: "Card Default Action"
        description: "Action when activating a Card entry"
        defaultValue: "type:number"
        options: [
            { label: "Type Number", value: "type:number" },
            { label: "Type CVV", value: "type:cvv" },
            { label: "Type Cardholder", value: "type:cardholder" },
            { label: "Copy Number", value: "copy:number" },
            { label: "Copy CVV", value: "copy:cvv" },
            { label: "Copy Cardholder", value: "copy:cardholder" },
            { label: "Copy Brand", value: "copy:brand" }
        ]
    }

    SelectionSetting {
        settingKey: "identityAction"
        label: "Identity Default Action"
        description: "Action when activating an Identity entry"
        defaultValue: "copy:name"
        options: [
            { label: "Copy Name", value: "copy:name" },
            { label: "Copy Address", value: "copy:address" },
            { label: "Copy SSN", value: "copy:ssn" },
            { label: "Copy Passport", value: "copy:passport" },
            { label: "Copy License", value: "copy:license" },
            { label: "Type Name", value: "type:name" },
            { label: "Type Address", value: "type:address" },
            { label: "Type SSN", value: "type:ssn" },
            { label: "Type Passport", value: "type:passport" },
            { label: "Type License", value: "type:license" }
        ]
    }

    SelectionSetting {
        settingKey: "sshKeyAction"
        label: "SSH Key Default Action"
        description: "Action when activating an SSH Key entry"
        defaultValue: "copy:public_key"
        options: [
            { label: "Copy Public Key", value: "copy:public_key" },
            { label: "Copy Fingerprint", value: "copy:fingerprint" },
            { label: "Type Public Key", value: "type:public_key" },
            { label: "Type Fingerprint", value: "type:fingerprint" }
        ]
    }
}
