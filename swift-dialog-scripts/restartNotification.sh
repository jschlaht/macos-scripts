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
scriptLog="${5:-"/var/log/checkUpdates.dialog.log"}"   # Parameter 5: Script Log Location [ /var/log/checkUpdates.dialog.log ] (i.e., Your organization's default location for client-side logs)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Uptime, last reboot date, currently logged-in user and language
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
uptimeDays=$(uptime | awk {'print $3'} | sed 's/,/ /g' | sed 's/d/ d/g')
lastRebootDate=$(date -jf "%s" "$(sysctl kern.boottime | awk -F'[= |,]' '{print $6}')" +"%Y-%m-%d %T")

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
    title="Ihr Mac ist seit ${uptimeDays} Tag(en) eingeschaltet."
    message="Letzter Neustart erfolgte am ${lastRebootDate}. Bitte asap neustarten!"
else
    title="Your Mac since ${uptimeDays} day/dais on."
    message="Macs last reboot date: ${lastRebootDate}. Please restart asap!"
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









