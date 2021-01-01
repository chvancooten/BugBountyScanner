#!/bin/bash
# Simple helper script to load BugBountyAutomator.sh results (the live scope) to BurpSuite for passive/active scanning and crawling.

if [ -z "$1" ]
then
    read -r -p "[?] What's the target live hosts file? [e.g. /root/BugBounty/scope.com/livedomains-scope.com.txt]: " file
else
    file=$1
fi

echo "[*] Loading live target hosts into burp, make sure burp proxy is running..."

httpx -silent -no-color -http-proxy httpx://127.0.0.1:8080 -follow-redirects -l "$file"