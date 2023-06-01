# Distribution Version
FROM ubuntu:22.04

# Control variables
ARG REHASH_PREFIX /srv/soylentnews.org

ARG PERL_VERSION=5.20.0
ARG PERL_DOWNLOAD=http://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz

# Install system build dependencies
RUN apt-get update
RUN apt-get -y install build-essential libgd-dev libmysqlclient-dev zlib1g zlib1g-dev libexpat1-dev git wget

# Unminimize the image since Perl's test suite requires it
RUN yes | unminimize

# Build Perl for Rehash
WORKDIR /build
RUN wget ${PERL_DOWNLOAD}
RUN tar zxf perl-${PERL_VERSION}.tar.gz
WORKDIR perl-${PERL_VERSION}

# We need to patch Perl due to bitrot
RUN ls
COPY patches/perl/* .
RUN patch -p1 < 00_fix_libcrypt_build.patch
RUN patch -p1 < 01_fix_errno_test_failure.patch
RUN patch -p1 < 02_fix_time_local.patch
RUN patch -p1 < 03_h2ph_gcc_fix.patch
RUN patch -p1 < 04_h2ph_fix_hex_constants.patch

RUN ./Configure -des -Dprefix=${REHASH_PREFIX} -Duseshrplib -Dusethreads
RUN make -j8
RUN make check
RUN make install

#RUN git clone https://github.com/soylentnews/rehash
#RUN cd rehash && make ENVIRONMENT_PREFIX=/srv/soylentnews.org build-environment
