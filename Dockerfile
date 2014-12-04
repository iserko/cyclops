FROM ubuntu:trusty

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install git curl libcurl4-openssl-dev build-essential && \
    apt-get -y install python-dev python-pip python-virtualenv

WORKDIR /opt
RUN git clone -b proxy_and_host_header_fixes https://github.com/iserko/cyclops.git

WORKDIR /opt/cyclops
RUN virtualenv venv && \
    . venv/bin/activate && \
    venv/bin/python setup.py install

ADD ./cyclops.conf /opt/cyclops/cyclops.conf

EXPOSE 9000
