#!/bin/sh
# check JAMF folder exists
# show notification

JAMFFolder="/Library/Application Support/JAMF"
icon1="/Library/Application Support/Projectname/Project-Icon-Icon.icns"
currentUser=$(who | awk '/console/{print $1}')
currentLanguage=$(sudo -u "$currentUser" osascript -e 'user locale of (get system info)')

case $currentLanguage in
    'de_DE')
            message1="Ihr Mac wird noch nicht mit JAMF verwaltet! Bitte wenden Sie sich an die Kollegen von Service Desk."
            message2="Ihr Mac wird bereits mit JAMF verwaltet! Alles gut :-)"
            title="JAMF Verwaltung"
            button1="Verstanden"
          ;;
    *)
          message1="Your Mac needs to be enrolled with JAMF! Please ask your colleagues at Service Desk."
          message2="Your Mac is already enrolled with JAMF!"
          title="JAMF Enrollment"
          button1="Accept"
        ;;
esac

if [ -d "$JAMFFolder" ]; then
    echo "$JAMFFolder is a directory."
    osascript <<-EndOfScript
display dialog "$message2" with title "$title" with icon POSIX file "/Library/Application Support/Projectname/Project-Icon.icns" buttons {"$button1"} default button 1
EndOfScript
else
  osascript <<-EndOfScript
display dialog "$message1" with title "$title" buttons {"$button1"} default button 1 with icon POSIX file "$icon1"
EndOfScript
fi

