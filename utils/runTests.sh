#!/bin/bash
### CURRENTLY NOT IN USE DUE TO INCOMPATIBILITY WITH GIHUB CI
# Test script to validate the correctness of Dockerized Github CI builds

echo "ENVIRONMENT:"
env

# Validate correct installation of key tools
# Golang
go version &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error - Go not (properly) installed"
    exit 1
fi

# Amass
amass -version &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error - Amass not (properly) installed"
    exit 1
fi

# HTTPX
httpx -version &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error - HTTPX not (properly) installed"
    exit 1
fi

# Subjack
subjack | grep -q "Usage of"
if [ $? -ne 0 ]; then
    echo "Error - Subjack not (properly) installed"
    exit 1
fi

# Webscreenshot
webscreenshot -h &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error - Webscreenshot not (properly) installed"
    exit 1
fi

# GAU
gau -version &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error - GAU not (properly) installed"
    exit 1
fi

# Nuclei
nuclei -version &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error - Nuclei not (properly) installed"
    exit 1
fi

# GoBuster
gobuster -h &> /dev/null
if [ $? -ne 2 ]; then
    echo "Error - GoBuster not (properly) installed"
    exit 1
fi

# GoSpider
gospider --version &> /dev/null 
if [ $? -ne 0 ]; then
    echo "Error - GoSpider not (properly) installed"
    exit 1
fi

# GF
gf -h &> /dev/null
if [ $? -ne 2 ]; then
    echo "Error - GF not (properly) installed"
    exit 1
fi

# Dig
dig -v &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error - Dig not (properly) installed"
    exit 1
fi

# Nmap
nmap -V &> /dev/null
if [ $? -ne 0 ]; then
    echo "Error - Nmap not (properly) installed"
    exit 1
fi

echo "All good!"
exit 0