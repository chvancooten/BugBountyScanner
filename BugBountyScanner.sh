#!/bin/bash
## Automated Bug Bounty recon script
## By Cas van Cooten

scriptDir=$(dirname "$(readlink -f "$0")")
baseDir=$PWD
lastNotified=0
thorough=true
notify=true
overwrite=false

function notify {
    if [ "$notify" = true ]
    then
        if [ $(($(date +%s) - lastNotified)) -le 3 ]
        then
            echo "[!] Notifying too quickly, sleeping to avoid skipped notifications..."
            sleep 3
        fi

        # Format string to escape special characters and send message through Telegram API.
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
        echo "-o, --outputdirectory     output directory, defaults to current directory ('.')"
        echo "-w, --overwrite           overwrite existing files. Skip steps with existing files if not provided (default: false)"
        echo "-c, --collaborator-id     pass a BurpSuite Collaborator ID to Nuclei to detect blind vulns (default: not enabled)"
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
        -o|--outputdirectory)
        baseDir="$2"
        shift
        shift
        ;;
        -w|--overwrite)
        overwrite=true
        shift
        ;;
        -c|--collaborator-id)
        collabID="$2"
        shift
        shift
    esac
done

if [ ! -d "$baseDir" ]
then
    read -r -N 1 -p "[?] Provided output directory \"$baseDir\" does not exist, create it? [Y/N] "
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 1
    fi
    mkdir -p "$baseDir"
fi

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
    mkdir -p "$DOMAIN"
    cd "$DOMAIN" || { echo "Something went wrong"; exit 1; }

    echo "[*] RUNNING RECON ON $DOMAIN."
    notify "Starting recon on $DOMAIN. Enumerating subdomains with Amass..."

    if [ ! -f "domains-$DOMAIN.txt" ] || [ "$overwrite" = true ]
    then
        echo "[*] RUNNING AMASS..."
        amass enum --passive -d "$DOMAIN" -o "domains-$DOMAIN.txt"
        notify "Amass completed! Identified *$(wc -l < "domains-$DOMAIN.txt")* subdomains. Checking for live hosts with HTTPX..."
    else
        echo "[-] SKIPPING AMASS"
    fi

    if [ ! -f "livedomains-$DOMAIN.txt" ] || [ "$overwrite" = true ]
    then
        echo "[*] RUNNING HTTPX..."
        httpx -silent -no-color -l "domains-$DOMAIN.txt" -title -content-length -web-server -status-code -ports 80,8080,443,8443 -threads 25 -o "httpx-$DOMAIN.txt"
        cut -d' ' -f1 < "httpx-$DOMAIN.txt" | sort -u > "livedomains-$DOMAIN.txt"
        notify "HTTPX completed. *$(wc -l < "livedomains-$DOMAIN.txt")* endpoints seem to be alive. Checking for hijackable subdomains with SubJack..."
    else
        echo "[-] SKIPPING HTTPX"
    fi

    if [ ! -f "subjack-$DOMAIN.txt" ] || [ "$overwrite" = true ]
    then
        echo "[*] RUNNING SUBJACK..."
        # Manually find 'fingerprints.json' file, as it somehow cannot find it after installing through Docker.
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
    else
        echo "[-] SKIPPING SUBJACK"
    fi

    if [ ! -d "webscreenshot" ] || [ "$overwrite" = true ]
    then
        echo "[*] RUNNING WEBSCREENSHOT..."
        webscreenshot -i "livedomains-$DOMAIN.txt" -o webscreenshot --no-error-file
        notify "WebScreenshot completed! Took *$(find webscreenshot/* -maxdepth 0 | wc -l)* screenshots. Getting Wayback Machine path list with GAU..."
    else
        echo "[-] SKIPPING WEBSCREENSHOT"
    fi

    if [ ! -f "WayBack-$DOMAIN.txt" ] || [ "$overwrite" = true ]
    then
        echo "[*] RUNNING GAU..."
        # Get ONLY Wayback URLs with parameters to prevent clutter
        gau -subs -providers wayback -o "gau-$DOMAIN.txt" "$DOMAIN"
        grep '?' < "gau-$DOMAIN.txt" | qsreplace -a > "WayBack-$DOMAIN.txt"
        rm "gau-$DOMAIN.txt"
        notify "GAU completed. Got *$(wc -l < "WayBack-$DOMAIN.txt")* paths."
    else
        echo "[-] SKIPPING GAU"
    fi

    if [ "$thorough" = true ] ; then
        if [ ! -f "nuclei-$DOMAIN.txt" ] || [ "$overwrite" = true ]
        then
            
            if [ -z "$collabID" ]
            then
                echo "[*] RUNNING NUCLEI (COLLABORATOR DISABLED)..."
                notify "Detecting known vulnerabilities with Nuclei (collaborator disabled)..."
                nuclei -c 150 -l "livedomains-$DOMAIN.txt" -t "$toolsDir"'/nuclei-templates/' -severity low,medium,high,critical -o "nuclei-$DOMAIN.txt"
            else
                echo "[*] RUNNING NUCLEI (COLLABORATOR ENABLED)..."
                notify "Detecting known vulnerabilities with Nuclei (collaborator enabled)..."
                nuclei -c 150 -l "livedomains-$DOMAIN.txt" -t "$toolsDir"'/nuclei-templates/' -severity low,medium,high,critical -o "nuclei-$DOMAIN.txt" -burp-collaborator-biid "$collabID"
            fi
            
            highIssues="$(grep -c 'high' < "nuclei-$DOMAIN.txt")"
            critIssues="$(grep -c 'critical' < "nuclei-$DOMAIN.txt")"
            if [ "$critIssues" -gt 0 ]
            then
                notify "Nuclei completed. Found *$(wc -l < "nuclei-$DOMAIN.txt")* (potential) issues, of which *$critIssues* are critical, and *$highIssues* are high severity. Spidering paths with GoSpider..."
            elif [ "$highIssues" -gt 0 ]
            then
                notify "Nuclei completed. Found *$(wc -l < "nuclei-$DOMAIN.txt")* (potential) issues, of which *$highIssues* are high severity. Spidering paths with GoSpider..."
            else
                notify "Nuclei completed. Found *$(wc -l < "nuclei-$DOMAIN.txt")* (potential) issues, of which none are critical or high severity. Spidering paths with GoSpider..."
            fi
        else
            echo "[-] SKIPPING NUCLEI"
        fi

        if [ ! -f "paths-$DOMAIN.txt" ] || [ "$overwrite" = true ]
        then
            echo "[*] RUNNING GOSPIDER..."
            # Spider for unique URLs, filter duplicate parameters
            gospider -S "livedomains-$DOMAIN.txt" -o GoSpider -t 2 -c 5 -d 3 --blacklist jpg,jpeg,gif,css,tif,tiff,png,ttf,woff,woff2,ico,svg
            cat GoSpider/* | grep -o -E "(([a-zA-Z][a-zA-Z0-9+-.]*\:\/\/)|mailto|data\:)([a-zA-Z0-9\.\&\/\?\:@\+-\_=#%;,])*" | sort -u | qsreplace -a | grep "$DOMAIN" > "tmp-GoSpider-$DOMAIN.txt"
            rm -rf GoSpider
            notify "GoSpider completed. Crawled *$(wc -l < "tmp-GoSpider-$DOMAIN.txt")* endpoints. Getting interesting endpoints and parameters..."

            ## Enrich GoSpider list with parameters from GAU/WayBack. Disregard new GAU endpoints to prevent clogging with unreachable endpoints (See Issue #24).
            # Get only endpoints from GoSpider list (assumed to be live), disregard parameters, and append ? for grepping
            sed "s/\?.*//" "tmp-GoSpider-$DOMAIN.txt" | sort -u | sed -e 's/$/\?/' > "tmp-LivePathsQuery-$DOMAIN.txt"
            # Find common endpoints containing (hopefully new and interesting) parameters from GAU/Wayback list
            grep -f "tmp-LivePathsQuery-$DOMAIN.txt" "WayBack-$DOMAIN.txt" > "tmp-LiveWayBack-$DOMAIN.txt"
            # Merge new parameters with GoSpider list and get only unique endpoints
            cat "tmp-LiveWayBack-$DOMAIN.txt" "tmp-GoSpider-$DOMAIN.txt" | sort -u | qsreplace -a > "paths-$DOMAIN.txt"
            rm "tmp-LivePathsQuery-$DOMAIN.txt" "tmp-LiveWayBack-$DOMAIN.txt" "tmp-GoSpider-$DOMAIN.txt"
        else
            echo "[-] SKIPPING GOSPIDER"
        fi

        if [ ! -d "check-manually" ] || [ "$overwrite" = true ]
        then
            echo "[*] GETTING INTERESTING PARAMETERS WITH GF..."
            mkdir "check-manually"
            gf ssrf < "paths-$DOMAIN.txt" > "check-manually/server-side-request-forgery.txt"
            gf xss < "paths-$DOMAIN.txt" > "check-manually/cross-site-scripting.txt"
            gf redirect < "paths-$DOMAIN.txt" > "check-manually/open-redirect.txt"
            gf rce < "paths-$DOMAIN.txt" > "check-manually/rce.txt"
            gf idor < "paths-$DOMAIN.txt" > "check-manually/insecure-direct-object-reference.txt"
            gf sqli < "paths-$DOMAIN.txt" > "check-manually/sql-injection.txt"
            gf lfi < "paths-$DOMAIN.txt" > "check-manually/local-file-inclusion.txt"
            gf ssti < "paths-$DOMAIN.txt" > "check-manually/server-side-template-injection.txt"
            notify "Done! Gathered a total of *$(wc -l < "paths-$DOMAIN.txt")* paths, of which *$(cat check-manually/* | wc -l)* possibly exploitable. Testing for Server-Side Template Injection..."
        else
            echo "[-] SKIPPING GF"
        fi

        if [ ! -f "potential-ssti.txt" ] || [ "$overwrite" = true ]
        then
            echo "[*] TESTING FOR SSTI..."
            qsreplace "BugBountyScanner{{9*9}}" < "check-manually/server-side-template-injection.txt" | \
            xargs -I % -P 100 sh -c 'curl -s "%" 2>&1 | grep -q "BugBountyScanner81" && echo "[+] Found endpoint likely to be vulnerable to SSTI: %" && echo "%" >> potential-ssti.txt'
            if [ -f "potential-ssti.txt" ]; then
                notify "Identified *$(wc -l < potential-ssti.txt)* endpoints potentially vulnerable to SSTI! Testing for Local File Inclusion..."
            else
                notify "No SSTI found. Testing for Local File Inclusion..."
            fi
        else
            echo "[-] SKIPPING TEST FOR SSTI"
        fi

        if [ ! -f "potential-lfi.txt" ] || [ "$overwrite" = true ]
        then
            echo "[*] TESTING FOR (*NIX) LFI..."
            qsreplace "/etc/passwd" < "check-manually/local-file-inclusion.txt" | \
            xargs -I % -P 100 sh -c 'curl -s "%" 2>&1 | grep -q "root:x:" && echo "[+] Found endpoint likely to be vulnerable to LFI: %" && echo "%" >> potential-lfi.txt'
            if [ -f "potential-lfi.txt" ]; then
                notify "Identified *$(wc -l < potential-lfi.txt)* endpoints potentially vulnerable to LFI! Testing for Open Redirections..."
            else
                notify "No LFI found. Testing for Open Redirections..."
            fi
        else
            echo "[-] SKIPPING TEST FOR (*NIX) LFI"
        fi

        if [ ! -f "potential-or.txt" ] || [ "$overwrite" = true ]
        then
            echo "[*] TESTING FOR OPEN REDIRECTS..."
            qsreplace "https://www.testing123.com" < "check-manually/open-redirect.txt" | \
            xargs -I % -P 100 sh -c 'curl -s "%" 2>&1 | grep -q "Location: https://www.testing123.com" && echo "[+] Found endpoint likely to be vulnerable to OR: %" && echo "%" >> potential-or.txt'
            if [ -f "potential-or.txt" ]; then
                notify "Identified *$(wc -l < potential-or.txt)* endpoints potentially vulnerable to open redirects! Resolving IP Addresses..."
            else
                notify "No open redirects found. Resolving IP Addresses..."
            fi
        else
            echo "[-] SKIPPING TEST FOR OPEN REDIRECTS"
        fi

        if [ ! -f "ip-addresses-$DOMAIN.txt" ] || [ "$overwrite" = true ]
        then
            echo "[*] RESOLVING IP ADDRESSES FROM HOSTS..."
            while read -r hostname; do
                dig "$hostname" +short >> "dig.txt"
            done < "domains-$DOMAIN.txt"
            grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' "dig.txt" | sort -u > "ip-addresses-$DOMAIN.txt" && rm "dig.txt"
            notify "Resolving done! Starting Nmap for *$(wc -l < "ip-addresses-$DOMAIN.txt")* IP addresses..."
        else
            echo "[-] SKIPPING RESOLVING HOST IP ADDRESSES"
        fi

        if [ ! -d "nmap" ] || [ "$overwrite" = true ]
        then
            echo "[*] RUNNING NMAP (TOP 1000 TCP)..."
            mkdir nmap
            nmap -T4 --open --source-port 53 --max-retries 3 --host-timeout 15m -iL "ip-addresses-$DOMAIN.txt" -oA nmap/nmap-tcp
            grep Port < nmap/nmap-tcp.gnmap | cut -d' ' -f2 | sort -u > nmap/tcpips.txt
            notify "Nmap TCP done! Identified *$(grep -c "Port" < "nmap/nmap-tcp.gnmap")* IPs with ports open. Starting Nmap UDP/SNMP scan for *$(wc -l < "nmap/tcpips.txt")* IP addresses..."

            echo "[*] RUNNING NMAP (SNMP UDP)..."
            nmap -T4 -sU -sV -p 161 --open --source-port 53 -iL nmap/tcpips.txt -oA nmap/nmap-161udp
            rm nmap/tcpips.txt
            notify "Nmap UDP done! Identified *$(grep "Port" < "nmap/nmap-161udp.gnmap" | grep -cv "filtered")* IPS with SNMP port open."
        else
            echo "[-] SKIPPING NMAP"
        fi
    fi

    cd ..
    echo "[+] DONE SCANNING $DOMAIN."
    notify "Recon on $DOMAIN finished."

done

echo "[+] DONE! :D"
notify "Recon finished! Go hack em!"