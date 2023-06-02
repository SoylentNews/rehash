# Distribution Version
FROM ubuntu:22.04

# Control variables
ARG REHASH_REPO=https://github.com/SoylentNews/rehash.git
ARG REHASH_PREFIX=/srv/soylentnews.org
ARG REHASH_ROOT=/srv/soylentnews.org/rehash

ARG PERL_VERSION=5.20.0
ARG PERL_DOWNLOAD=https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz

ARG APACHE_VERSION=2.2.29
ARG APACHE_DOWNLOAD=https://archive.apache.org/dist/httpd/httpd-${APACHE_VERSION}.tar.gz

ARG MOD_PERL_VERSION=2.0.9
#ARG MOD_PERL_DOWNLOAD=https://mirror.cogentco.com/pub/apache/perl/mod_perl-${MOD_PERL_VERSION}.tar.gz
ARG MOD_PERL_DOWNLOAD=https://archive.apache.org/dist/perl/mod_perl-2.0.9.tar.gz

# rehash uses its own Perl, make we need to define that
ENV REHASH_PERL=${REHASH_PREFIX}/perl/bin/perl
ENV REHASH_CPAMN=${REHASH_PREFIX}/perl/bin/cpanm

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

RUN ./Configure -des -Dprefix=${REHASH_PREFIX}/perl -Duseshrplib -Dusethreads
RUN make -j8
#RUN make check
RUN make install

# Build Apache 2.2
WORKDIR /build
RUN wget ${APACHE_DOWNLOAD}
RUN tar zxf httpd-${APACHE_VERSION}.tar.gz
WORKDIR httpd-${APACHE_VERSION}

RUN ./configure --prefix=${REHASH_PREFIX}/apache --enable-mods-shared=most
RUN make
RUN make install

# Build mod_perl
WORKDIR /build
RUN wget ${MOD_PERL_DOWNLOAD}
RUN tar zxf mod_perl-${MOD_PERL_VERSION}.tar.gz
WORKDIR mod_perl-${MOD_PERL_VERSION}

RUN ${REHASH_PERL} Makefile.PL MP_APXS=${REHASH_PREFIX}/apache/bin/apxs
RUN make
RUN make test
RUN make install

# Install CPAN Minus to make scriptable install possible
WORKDIR ${REHASH_PREFIX}
RUN git clone ${REHASH_REPO}
RUN ${REHASH_PERL} ${REHASH_ROOT}/utils/cpanm App::cpanminus
RUN ${REHASH_CPAMN} Apache2::Upload
RUN ${REHASH_CPAMN} Cache::Memcached
RUN ${REHASH_CPAMN} Cache::Memcached::Fast
RUN ${REHASH_CPAMN} Data::JavaScript::Anon
RUN ${REHASH_CPAMN} Date::Calc
RUN ${REHASH_CPAMN} Date::Format
RUN ${REHASH_CPAMN} Date::Parse
RUN ${REHASH_CPAMN} DateTime::Format::MySQL
RUN ${REHASH_CPAMN} DBD::mysql
RUN ${REHASH_CPAMN} Digest::MD5
RUN ${REHASH_CPAMN} GD
RUN ${REHASH_CPAMN} GD::Text::Align
RUN ${REHASH_CPAMN} HTML::Entities
RUN ${REHASH_CPAMN} HTML::FormatText
RUN ${REHASH_CPAMN} HTML::Tagset
RUN ${REHASH_CPAMN} HTML::TokeParser
RUN ${REHASH_CPAMN} HTML::TreeBuilder
RUN ${REHASH_CPAMN} HTTP::Request
RUN ${REHASH_CPAMN} Image::Size
RUN ${REHASH_CPAMN} JavaScript::Minifier
RUN ${REHASH_CPAMN} JSON
RUN ${REHASH_CPAMN} Lingua::Stem
#RUN ${REHASH_CPAMN} LWP::Parallel::UserAgent
#RUN ${REHASH_CPAMN} LWP::UserAgent
RUN ${REHASH_CPAMN} Mail::Address
RUN ${REHASH_CPAMN} Mail::Bulkmail
#RUN ${REHASH_CPAMN} Mail::Sendmail
RUN ${REHASH_CPAMN} MIME::Types
RUN ${REHASH_CPAMN} Mojo::Server::Daemon
RUN ${REHASH_CPAMN} Net::IP
RUN ${REHASH_CPAMN} Net::Server
#RUN ${REHASH_CPAMN} Schedule::Cron
#RUN ${REHASH_CPAMN} SOAP::Lite
RUN ${REHASH_CPAMN} Sphinx::Search
RUN ${REHASH_CPAMN} URI::Encode
RUN ${REHASH_CPAMN} Template
RUN ${REHASH_CPAMN} XML::Parser
RUN ${REHASH_CPAMN} XML::Parser::Expat
RUN ${REHASH_CPAMN} XML::RSS
