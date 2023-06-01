FROM ubuntu:22.04

RUN apt-get update
RUN apt-get -y install build-essential libgd-dev libmysqlclient-dev zlib1g zlib1g-dev libexpat1-dev git wget

RUN git clone https://github.com/soylentnews/rehash
RUN cd rehash && make ENVIRONMENT_PREFIX=/srv/soylentnews.org build-environment

