#!/bin/sh
# check JAMF folder exists
# show notification

JAMFFolder="/Library/Application Support/JAMF"
if [ -d "$JAMFFolder" ]; then
    echo "$JAMFFolder is a directory."
    osascript -e 'display notification "Your Mac is already enrolled with JAMF!" with title "JAMF Enrollment" subtitle "Well done!"'
else
    osascript -e 'display notification "Your Mac needs to be enrolled with JAMF!" with title "JAMF Enrollment" subtitle "Please contact Service Desk:"'
fi

