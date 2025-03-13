# Google Drive Manager for macOS

A script to completely manage Google Drive on macOS - uninstall existing installations and optionally install the latest version.

## Usage

Run this command in Terminal to download and execute the script:

```bash
curl -fsSL https://raw.githubusercontent.com/darkyy92/google-drive-mac-manager/main/google_drive_mac_manager.sh | sudo bash
```

This script will:
- Kill all Google Drive processes
- Remove the application and all associated files
- Remove preferences, caches, and launch agents
- Create a detailed log in /tmp
- Offer to download and install the latest version of Google Drive

## Features

- **Complete Uninstallation**: Thoroughly removes all Google Drive components
- **Fresh Installation**: Option to download and install the latest version directly from Google
- **Detailed Logging**: Creates comprehensive logs of all operations
- **User-Specific**: Only affects the currently logged-in user's files
- **Safe Execution**: Performs checks before and after operations

## Requirements
- Administrative privileges (sudo)
- macOS
- Internet connection (for installation option)

## License
MIT License - Use as you wish
