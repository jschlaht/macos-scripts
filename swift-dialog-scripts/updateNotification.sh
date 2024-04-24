#!/bin/zsh

dialogBinary="/usr/local/bin/dialog"
dialogOutput="/var/tmp/dialogOutput.json"
optionsFile="/var/tmp/dialogOptions.json"

icon="https://mpib.jamfcloud.com/api/v1/branding-images/download/4"
if [ "${5}" != "" ]
then
    icon=${5}
fi
bannerImage="https://mpib.jamfcloud.com/api/v1/branding-images/download/8"


osVersion=$(sw_vers -productVersion)
osBuild=$(sw_vers -buildVersion)

currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
currentLanguage=$(sudo -u "$currentUser" osascript -e 'user locale of (get system info)')

optionsJSON='{
    "bannerimage" : "'"${bannerImage}"'",
    "title" : "Run check for macOS updates on your Mac",
    "titlefont" : "weight=light,size=20",
    "messagefont" : "weight=light,size=24",
    "icon" : "'"${icon}"'",
    "iconsize" : 128,
    "height" : "525",
    "hideicon" : 0,
    "infobutton" : 1,
    "quitoninfo" : 0,
    "overlayicon" : "/System/Applications/System Settings.app"
    }'

echo "$optionsJSON" > "$optionsFile"

if [[ "$currentLanguage" == "de_DE" ]]; then
    button1text="Update starten"
    button2text="Update verschieben"
    infobuttontext="Mehr Informationen"
    message="Update auf Version **${4}** verfügbar.\\n\\n Es ist von uns geprüft und wird dringend empfohlen!\\n\\n Bitte aktualisieren Sie ihr macOS über Update Policy in MPIB App Store!"
else
    button1text="start update"
    button2text="postpone update"
    infobuttontext="Click here for more details"
    message="Update to version **${4}** is available.\\n\\n It has been tested by us and is highly recommended!\\n\\n Please update your macOS over update policy in MPIB App Store!"
fi


${dialogBinary} \
    --jsonfile ${optionsFile}  \
    -o \
    --message ${message} \
    --button1text ${button1text} \
    --button2text ${button2text} \
    --infobuttontext ${infobuttontext} \
    --button1action ${7} \
    --infobuttonaction ${6} \
    --infobox "#### User  \n - ${currentUser}  \n#### macOS  \n - version ${osVersion}  \n - build ${osBuild}"

returncode=$?

echo $returncode

case ${returncode} in
  0)
  echo "Pressed OK"
  open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane
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

exit 0






