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
    git >/dev/null \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install webscreenshot

RUN cd /opt && \
    wget https://dl.google.com/go/go1.14.7.linux-amd64.tar.gz >/dev/null && \
    tar -xvf go1.14.7.linux-amd64.tar.gz >/dev/null && \
    rm -rf /opt/go1.14.7.linux-amd64.tar.gz >/dev/null && \
    mv go /usr/local 
ENV GOROOT /usr/local/go
ENV GOPATH /root/go
ENV PATH ${GOPATH}/bin:${GOROOT}/bin:${PATH}

RUN export GO111MODULE=on \
    && go get -u github.com/OWASP/Amass/v3/...
RUN go get -u github.com/lc/gau >/dev/null
RUN go get -u github.com/tomnomnom/gf >/dev/null
RUN go get -u github.com/jaeles-project/gospider >/dev/null
RUN go get -u github.com/projectdiscovery/httpx/cmd/httpx >/dev/null
RUN go get -u github.com/tomnomnom/qsreplace >/dev/null
RUN go get -u github.com/haccer/subjack >/dev/null

RUN cd /opt && \
    git clone https://github.com/projectdiscovery/nuclei.git >/dev/null && \
    cd nuclei/v2/cmd/nuclei/ && \
    go build >/dev/null && \
    mv nuclei /usr/local/bin/ && \
    return 0

RUN cd /opt && \
    git clone -q https://github.com/projectdiscovery/nuclei-templates.git >/dev/null

RUN cd /opt && \
    git clone -q https://github.com/1ndianl33t/Gf-Patterns >/dev/null && \
    mkdir ${HOME}/.gf && \
    cp /opt/Gf-Patterns/*.json ${HOME}/.gf

COPY ./BugBountyScanner.sh /root
COPY ./.env.example /root
RUN chmod +x /root/BugBountyScanner.sh