# Jamf Connect Version Install

This script downloads and installs the latest available Jamf Connect software for Mac, or a specifically targeted version, **directly on the client Mac**. This means you don't need to manually download and store updated installers each month on a distribution server.

## Features

- **Version Targeting:** Install any available Jamf Connect version\
  _(installs the latest by default, or specify a version in the script parameters)._
- **Automatic Installer Handling:**\
  No more worrying about Jamf Connect’s installer packaging change in version 3.0.0. The script detects the version and uses the correct install workflow (old or new).
- **Enhanced Logging:**\
  Activity is recorded in `/Library/Logs/JamfConnectInstallUnified.log`.
- **Checksum Option:**\
  Optionally supports SHA256 checks for secure deployments.
- **Clear Output & Error Handling:**\
  Step-by-step logs for easier troubleshooting.
- **No Manual Package Handling:**\
  Fully automates download, checksum, and install.

## Usage

- **Default:** Downloads and installs the _latest_ Jamf Connect release.
- **To install a specific version:**\
  Pass the version as the fifth script parameter (e.g., via Jamf Pro’s `$5`).\
  _Example:_ `2.29.0`, `3.0.0`, etc.
- **Optional:**\
  Provide a SHA256 checksum as parameter `$4` for additional integrity verification (optional, recommended if you host your own installers).

### Example Table (Jamf Pro Parameters)

| Parameter   | Purpose/Use                    | Example            |
|-------------|-------------------------------|--------------------|
| Parameter 4 | SHA256 Checksum _(optional)_   | `abc123...`        |
| Parameter 5 | Target Jamf Connect Version    | `3.0.1`            |

---

## Notes

- The script _automatically chooses_ the legacy (pre-3.0) or newer (3.0+) Jamf Connect installer method.\
  **You do not need to adjust for installer packaging changes!**
- If your organization uses a custom install path or name for the Jamf Connect app, adjust the `appPath` variable in the script as needed.

---

## Credits

- [Original script by William Smith (talkingmoose)](https://gist.github.com/talkingmoose/94882adb69403a24794f6b84d4ae9de5)
- Enhanced by @andrewmbarnett and contributors
- Last updated: June 11, 2025

---

If you need help or run into issues, refer to the log at `/Library/Logs/JamfConnectInstallUnified.log` or open an issue.
