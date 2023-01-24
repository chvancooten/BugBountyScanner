# BugBountyScanner

[![GitHub Workflow Status](https://img.shields.io/github/workflow/status/chvancooten/bugbountyscanner/Docker%20Build)](https://github.com/chvancooten/BugBountyScanner/actions)
[![Docker Pulls Badge](https://img.shields.io/docker/pulls/chvancooten/bugbountyscanner)](https://hub.docker.com/r/chvancooten/bugbountyscanner/)
[![Docker Automated Badge](https://img.shields.io/docker/cloud/automated/chvancooten/bugbountyscanner)](https://hub.docker.com/r/chvancooten/bugbountyscanner/)
[![Docker Image Size Badge](https://img.shields.io/docker/image-size/chvancooten/bugbountyscanner)](https://hub.docker.com/r/chvancooten/bugbountyscanner/)
[![PRs Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)](http://makeapullrequest.com)

# AMAN T. WAS HERE

A Bash script and Docker image for Bug Bounty reconnaissance, intended for headless use. Low on resources, high on information output.

Helpful? BugBountyScanner helped you net a bounty?

[![Docker Image Size Badge](https://img.shields.io/badge/%F0%9F%8D%BA-Buy%20me%20a%20beer-orange)](https://www.buymeacoffee.com/chvancooten)

## Description

> ⚠ Note: Using the script over a VPN is highly recommended.

It's recommended to run BugBountyScanner from a server (VPS or home server), and _not_ from your terminal. It is programmed to be low on resources, with potentially multiple days of scanning in mind for bigger scopes. The script functions on a stand-alone basis.

You can run the script either as a docker image or from your preferred Debian/Ubuntu system (see below). All that is required is kicking off the script and forgetting all about it! Running the script takes anywhere in between several minutes (for very small scopes < 10 subdomains) and several days (for very large scopes > 20000 subdomains). A 'quick mode' flag is present, which drops some time-consuming tasks such as vulnerability identification, port scanning, and web endpoint crawling.

## Installation

### Docker

Docker Hub Link: https://hub.docker.com/r/chvancooten/bugbountyscanner. Images are pushed to the `:latest` tag whenever an update to BugBountyScanner is pushed. Poke me if I forget, Docker Hub nuked automatic builds :(.

You can pull the Docker image from Docker Hub as below.

```
docker pull chvancooten/bugbountyscanner
docker run -it chvancooten/bugbountyscanner /bin/bash
```

Docker-Compose can also be used.

```
version: "3"
services:
  bugbountybox:
    container_name: BugBountyBox
    stdin_open: true
    tty: true
    image: chvancooten/bugbountyscanner:latest
    environment:
    - telegram_api_key=X
    - telegram_chat_id=X
    volumes:
      - ${USERDIR}/docker/bugbountybox:/root/bugbounty
    # VPN recommended :)
    network_mode: service:your_vpn_container
    depends_on:
      - your_vpn_container
```

Alternatively, you can build the image from source.

```
git clone https://github.com/chvancooten/BugBountyScanner.git
cd BugBountyScanner
docker build .
```

### Manual

If you prefer running the script manually, you can do so.

> ℹ Note: The script has been built on -and tested for- Ubuntu 20.04. Your mileage may vary with other distro's, but it should work on most Debian-based installs (such as Kali Linux).

```
git clone https://github.com/chvancooten/BugBountyScanner.git
cd BugBountyScanner
cp .env.example .env # Edit accordingly
chmod +x BugBountyScanner.sh setup.sh
./setup.sh -t /custom/tools/dir # Setup is automatically triggered, but can be manually run
./BugBountyScanner.sh --help
./BugBountyScanner.sh -d target1.com -d target2.net -t /custom/tools/dir --quick
```

## Usage

Use `--help` or `-h` for a brief help menu.

```
root@dockerhost:~# ./BugBountyScanner.sh -h
BugBountyHunter - Automated Bug Bounty reconnaissance script
 
./BugBountyScanner.sh [options]
 
options:
-h, --help                show brief help
-t, --toolsdir            tools directory (no trailing /), defaults to '/opt'
-q, --quick               perform quick recon only (default: false)
-d, --domain <domain>     top domain to scan, can take multiple
-o, --outputdirectory     parent output directory, defaults to current directory (subfolders will be created per domain)
-w, --overwrite           overwrite existing files. Skip steps with existing files if not provided (default: false)
 
Note: 'ToolsDir', 'telegram_api_key' and 'telegram_chat_id' can be defined in .env or through Docker environment variables.
 
example:
./BugBountyScanner.sh --quick -d google.com -d uber.com -t /opt
```

## Features

- Resource-efficient, suitable for running in the background for a prolonged period of time on a low-resource VPS, home server, or Raspberry Pi
- Telegram status notifications with per-command results
- Extensive CVE and misconfiguration detection with Nuclei (no intrusive or informational checks)
- Subdomain enumeration and live webserver detection
- Web screenshotting and crawling, HTML screenshot report generation
- Retrieving (hopefully sensitive) endpoints from the Wayback Machine
- Identification of interesting parameterized URLs with Gf
- Enumeration of common "temporary" and forgotten files with GoBuster
- Automatic detection of LFI, SSTI, and Open Redirects in URL parameters
- Subdomain takeover detection
- Port scanning (Top 1000 TCP + SNMP)
- 'Quick Mode' for opsec-safe (ish) infrastructure reconnaissance

## Tools

- `amass`
- `dnsutils`
- `Go`
- `gau`
- `Gf` (with `Gf-Patterns`)
- `GoBuster`
- `gospider`
- `httpx`
- `nmap`
- `Nuclei` (with `Nuclei-Templates`)
- `qsreplace`
- `subjack`
- `webscreenshot`
