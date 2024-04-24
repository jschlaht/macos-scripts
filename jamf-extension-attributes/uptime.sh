#!/bin/sh
echo "<result>`uptime | awk {'print $3'} | sed 's/,/ /g' | sed 's/d/ d/g'`</result>"
