FROM ubuntu:20.04

LABEL maintainer="Cas van Cooten"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /root

RUN apt-get update && \
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
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install webscreenshot

RUN cd /opt && \
    wget https://dl.google.com/go/go1.14.7.linux-amd64.tar.gz && \
    tar -xvf go1.14.7.linux-amd64.tar.gz && \
    rm -rf /opt/go1.14.7.linux-amd64.tar.gz && \
    mv go /usr/local 
ENV GOROOT /usr/local/go
ENV GOPATH /root/go
ENV PATH ${GOPATH}/bin:${GOROOT}/bin:${PATH}

RUN go get -u github.com/lc/gau
RUN go get -u github.com/tomnomnom/gf
RUN go get -u github.com/jaeles-project/gospider
RUN go get -u github.com/projectdiscovery/httpx/cmd/httpx
RUN go get -u github.com/tomnomnom/qsreplace
RUN go get -u github.com/haccer/subjack
RUN export GO111MODULE=on \
    && go get -u github.com/OWASP/Amass/v3/...

RUN cd /opt && \
    git clone https://github.com/projectdiscovery/nuclei.git && \
    cd nuclei/cmd/nuclei/ && \
    go build && \
    mv nuclei /usr/local/bin/ && \
    return 0

RUN cd /opt && \
    git clone -q https://github.com/projectdiscovery/nuclei-templates.git

RUN cd /opt && \
    git clone -q https://github.com/1ndianl33t/Gf-Patterns && \
    mkdir ${HOME}/.gf && \
    cp /opt/Gf-Patterns/*.json ${HOME}/.gf

COPY ./BugBountyScanner.sh /root
COPY ./.env.example /root