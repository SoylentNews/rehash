# Distribution Version
FROM ubuntu:22.04 AS rehash

# Control variables
ENV REHASH_REPO=https://github.com/SoylentNews/rehash.git
ENV REHASH_PREFIX=/srv/soylentnews.org
ENV REHASH_ROOT=/srv/soylentnews.org/rehash
ENV REHASH_SRC=/build/rehash

# Mail smarthost
ENV ENABLE_MAIL=false
ENV MYHOSTNAME=soylentnews.org
ENV RELAYHOST=postfix

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# MySQL Database Stuff
ENV MYSQL_HOST=localhost
ENV MYSQL_DATABASE=soylentnews
ENV MYSQL_USER=soylentnews
ENV MYSQL_PASSWORD=soylentnews

ENV PERL_VERSION=5.36.1
ENV PERL_DOWNLOAD=https://www.cpan.org/src/5.0/perl-${PERL_VERSION}.tar.gz

ENV APACHE_VERSION=2.2.34
ENV APACHE_DOWNLOAD=https://archive.apache.org/dist/httpd/httpd-${APACHE_VERSION}.tar.gz

ENV MOD_PERL_VERSION=2.0.13
ENV MOD_PERL_DOWNLOAD=https://mirror.cogentco.com/pub/apache/perl/mod_perl-${MOD_PERL_VERSION}.tar.gz

# rehash uses its own Perl, make we need to define that
ENV REHASH_PERL=${REHASH_PREFIX}/perl/bin/perl
ENV REHASH_CPANM=${REHASH_PREFIX}/perl/bin/cpanm

# Open ports
EXPOSE 80

# for ipn
EXPOSE 2626


# Unminimize the image since Perl's test suite requires it
RUN apt-get update
RUN yes | unminimize

# Install system build dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential libgd-dev libmysqlclient-dev zlib1g zlib1g-dev libexpat1-dev git wget sudo postfix fortune
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

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
COPY utils/cpanm /build/cpanm
RUN ${REHASH_PERL} /build/cpanm App::cpanminus

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
RUN ${REHASH_CPANM} -T --notest DateTime::Format::MySQL
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
RUN ${REHASH_CPANM} Email::Valid

RUN ${REHASH_CPANM} Crypt::CBC
RUN ${REHASH_CPANM} HTML::PopupTreeSelect
RUN ${REHASH_CPANM} Twitter::API

# DBIx::Password is ... uh ... not easy to deal with.
# Just copy in a pregenerated version
WORKDIR /
COPY DBIx/make_password_pm.sh .
COPY DBIx/Password.pm.in .
RUN mkdir -p ${REHASH_PREFIX}/perl/lib/${PERL_VERSION}/DBIx/
RUN sh make_password_pm.sh  ${MYSQL_HOST} ${MYSQL_DATABASE} ${MYSQL_USER} ${MYSQL_PASSWORD} > ${REHASH_PREFIX}/perl/lib/${PERL_VERSION}/DBIx/Password.pm
RUN adduser --system --group --uid 50000 --gecos "Slash" slash

# Copy in the rehash source code
ADD . ${REHASH_SRC}/
WORKDIR ${REHASH_SRC}
RUN make USER=slash GROUP=slash PERL=${REHASH_PERL} SLASH_PREFIX=${REHASH_ROOT}
RUN make USER=slash GROUP=slash PERL=${REHASH_PERL} SLASH_PREFIX=${REHASH_ROOT} install
RUN cp ${REHASH_SRC}/httpd/site.conf ${REHASH_ROOT}/httpd/site.conf

# Create the slashsites files
RUN echo "slash:slash:soylent-mainpage" > ${REHASH_ROOT}/slash.sites
RUN echo "sudo -u slash" > ${REHASH_ROOT}/mysudo

# Startup scripts and permissions
COPY bin/start-rehash /start-rehash
RUN chmod +x /start-rehash
RUN ln -s ${REHASH_PREFIX} /rehash-prefix

# So logs on production end up here, just create it and figure out
# how the path gets created later
RUN mkdir -p ${REHASH_ROOT}/site/soylent-mainpage/logs/

# make the SN logs folder, hack for production
RUN mkdir -p /srv/soylentnews.logs

RUN chown slash:slash -R ${REHASH_PREFIX}/rehash
RUN chown slash:slash -R ${REHASH_PREFIX}/apache/logs
RUN chown slash:slash -R /srv/soylentnews.logs

RUN echo "KeepAlive on" >> ${REHASH_PREFIX}/apache/conf/httpd.conf
RUN echo "KeepAliveTimeout 600" >> ${REHASH_PREFIX}/apache/conf/httpd.conf
RUN echo "MaxKeepAliveRequests 0" >> ${REHASH_PREFIX}/apache/conf/httpd.conf
RUN echo "TraceEnable Off" >> ${REHASH_PREFIX}/apache/conf/httpd.conf

RUN echo "LoadModule apreq_module modules/mod_apreq2.so" >> ${REHASH_PREFIX}/apache/conf/httpd.conf
RUN echo "LoadModule perl_module modules/mod_perl.so" >> ${REHASH_PREFIX}/apache/conf/httpd.conf
RUN echo "Include /rehash-prefix/rehash/httpd/slash.conf" >> ${REHASH_PREFIX}/apache/conf/httpd.conf
RUN echo "Include /rehash-prefix/rehash/httpd/site.conf" >> ${REHASH_PREFIX}/rehash/httpd/slash.conf
RUN echo "LogLevel Debug" >> ${REHASH_PREFIX}/apache/conf/httpd.conf

COPY conf/postfix/main.cf /main.cf
CMD /start-rehash
