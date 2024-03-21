#!/bin/sh
# check JAMF folder exists
# show dialog

JAMFFolder="/Library/Application Support/JAMF"
icon1="/Library/Application Support/Projectname/Project-Icon-Icon.icns"
currentUser=$(who | awk '/console/{print $1}')
currentLanguage=$(sudo -u "$currentUser" osascript -e 'user locale of (get system info)')

case $currentLanguage in
    'de_DE')
            message1="Ihr Mac wird noch nicht mit Jamf verwaltet! Bitte wenden Sie sich an die Kollegen vom Servicedesk."
            title="Jamf Verwaltung"
            button1="Verstanden"
          ;;
    *)
          message1="Your Mac needs to be enrolled with Jamf! Please ask your colleagues at the Servicedesk."
          title="Jamf Enrollment"
          button1="Acknowledge"
        ;;
esac

if [ ! -d "$JAMFFolder" ]; then
  osascript <<-EndOfScript
display dialog "$message1" with title "$title" buttons {"$button1"} default button 1 with icon POSIX file "$icon1"
EndOfScript
fi

