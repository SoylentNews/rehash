###############################################################################
# slashdotrc.pl
# This is the main global configuration file.
#
# Copyright (C) 1997 Rob "CmdrTaco" Malda
# malda@slashdot.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
#  $Id$
###############################################################################
require URI;

# hardcoded variables to reduce the SQL. Normally use getvars()
# change this according to site specifics

my %my_conf = (
	adminmail	=> 'admin@yoursite.com',
	siteowner	=> 'slash',
	datadir		=> '/home/slash',
	basedomain	=> 'www.yoursite.com',    # add ":PORT" here if required
	cookiedomain	=> '', # ".yoursite.com', # off by default
	siteadmin	=> 'admin',
	siteadmin_name	=> 'Slash Admin',
	smtp_server	=> 'smtp.yoursite.com',
	sitename	=> 'Slash Site',
	slogan		=> 'Slashdot Like Automated Storytelling Homepage',
	breaking	=> 100,
	shit		=> 0,
	mainfontface	=> 'verdana,helvetica,arial',
	fontbase	=> 0,	# base font size, default 0
	updatemin	=> 5,	# do slashd updates, default 5
	archive_delay	=> 60,	# days to wait for story archiving, comments deleting
	submiss_view	=> 1,	# allow users to view submissions queue
	submiss_ts	=> 1,	# print timestamp in submissions view
	articles_only	=> 0,	# show only Articles in submission count in admin menu
	admin_timeout	=> 30,	# time in minutes before idle admin session ends

# this controls the life of %storyBank
	story_expire	=> 600,
	titlebar_width	=> '100%',
	dsn		=> 'DBI:mysql:database=slash;host=localhost',
	dbuser		=> 'slash',
	dbpass		=> 'yourpassword',

# this is up to you to your own ad system. Sorry :-)
	adfu_dsn	=> 'DBI:mysql:database=yourdb;host=youraddbhost',
	adfu_dbuser	=> 'slash',
	adfu_dbpass	=> 'adfudbpassword',
	run_ads		=> 0,	# whether we run ads or not

# if this is on, the mailinglist will go out. Do you want that?
	send_mail	=> 0,

# The following variables can be used to tweak your Slash Moderation
	authors_unlimited	=> 1,   # authors have unlimited moderation
	metamod_sum		=> 3,   # sum of moderations 1 for release
	maxtokens		=> 40,	# Token threshold that must be hit to get any points
	tokensperpoint		=> 8,	# Number of tokens per point
	maxpoints		=> 5,	# The maximum number of points any moderator can have
	stir			=> 3,  	# Number of days before unused moderator points expire
	tokenspercomment	=> 6,	# Number of tokens to feed the system for each comment
	down_moderations	=> -6,	# number of how many comments you can post that get down moderated

# very important - if you set this to one, make sure 
# that you can use IPC::Shareable on your system
	use_ipc		=> 0,
	post_limit	=> 10,	# seconds delay before repeat posting
);

# these keys dependent on values set above
$my_conf{rootdir}	= "http://$my_conf{basedomain}";
$my_conf{basedir}	= $my_conf{datadir} . "/public_html";
$my_conf{imagedir}	= "$my_conf{rootdir}/images";
$my_conf{rdfimg}	= "$my_conf{imagedir}/topics/topicslash.gif";
$my_conf{cookiepath}	= URI->new($my_conf{rootdir})->path . '/';


# $$ for use by slashd, etc., for when there is no $ENV{SERVER_NAME}
$Slash::conf{lc $ENV{SERVER_NAME}} = \%my_conf;
$Slash::conf{$$}		= \%my_conf;
$Slash::conf{DEFAULT}		= \%my_conf;

# if you have more than one SERVER_NAME pointing to the same slash
# instance (such as www.slashdot.org and slashdot.org), then you
# can hardcode it in here, like so:
# $Slash::conf{$$}		= \%my_conf;
# $Slash::conf{'www.foo.com'}	= \%my_conf;
# $Slash::conf{'foo.com'}	= \%my_conf;
# etc.

1;
