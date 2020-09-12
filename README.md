# BugBountyScanner
A simple Bash script for Bug Bounty reconnaissance, intended for headless use. Low on resources, high on information output.

## How to use

> ⚠ Note: Using the script over a VPN is highly recommended.

It's recommended to run BugBountyScanner from a server (VPS or home server), and _not_ from your terminal. It is programmed to be low on resources, with potentially multiple days of scanning in mind for bigger scopes. I created the script with the docker image [`hackersploit/bugbountytoolkit`](https://github.com/AlexisAhmed/BugBountyToolkit) in mind, if you use another setup please note the requirements below.

The only required adaptation is including your API key for the [Telegram Bot API](https://core.telegram.org/bots/api) (or adapting the `notify` function to suit your notification needs). After that, all that is required is kicking off the script and forgetting all about it! Running the script takes anywhere in between several minutes (for very small scopes < 10 subdomains) and several days (for very large scopes > 20000 subdomains). A 'thorough mode' flag is present, which includes some time-consuming tasks such as port scanning and subdomain crawling.

```
root@yourhost:~/bugbounty# ./BugBountyAutomator.sh target1.com,target2.com
[?] Perform quick scan (recon only)? [y/N]: n
[*] DEPENDENCIES FOUND. NOT INSTALLING.
[*] Running recon on target1.com!
```

### Requirements

- `nmap`
- `amass`

### Requirements installed by script

- `Go`
- `gau`
- `Gf` (with `Gf-Patterns`)
- `gospider`
- `httpx`
- `Nuclei` (with `Nuclei-Templates`)
- `qsreplace`
- `subjack`
- `webscreenshot`

## Features

- Resource-efficient, suitable for running in the background for a prolonged period of time on e.g. a home server or Raspberry Pi
- Telegram status notifications
- Extensive CVE and misconfiguration detection with Nuclei
- Subdomain enumeration and live webserver detection
- Web screenshotting and spidering
- Retrieving (hopefully sensitive) endpoints from the Wayback Machine
- Identification of interesting parameterized URLs with Gf
- Subdomain takeover detection
- Port scanning (Top 1000 TCP + SNMP)

## To-do

- [ ] Automatically install all requirements
- [x] Implement additional vulnerability checks (please reach out if you have any suggestions!)
    - [x] Implement Nuclei for automatic checks
- [x] Optimize nmap scans
- [x] Implement basic multi-domain support

- **Won't fix:** Integration with BurpSuite proxy. Would introduce too many dependencies and reduce ease of use. As a solution I have included a script that sends the crawled scope (or any list of endpoints)       through the burp proxy for manual passive/active crawling.
