FROM ubuntu:20.04

LABEL maintainer="Cas van Cooten"

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY setup.sh /root
COPY BugBountyScanner.sh /root
COPY utils /root/utils
COPY assets /root/assets
COPY .env.example /root

ENV GOROOT=/usr/local/go
ENV GOPATH=/root/go
ENV PATH=$PATH:/root/go/bin:/usr/local/go/bin
ENV GO111MODULE=on

RUN chmod +x /root/BugBountyScanner.sh /root/setup.sh
RUN /root/setup.sh
RUN rm /root/setup.sh