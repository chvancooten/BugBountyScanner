#!/bin/bash
## Automated Bug Bounty recon script
## By Cas van Cooten

scriptDir=$(dirname "$(readlink -f "$0")")
baseDir=$PWD
lastNotified=0
thorough=true
notify=true

function notify {
    if [ "$notify" = true ]
    then
        if [ $(($(date +%s) - lastNotified)) -le 3 ]
        then
            echo "[!] Notifying too quickly, sleeping to avoid skipped notifications..."
            sleep 3
        fi

        message=`echo -ne "*BugBountyAutomator [$DOMAIN]:* $1" | sed 's/[^a-zA-Z 0-9*_]/\\\\&/g'`
        curl -s -X POST "https://api.telegram.org/bot$telegram_api_key/sendMessage" -d chat_id="$telegram_chat_id" -d text="$message" -d parse_mode="MarkdownV2" &> /dev/null
        lastNotified=$(date +%s)
    fi
}

if [ -f "$scriptDir/.env" ]
then
    set -a
    . .env
    set +a
fi

if [ -z "$telegram_api_key" ] || [ -z "$telegram_chat_id" ]
then
    echo "[i] \$telegram_api_key and \$telegram_chat_id variables not found, disabling notifications..."
    notify=false
fi

for arg in "$@"
do
    case $arg in
        -h|--help)
        echo "BugBountyHunter - Automated Bug Bounty reconnaisance script"
        echo " "
        echo "$0 [options]"
        echo " "
        echo "options:"
        echo "-h, --help                show brief help"
        echo "-t, --toolsdir            tools directory (no trailing /), defaults to '/opt'"
        echo "-q, --quick               perform quick recon only (default: false)"
        echo "-d, --domain <domain>     top domain to scan, can take multiple"
        echo " "
        echo "Note: 'ToolsDir', 'telegram_api_key' and 'telegram_chat_id' can be defined in .env or through Docker environment variables."
        echo " "
        echo "example:"
        echo "$0 --quick -d google.com -d uber.com -t /opt"
        exit 0
        ;;
        -q|--quick)
        thorough=false
        shift
        ;;
        -d|--domain)
        domainargs+=("$2")
        shift
        shift
        ;;
        -t|--toolsdir)
        toolsDir="$2"
        shift
        shift
        ;;
    esac
done

if [ "${#domainargs[@]}" -ne 0 ]
then
    IFS=', ' read -r -a DOMAINS <<< "${domainargs[@]}"
else
    read -r -p "[?] What's the target domain(s)? E.g. \"domain.com,domain2.com\". DOMAIN: " domainsresponse
    IFS=', ' read -r -a DOMAINS <<< "$domainsresponse"  
fi

if [ -z "$toolsDir" ]
then
    echo "[i] \$toolsDir variable not defined in .env, defaulting to /opt..."
    toolsDir="/opt"
fi

echo "$PATH" | grep -q "$HOME/go/bin" || export PATH=$PATH:$HOME/go/bin

if command -v nuclei &> /dev/null # Very crude dependency check :D
then
	echo "[*] DEPENDENCIES FOUND. NOT INSTALLING."
else
    bash "$scriptDir/setup.sh" -t "$toolsDir"
fi

cd "$baseDir" || { echo "Something went wrong"; exit 1; }

echo "[*] STARTING RECON."
notify "Starting recon on *${#DOMAINS[@]}* subdomains."

for DOMAIN in "${DOMAINS[@]}"
do
    mkdir "$DOMAIN"
    cd "$DOMAIN" || { echo "Something went wrong"; exit 1; }

    echo "[*] RUNNING RECON ON $DOMAIN."
    notify "Starting recon on $DOMAIN. Enumerating subdomains with Amass..."

    echo "[*] RUNNING AMASS..."
    amass enum --passive -d "$DOMAIN" -o "domains-$DOMAIN.txt" 
    notify "Amass completed! Identified *$(wc -l < "domains-$DOMAIN.txt")* subdomains. Checking for live hosts with HTTPX..."

    echo "[*] RUNNING HTTPX..."
    httpx -silent -no-color -l "domains-$DOMAIN.txt" -title -content-length -web-server -status-code -ports 80,8080,443,8443 -threads 25 -o "httpx-$DOMAIN.txt"
    cut -d' ' -f1 < "httpx-$DOMAIN.txt" | sort -u > "livedomains-$DOMAIN.txt"
    notify "HTTPX completed. *$(wc -l < "livedomains-$DOMAIN.txt")* endpoints seem to be alive. Checking for hijackable subdomains with SubJack..."

    echo "[*] RUNNING SUBJACK..."
    subjack -w "domains-$DOMAIN.txt" -t 100 -c "$(find / -name "fingerprints.json" 2>/dev/null)" -o "subjack-$DOMAIN.txt" -a
    if [ -f "subjack-$DOMAIN.txt" ]; then
        echo "[+] HIJACKABLE SUBDOMAINS FOUND!"
        notify "SubJack completed. One or more hijackable subdomains found!"
        notify "Hijackable domains: $(cat "subjack-$DOMAIN.txt")"
        notify "Gathering live page screenshots with WebScreenshot..."
    else
        echo "[-] NO HIJACKABLE SUBDOMAINS FOUND."
        notify "No hijackable subdomains found. Gathering live page screenshots with WebScreenshot..."
    fi

    echo "[*] RUNNING WEBSCREENSHOT..."
    webscreenshot -i "livedomains-$DOMAIN.txt" -o webscreenshot --no-error-file
    notify "WebScreenshot completed! Took *$(find webscreenshot/* -maxdepth 0 | wc -l)* screenshots. Getting Wayback Machine path list with GAU..."

    echo "[*] RUNNING GAU..."
    gau -subs -providers wayback -o "gau-$DOMAIN.txt" "$DOMAIN"
    grep '?' < "gau-$DOMAIN.txt" | qsreplace -a > "WayBack-$DOMAIN.txt"
    rm "gau-$DOMAIN.txt"
    notify "GAU completed. Got *$(wc -l < "WayBack-$DOMAIN.txt")* paths."

    ######### OBSOLETE, REPLACED BY NUCLEI #########
    # echo "[*] SEARCHING FOR TELERIK ENDPOINTS..."
    # notify "Searching for potentially vulnerable Telerik endpoints..."
    # httpx -silent -l "domains-$DOMAIN.txt" -path /Telerik.Web.UI.WebResource.axd?type=rau -ports 80,8080,443,8443 -threads 25 -mc 200 -sr -srd telerik-vulnerable
    # grep -r -L -Z "RadAsyncUpload" telerik-vulnerable | xargs --null rm
    # if [ "$(find telerik-vulnerable/* -maxdepth 0 | wc -l)" -eq "0" ]; then
    #     echo "[-] NO TELERIK ENDPOINTS FOUND."
    #     notify "No Telerik endpoints found."
    # else
    #     echo "[+] TELERIK ENDPOINTS FOUND!"
    #     notify "*$(find telerik-vulnerable/* -maxdepth 0 | wc -l)* Telerik endpoints found. Manually inspect if vulnerable!"
    #     for file in telerik-vulnerable/*; do
    #         printf "\n\n########## %s ##########\n\n" "$file" >> potential-telerik.txt
    #         cat "$file" >> potential-telerik.txt
    #     done
    # fi
    # rm -rf telerik-vulnerable
    #
    # echo "[*] SEARCHING FOR EXPOSED .GIT FOLDERS..."
    # notify "Searching for exposed .git folders..."
    # httpx -silent -l "domains-$DOMAIN.txt" -path /.git/config -ports 80,8080,443,8443 -threads 25 -mc 200 -sr -srd gitfolders
    # grep -r -L -Z "\[core\]" gitfolders | xargs --null rm
    # if [ "$(find gitfolders/* -maxdepth 0 | wc -l)" -eq "0" ]; then
    #     echo "[-] NO .GIT FOLDERS FOUND."
    #     notify "No .git folders found."
    # else
    #     echo "[+] .GIT FOLDERS FOUND!"
    #     notify "*$(find gitfolders/* -maxdepth 0 | wc -l)* .git folders found!"
    #     for file in gitfolders/*; do
    #         printf "\n\n########## %s ##########\n\n" "$file" >> gitfolders.txt
    #         cat "$file" >> gitfolders.txt
    #     done
    # fi
    # rm -rf gitfolders
    ################################################

    if [ "$thorough" = true ] ; then
        echo "[*] RUNNING NUCLEI..."
        notify "Detecting known vulnerabilities with Nuclei..."
        nuclei -c 75 -l "livedomains-$DOMAIN.txt" -t "$toolsDir"'/nuclei-templates/' -severity low,medium,high -o "nuclei-$DOMAIN.txt"
        notify "Nuclei completed. Found *$(wc -l < "nuclei-$DOMAIN.txt")* (potential) issues. Spidering paths with GoSpider..."

        echo "**] RUNNING GOSPIDER..."
        gospider -S "livedomains-$DOMAIN.txt" -o GoSpider -t 2 -c 5 -d 3 --blacklist jpg,jpeg,gif,css,tif,tiff,png,ttf,woff,woff2,ico,svg
        cat GoSpider/* | grep -o -E "(([a-zA-Z][a-zA-Z0-9+-.]*\:\/\/)|mailto|data\:)([a-zA-Z0-9\.\&\/\?\:@\+-\_=#%;,])*" | sort -u | qsreplace -a | grep "$DOMAIN" > "GoSpider-$DOMAIN.txt"
        rm -rf GoSpider
        notify "GoSpider completed. Crawled *$(wc -l < "GoSpider-$DOMAIN.txt")* endpoints. Identifying interesting parameterized endpoints (from WaybackMachine and GoSpider) with GF..."

        # Merge GAU and GoSpider files into one big list of (hopefully) interesting paths
        cat "WayBack-$DOMAIN.txt" "GoSpider-$DOMAIN.txt" | sort -u | qsreplace -a > "paths-$DOMAIN.txt"
        rm "WayBack-$DOMAIN.txt" "GoSpider-$DOMAIN.txt"

        ######### OBSOLETE, REPLACED BY GF / MANUAL INSPECTION #########
        # echo "[**] SEARCHING FOR POSSIBLE SQL INJECTIONS..."
        # notify "(THOROUGH) Searching for possible SQL injections..."
        # grep "=" "paths-$DOMAIN.txt" | sed '/^.\{255\}./d' | qsreplace "' OR '1" | httpx -silent -threads 25 -sr -srd sqli-vulnerable
        # grep -r -L -Z "syntax error\|mysql\|sql" sqli-vulnerable | xargs --null rm
        # if [ "$(find sqli-vulnerable/* -maxdepth 0 | wc -l)" -eq "0" ]; then
        #     notify "No possible SQL injections found."
        # else
        #     notify "Identified *$(find sqli-vulnerable/* -maxdepth 0 | wc -l)* endpoints potentially vulnerable to SQL injection!"
        #     for file in sqli-vulnerable/*; do
        #         printf "\n\n########## %s ##########\n\n" "$file" >> potential-sqli.txt
        #         cat "$file" >> potential-sqli.txt
        #     done
        # fi
        # rm -rf sqli-vulnerable
        ################################################################

        echo "[*] GETTING INTERESTING PARAMETERS WITH GF..."
        mkdir "check-manually"
        gf ssrf < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/server-side-request-forgery.txt"
        gf xss < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/cross-site-scripting.txt"
        gf redirect < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/open-redirect.txt"
        gf rce < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/rce.txt"
        gf idor < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/insecure-direct-object-reference.txt"
        gf sqli < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/sql-injection.txt"
        gf lfi < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/local-file-inclusion.txt"
        gf ssti < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/server-side-template-injection.txt"
        gf debug_logic < "paths-$DOMAIN.txt" | httpx -silent -no-color -threads 25 -mc 200 -o "check-manually/debug-logic.txt"
        notify "GF done! Identified *$(cat check-manually/* | wc -l)* interesting and live parameter endpoints to check. Testing for Server-Side Template Injection..."

        echo "[*] Testing for SSTI..."
        qsreplace "BugBountyScanner{{9*9}}" < "check-manually/server-side-template-injection.txt" | httpx -silent -threads 25 -sr -srd ssti-vulnerable
        grep -r -L -Z "BugBountyScanner81" ssti-vulnerable | xargs --null rm
        if [ "$(find ssti-vulnerable/* -maxdepth 0 | wc -l)" -eq "0" ]; then
            notify "No possible SSTI found. Testing for LFI..."
        else
            notify "Identified *$(find ssti-vulnerable/* -maxdepth 0 | wc -l)* endpoints potentially vulnerable to SSTI! Testing for Local File Inclusion..."
            for file in ssti-vulnerable/*; do
                printf "\n\n########## %s ##########\n\n" "$file" >> potential-ssti.txt
                cat "$file" >> potential-ssti.txt
            done
        fi
        rm -rf ssti-vulnerable

        echo "[*] Testing for (*nix) LFI..."
        qsreplace "/etc/passwd" < "check-manually/local-file-inclusion.txt" | httpx -silent -threads 25 -sr -srd lfi-vulnerable
        grep -r -L -Z "root:x:" lfi-vulnerable | xargs --null rm
        if [ "$(find lfi-vulnerable/* -maxdepth 0 | wc -l)" -eq "0" ]; then
            notify "No possible LFI found. Testing for Open Redirections..."
        else
            notify "Identified *$(find lfi-vulnerable/* -maxdepth 0 | wc -l)* endpoints potentially vulnerable to LFI! Testing for Open Redirections..."
            for file in lfi-vulnerable/*; do
                printf "\n\n########## %s ##########\n\n" "$file" >> potential-lfi.txt
                cat "$file" >> potential-lfi.txt
            done
        fi
        rm -rf lfi-vulnerable

        echo "[*] Testing for Open Redirects..."
        qsreplace "https://www.testing123.com" < "check-manually/open-redirect.txt" | httpx -silent -threads 25 -sr -srd or-vulnerable
        grep -r -L -Z "Location: https://www.testing123.com" or-vulnerable | xargs --null rm
        if [ "$(find or-vulnerable/* -maxdepth 0 | wc -l)" -eq "0" ]; then
            notify "No possible OR found. Resolving hosts..."
        else
            notify "Identified *$(find or-vulnerable/* -maxdepth 0 | wc -l)* endpoints potentially vulnerable to OR! Resolving hosts..."
            for file in or-vulnerable/*; do
                printf "\n\n########## %s ##########\n\n" "$file" >> potential-or.txt
                cat "$file" >> potential-or.txt
            done
        fi
        rm -rf or-vulnerable

        echo "[*] Resolving IP addresses from hosts..."
        while read -r hostname; do
            dig "$hostname" +short >> "dig.txt"
        done < "domains-$DOMAIN.txt"
        grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' "dig.txt" | sort -u > "ip-addresses-$DOMAIN.txt" && rm "dig.txt"
        notify "Resolving done! Starting Nmap for *$(wc -l < "ip-addresses-$DOMAIN.txt")* IP addresses..."

        echo "[*] RUNNING NMAP (TOP 1000 TCP)..."
        mkdir nmap
        nmap -T4 --open --source-port 53 --max-retries 3 --host-timeout 15m -iL "ip-addresses-$DOMAIN.txt" -oA nmap/nmap-tcp
        grep Port < nmap/nmap-tcp.gnmap | cut -d' ' -f2 | sort -u > nmap/tcpips.txt
        notify "Nmap TCP done! Identified *$(grep -c "Port" < "nmap/nmap-tcp.gnmap")* IPs with ports open. Starting Nmap UDP/SNMP scan for *$(wc -l < "nmap/tcpips.txt")* IP addresses..."   

        echo "[*] RUNNING NMAP (SNMP UDP)..."
        nmap -T4 -sU -sV -p 161 --open --source-port 53 -iL nmap/tcpips.txt -oA nmap/nmap-161udp
        rm nmap/tcpips.txt
        notify "Nmap UDP done! Identified *$(grep "Port" < "nmap/nmap-161udp.gnmap" | grep -cv "filtered")* IPS with SNMP port open." 
    fi

    cd ..
    echo "[+] DONE SCANNING $DOMAIN."
    notify "Recon on $DOMAIN finished."

done

echo "[+] DONE! :D"
notify "Recon finished! Go hack em!"