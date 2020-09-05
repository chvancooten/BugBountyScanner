#!/bin/bash
## Simple Automated Bug Bounty recon script
## By Cas van Cooten

### SECRETS
telegram_api_key='XXXXXXXXX:XXXXXXXXXXXXXXXXXXXXXXXXXXXX'
telegram_chat_id='XXXXXXXXX'
### END SECRETS

lastNotified=0
function notify {
    if [ $((`date +%s` - $lastNotified)) -le 3 ]; then
        echo "[!] Notifying too quickly, sleeping to avoid skipped notifications..."
        sleep 3
    fi
    message=`echo -ne "*BugBountyAutomator [$DOMAIN]:* $1" | sed 's/[^a-zA-Z 0-9*_]/\\\\&/g'`
    curl -s -X POST https://api.telegram.org/bot$telegram_api_key/sendMessage -d chat_id="$telegram_chat_id" -d text="$message" -d parse_mode="MarkdownV2" &> /dev/null
    lastNotified=`date +%s`
}

if [ -z "$1" ]
then
    read -r -p "[?] What's the target domain? E.g. \"domain.com\". DOMAIN: " DOMAIN
else
    DOMAIN=$1
fi

read -r -p "[?] Create subfolder (no will output files in current folder)? [y/n]: " subfresponse
case "$subfresponse" in
    [yY][eE][sS]|[yY]) 
        mkdir $DOMAIN
		cd $DOMAIN
        ;;
esac

read -r -p "[?] Perform thorough scan (not recommended for very big scopes)? [y/n]: " thoroughresponse
case "$thoroughresponse" in
    [yY][eE][sS]|[yY]) 
        thorough=true
        ;;
esac
if command -v subjack &> /dev/null
then
	  echo "[*] DEPENDENCIES FOUND. NOT INSTALLING."
else
	  echo "[*] INSTALLING DEPENDENCIES..."
	  # Based on running 'hackersploit/bugbountytoolkit' docker image which has Amass/Nmap included. Adapt where required.
	  apt update --assume-yes 
	  apt install --assume-yes phantomjs
	  apt install --assume-yes xvfb
	  pip install webscreenshot
	
	  echo "[*] INSTALLING GO DEPENDENCIES (OUTPUT MAY FREEZE)..."
      go get -u github.com/projectdiscovery/httpx/cmd/httpx
	  go get -u github.com/haccer/subjack
	  go get -u github.com/jaeles-project/gospider
	  go get -u github.com/tomnomnom/qsreplace
fi

echo "[*] RUNNING RECON ON $DOMAIN!"
notify "Starting recon on $DOMAIN!"

echo "[*] RUNNING AMASS..."
notify "Enumerating subdomains with Amass..."
amass enum --passive -d $DOMAIN -o domains-$DOMAIN.txt 
notify "Amass completed! Identified *`cat domains-$DOMAIN.txt | wc -l`* subdomains."

echo "[*] RUNNING HTTPX..."
notify "Checking for live hosts with HTTPX..."
httpx -silent -no-color -l domains-$DOMAIN.txt -title -content-length -web-server -status-code -ports 80,8080,443,8443 -threads 25 -o httpx-$DOMAIN.txt
cat httpx-$DOMAIN.txt | cut -d' ' -f1 | sort -u > livedomains-$DOMAIN.txt
notify "HTTPX completed. *`cat livedomains-$DOMAIN.txt | wc -l`* endpoints seem to be alive."

echo "[*] RUNNING SUBJACK..."
notify "Checking for hijackable subdomains with SubJack..."
subjack -w domains-$DOMAIN.txt -t 100 -o subjack-$DOMAIN.txt -a
if [ -f "subjack-$DOMAIN.txt" ]; then
    echo "[+] HIJACKABLE SUBDOMAINS FOUND!"
    notify "SubJack completed. One or more hijackable subdomains found!"
	notify "Hijackable domains: `cat subjack-$DOMAIN.txt`"
else
	echo "[-] NO HIJACKABLE SUBDOMAINS FOUND."
	notify "SubJack completed. No hijackable subdomains found."
fi

echo "[*] RUNNING WEBSCREENSHOT..."
notify "Gathering live page screenshots with WebScreenshot..."
webscreenshot -i livedomains-$DOMAIN.txt -o webscreenshot --no-error-file
notify "WebScreenshot completed! Took *`ls -1 webscreenshot | wc -l`* screenshots."

echo "[*] SEARCHING FOR TELERIK ENDPOINTS..."
notify "Searching for potentially vulnerable Telerik endpoints..."
httpx -silent -l domains-$DOMAIN.txt -path /Telerik.Web.UI.WebResource.axd?type=rau -ports 80,8080,443,8443 -threads 25 -mc 200 -sr -srd telerik-vulnerable
grep -r -L -Z "RadAsyncUpload" telerik-vulnerable | xargs --null rm
if [ $(ls -1 telerik-vulnerable | wc -l) -eq "0" ]; then
	echo "[-] NO TELERIK ENDPOINTS FOUND."
	notify "No Telerik endpoints found."
else
    echo "[+] TELERIK ENDPOINTS FOUND!"
    notify "*`ls -1 telerik-vulnerable | wc -l`* Telerik endpoints found. Manually inspect if vulnerable!"
    for file in telerik-vulnerable/*; do
        printf "\n\n########## $file ##########\n\n" >> potential-telerik.txt
        cat $file >> potential-telerik.txt
    done
fi
rm -rf telerik-vulnerable

echo "[*] SEARCHING FOR EXPOSED .GIT FOLDERS..."
notify "Searching for exposed .git folders..."
httpx -silent -l domains-$DOMAIN.txt -path /.git/config -ports 80,8080,443,8443 -threads 25 -mc 200 -sr -srd gitfolders
grep -r -L -Z "\[core\]" gitfolders | xargs --null rm
if [ $(ls -1 gitfolders | wc -l) -eq "0" ]; then
	echo "[-] NO .GIT FOLDERS FOUND."
	notify "No .git folders found."
else
    echo "[+] .GIT FOLDERS FOUND!"
    notify "*`ls -1 gitfolders | wc -l`* .git folders found!"
    for file in gitfolders/*; do
        printf "\n\n########## $file ##########\n\n" >> gitfolders.txt
        cat $file >> gitfolders.txt
    done
fi
rm -rf gitfolders

if [ "$thorough" = true ] ; then
    echo "[**] RUNNING GOSPIDER..."
    notify "(THOROUGH) Spidering parameters and pages with GoSpider..."
    gospider -S livedomains-$DOMAIN.txt -o GoSpider -t 3 -c 5 -d 3 --blacklist jpg,jpeg,gif,css,tif,tiff,png,ttf,woff,woff2,ico,svg
    cat GoSpider/* | grep -o -E "(([a-zA-Z][a-zA-Z0-9+-.]*\:\/\/)|mailto|data\:)([a-zA-Z0-9\.\&\/\?\:@\+-\_=#%;,])*" | sort -u | qsreplace -a | grep $DOMAIN > GoSpider-$DOMAIN.txt
    rm -rf GoSpider
    notify "GoSpider completed. Crawled *`cat GoSpider-$DOMAIN.txt | wc -l`* endpoints."

    echo "[**] SEARCHING FOR POSSIBLE SQL INJECTIONS..."
    notify "(THOROUGH) Searching for possible SQL injections..."
    grep "=" GoSpider-$DOMAIN.txt | sed '/^.\{255\}./d' | qsreplace "' OR '1" | httpx -silent -threads 25 -sr -srd sqli-vulnerable
    grep -r -L -Z "syntax error\|mysql\|sql" sqli-vulnerable | xargs --null rm
    if [ $(ls -1 sqli-vulnerable | wc -l) -eq "0" ]; then
        notify "No possible SQL injections found."
    else
        notify "Identified *`ls -1 sqli-vulnerable | wc -l`* endpoints potentially vulnerable to SQL injection!"
        for file in sqli-vulnerable/*; do
            printf "\n\n########## $file ##########\n\n" >> potential-sqli.txt
            cat $file >> potential-sqli.txt
        done
    fi
    rm -rf sqli-vulnerable

    echo "[**] RUNNING NMAP (TOP 1000 TCP)..."
    notify "(THOROUGH) Starting Nmap for *`cat domains-$DOMAIN.txt | wc -l`* IP addresses..."
    mkdir nmap
    nmap -T4 --open --source-port 53 --max-retries 3 --host-timeout 15m -iL domains-$DOMAIN.txt -oA nmap/nmap-tcp
    notify "Nmap TCP done! Identified *`cat nmap/nmap-tcp.gnmap | grep "Port" | wc -l`* IPs with ports open."   

    echo "[**] RUNNING NMAP (SNMP UDP)..."
    cat nmap/nmap-tcp.gnmap | grep Port | cut -d' ' -f2 | sort -u > nmap/tcpips.txt
    notify "(THOROUGH) Starting Nmap UDP/SNMP scan for *`cat nmap/tcpips.txt | wc -l`* IP addresses..."
    nmap -T4 -sU -sV -p 161 --open --source-port 53 -iL nmap/tcpips.txt -oA nmap/nmap-161udp
    rm nmap/tcpips.txt
    notify "Nmap TCP done! Identified *`cat nmap/nmap-161udp.gnmap | grep "Port" | grep -v "filtered" | wc -l`* IPS with SNMP port open." 
fi

echo "[+] DONE! :D"
notify "Recon on $DOMAIN finished! Go hack em!"
