FROM ubuntu:20.04

LABEL maintainer="Cas van Cooten"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /root

RUN apt-get update >/dev/null && \
    apt-get install -y \
    phantomjs \
    xvfb \
    dnsutils \
    nmap \
    python3.5 \
    python2 \
    python3-pip \
    curl \
    wget \
    unzip \
    git >/dev/null \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install webscreenshot >/dev/null

RUN cd /opt && \
    wget --quiet https://dl.google.com/go/go1.14.7.linux-amd64.tar.gz && \
    tar -xvf go1.14.7.linux-amd64.tar.gz >/dev/null && \
    rm -rf /opt/go1.14.7.linux-amd64.tar.gz >/dev/null && \
    mv go /usr/local 
ENV GOROOT /usr/local/go
ENV GOPATH /root/go
ENV PATH ${GOPATH}/bin:${GOROOT}/bin:${PATH}

ENV GO111MODULE on
RUN go get -u github.com/lc/gau >/dev/null
RUN go get -u github.com/tomnomnom/gf >/dev/null
RUN go get -u github.com/jaeles-project/gospider >/dev/null
#RUN go get -u github.com/projectdiscovery/httpx/cmd/httpx >/dev/null
RUN go get -u github.com/tomnomnom/qsreplace >/dev/null
RUN go get -u github.com/haccer/subjack >/dev/null
RUN go get -u github.com/projectdiscovery/nuclei/v2/cmd/nuclei >/dev/null

RUN wget https://github.com/projectdiscovery/httpx/releases/download/v1.0.1/httpx_1.0.1_linux_amd64.tar.gz -q && \
    tar xvf httpx_1.0.1_linux_amd64.tar.gz -C /usr/bin/ httpx && \
    rm httpx_1.0.1_linux_amd64.tar.gz

RUN cd /opt && \
    wget https://github.com/OWASP/Amass/releases/download/v3.10.5/amass_linux_amd64.zip -q && \
    unzip -q amass_linux_amd64.zip && \
    mv amass_linux_amd64 amass && \
    rm amass_linux_amd64.zip && \
    cp /opt/amass/amass /usr/bin/amass

RUN cd /opt && \
    git clone -q https://github.com/projectdiscovery/nuclei-templates.git

RUN cd /opt && \
    git clone -q https://github.com/1ndianl33t/Gf-Patterns && \
    mkdir ${HOME}/.gf && \
    cp /opt/Gf-Patterns/*.json ${HOME}/.gf

RUN apt remove unzip -y &>/dev/null

COPY ./BugBountyScanner.sh /root
COPY ./.env.example /root
RUN chmod +x /root/BugBountyScanner.sh