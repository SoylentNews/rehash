# Distribution Version
FROM ubuntu:22.04 AS rehash

# Control variables
ARG REHASH_REPO=https://github.com/SoylentNews/rehash.git
ARG REHASH_PREFIX=/srv/soylentnews.org
ARG REHASH_ROOT=/srv/soylentnews.org/
ARG REHASH_SRC=/build/rehash

# MySQL Database Stuff
ARG MYSQL_HOST=localhost
ARG MYSQL_DATABASE=soylentnews
ARG MYSQL_USER=soylentnews
ARG MYSQL_PASSWORD=soylentnews

ARG PERL_VERSION=5.30.0
ARG PERL_DOWNLOAD=https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz

ARG APACHE_VERSION=2.2.29
ARG APACHE_DOWNLOAD=https://archive.apache.org/dist/httpd/httpd-${APACHE_VERSION}.tar.gz

ARG MOD_PERL_VERSION=2.0.9
#ARG MOD_PERL_DOWNLOAD=https://mirror.cogentco.com/pub/apache/perl/mod_perl-${MOD_PERL_VERSION}.tar.gz
ARG MOD_PERL_DOWNLOAD=https://archive.apache.org/dist/perl/mod_perl-2.0.9.tar.gz

# rehash uses its own Perl, make we need to define that
ENV REHASH_PERL=${REHASH_PREFIX}/perl/bin/perl
ENV REHASH_CPANM=${REHASH_PREFIX}/perl/bin/cpanm

# Open ports
EXPOSE 80

# for ipn
EXPOSE 2626

# Install system build dependencies
RUN apt-get update
RUN apt-get -y install build-essential libgd-dev libmysqlclient-dev zlib1g zlib1g-dev libexpat1-dev git wget

# Unminimize the image since Perl's test suite requires it
RUN yes | unminimize

WORKDIR /build
RUN wget ${PERL_DOWNLOAD}
RUN tar zxf perl-${PERL_VERSION}.tar.gz
WORKDIR /build/perl-${PERL_VERSION}

RUN ./Configure -des -Dprefix=${REHASH_PREFIX}/perl -Duseshrplib -Dusethreads
RUN make -j8
#RUN make check
RUN make install

# Build Apache 2.2
WORKDIR /build
RUN wget ${APACHE_DOWNLOAD}
RUN tar zxf httpd-${APACHE_VERSION}.tar.gz
WORKDIR /build/httpd-${APACHE_VERSION}

RUN ./configure --prefix=${REHASH_PREFIX}/apache --enable-mods-shared=most
RUN make
RUN make install

# Build mod_perl
WORKDIR /build
RUN wget ${MOD_PERL_DOWNLOAD}
RUN tar zxf mod_perl-${MOD_PERL_VERSION}.tar.gz
WORKDIR /build/mod_perl-${MOD_PERL_VERSION}

RUN ${REHASH_PERL} Makefile.PL MP_APXS=${REHASH_PREFIX}/apache/bin/apxs
RUN make
RUN make test
RUN make install

# Install CPAN Minus to make scriptable install possible
WORKDIR /build
RUN git clone ${REHASH_REPO}
RUN ${REHASH_PERL} ${REHASH_SRC}/utils/cpanm App::cpanminus

# The tests fail on Docker due to a connection upgrade inline issue.
# This is probably good enough, and we shoudln't be depending on external
# servers during building unnecessarily

RUN NO_NETWORK_TESTING=1 ${REHASH_CPANM} Net::HTTP
RUN ${REHASH_CPANM} Apache2::Upload
RUN ${REHASH_CPANM} Cache::Memcached
RUN ${REHASH_CPANM} Cache::Memcached::Fast
RUN ${REHASH_CPANM} Data::JavaScript::Anon
RUN ${REHASH_CPANM} Date::Calc
RUN ${REHASH_CPANM} Date::Format
RUN ${REHASH_CPANM} Date::Parse
RUN ${REHASH_CPANM} DateTime::Format::MySQL
RUN ${REHASH_CPANM} DBD::mysql
RUN ${REHASH_CPANM} Digest::MD5
RUN ${REHASH_CPANM} GD
RUN ${REHASH_CPANM} GD::Text::Align
RUN ${REHASH_CPANM} HTML::Entities
RUN ${REHASH_CPANM} HTML::FormatText
RUN ${REHASH_CPANM} HTML::Tagset
RUN ${REHASH_CPANM} HTML::TokeParser
RUN ${REHASH_CPANM} HTML::TreeBuilder
RUN ${REHASH_CPANM} HTTP::Request
RUN ${REHASH_CPANM} Image::Size
RUN ${REHASH_CPANM} JavaScript::Minifier
RUN ${REHASH_CPANM} JSON
RUN ${REHASH_CPANM} Lingua::Stem
RUN ${REHASH_CPANM} LWP::Parallel::UserAgent
RUN ${REHASH_CPANM} LWP::UserAgent
RUN ${REHASH_CPANM} Mail::Address
RUN ${REHASH_CPANM} Mail::Bulkmail

# Disable tests on Mail::Sendmail because it works by sending an email to the author
RUN ${REHASH_CPANM} Mail::Sendmail --notest

RUN ${REHASH_CPANM} MIME::Types
RUN ${REHASH_CPANM} Mojo::Server::Daemon
RUN ${REHASH_CPANM} Net::IP
RUN ${REHASH_CPANM} Net::Server

# Time::ParseDate is a dependency of Schedule::Cron but has test problems
#
# This fails in Docker due to possibly missing tiemzone data, but rehash
# assumes and expects to be running on UTC so bypassing the test failure

RUN ${REHASH_CPANM} Time::ParseDate --notest
RUN ${REHASH_CPANM} Schedule::Cron

RUN ${REHASH_CPANM} SOAP::Lite
RUN ${REHASH_CPANM} Sphinx::Search
RUN ${REHASH_CPANM} URI::Encode
RUN ${REHASH_CPANM} Template
RUN ${REHASH_CPANM} XML::Parser
RUN ${REHASH_CPANM} XML::Parser::Expat
RUN ${REHASH_CPANM} XML::RSS

# DBIx::Password is ... uh ... not easy to deal with.
# Just copy in a pregenerated version
WORKDIR /build
COPY DBIx/make_password_pm.sh .
COPY DBIx/Password.pm.in .
RUN mkdir -p ${REHASH_PREFIX}/perl/lib/${PERL_VERSION}/DBIx/
RUN sh make_password_pm.sh  ${MYSQL_HOST} ${MYSQL_DATABASE} ${MYSQL_USER} ${MYSQL_PASSWORD} > ${REHASH_PREFIX}/perl/lib/${PERL_VERSION}/DBIx/Password.pm
RUN adduser --system --group --gecos "Slash" slash

WORKDIR ${REHASH_SRC}
RUN make USER=slash GROUP=slash PERL=${REHASH_PERL} SLASH_PREFIX=${REHASH_ROOT}
RUN make USER=slash GROUP=slash PERL=${REHASH_PERL} SLASH_PREFIX=${REHASH_ROOT} install

# Create the slashsites files
RUN echo "slash:slash:soylent-mainpage" > ${REHASH_ROOT}/slash.sites
COPY bin/start-rehash /start-rehash
RUN chmod +x /start-rehash
CMD /start-rehash
