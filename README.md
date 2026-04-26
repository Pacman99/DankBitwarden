# Bitwarden Plugin for DMS Launcher
Launcher plugin for DankMaterialShell to search through bitwarden entries with rbw and copy or type fields.

## Features
- Search across all Bitwarden entries from the DMS launcher
- Supports Login, Card, Identity, SSH Key, and Note entry types with type-specific icons
- Configurable default action per entry type (autotype, copy, or type any field)
- Login autotype pastes username, presses Tab, then pastes password
- Context menu with Copy/Type for every field on the entry
- Previous entry sorted to the top

## Usage
1. Install and setup `rbw` following [its readme](https://github.com/doy/rbw).
2. Confirm that running `rbw list` prints out all entries.
3. Install this plugin (id is `dankBitwarden`) following instructions in the [dms-plugin-registry](https://github.com/AvengeMedia/dms-plugin-registry).
4. Optionally, go to the DMS Plugins settings page and set a trigger for dankBitwarden (default is `[`).
5. Start up DMS Launcher and type the trigger, all bitwarden entries will show up.
6. Selecting an entry will type the username and password for you. Right clicking or typing `F10` will bring up the context menu with options to copy or type the username, password, and totp.
7. If password list is ever outdated, select the `Sync` button after typing the trigger in the launcher. This will run `rbw sync` for you then update the password list. Depending on the size of the bitwarden vault, this can take around 10s.

## Security
It's highly recommended to go over the code before using this plugin since it is handling sensitive data. The plugin never loads any password into its memory. Passwords are directly piped to either `wtype` or `dms cl copy`.
