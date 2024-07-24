#!/bin/zsh
####################################################################################################
#
# check macOS updates in /Library/Preferences/com.apple.SoftwareUpdate.plist
#
####################################################################################################

#set -x
updatePlistFile="/Library/Preferences/com.apple.SoftwareUpdate.plist"
#updatePlistFile="/Users/jschlaht/Projects/macos-scripts-github/swift-dialog-scripts/com.apple.SoftwareUpdate-2.plist"
updatePlistFile="/Users/jschlaht/Projects/macos-scripts-github/swift-dialog-scripts/com.apple.SoftwareUpdate.onlyUpgrade.major.plist"
#updatePlistFile="/Users/jschlaht/Projects/macos-scripts-github/swift-dialog-scripts/com.apple.SoftwareUpdate.major.plist"

####################################################################################################
#
# Global Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
button1action="${4:-"jamfselfservice://content?entity=policy&id=192&action=view"}"                # Parameter 4: Button 1 action URL [ open system preference panes for software updates ]
#button1action="${4:-"open 'x-apple.systempreferences:com.apple.preferences.softwareupdate'"}"    # Parameter 4: Button 1 action URL [ open system preference panes for software updates ]
scriptLog="${5:-"/var/log/checkUpdates.dialog.log"}"                                              # Parameter 5: Script Log Location [ /var/log/checkUpdates.dialog.log ] (i.e., Your organization's default location for client-side logs)
upgradeURL="${6:-"jamfselfservice://content?entity=policy&id=176&action=view"}"                   # Parameter 6: URL to latest upgrade policy
upgradeTo13="${7:-"jamfselfservice://content?entity=policy&id=60&action=view"}"                   # Parameter 7: URL to macOS 13 Ventura upgrade policy
upgradeTo12="${8:-"jamfselfservice://content?entity=policy&id=62&action=view"}"                   # Parameter 8: URL to macOS 12 Monterey upgrade policy
upgradeTo11="${9:-"jamfselfservice://content?entity=policy&id=63&action=view"}"                   # Parameter 9: URL to macOS 11 BigSur upgrade policy
updateWithRestart="${10:-"jamfselfservice://content?entity=policy&id=81&action=view"}"            # Parameter 10: URL for update with force restart

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Operating System, currently logged-in user and language
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
osVersion=$(sw_vers -productVersion)
osBuild=$(sw_vers -buildVersion)

currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
currentLanguage=$(sudo -u "$currentUser" osascript -e 'user locale of (get system info)')

exitCode="0"

upgradePossible="upgrade-no"

####################################################################################################
#
# Dialog Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# dialog binary, output and options files
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
dialogBinary="/usr/local/bin/dialog"
optionsFile="/var/tmp/dialogOptions.json"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# dialog images, icons and actions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
bannerImage="https://mpib.jamfcloud.com/api/v1/branding-images/download/8"
icon="https://mpib.jamfcloud.com/api/v1/branding-images/download/4"
updateIcon="/System/Applications/System Settings.app"
overlayIcon="caution"

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
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogCheck() {
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
    "bannerheight" : 160,
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

number_of_available_os_updates=$(defaults read ${updatePlistFile} LastRecommendedUpdatesAvailable)

updateScriptLog "Prepare Dialog Values: ${number_of_available_os_updates} available"

# shellcheck disable=SC2071
if [[ ${number_of_available_os_updates} > 0 ]]; then

    updateScriptLog "Prepare Dialog Values: set updates variables for language ${currentLanguage}"

    if [[ ${number_of_available_os_updates} > 0 ]]; then
      height=465
    fi
    if [[ ${number_of_available_os_updates} > 1 ]]; then
      height=485
    fi
    if [[ ${number_of_available_os_updates} > 2 ]]; then
      height=525
    fi
    if [[ ${number_of_available_os_updates} > 3 ]]; then
      height=585
    fi

    if [[ "$currentLanguage" == "de_DE" ]]; then
        button1text="Update ausführen"
        button2UpdateText="Update verschieben"
        button2UpgradeText="Upgrade verschieben"
        button3text="Upgrade starten"
        infobuttontext="Mehr Informationen"
        message="Für Ihr Mac sind folgende Updates verfügbar.\\n\\n Diese sind von uns geprüft und werden _dringend_ empfohlen!\\n\\n Bitte aktualisieren Sie Ihr macOS über Systemeinstellungen indem Sie auf **_Update ausführen_** klicken!"
        restart_message="Neustart notwendig!"
    else
        button1text="run update"
        button2UpdateText="postpone update"
        button2UpgradeText="postpone upgrade"
        button3text="start upgrade"
        infobuttontext="Click here for more details"
        message="The following updates are available for your Mac.\\n\\n These have been tested by us and are _strongly_ recommended!\\n\\n Please update your macOS by clicking on **_run update_**!"
        restart_message="Restart required!"
    fi

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # Prepare Dialog Values: updates-available settings for swiftDialog
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    updateScriptLog "Prepare Dialog Values: updates-available settings for swiftDialog "

    number_upgrades_with_restart=0
    number_updates_with_restart=0
    number_updates_without_restart=0

    tee -a "$optionsFile" << EOF
    "messagefont" : "weight=light,size=16,name=Helvetica",
    "button1text" : "${button1text}",
    "height" : "${height}",
    "infobutton" : 1,
    "listitem" : [
EOF

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # Prepare Dialog Values: generate list entries for updates
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    updateScriptLog "Prepare Dialog Values: generate list entries for updates"

    for ((i = 0 ; i < ${number_of_available_os_updates} ; i++)); do
        update_name=$(/usr/libexec/PlistBuddy -c "print :RecommendedUpdates:${i}:Display\ Name" ${updatePlistFile})
        update_version=$(/usr/libexec/PlistBuddy -c "print :RecommendedUpdates:${i}:Display\ Version" ${updatePlistFile})
        restart_required=$(/usr/libexec/PlistBuddy -c "print :RecommendedUpdates:${i}:MobileSoftwareUpdate" ${updatePlistFile})
        identifier=$(/usr/libexec/PlistBuddy -c "print :RecommendedUpdates:${i}:Identifier" ${updatePlistFile})

        update_type=${identifier##*_}
        if [[ ${update_type} == 'major' ]]; then
          update_name="Upgrade - ${update_name}"
          upgradePossible="upgrade-yes"
          number_upgrades_with_restart=$((number_upgrades_with_restart+1))
          upgradeVersion=${update_version}
        else
          if [[ ${restart_required} ]]; then
              number_updates_with_restart=$((number_updates_with_restart+1))
          else
              number_updates_without_restart=$((number_updates_without_restart+1))
          fi
        fi

        update_icon="${updateIcon}"
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

    tee -a "$optionsFile" << EOF
    ],
EOF

  if [[ ${upgradePossible} == "upgrade-yes" ]]; then
    if [[ "$currentLanguage" == "de_DE" ]]; then
        message="Für Ihr Mac sind folgende Updates und ein Upgrade verfügbar.\\n\\n Updates sind von uns geprüft und werden _dringend_ empfohlen!\\n\\n Bitte aktualisieren Sie Ihr macOS über Systemeinstellungen indem Sie auf **_Update ausführen_** klicken!"
    else
        message="The following updates and an upgrade are available for your Mac.\\n\\n These have been tested by us and are _strongly_ recommended!\\n\\n Please update your macOS by clicking on **_run update_**!"
    fi
    # define upgrade major version
    upgradeMajorVersion=$(echo ${upgradeVersion} | awk -F. '{ print $1; }')
    if [[ ${upgradeMajorVersion} == 13 ]]; then
      upgradeURL=${upgradeTo13}
    fi
    if [[ ${upgradeMajorVersion} == 12 ]]; then
      upgradeURL=${upgradeTo12}
    fi
    if [[ ${upgradeMajorVersion} == 11 ]]; then
      upgradeURL=${upgradeTo11}
    fi
    tee -a "$optionsFile" << EOF
      "infobuttontext" : "${button3text}",
      "infobuttonaction" : "${upgradeURL}",
EOF
  else
    tee -a "$optionsFile" << EOF
      "infobuttontext" : "${infobuttontext}",
      "infobuttonaction" : "${infobuttonaction}",
EOF
  fi

  if [[ ${number_updates_with_restart} -gt 0 ]]; then
    tee -a "$optionsFile" << EOF
      "button1action" : "${updateWithRestart}",
      "button2text" : "${button2UpdateText}",
EOF
  elif [[ ${number_updates_without_restart} -gt 0 ]]; then
    tee -a "$optionsFile" << EOF
      "button1action" : "${button1action}",
      "button2text" : "${button2UpdateText}",
EOF
  else
    # only one upgrade is possible
    if [[ "$currentLanguage" == "de_DE" ]]; then
        message="Für Ihr Mac ist ein Upgrade verfügbar. Dieser ist von uns geprüft und freigegeben!\\n\\n Bitte aktualisieren Sie Ihr macOS indem Sie auf **_Upgrade starten_** klicken!"
    else
        message="The following upgrade is available for your Mac. These have been tested and approved by us!\\n\\n Please upgrade your macOS by clicking on **_start upgrade_**!"
    fi
    tee -a "$optionsFile" << EOF
      "button2text" : "${button2UpgradeText}",
EOF
  fi

    tee -a "$optionsFile" << END
    "message" : "${message}",
    "title" : "none"
}
END

else
  updateScriptLog "Execute Dialog: no updates -> exit"
  exit "${exitCode}"
fi

####################################################################################################
#
# Execute Dialog
#
####################################################################################################
updateScriptLog "Execute Dialog: execute swiftDialog with given optionsfile and infobox"

if [[ ${number_updates_with_restart} -eq 0 && ${number_updates_without_restart} -eq 0 ]]; then
  ${dialogBinary} \
      --jsonfile ${optionsFile}  \
      -o \
      --infobox "#### User - ${currentUser}  \n#### macOS  \n - version ${osVersion}  \n - build ${osBuild}" \
      --button1disabled
else
  ${dialogBinary} \
      --jsonfile ${optionsFile}  \
      -o \
      --infobox "#### User - ${currentUser}  \n#### macOS  \n - version ${osVersion}  \n - build ${osBuild}"
fi


returncode=$?

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Execute Dialog: handle returncode
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
updateScriptLog "Execute Dialog: handle returncode ${returncode}"

case ${returncode} in
  0)
  #open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane
  open 'x-apple.systempreferences:com.apple.preferences.softwareupdate'
  echo "Pressed OK"
  # Button 1 processing here
  ;;
  2)
  echo "Pressed Cancel Button (button 2)"
  # Button 2 processing here
  ;;
  3)
  echo "Pressed Info Button (button 3)"
  # Button 3 processing here
  # open ${upgradeURL}
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
#rm $optionsFile

updateScriptLog "Execute Dialog: exit"
exit "${exitCode}"









