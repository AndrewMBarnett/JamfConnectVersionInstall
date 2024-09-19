#!/bin/zsh

:<<ABOUT_THIS_SCRIPT
-------------------------------------------------------------------------------

	Written by:William Smith
	Partner Program Manager
	Jamf
	bill@talkingmoose.net
	https://gist.github.com/talkingmoose/94882adb69403a24794f6b84d4ae9de5
	
	Originally posted: June 1, 2023

	Purpose: Downloads and installs the latest available Jamf Connect software
	for Mac directly on the client. This avoids having to manually download
	and store an up-to-date installer on a distribution server every month.
	
	Instructions: Optionally update the sha256Checksum value with a
	known SHA 256 string. Run the script with elevated privileges.
	If using Jamf Pro, consider replacing the sha256Checksum value
	with "$4", entering the checksum as script parameter in a policy.

	Except where otherwise noted, this work is licensed under
	http://creativecommons.org/licenses/by/4.0/

	"If you are going to fail, then fail gloriously."

    Updated on: 09/19/2024
	Updated by: @andrewmbarnett (https://gist.github.com/AndrewMBarnett)
	
	Updates:
	- Added in the option to download a targeted version of Jamf Connect
	- Added in to show the latest version of Jamf Connect
	- Added in a check to see if the connectVersion variable is set to either download the targeted version or the latest
  - Added in the option to download a targeted version of Jamf Connect
  - Added in script version, script name
  - Added in extra log output
  - Added in a check for the script log file and creates it if it doesn't exist
-------------------------------------------------------------------------------
ABOUT_THIS_SCRIPT

# Script Version
scriptVersion="1.2"
# Script Name
scriptName="JamfConnectVersionDownload"
# path to this script
currentDirectory=$( /usr/bin/dirname "$0" )
# name of this script
currentScript=$( /usr/bin/basename -s .sh "$0" )
# create log file in same directory as script
logFile="/Library/Logs/$currentScript - $( /bin/date '+%y-%m-%d' ).log"

# enter the SHA 256 checksum for the download file
# download the package and run '/usr/bin/shasum -a 256 /path/to/file.pkg'
# this will change with each version
# leave blank to to skip the checksum verification (less secure) or if using a $4 script parameter with Jamf Pro

function updateScriptLog() {
    echo "${scriptName} ($scriptVersion): $(date +%Y-%m-%d\ %H:%M:%S) - ${1}" | tee -a "${logFile}"
}

function preFlight() {
    updateScriptLog "[PRE-FLIGHT]      ${1}"
}

function notice() {
    updateScriptLog "[NOTICE]          ${1}"
}

function infoOut() {
    updateScriptLog "[INFO]            ${1}"
}

function errorOut() {
    updateScriptLog "[ERROR]           ${1}"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Create the log file if it does not exist
if [[ ! -f "${logFile}" ]]; then
    touch "${logFile}"
    if [[ -f "${logFile}" ]]; then
        preFlight "Created specified script log"
    else
        fatal "Unable to create specified script log '${logFile}'; exiting.\n\n(Is this script running as 'root' ?)"
    fi
else
    preFlight "Specified script log exists; writing log entries to it"
fi

sha256Checksum="" # e.g. "67b1e8e036c575782b1c9188dd48fa94d9eabcb81947c8632fd4acac7b01644b"

if [ "$4" != "" ] && [ "$sha256Checksum" = "" ]
then
	sha256Checksum=$4
fi

# functions
function logcomment()	{
	if [ $? = 0 ] ; then
		/bin/date "+%Y-%m-%d %H:%M:%S	$1" >> "$logFile"
	else
		/bin/date "+%Y-%m-%d %H:%M:%S	$2" >> "$logFile"
	fi
}

# temporary file name for downloaded package
dmgFile="JamfConnect.dmg"
pkgFile="JamfConnect.pkg"

# Jamf Connect Version target number (Leave blank for latest Connect Version)
connectVersion="2.39.0"

# Jamf Connect full download URL to the latest version
connectURL="https://files.jamfconnect.com/JamfConnect.dmg"
# Jamf Connect latest version available on the website
appNewVersion=$(curl -fsIL "${connectURL}" | grep "x-amz-meta-version" | grep -o "[0-9.].*[0-9.].*[0-9]")
notice "Latest Jamf Connect Version: $appNewVersion"

# Check if Connect Version is blank
if [ "$connectVersion" = "" ]; then
    infoOut "Connect Version was blank, downloading latest version..."
    # get the latest version of the product
    downloadURL="https://files.jamfconnect.com/JamfConnect.dmg"
    infoOut "Download URL: $downloadURL"
else
    notice "Downloading Connect Version: $connectVersion"
    # this is the full download URL to the latest version of the product
    downloadURL="https://files.jamfconnect.com/JamfConnect-$connectVersion.dmg"
    infoOut "Download URL: $downloadURL"
fi

# create temporary working directory
infoOut "Creating working directory '$tempDirectory'"
workDirectory=$( /usr/bin/basename $0 )
tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

# change directory to temporary working directory
infoOut "Changing directory to working directory '$tempDirectory'"
cd "$tempDirectory"

# download the installer package
infoOut "Downloading disk image $dmgFile"
/usr/bin/curl "$downloadURL" \
--location \
--silent \
--output "$dmgFile"

# checksum the download
downloadChecksum=$( /usr/bin/shasum -a 256 "$tempDirectory/$dmgFile" | /usr/bin/awk '{ print $1 }' )
infoOut "Checksum for downloaded disk image: $downloadChecksum"

# install the download if checksum validates
if [ "$sha256Checksum" = "$downloadChecksum" ] || [ "$sha256Checksum" = "" ]; then
	infoOut "Checksum verified. Installing software..."
	
	# mounting DMG
	notice "Mounting $dmgFile..."
	appVolume=$( yes | /usr/bin/hdiutil attach -nobrowse "$tempDirectory/$dmgFile" | /usr/bin/grep /Volumes | /usr/bin/sed -e 's/^.*\/Volumes\///g' )
	notice "Mounted $dmgFile." "Failed to mount $dmgFile."
	infoOut "Mounted volume: "$appVolume""
	
	# install software
	infoOut "Installing software..."
	/usr/sbin/installer -pkg "/Volumes/$appVolume/$pkgFile" -target /
	infoOut "Installed software." "Failed to install software."
	
	# unmount DMG
	infoOut "Unmounting $dmgFile..."
	/sbin/umount -f "/Volumes/$appVolume" # forcibly unmount
	infoOut "Unmounting $dmgFile." "Failed to unmount $dmgFile."
	
else
	error "Checksum failed. Recalculate the SHA 256 checksum and try again. Or download may not be valid."
	exit 1
fi

# delete DMG
notice "Deleting DMG..."
/bin/rm -R "$tempDirectory"
infoOut "Deleted DMG." "Failed to delete DMG."

exit $exitCode
