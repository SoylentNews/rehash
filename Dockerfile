# Distribution Version
FROM ubuntu:22.04 AS rehash

# Control variables
ENV REHASH_PREFIX=/srv/soylentnews.org
ENV REHASH_ROOT=/srv/soylentnews.org/rehash
ENV REHASH_SRC=/build/rehash
ENV REHASH_PERL=${REHASH_PREFIX}/perl/bin/perl

# Perl version needs to be set here. This is also in the Makefile, but
# for bare metal installs, DBIx::Password is done interactively. However,
# for automated installs, we need to manually drop it into the right place

# Bad things will happen if this number, and the one in the Makefile are out of sync
ENV PERL_VERSION=5.36.1

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

# Open ports
EXPOSE 80

# for ipn
EXPOSE 2626

# Unminimize the image since Perl's test suite requires it
RUN apt-get update
RUN yes | unminimize

# Install system build dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential libgd-dev libmysqlclient-dev zlib1g zlib1g-dev libexpat1-dev git wget sudo postfix
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# HACK ALERT - We want to still support building rehash out of the Makefile
# sans Docker, but simply copying the entire rehash folder here will rebuild
# the entire dependency tree, so just copy the base makefile, which will prevent
# Docker from rebuilding the whole fracking thing unless the actual Makefile
# changes (which should be extremely rare)

WORKDIR /build
COPY Makefile /build
COPY utils/cpanm /build/utils/cpanm
RUN make build-environment ENVIRONMENT_PREFIX=${REHASH_PREFIX} DO_APACHE_CONFIG=0

# DBIx::Password is ... uh ... not easy to deal with.
# Just copy in a pregenerated version
WORKDIR /
COPY DBIx/make_password_pm.sh .
COPY DBIx/Password.pm.in .
RUN mkdir -p ${REHASH_PREFIX}/perl/lib/${PERL_VERSION}/DBIx/
RUN sh make_password_pm.sh  ${MYSQL_HOST} ${MYSQL_DATABASE} ${MYSQL_USER} ${MYSQL_PASSWORD} > ${REHASH_PREFIX}/perl/lib/${PERL_VERSION}/DBIx/Password.pm
RUN adduser --system --group --gecos "Slash" slash

# Assuming we have everything build now, we're ready to install rehash now
ADD . ${REHASH_SRC}/
WORKDIR ${REHASH_SRC}

# Copy in the rehash source code
RUN make USER=slash GROUP=slash PERL=${REHASH_PERL} SLASH_PREFIX=${REHASH_ROOT}
RUN make USER=slash GROUP=slash PERL=${REHASH_PERL} SLASH_PREFIX=${REHASH_ROOT} install
RUN make ENVIRONMENT_PREFIX=${REHASH_PREFIX} stamp/append-apache-config
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

COPY conf/postfix/main.cf /main.cf
CMD /start-rehash
