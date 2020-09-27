# BugBountyScanner

[![Docker Build Badge](https://img.shields.io/docker/cloud/build/chvancooten/bugbountyscanner)](https://hub.docker.com/r/chvancooten/bugbountyscanner/)
[![Docker Automated Badge](https://img.shields.io/docker/cloud/automated/chvancooten/bugbountyscanner)](https://hub.docker.com/r/chvancooten/bugbountyscanner/)
[![Docker Image Size Badge](https://img.shields.io/docker/image-size/chvancooten/bugbountyscanner)](https://hub.docker.com/r/chvancooten/bugbountyscanner/)
[![Docker Pulls Badge](https://img.shields.io/docker/pulls/chvancooten/bugbountyscanner)](https://hub.docker.com/r/chvancooten/bugbountyscanner/)

A simple Bash script for Bug Bounty reconnaissance, intended for headless use. Low on resources, high on information output.

## Description

> ⚠ Note: Using the script over a VPN is highly recommended.

It's recommended to run BugBountyScanner from a server (VPS or home server), and _not_ from your terminal. It is programmed to be low on resources, with potentially multiple days of scanning in mind for bigger scopes. The script functions on a stand-alone basis.

You can run the script either as a docker image or from your preferred Debian/Ubuntu system (see below). All that is required is kicking off the script and forgetting all about it! Running the script takes anywhere in between several minutes (for very small scopes < 10 subdomains) and several days (for very large scopes > 20000 subdomains). A 'thorough mode' flag is present, which includes some time-consuming tasks such as port scanning and subdomain crawling.

## Installation

### Docker

Docker Hub Link: https://hub.docker.com/r/chvancooten/bugbountyscanner.

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

```
git clone https://github.com/chvancooten/BugBountyScanner.git
cd BugBountyScanner
cp .env.example .env
# Edit accordingly
chmod +x BugBountyScanner.sh
# Setup is automatically triggered, but can be manually run
chmod +x setup.sh
./setup.sh -t /custom/tools/dir
./BugBountyScanner.sh --help
./BugBountyScanner.sh -d target1.com -d target2.net -t /custom/tools/dir --quick
```

## Features

- Resource-efficient, suitable for running in the background for a prolonged period of time on e.g. a home server or Raspberry Pi
- Telegram status notifications
- Extensive CVE and misconfiguration detection with Nuclei
- Subdomain enumeration and live webserver detection
- Web screenshotting and crawling
- Retrieving (hopefully sensitive) endpoints from the Wayback Machine
- Identification of interesting parameterized URLs with Gf
- Subdomain takeover detection
- Port scanning (Top 1000 TCP + SNMP)

## Tools

- `amass`
- `dnsutils`
- `Go`
- `gau`
- `Gf` (with `Gf-Patterns`)
- `gospider`
- `httpx`
- `nmap`
- `Nuclei` (with `Nuclei-Templates`)
- `qsreplace`
- `subjack`
- `webscreenshot`
