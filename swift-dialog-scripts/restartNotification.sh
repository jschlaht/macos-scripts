#!/bin/zsh
####################################################################################################
#
# show restart notification
#
####################################################################################################

####################################################################################################
#
# Global Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
daysWithoutRebootLimit="${4:14}" # Default 14 days without reboot
scriptLog="${5:-"/var/log/checkUpdates.dialog.log"}"   # Parameter 5: Script Log Location [ /var/log/checkUpdates.dialog.log ] (i.e., Your organization's default location for client-side logs)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Uptime, last reboot date, currently logged-in user and language
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
lastRebootTimestamp=$(sysctl kern.boottime | awk -F'[= |,]' '{print $6}')
nowTimestamp=$(date +%s)
now=$(date -jf "%s" "$nowTimestamp" +"%Y-%m-%d %T")
upTimestamp=$((nowTimestamp-lastRebootTimestamp))
lastRebootDate=$(date -jf "%s" "$(sysctl kern.boottime | awk -F'[= |,]' '{print $6}')" +"%Y-%m-%d %T")
uptimeDays=$((upTimestamp/(24*60*60)))
uptimeHours=$((upTimestamp/(60*60)))

if [[ "${uptimeDays}" -lt "${daysWithoutRebootLimit}" ]]; then
    updateScriptLog "Param Check: Uptime is below the limit"
    exit 1
fi
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
currentLanguage=$(sudo -u "$currentUser" osascript -e 'user locale of (get system info)')

exitCode="0"

####################################################################################################
#
# Dialog Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# dialog binary, output and options files
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
dialogBinary="/usr/local/bin/dialog"
dialogOutput="/var/tmp/dialogOutput.json"

####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Script Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\n###\n# Show restart notification \n###\n"
updateScriptLog "Pre-flight Check: Initiating …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${currentUser}" || "${currentUser}" == "loginwindow" ]]; then
    updateScriptLog "Pre-flight Check: No user logged-in; exiting."
    exit 1
else
    currentUserFullname=$( id -F "${currentUser}" )
    currentUserFirstname=$( echo "$currentUserFullname" | cut -d " " -f 1 )
    currentUserID=$( id -u "${currentUser}" )
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "Pre-flight Check: Complete"

####################################################################################################
#
# Prepare Dialog Values
#
####################################################################################################

updateScriptLog "Prepare Dialog Values: Start"

updateScriptLog "Prepare Dialog Values: set updates variables for language ${currentLanguage}"

if [[ "$currentLanguage" == "de_DE" ]]; then
    if [[ $uptimeDays -gt 0 ]]; then
        title="Ihr Mac ist seit ${uptimeDays} Tagen eingeschaltet."
    else
        title="Ihr Mac ist seit ${uptimeHours} Stunden eingeschaltet."
    fi
    message="Letzter Neustart erfolgte am ${lastRebootDate}. Bitte asap neustarten!"
else
    if [[ $uptimeDays -gt 0 ]]; then
        title="Active for ${uptimeDays} days."
    else
        title="Active for ${uptimeHours} hours."
    fi
    message="Your Mac last rebooted on ${lastRebootDate}. Please restart it soon!"
fi

####################################################################################################
#
# Execute Dialog
#
####################################################################################################
updateScriptLog "Execute Dialog: execute swiftDialog"

${dialogBinary} \
    --notification \
    --title "${title}" \
    --message "${message}"

returncode=$?

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute Dialog: handle returncode
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
updateScriptLog "Execute Dialog: handle returncode ${returncode}"

case ${returncode} in
  0)
  echo "Pressed OK"
  #open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane
  # Button 1 processing here
  ;;
  2)
  echo "Pressed Cancel Button (button 2)"
  # Button 2 processing here
  ;;
  3)
  echo "Pressed Info Button (button 3)"
  # Button 3 processing here
  ;;
  4)
  echo "Timer Expired"
  # Timer ran out code here
  ;;
  20)
  echo "Do Not Disturb is enabled"
  # Do Not Disturb Processing here
  ;;
  201)
  echo "Image resource not found"
  ;;
  202)
  echo "Image for icon not found"
  ;;
  *)
  echo "Something else happened"
  ;;
esac

updateScriptLog "Execute Dialog: exit"
exit "${exitCode}"









