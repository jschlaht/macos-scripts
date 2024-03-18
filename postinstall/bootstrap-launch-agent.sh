#!/bin/sh
# activate launch agent for each user

# Run postinstall actions for root.
echo "Executing postinstall"
# Add commands to execute in system context here.

# Run postinstall actions for all logged in users.
for pid_uid in $(ps -axo pid,uid,args | grep -i "[l]oginwindow.app" | awk '{print $1 "," $2}'); do
    pid=$(echo $pid_uid | cut -d, -f1)
    uid=$(echo $pid_uid | cut -d, -f2)
    # Replace echo with e.g. launchctl load.
    launchctl bsexec "$pid" chroot -u "$uid" / launchctl bootstrap gui/"$uid" /Library/LaunchAgents/<package-identifier>.plist
done

exit 0
