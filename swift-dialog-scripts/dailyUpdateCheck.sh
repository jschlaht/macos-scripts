#!/bin/zsh
####################################################################################################
#
# check macOS updates in /Library/Preferences/com.apple.SoftwareUpdate.plist
#
####################################################################################################

#set -x

####################################################################################################
#
# Global Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
button1action="${4:-"jamfselfservice://content?entity=policy&id=81&action=execute"}"                # Parameter 4: Button 1 action URL [ URL for [execute|view] of install recommended updates policy ]
scriptLog="${5:-"/var/log/checkUpdates.dialog.log"}"                                           # Parameter 5: Script Log Location [ /var/log/checkUpdates.dialog.log ] (i.e., Your organization's default location for client-side logs)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Operating System, currently logged-in user and language
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
osVersion=$(sw_vers -productVersion)
osBuild=$(sw_vers -buildVersion)
osMajorVersion=$(sw_vers -productVersion | awk -F. '{ print $1; }')

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
optionsFile="/var/tmp/dialogOptions.json"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# dialog images, icons and actions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
bannerImage="https://mpib.jamfcloud.com/api/v1/branding-images/download/8"
icon="https://mpib.jamfcloud.com/api/v1/branding-images/download/4"
overlayIcon="https://ics.services.jamfcloud.com/icon/hash_37cdfa19f3e2791ace541162024efce19c7b446d5866004bf1395bc15eef9825"

infobuttonaction="https://support.apple.com/de-de/HT201222"

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

updateScriptLog "\n\n###\n# Check updates for your Mac \n###\n"
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
# Pre-flight Check: Validate / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {

    # Output Line Number in `verbose` Debug Mode
    if [[ "${debugMode}" == "verbose" ]]; then updateScriptLog "Pre-flight Check: # # # SETUP YOUR MAC VERBOSE DEBUG MODE: Line No. ${LINENO} # # #" ; fi

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl --silent --fail --location "https://api.github.com/repositories/346831918/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        updateScriptLog "Pre-flight Check: Dialog not found. Installing..."

        # Create temporary working directory
        workDirectory=$( /usr/bin/basename "$0" )
        tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

        # Download the installer package
        /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

        # Verify the download
        teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

        # Install the package if Team ID validates
        if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

            /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
            sleep 2
            dialogVersion=$( /usr/local/bin/dialog --version )
            updateScriptLog "Pre-flight Check: swiftDialog version ${dialogVersion} installed; proceeding..."

        else

            exitCode="1"
            exit "${exitCode}"

        fi

        # Remove the temporary working directory when done
        /bin/rm -Rf "$tempDirectory"

    else

        updateScriptLog "Pre-flight Check: swiftDialog version $(dialog --version) found; proceeding..."

    fi

}

if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
    dialogCheck
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

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Prepare Dialog Values: basic settings for swiftDialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
updateScriptLog "Prepare Dialog Values: basic settings for swiftDialog "

tee "$optionsFile" << EOT
{
    "bannerimage" : "${bannerImage}",
    "titlefont" : "weight=light,size=20,name=Helvetica",
    "icon" : "${icon}",
    "iconsize" : 128,
    "hideicon" : 0,
    "quitoninfo" : 0,
    "overlayicon" : "${overlayIcon}",
EOT

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Prepare Dialog Values: check number of available updates
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

number_of_available_os_updates=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist LastRecommendedUpdatesAvailable)

updateScriptLog "Prepare Dialog Values: ${number_of_available_os_updates} available"

if [[ ${number_of_available_os_updates} > 0 ]]; then

    updateScriptLog "Prepare Dialog Values: set updates variables for language ${currentLanguage}"

    if [[ "$currentLanguage" == "de_DE" ]]; then
        title="Ihr Mac auf verfügbare macOS Updates prüfen"
        button1text="Updates ausführen"
        button2text="Updates verschieben"
        infobuttontext="Mehr Informationen"
        message="Für Ihr Mac sind folgende Updates verfügbar.\\n\\n Diese sind von uns geprüft und werden _dringend_ empfohlen!\\n\\n Bitte aktualisieren Sie ihr macOS indem Sie auf **_Updates ausführen_** klicken!"
        restart_message="Neustart notwendig!"
    else
        title="Check for macOS updates on your Mac"
        button1text="run updates"
        button2text="postpone updates"
        infobuttontext="Click here for more details"
        message="The following updates are available for your Mac.\\n\\n These have been tested by us and are _strongly_ recommended!\\n\\n Please update your macOS by clicking on **_run updates_**!"
        restart_message="Restart required!"
    fi

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # Prepare Dialog Values: updates-available settings for swiftDialog
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    updateScriptLog "Prepare Dialog Values: updates-available settings for swiftDialog "

    tee -a "$optionsFile" << EOF
    "title" : "${title}",
    "message" : "${message}",
    "messagefont" : "weight=light,size=16,name=Helvetica",
    "button1text" : "${button1text}",
    "button2text" : "${button2text}",
    "button1action" : "${button1action}",
    "infobuttontext" : "${infobuttontext}",
    "infobuttonaction" : "${infobuttonaction}",
    "height" : "625",
    "infobutton" : 1,
    "listitem" : [
EOF

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # Prepare Dialog Values: generate list entries for updates
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    updateScriptLog "Prepare Dialog Values: generate list entries for updates"

    for ((i = 0 ; i < ${number_of_available_os_updates} ; i++)); do
        # prod settigns
        update_name=$(/usr/libexec/PlistBuddy -c "print :RecommendedUpdates:${i}:Display\ Name" /Library/Preferences/com.apple.SoftwareUpdate.plist)
        update_version=$(/usr/libexec/PlistBuddy -c "print :RecommendedUpdates:${i}:Display\ Version" /Library/Preferences/com.apple.SoftwareUpdate.plist)
        restart_required=$(/usr/libexec/PlistBuddy -c "print :RecommendedUpdates:${i}:MobileSoftwareUpdate" /Library/Preferences/com.apple.SoftwareUpdate.plist)

        update_icon="${overlayIcon}"
        if [[ ${update_name} == 'Safari' ]]; then
            update_icon="/Applications/Safari.app"
        fi

        update_status="error"
        if [[ ${restart_required} ]]; then
            status_text=${restart_message}
        else
            update_name="${update_name} ${update_version}"
            status_text=""
        fi

        tee -a "$optionsFile" << EOF
    {"title" : "${update_name}", "icon" : "${update_icon}", "status" : "${update_status}", "statustext" : "${status_text}"}
EOF
        if [[ "${i}+1" -lt ${number_of_available_os_updates} ]]; then
        tee -a "$optionsFile" << EOF
    ,
EOF
        fi
    done

    tee -a "$optionsFile" << END
    ]
}
END

else
    updateScriptLog "Prepare Dialog Values: set up to date variables for language ${currentLanguage}"

    if [[ "$currentLanguage" == "de_DE" ]]; then
        title="Ihr Mac auf verfügbare macOS Updates prüfen"
        button1text="Schliessen"
        message="### Herzlichen Glückwunsch!\\n\\n Ihr macOS ist aktuell, keine Updates erforderlich!"
    else
        title="Check for macOS updates on your Mac"
        button1text="close"
        message="### Congratulations!\\n\\n Your macOS is up to date, no updates required!"
    fi

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # Prepare Dialog Values: no updates available settings for swiftDialog
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    updateScriptLog "Prepare Dialog Values: no updates available settings for swiftDialog "

    tee -a "$optionsFile" << EOF
    "title" : "${title}",
    "message" : "${message}",
    "messagefont" : "weight=light,size=20,name=Helvetica",
    "height" : "525",
    "timer" : 5,
    "hidetimerbar" : 1,
    "button1text" : "${button1text}",
}
EOF

fi

####################################################################################################
#
# Execute Dialog
#
####################################################################################################
updateScriptLog "Execute Dialog: execute swiftDialog with given optionsfile and infobox"

${dialogBinary} \
    --jsonfile ${optionsFile}  \
    -o \
    --infobox "#### User  \n - ${currentUser}  \n#### macOS  \n - version ${osVersion}  \n - build ${osBuild}"

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

updateScriptLog "Execute Dialog: remove options file"
rm $optionsFile

updateScriptLog "Execute Dialog: exit"
exit "${exitCode}"









