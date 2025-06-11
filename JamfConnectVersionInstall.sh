#!/bin/zsh

### --- Setup --- ###
scriptVersion="2.1"
scriptName="JamfConnectInstallUnified"
logFile="/Library/Logs/$scriptName.log"

# Script parameters
# User parameters
sha256Checksum="" # Can be passed as $4
if [[ "$4" != "" && "$sha256Checksum" = "" ]]; then sha256Checksum=$4; fi

# Connect Version (by $5) or auto-discover
connectVersion=""
openApps="" # Open installed app after install? (default: false)
if [[ "$openApps" != "true" && "$openApps" != "false" ]]; then
    openApps="false"
fi
connectURL="https://files.jamfconnect.com/JamfConnect.dmg"

# Functions
function updateScriptLog() {
    echo "${scriptName} ($scriptVersion): $(date +%Y-%m-%d\ %H:%M:%S) - ${1}" | tee -a "${logFile}"
}
function preFlight()  { updateScriptLog "[PRE-FLIGHT]      ${1}"; }
function notice()     { updateScriptLog "[NOTICE]          ${1}"; }
function infoOut()    { updateScriptLog "[INFO]            ${1}"; }
function errorOut()   { updateScriptLog "[ERROR]           ${1}"; }
function fatal()      { errorOut "${1}"; exit 1; }

if [[ ! -f "${logFile}" ]]; then
    touch "${logFile}" || fatal "Unable to create specified script log '${logFile}'; exiting. (Is this script running as 'root'?)"
    preFlight "Created specified script log"
else
    preFlight "Specified script log exists; writing log entries to it"
fi

# Extract 3-field version from latest download
if [[ -z "$connectVersion" ]]; then
    appNewVersion=$(curl -fsIL "${connectURL}" | grep "x-amz-meta-version" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+")
    connectVersion="$appNewVersion"
    infoOut "No connectVersion specified; using latest: $connectVersion"
else
    # Normalize if only two-field version given
    if [[ "$connectVersion" =~ ^[0-9]+\.[0-9]+$ ]]; then
        connectVersion="${connectVersion}.0"
    fi
    infoOut "Target Connect Version set: $connectVersion"
fi

# Compare versions
versionThreshold="3.0.0"

# Download URL
if [[ "$connectVersion" == "$appNewVersion" || -z "$connectVersion" ]]; then
    downloadURL="$connectURL"
else
    downloadURL="https://files.jamfconnect.com/JamfConnect-${connectVersion}.dmg"
fi

# Paths for both version branches
oldAppPath="/Applications/Jamf Connect.app"
newAppPath="/Applications/Jamf Connect.app"
newPkgName="JamfConnectLogin.pkg"
oldPkgName="JamfConnect.pkg"

# --- Robust version compare, returns 0 if $1 >= $2 ---
version_gte() {
    local ver1 ver2
    local i left right
    ver1=(${(s:.:)1})  # split $1 on .
    ver2=(${(s:.:)2})  # split $2 on .
    while [[ ${#ver1[@]} -lt 3 ]]; do ver1+=("0"); done
    while [[ ${#ver2[@]} -lt 3 ]]; do ver2+=("0"); done

    for i in 1 2 3; do
        left=$((10#${ver1[i]}))
        right=$((10#${ver2[i]}))
        if (( left > right )); then return 0; fi
        if (( left < right )); then return 1; fi
    done

    return 0
}

### --- Main Branch ---
if version_gte "$connectVersion" "$versionThreshold"; then
    # >= 3.0.0 Script Flow (Jamf 3.x+)
    notice "Jamf Connect version $connectVersion is >= $versionThreshold; using NEW installer method."
    appPath="$newAppPath"
    infoOut "Using app path: $appPath"
    TMP_PATH="/private/tmp"
    VendorDMG="JamfConnect.dmg"
    VendorCDR="JamfConnect.cdr"
    JamfConnectVOLUME="/Volumes/JamfConnectLogin"
    INSTALLER_PKG_NAME="$newPkgName"

    TARGET_MOUNT=$3; [[ -z "$TARGET_MOUNT" ]] && TARGET_MOUNT="/"

    infoOut "Downloading JamfConnect $connectVersion DMG to $TMP_PATH/$VendorDMG..."
    /usr/bin/curl --silent --fail --location "$downloadURL" -o "$TMP_PATH/$VendorDMG"
    [[ $? -ne 0 ]] && fatal "Download failed. Exiting."

    infoOut "Converting DMG to CDR..."
    /usr/bin/hdiutil convert -quiet "$TMP_PATH/$VendorDMG" -format UDTO -o "$TMP_PATH/$VendorCDR"
    [[ $? -ne 0 ]] && fatal "hdiutil convert failed. Exiting."

    infoOut "Mounting converted DMG as $JamfConnectVOLUME..."
    /usr/bin/hdiutil attach "${TMP_PATH}/${VendorCDR}" -nobrowse -quiet
    [[ $? -ne 0 ]] && fatal "Failed to mount CDR. Exiting."

    infoOut "Copying installer from $JamfConnectVOLUME/$INSTALLER_PKG_NAME to /tmp/JamfConnect.pkg"
    cp -R "$JamfConnectVOLUME/$INSTALLER_PKG_NAME" /tmp/JamfConnect.pkg || fatal "Copy failed. Exiting."

    /usr/bin/hdiutil detach "$JamfConnectVOLUME" > /dev/null 2>&1
    rm -f "$TMP_PATH/$VendorDMG" "$TMP_PATH/$VendorCDR"

    INSTALLER_FILENAME="/tmp/JamfConnect.pkg"
    infoOut "Installing $INSTALLER_FILENAME to $TARGET_MOUNT"
    /usr/sbin/installer -pkg "$INSTALLER_FILENAME" -target "$TARGET_MOUNT" || fatal "Installer failed. Exiting."
    rm -f "$INSTALLER_FILENAME"

    notice "Jamf Connect $connectVersion installed via NEW method."
    # Uncomment if you want to enable notify integration (if applicable)
    # /usr/local/bin/authchanger -reset -JamfConnect -Notify

else
    # < 3.0.0 Script Flow (Jamf 2.x and earlier)
    notice "Jamf Connect version $connectVersion is less than $versionThreshold; using OLD installer method."
    appPath="$oldAppPath"
    dmgFile="JamfConnect.dmg"
    infoOut "Using app path: $appPath"

    workDirectory=$(/usr/bin/basename $0)
    tempDirectory=$(/usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX")
    infoOut "Changing to working directory '$tempDirectory'"
    cd "$tempDirectory" || fatal "Failed to cd to temp directory."

    infoOut "Downloading $oldPkgName from $downloadURL"
    /usr/bin/curl --fail --silent --location "$downloadURL" --output "$dmgFile" || fatal "Download failed. Exiting."

    downloadChecksum=$(/usr/bin/shasum -a 256 "$tempDirectory/$dmgFile" | /usr/bin/awk '{ print $1 }')
    infoOut "Checksum for downloaded disk image: $downloadChecksum"

    if [[ "$sha256Checksum" = "$downloadChecksum" ]] || [[ -z "$sha256Checksum" ]]; then
        infoOut "Checksum verified. Installing software..."
        notice "Mounting $dmgFile..."
        appVolume=$(yes | /usr/bin/hdiutil attach -nobrowse "$tempDirectory/$dmgFile" | grep "/Volumes/" | sed -e 's/^.*\/Volumes\///g')
        notice "Mounted $dmgFile. ($appVolume)"

        installerPath="/Volumes/$appVolume/$oldPkgName"
        infoOut "Installing $installerPath..."
        /usr/sbin/installer -pkg "$installerPath" -target / || fatal "Installer failed."
        infoOut "Installed software."

        infoOut "Unmounting $dmgFile..."
        /sbin/umount -f "/Volumes/$appVolume" || infoOut "Failed to unmount $dmgFile."
    else
        fatal "Checksum failed. Recalculate the SHA 256 checksum and try again. Or download may not be valid."
    fi

    notice "Deleting temp directory..."
    /bin/rm -R "$tempDirectory"
    infoOut "Deleted temp directory."
fi

### --- Open the installed app, if requested ---
if [[ "$openApps" == "true" ]]; then
    if [[ -d "$appPath" || -f "$appPath" ]]; then
        sleep 0.5
        infoOut "Opening $appPath to enable Connect and Launch Agent"
        pkill "Jamf Connect"
        open -a "$appPath"
    else
        infoOut "App path $appPath not found, not opening."
    fi
else
    infoOut "Skipping opening $appPath"
fi

notice "Goodbye!"
exit 0