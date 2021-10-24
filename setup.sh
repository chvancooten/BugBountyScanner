#!/bin/bash
## Automated Bug Bounty recon script dependency installer
## By Cas van Cooten

if [ "$EUID" -ne 0 ]
then
  echo "[-] Installation requires elevated privileges, please run as root"
  echo "[*] Running 'sudo $0' will install for current user"
  echo "[*] Running 'sudo su; $0' will install for root user"
  exit 1
fi

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
        echo ""
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
echo "[!] NOTE: INSTALLATION HAS BEEN TESTED ON UBUNTU ONLY. RESULTS MAY VARY FOR OTHER DISTRIBUTIONS."

baseDir=$PWD
username="$(logname 2>/dev/null || echo root)"
homeDir=$(eval echo "~$username")

mkdir -p "$toolsDir"
cd "$toolsDir" || { echo "Something went wrong"; exit 1; }

# Various apt packages
echo "[*] Running apt update and installing apt-based packages, this may take a while..."
apt-get update >/dev/null
apt-get install -y phantomjs xvfb dnsutils nmap python3.5 python2 python3-pip curl wget unzip git >/dev/null
rm -rf /var/lib/apt/lists/*

# Webscreenshot
echo "[*] Installing WebScreenshot via pip..."
pip3 install webscreenshot >/dev/null

# Golang
go version &> /dev/null
if [ $? -ne 0 ]; then
    echo "[*] Installing Golang..."
    wget --quiet https://golang.org/dl/go1.17.2.linux-amd64.tar.gz
    tar -xvf go1.17.2.linux-amd64.tar.gz >/dev/null
    rm -rf ./go1.17.2.linux-amd64.tar.gz >/dev/null
    mv go /usr/local 
    export GOROOT="/usr/local/go"
    export GOPATH="$homeDir/go"
    export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin:${PATH}"
else
    echo "[*] Skipping Golang install, already installed."
    echo "[!] Note: This may cause errors. If it does, check your Golang version and settings."
fi

# Go packages
echo "[*] Installing various Go packages..."
export GO111MODULE="on"
go get -u github.com/lc/gau &>/dev/null
go get -u github.com/tomnomnom/gf &>/dev/null
go get -u github.com/jaeles-project/gospider &>/dev/null
go get -u github.com/tomnomnom/qsreplace &>/dev/null
go get -u github.com/haccer/subjack &>/dev/null
go get -u github.com/projectdiscovery/nuclei/v2/cmd/nuclei &>/dev/null
go get -u github.com/OJ/gobuster &>/dev/null

# Subjack fingerprints file
echo "[*] Installing Subjack fingerprints..."
mkdir "$toolsDir/subjack"
wget https://raw.githubusercontent.com/haccer/subjack/master/fingerprints.json -O $toolsDir/subjack/fingerprints.json -q

# GoBuster temporary files wordlist
echo "[*] Installing GoBuster wordlist..."
mkdir "$toolsDir/wordlists"
wget https://raw.githubusercontent.com/Bo0oM/fuzz.txt/master/fuzz.txt -O $toolsDir/wordlists/tempfiles.txt -q

# HTTPX
echo "[*] Installing HTTPX..."
wget https://github.com/projectdiscovery/httpx/releases/download/v1.0.3/httpx_1.0.3_linux_amd64.tar.gz -q
tar xvf httpx_1.0.3_linux_amd64.tar.gz -C /usr/bin/ httpx >/dev/null
rm httpx_1.0.3_linux_amd64.tar.gz

# Amass
echo "[*] Installing Amass..."
wget https://github.com/OWASP/Amass/releases/download/v3.11.0/amass_linux_amd64.zip -q
unzip -q amass_linux_amd64.zip
mv amass_linux_amd64 amass
rm amass_linux_amd64.zip
cp $toolsDir/amass/amass /usr/bin/amass

# Nuclei-templates
echo "[*] Installing Nuclei-templates..."
git clone -q https://github.com/projectdiscovery/nuclei-templates.git
# remove basic auth (and possible future) bruteforcing template(s) because we don't want that >:[
find nuclei-templates/ -name "*brute*" -type f -exec rm -rf {} \;

# Gf-patterns
echo "[*] Installing Gf-patterns..."
git clone -q https://github.com/1ndianl33t/Gf-Patterns
mkdir "$homeDir"/.gf
cp "$toolsDir"/Gf-Patterns/*.json "$homeDir"/.gf

# Persist configured environment variables via global profile.d script
echo "[*] Setting environment variables..."
if [ -f "$homeDir"/.bashrc ]
then
    { echo "export GOROOT=/usr/local/go";
    echo "export GOPATH=$homeDir/go";
    echo 'export PATH=$PATH:$GOPATH/bin:$GOROOT/bin';
    echo "export GO111MODULE=on"; } >> "$homeDir"/.bashrc
fi

if [ -f "$homeDir"/.zshrc ]
then
    { echo "export GOROOT=/usr/local/go";
    echo "export GOPATH=$homeDir/go";
    echo 'export PATH=$PATH:$GOPATH/bin:$GOROOT/bin';
    echo "export GO111MODULE=on"; } >> "$homeDir"/.zshrc
fi

# Cleanup
apt remove unzip -y &>/dev/null
cd "$baseDir" || { echo "Something went wrong"; exit 1; }

echo "[*] SETUP FINISHED."
exit 0