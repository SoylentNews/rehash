# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

##
##  Makefile -- Current one for Slash
##

#   the used tools
VERSION = 16.02
DISTNAME = rehash
DISTVNAME = $(DISTNAME)-$(VERSION)

CHMOD = chmod
MODE = 0755
SHELL = /bin/sh
PERL = perl
NOOP = $(SHELL) -c true
RM_RF = rm -rf
RM = rm -f
SUFFIX = .gz
COMPRESS = gzip --best
TAR  = tar
SED  = sed
TARFLAGS = cvf
PREOP = @$(NOOP)
POSTOP = @$(NOOP)
TO_UNIX = @$(NOOP)
ENVIRONMENT_PREFIX=/opt/rehash-environment
SLASH_PREFIX = $(ENVIRONMENT_PREFIX)/rehash
# If this isn't used anymore, can we remove it?
INIT = /etc
USER = nobody
GROUP = nogroup
CP = cp
INSTALL = install
UNAME = `uname`
MAKE = make -s

# Apache stuff
APACHE_MIRROR=http://archive.apache.org/dist/httpd/
APACHE_VER=2.2.29
APACHE_DIR=httpd-$(APACHE_VER)
APACHE_FILE=$(APACHE_DIR).tar.bz2

# Perl stuff
PERL_MIRROR=http://www.cpan.org/src/5.0/
PERL_VER=5.20.0
PERL_DIR=perl-$(PERL_VER)
PERL_FILE=$(PERL_DIR).tar.gz
REHASH_PERL=$(ENVIRONMENT_PREFIX)/perl-$(PERL_VER)/bin/perl
REHASH_CPANM=$(ENVIRONMENT_PREFIX)/perl-$(PERL_VER)/bin/cpanm

# mod_perl stuff
# mod_perl 2.0.9 is for 2.4 apache, unclear if it
# works on 2.2, but we're not upgrading (yet)

MOD_PERL_MIRROR=http://mirror.cogentco.com/pub/apache/perl/
#MOD_PERL_VER=http://archive.apache.org/dist/perl/
MOD_PERL_VER=2.0.9
MOD_PERL_DIR=mod_perl-$(MOD_PERL_VER)
MOD_PERL_FILE=$(MOD_PERL_DIR).tar.gz

# Subdirectories excl. CVS in the current directory (like plugins/ or tagboxes/)
SUBDIRS = `find . -maxdepth 1 -name CVS -prune -o -type d -name [a-zA-Z]\* -print`

# Perl scripts, grouped by directory.
BINFILES = `find bin -name CVS -prune -o -name .git -prune -o -name [a-zA-Z]\* -type f -print`
SBINFILES = `find sbin -name CVS -prune -o -name .git -prune -o -name [a-zA-Z]\* -type f -print`
THEMEFILES = `find themes -name CVS -prune -o -name .git -prune -o -name [a-zA-z]\*.pl -print`
PLUGINFILES = `find plugins themes/*/plugins -name CVS -prune -o -name .git -prune -o -name [a-zA-Z]\*.pl -print`
PLUGINSTALL = `find . -name CVS -prune -o -name .git -prune -o -type d -print | egrep 'plugins/[a-zA-Z0-9]+$$'`
PLUGINDIRS = `find . -name CVS -prune -o -name .git -prune -o -type d -print | egrep 'plugins$$'`

# What do we use to invoke perl?
REPLACEWITH = `$(PERL) -MConfig -e 'print quotemeta($$Config{startperl})' | sed 's/@/\\@/g'`

# Scripts that need special treatment for $(SLASH_PREFIX)
PREFIX_REPLACE_FILES = utils/slash utils/ipn httpd/slash.conf

# Used by the RPM build.
BUILDROOT=/var/tmp/slash-buildroot
INSTALLSITEARCH=`$(PERL) -MConfig -e 'print "$(BUILDROOT)/$$Config{installsitearch}"'`
INSTALLSITELIB=`$(PERL) -MConfig -e 'print "$(BUILDROOT)/$$Config{installsitelib}"'`
INSTALLMAN3DIR=`$(PERL) -MConfig -e 'print "$(BUILDROOT)/$$Config{installman3dir}"'`

.PHONY : all pluginsandtagboxes slash install

#   install the shared object file into Apache
# We should run a script on the binaries to get the right
# version of perl.
# I should also grab an install-sh instead of using $(CP)
slash:
	@echo "=== INSTALLING SLASH MODULES ==="
	@if [ ! "$(RPM)" ] ; then \
		(cd Slash; $(PERL) Makefile.PL; $(MAKE) install UNINST=1); \
	else \
		echo " - Performing an RPM build"; \
		(cd Slash; $(PERL) Makefile.PL INSTALLSITEARCH=$(INSTALLSITEARCH) INSTALLSITELIB=$(INSTALLSITELIB) INSTALLMAN3DIR=$(INSTALLMAN3DIR); $(MAKE) install UNINST=1); \
	fi

pluginsandtagboxes:
	@echo "=== INSTALLING SLASH PLUGINS AND TAGBOXES ==="
	@(pluginstall=$(PLUGINSTALL); \
	for f in $$pluginstall $$taginstall; do \
		(cd $$f; \
		 echo == $$PWD; \
		 if [ -f Makefile.PL ]; then \
		 	if [ ! "$(RPM)" ] ; then \
				$(PERL) Makefile.PL; \
				$(MAKE) install UNINST=1;\
				$(MAKE) realclean; \
			else \
				echo " - Performing an RPM build."; \
				$(PERL) Makefile.PL INSTALLSITEARCH=$(INSTALLSITEARCH) INSTALLSITELIB=$(INSTALLSITELIB) INSTALLMAN3DIR=$(INSTALLMAN3DIR); \
				$(MAKE) install UNINST=1; \
				$(MAKE) realclean; \
			fi; \
		 fi); \
	done)

all: install

install: slash pluginsandtagboxes
	# Create all necessary directories.
	$(INSTALL) -d \
		$(SLASH_PREFIX)/bin/ \
		$(SLASH_PREFIX)/httpd/ \
		$(SLASH_PREFIX)/themes/ \
		$(SLASH_PREFIX)/plugins/ \
		$(SLASH_PREFIX)/sbin \
		$(SLASH_PREFIX)/sql/ \
		$(SLASH_PREFIX)/sql/mysql/

	# Quick hack to avoid the need for "cp -ruv" which breaks under FreeBSD
	# is to just copy the directories now. We may end up copying over a file
	# in the next step that we copy now. To fix this, a major portion of this
	# section of the Makefile would need to be rewritten to do this sanely
	# and there just isn't the time for that right now.
	#
	# Install the plugins and tagboxes.  Will also install kruft like CVS/
	# and blib/ directories if they are around. Maybe a smarter copying
	# procedure is called for, here?)
	#
	# Note: Many users of Slash have taken to symlinking the plugins and themes
	# directories into $(SLASH_PREFIX) from their checked-out CVS trees. We
	# should try to check for this in the future and behave accordingly.
	# (Update, 2006-05-06: no, we're not going to check for that.  Editing a
	# CVS checkout is great, but push it live with a 'make install' please.)
	#
	# OpenBSD needs "-R" here instead of "-rv".  Its manpage notes:
	# Historic versions of the cp utility had a -r option.  This implementation
	# supports that option; however, its use is strongly discouraged, as it
	# does not correctly copy special files, symbolic links or FIFOs.
	#
	@(pluginstall=$(PLUGINSTALL); \
	for f in $$pluginstall; do \
		($(CP) -r $$f $(SLASH_PREFIX)/plugins); \
	done);

	# Now all the themes
	$(CP) -r themes/* $(SLASH_PREFIX)/themes

	# Ensure we use the proper Perl interpreter and prefix in all scripts that
	# we install. Note the use of Perl as opposed to dirname(1) and basename(1)
	# which may or may not exist on any given system.
	(replacewith=$(REPLACEWITH); \
	 binfiles=$(BINFILES); \
	 sbinfiles=$(SBINFILES); \
	 themefiles=$(THEMEFILES); \
	 pluginfiles=$(PLUGINFILES); \
	 if [ "$$replacewith" != "\#\!\/usr\/bin\/perl" ]; then \
	 	replace=1; \
		replacestr='(using $(PERL))'; \
	 else \
	 	replace=0; \
	 fi; \
	 for f in $$binfiles $$sbinfiles $$themefiles $$pluginfiles $$tagboxfiles; do \
		n=$(SLASH_PREFIX)/$$f; \
		$(INSTALL) -d $(SLASH_PREFIX)/$$d; \
	 	if [ $$replace ]; then \
			cat $$f | \
			sed -e "1s/\#\!\/usr\/bin\/perl/$$replacewith/" > $$n.tmp; \
			$(INSTALL) -m $(MODE) $$n.tmp $$n; \
			$(RM) $$n.tmp; \
		else \
			$(INSTALL) $$f $$n; \
		fi; \
	done)

	$(CP) sql/mysql/slashschema_create.sql $(SLASH_PREFIX)/sql/mysql/schema.sql
	$(CP) sql/mysql/defaults.sql $(SLASH_PREFIX)/sql/mysql/defaults.sql

	# This needs BSD support (and Solaris)...
	# ... and the $(SLASH_PREFIX) section is a really ugly hack, too.
	(if [ "$(SLASH_PREFIX)" != "/usr/local/slash" ]; then			\
		replace=1;							\
	 fi;									\
	 for a in $(PREFIX_REPLACE_FILES); do 					\
	 	if [ $$replace ]; then						\
			perl -i.bak -pe 's{/usr/local/slash}{$(SLASH_PREFIX)}' $$a;	\
		fi;								\
		case "$$a" in							\
	 	'utils/slash')							\
			 if [ "$(INIT)" != "/etc" ]; then			\
			 	if [ -d $(INIT) ]; then 		\
			 		init=$(INIT);				\
				fi;								\
			 elif [ -d /etc/init.d ]; then 				\
	 			init=/etc;					\
			 elif [ -d /etc/rc.d/init.d ]; then 			\
		 		init=/etc/rc.d;					\
			 fi;							\
			 if [ $$init ]; then					\
 			 	$(INSTALL) utils/slash $$init/init.d/;		\
				ln -s -f ../init.d/slash $$init/rc3.d/S99slash;	\
				ln -s -f ../init.d/slash $$init/rc6.d/K99slash;	\
			 else 							\
				echo "*** Makefile can't determine where your init scripts live."; \
				if [ $$init ]; then				\
					echo "***   ('$(INIT)' does not exist)";	\
				fi;						\
				echo "*** You will need to look at how to install utils/slash"; \
				echo "*** on your own.";			\
			 fi;							\
			 ;;							\
	 	'utils/ipn')							\
			 if [ "$(INIT)" != "/etc" ]; then			\
			 	if [ -d $(INIT) ]; then 		\
			 		init=$(INIT);				\
				fi;								\
			 elif [ -d /etc/init.d ]; then 				\
	 			init=/etc;					\
			 elif [ -d /etc/rc.d/init.d ]; then 			\
		 		init=/etc/rc.d;					\
			 fi;							\
			 if [ $$init ]; then					\
 			 	$(INSTALL) utils/ipn $$init/init.d/;		\
				ln -s -f ../init.d/ipn $$init/rc3.d/S99ipn;	\
				ln -s -f ../init.d/ipn $$init/rc6.d/K99ipn;	\
			 else 							\
				echo "*** Makefile can't determine where your init scripts live."; \
				if [ $$init ]; then				\
					echo "***   ('$(INIT)' does not exist)";	\
				fi;						\
				echo "*** You will need to look at how to install utils/ipn"; \
				echo "*** on your own.";			\
			 fi;							\
			 ;;							\
		'httpd/slash.conf')						\
			if [ -f $(SLASH_PREFIX)/httpd/slash.conf ]; then	\
				echo "Preserving old slash.conf"; 		\
			else 							\
				$(CP) httpd/slash.conf $(SLASH_PREFIX)/httpd/slash.conf; \
			fi;							\
			$(CP) httpd/slash.conf $(SLASH_PREFIX)/httpd/slash.conf.def; \
			;;							\
		esac;								\
		if [ $$replace ]; then						\
	 		mv $$a.bak $$a;	 					\
		fi;								\
	done)
	# Remove any kruft thay may have been copied that shouldn't have been.
	# Normally we save some time by not diving into an installed site's
	# htdocs' archived directories, but apparently Sun's "find" doesn't
	# support "-path" so skip it.
	if [ $(UNAME) != "SunOS" ]; then					\
	find $(SLASH_PREFIX)							\
		\( -type d -a -path */site/*/htdocs*/[0-9][0-9]* -a -prune \)	\
		-o								\
		\( -name CVS -type d   -o   -name .#* -type f \)		\
			-a \( -prune						\
				-exec $(RM_RF) {} \; \)				\
		2> /dev/null ;							\
	else									\
	find $(SLASH_PREFIX)							\
		\( -name CVS -type d   -o   -name .#* -type f \)		\
			-a \( -prune						\
				-exec $(RM_RF) {} \; \)				\
		2> /dev/null ;							\
	fi

	touch $(SLASH_PREFIX)/slash.sites
	chown $(USER):$(GROUP) $(SLASH_PREFIX)
	chown -R $(USER):$(GROUP) $(SLASH_PREFIX)/themes
	chown -R $(USER):$(GROUP) $(SLASH_PREFIX)/sbin
	chown -R $(USER):$(GROUP) $(SLASH_PREFIX)/bin
	chown -R $(USER):$(GROUP) $(SLASH_PREFIX)/sql
	chown -R $(USER):$(GROUP) $(SLASH_PREFIX)/plugins
# Add a @ to suppress output of the echo's
	@echo "+--------------------------------------------------------+"; \
	echo "| All done.                                              |"; \
	echo "| If you want to let Slash handle your httpd.conf file   |"; \
	echo "| go add:                                                |"; \
	echo "|                                                        |"; \
	echo "| Include $(SLASH_PREFIX)/httpd/slash.conf              |"; \
	echo "|                                                        |"; \
	echo "| to your httpd.conf for apache.                         |"; \
	echo "| If not, cat its content into your httpd.conf file.     |"; \
	echo "|                                                        |"; \
	echo "| Thanks for installing Slash.                           |"; \
	echo "+--------------------------------------------------------+"; \

reload: install
	apachectl stop
	apachectl start

#   cleanup
# We need this to remove Makefile.old's as well, and *.xs.orig
clean:
	(cd Slash; if [ ! -f Makefile ]; then perl Makefile.PL; fi; $(MAKE) clean)
	(cd plugins; $(MAKE) clean)
	find ./ | grep Makefile.old | xargs rm

distclean: clean
	rm -r dist build stamp

dist: $(DISTVNAME).tar$(SUFFIX)

$(DISTVNAME).tar$(SUFFIX) : distdir
	$(PREOP)
	$(TO_UNIX)
	$(TAR) $(TARFLAGS) $(DISTVNAME).tar $(DISTVNAME)
	$(RM_RF) $(DISTVNAME)
	$(COMPRESS) $(DISTVNAME).tar
	$(POSTOP)

distdir :
	$(RM_RF) $(DISTVNAME)
	$(PERL) -MExtUtils::Manifest=manicopy,maniread \
	-e "manicopy(maniread(),'$(DISTVNAME)', '$(DIST_CP)');"

manifest :
	(cd Slash; $(MAKE) distclean)
	$(PERL) -MExtUtils::Manifest -e 'ExtUtils::Manifest::mkmanifest'

rpm :
	rpm -ba slash.spec

build-environment: stamp/apache-built stamp/perl-built stamp/mod-perl-built stamp/install-cpamn stamp/install-apache2-upload stamp/install-cache-memcached stamp/install-cache-memcached-fast stamp/install-data-javascript-anon stamp/install-date-calc stamp/install-date-format stamp/install-date-language stamp/install-date-parse stamp/install-datetime-format-mysql stamp/install-dbd-mysql stamp/install-digest-md5 stamp/install-email-valid stamp/install-gd stamp/install-gd-text-align stamp/install-html-entities stamp/install-html-formattext stamp/install-html-tagset stamp/install-html-tokeparser stamp/install-html-treebuilder stamp/install-http-request stamp/install-image-size stamp/install-javascript-minifier stamp/install-json stamp/install-lingua-stem stamp/install-lwp-parallel-useragent stamp/install-lwp-useragent stamp/install-mail-address stamp/install-mail-bulkmail  stamp/install-mail-sendmail stamp/install-mime-types stamp/install-mojo-server-daemon  stamp/install-net-ip stamp/install-net-server stamp/install-schedule-cron stamp/install-soap-lite stamp/install-sphinx-search stamp/install-uri-encode stamp/install-template stamp/install-xml-parser stamp/install-xml-parser-expat stamp/install-xml-rss
	@echo "Setting permissions on the $(ENVIRONMENT_PREFIX) directory"
	chown $(USER):$(GROUP) -R $(ENVIRONMENT_PREFIX)
	@echo ""
	@echo "Rehash Environment Successfully Installed!"
	@echo ""
	@echo "If you're reading this, the following software was "
	@echo "installed to $(ENVIRONMENT_PREFIX):"
	@echo ""
	@echo "httpd: $(APACHE_VER)"
	@echo "perl: $(PERL_VER)"
	@echo "mod_perl: $(MOD_PERL_VER)"
	@echo ""
	@echo "As well as the latest version of rehash's dependencies"
	@echo "from CPAN. It's recommended everytime you upgrade"
	@echo "your site, you re-run build-environment to update"
	@echo "everything to the latest version."
	@echo ""
	@echo "If Upgrading:"
	@echo "Your old apache/perl directories have been left in"
	@echo "place; before switching over to the new versions,"
	@echo "make sure you update httpd.conf and migrate"
	@echo "DBIx::Password to your new perl directory. See INSTALL"
	@echo "for more information."
	@echo ""
	@echo "For New Installs:"
	@echo "Rehash has one final dependency not handled by this"
	@echo "script: DBIx::Password. You can install it by running"
	@echo "make install-dbi-password, but make sure to check "
	@echo "INSTALL for more information before running this"
	@echo "this command!"
	@echo ""
	@echo "Feel free to join us in #dev on irc.soylentnews.org"
	@echo "if you need help or have any questions!"
	@echo ""
	@echo "Thanks for installing Rehash."

get-rehash-dependencies: dist/$(APACHE_FILE) dist/$(PERL_FILE) dist/$(MOD_PERL_FILE)

dist/$(APACHE_FILE):
	-mkdir dist
	cd dist; wget $(APACHE_MIRROR)/$(APACHE_FILE)

stamp/apache-built: dist/$(APACHE_FILE)
	-mkdir build stamp
	-rm -rf build/$(APACHE_DIR)
	cd build && tar jxf ../dist/$(APACHE_FILE); cd $(APACHE_DIR) && ./configure --prefix=$(ENVIRONMENT_PREFIX)/apache-$(APACHE_VER) --enable-mods-shared=most && make && make install
	touch stamp/apache-built

dist/$(PERL_FILE):
	-mkdir dist
	cd dist; wget $(PERL_MIRROR)/$(PERL_FILE)

stamp/perl-built: dist/$(PERL_FILE)
	-mkdir build stamp
	-rm -rf build/$(PERL_DIR)
	cd build && tar zxf ../dist/$(PERL_FILE) && cd $(PERL_DIR) && ./Configure -des -Dprefix=$(ENVIRONMENT_PREFIX)/perl-$(PERL_VER) -Duseshrplib -Dusethreads && make && make check && make install
	touch stamp/perl-built

dist/$(MOD_PERL_FILE):
	-mkdir dist
	cd dist; wget $(MOD_PERL_MIRROR)/$(MOD_PERL_FILE)

stamp/mod-perl-built: dist/$(MOD_PERL_FILE)
	-mkdir build stamp
	-rm -rf build/$(MOD_PERL_DIR)
	cd build && tar xvf ../dist/$(MOD_PERL_FILE) && cd $(MOD_PERL_DIR) && $(REHASH_PERL) Makefile.PL MP_APXS=$(ENVIRONMENT_PREFIX)/apache-$(APACHE_VER)/bin/apxs && make && make test && make install
	touch stamp/mod-perl-built

stamp/install-cpamn:
	-mkdir stamp
	$(REHASH_PERL) utils/cpanm App::cpanminus
	touch stamp/install-cpamn

stamp/install-apache2-upload:
	-mkdir stamp
	$(REHASH_CPANM) Apache2::Upload
	touch stamp/install-apache2-upload

stamp/install-cache-memcached:
	-mkdir stamp
	$(REHASH_CPANM) Cache::Memcached
	touch stamp/install-cache-memcached

stamp/install-cache-memcached-fast:
	-mkdir stammp
	$(REHASH_CPANM) Cache::Memcached::Fast
	touch stamp/install-cache-memcached-fast

stamp/install-data-javascript-anon:
	-mkdir stamp
	$(REHASH_CPANM) Data::JavaScript::Anon
	touch stamp/install-data-javascript-anon

stamp/install-date-calc:
	-mkdir stamp
	$(REHASH_CPANM) Date::Calc
	touch stamp/install-date-calc
	
stamp/install-twitter-api:
	-mkdir stamp
	$(REHASH_CPANM) Twitter::API
	touch stamp/install-twitter-api
	
stamp/install-date-format:
	-mkdir stamp
	$(REHASH_CPANM) Date::Format
	touch stamp/install-date-format

stamp/install-date-language:
	-mkdir stamp
	$(REHASH_CPANM) Date::Language
	touch stamp/install-date-language

stamp/install-date-parse:
	-mkdir stamp
	$(REHASH_CPANM) Date::Parse
	touch stamp/install-date-parse

stamp/install-datetime-format-mysql:
	-mkdir stamp
	$(REHASH_CPANM) DateTime::Format::MySQL
	touch stamp/install-datetime-format-mysql

stamp/install-dbd-mysql:
	-mkdir stamp
	$(REHASH_CPANM) DBD::mysql
	touch stamp/install-dbd-mysql

stamp/install-digest-md5:
	-mkdir stamp
	$(REHASH_CPANM) Digest::MD5
	touch stamp/install-digest-md5

stamp/install-email-valid:
	-mkdir stamp
	$(REHASH_CPANM) Email::Valid
	touch stamp/install-email-valid

stamp/install-gd:
	-mkdir stamp
	$(REHASH_CPANM) GD
	touch stamp/install-gd

stamp/install-gd-text-align:
	-mkdir stamp
	$(REHASH_CPANM) GD::Text::Align
	touch stamp/install-gd-text-align

stamp/install-html-entities:
	-mkdir stamp
	$(REHASH_CPANM) HTML::Entities
	touch stamp/install-html-entities

stamp/install-html-formattext:
	-mkdir stamp
	$(REHASH_CPANM) HTML::FormatText
	touch stamp/install-html-formattext

stamp/install-html-tagset:
	-mkdir stamp
	$(REHASH_CPANM) HTML::Tagset
	touch stamp/install-html-tagset

stamp/install-html-tokeparser:
	-mkdir stamp
	$(REHASH_CPANM) HTML::TokeParser
	touch stamp/install-html-tokeparser

stamp/install-html-treebuilder:
	-mkdir stamp
	$(REHASH_CPANM) HTML::TreeBuilder
	touch stamp/install-html-treebuilder

stamp/install-http-request:
	-mkdir stamp
	$(REHASH_CPANM) HTTP::Request
	touch stamp/install-http-request

stamp/install-image-size:
	-mkdir stamp
	$(REHASH_CPANM) Image::Size
	touch stamp/install-image-size

stamp/install-javascript-minifier:
	-mkdir stamp
	$(REHASH_CPANM) JavaScript::Minifier
	touch stamp/install-javascript-minifier

stamp/install-json:
	-mkdir stamp
	$(REHASH_CPANM) JSON
	touch stamp/install-json

stamp/install-lingua-stem:
	-mkdir stamp
	$(REHASH_CPANM) Lingua::Stem
	touch stamp/install-lingua-stem

stamp/install-lwp-parallel-useragent:
	-mkdir stamp
	$(REHASH_CPANM) LWP::Parallel::UserAgent
	touch stamp/install-lwp-parallel-useragent

stamp/install-lwp-useragent:
	-mkdir stamp
	$(REHASH_CPANM) LWP::UserAgent
	touch stamp/install-lwp-useragent

stamp/install-mail-address:
	-mkdir stamp
	$(REHASH_CPANM) Mail::Address
	touch stamp/install-mail-address

stamp/install-mail-bulkmail:
	-mkdir stamp
	$(REHASH_CPANM) Mail::Bulkmail
	touch stamp/install-mail-bulkmail

stamp/install-mail-sendmail:
	-mkdir stamp
	$(REHASH_CPANM) Mail::Sendmail
	touch stamp/install-mail-sendmail

stamp/install-mime-types:
	-mkdir stamp
	$(REHASH_CPANM) MIME::Types
	touch stamp/install-mime-types

stamp/install-mojo-server-daemon:
	-mkdir stamp
	$(REHASH_CPANM) Mojo::Server::Daemon
	touch stamp/install-mojo-server-daemon

stamp/install-net-ip:
	-mkdir stamp
	$(REHASH_CPANM) Net::IP
	touch stamp/install-net-ip

stamp/install-net-server:
	-mkdir stamp
	$(REHASH_CPANM) Net::Server
	touch stamp/install-net-server

stamp/install-schedule-cron:
	-mkdir stamp
	$(REHASH_CPANM) Schedule::Cron
	touch stamp/install-schedule-cron

stamp/install-soap-lite:
	-mkdir stamp
	$(REHASH_CPANM) SOAP::Lite
	touch stamp/install-soap-lite

stamp/install-sphinx-search:
	-mkdir stamp
	$(REHASH_CPANM) Sphinx::Search
	touch stamp/install-sphinx-search

stamp/install-uri-encode:
	-mkdir stamp
	$(REHASH_CPANM) URI::Encode
	touch stamp/install-uri-encode

stamp/install-template:
	-mkdir stamp
	$(REHASH_CPANM) Template
	touch stamp/install-template

stamp/install-xml-parser:
	-mkdir stamp
	$(REHASH_CPANM) XML::Parser
	touch stamp/install-xml-parser

stamp/install-xml-parser-expat:
	-mkdir stamp
	$(REHASH_CPANM) XML::Parser::Expat
	touch stamp/install-xml-parser-expat

stamp/install-xml-rss:
	-mkdir stamp
	$(REHASH_CPANM) XML::RSS
	touch stamp/install-xml-rss

install-dbix-password:
	$(REHASH_CPANM) --interactive DBIx::Password

stamp/append-apache-config:
	@echo "Appending Apache's configuration with necessary module configuration"
	echo "LoadModule perl_module modules/mod_perl.so" >> $(ENVIRONMENT_PREFIX)/$(APACHE_DIR)/conf/httpd.conf
	echo "LoadModule apreq_module modules/mod_apreq2.so"  >> $(ENVIRONMENT_PREFIX)/$(APACHE_DIR)/conf/httpd.conf
	echo "Include $(SLASH_PREFIX)/httpd/slash.conf" >> $(ENVIRONMENT_PREFIX)/$(APACHE_DIR)/conf/httpd.conf
	touch stamp/append-apache-config:
