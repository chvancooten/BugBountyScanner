#!/bin/bash
## Automated Bug Bounty recon script dependency installer
## By Cas van Cooten

### NOTE: This installation script is deprecated by the implementation of the Dockerfile. Not all dependencies may automatically work.

for arg in "$@"
do
    case $arg in
        -h|--help)
        echo "BugBountyHunter Dependency Installer"
        echo " "
        echo "$0 [options]"
        echo " "
        echo "options:"
        echo "-h, --help                show brief help"
        echo "-t, --toolsdir            tools directory, defaults to '/opt'"
        echo ""
        echo "Note: If you choose a non-default tools directory, please adapt the default in the BugBountyAutomator.sh file or pass the -t flag to ensure it finds the right tools."
        echo " "
        echo "example:"
        echo "$0 -t /opt"
        exit 0
        ;;
        -t|--toolsdir)
        toolsDir="$2"
        shift
        shift
        ;;
    esac
done

if [ -z "$toolsDir" ]
then
    toolsDir="/opt"
fi

echo "[*] INSTALLING DEPENDENCIES IN \"$toolsDir\"..."

mkdir -p "$toolsDir"

apt update -y 
apt install -y phantomjs xvfb dnsutils nmap
pip install webscreenshot

echo "[*] UPDATING GOLANG, MAY TAKE A WHILE.."
curl "https://raw.githubusercontent.com/udhos/update-golang/master/update-golang.sh" | bash &> /dev/null

echo "[*] INSTALLING GO DEPENDENCIES (OUTPUT MAY FREEZE)..."
go get -u github.com/lc/gau
go get -u github.com/tomnomnom/gf
go get -u github.com/jaeles-project/gospider
go get -u github.com/projectdiscovery/httpx/cmd/httpx
go get -u github.com/tomnomnom/qsreplace
go get -u github.com/haccer/subjack
export GO111MODULE=on && go get -u github.com/OWASP/Amass/v3/...

echo "[*] INSTALLING GIT DEPENDENCIES..."
### Nuclei (Workaround -https://github.com/projectdiscovery/nuclei/issues/291)
cd "$toolsDir" || { echo "Something went wrong"; exit 1; }
git clone -q https://github.com/projectdiscovery/nuclei.git 
cd nuclei/v2/cmd/nuclei/ || { echo "Something went wrong"; exit 1; }
go build
mv nuclei /usr/local/bin/

### Nuclei templates
cd "$toolsDir" || { echo "Something went wrong"; exit 1; }
git clone -q https://github.com/projectdiscovery/nuclei-templates.git

### Gf-Patterns
cd "$toolsDir" || { echo "Something went wrong"; exit 1; }
git clone -q https://github.com/1ndianl33t/Gf-Patterns
mkdir ~/.gf
cp "$toolsDir"/Gf-Patterns/*.json ~/.gf

echo "[*] SETUP FINISHED."
