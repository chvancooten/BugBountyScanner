# BugBountyScanner
A simple Bash script for Bug Bounty reconnaissance, intended for headless use. Low on resources, high on information output.

## How to use

> ⚠ Note: Using the script over a VPN is highly recommended.

It's recommended to run BugBountyScanner from a (dedicated) server, and _not_ from your terminal. It is programmed to be low on resources, with potentially multiple days of scanning in mind for bigger scopes. I created the script with the docker image [`hackersploit/bugbountytoolkit`](https://github.com/AlexisAhmed/BugBountyToolkit) in mind, if you use another setup please note the requirements below.

The only required adaptation is including your API key for the [Telegram Bot API](https://core.telegram.org/bots/api) (or adapting the `notify` function to suit your notification needs). After that, all that is required is kicking off the script and forgetting all about it! Running the script takes anywhere in between several minutes (for very small scopes < 10 subdomains) and several days (for very large scopes > 20000 subdomains). A 'thorough mode' flag is present, which includes some time-consuming tasks such as port scanning and subdomain crawling.

```
root@yourhost:~/bugbounty# ./BugBountyAutomator.sh target.com
[?] Create subfolder (no will output files in current folder)? [y/n]: y
[?] Perform thorough scan (not recommended for very big scopes)? [y/n]: y
[*] DEPENDENCIES FOUND. NOT INSTALLING.
[*] Running recon on target.com!
```

### Requirements

- `nmap`
- `amass`
- `Go`

### Requirements installed by script

- `gau`
- `gospider`
- `httpx`
- `qsreplace`
- `subjack`
- `webscreenshot`

## Features

- Resource-efficient, suitable for running in the background for a prolonged period of time on e.g. a home server or Raspberry Pi
- Telegram status notifications
- Subdomain enumeration and live webserver detection
- Web screenshotting and spidering
- Retrieving (hopefully sensitive) endpoints from the Wayback Machine
- Subdomain hijacking detection
- Basic SQL injection detection
- Detection of .git folders
- Detection of Telerik endpoints (often vulnerable 😁)
- Port scanning (Top 1000 TCP + SNMP)

## To-do

- [ ] Automatically install all requirements
- [ ] Implement additional vulnerability checks (please reach out if you have any suggestions!)
    - [ ] Implement Nuclei for automatic checks
- [ ] Optimize nmap scans

- [x] Implement basic multi-domain support
- [x] Integrate with BurpSuite proxy / active scan

  - **Won't fix:** Would introduce too many dependencies and reduce ease of use. As a solution I have included a script that sends the crawled scope (or any list of endpoints)       through the burp proxy for manual passive/active crawling.
