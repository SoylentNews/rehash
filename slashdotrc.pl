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
	adminmail	=> 'admin@example.com',
	mailfrom	=> 'reply-to@example.com',
	siteowner	=> 'slash',
	datadir		=> '/home/slash',
	basedomain	=> 'www.example.com',    # add ":PORT" here if required
	cookiedomain	=> '', # ".example.com', # off by default
	siteadmin	=> 'admin',
	siteadmin_name	=> 'Slash Admin',
	smtp_server	=> 'smtp.example.com',
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
	allow_anonymous	=> 1,	# allow anonymous posters
	use_dept	=> 1,	# use "dept." field
	max_depth	=> 7,	# max depth for nesting of comments
	approvedtags    => [qw(B I P A LI OL UL EM BR TT STRONG BLOCKQUOTE DIV)],
	defaultsection  => 'articles',  # default section for articles
	http_proxy	=> '',	# 'http://proxy.example.com/'

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
	authors_unlimited	=> 1,		# authors have unlimited moderation
	m2_comments		=> 10,		# Number of comments for meta-moderation.
	m2_maxunfair		=> 0.5,		# Minimum % of unfairs for M2 penalty.
	m2_toomanyunfair	=> 0.3,		# Minimum % of unfairs for which M2 is ignored.
	m2_bonus		=> '+1',	# Bonus for participating in meta-moderation.
	m2_penalty		=> '-1',	# Penalty for misuse of meta-moderation.
	m2_userpercentage	=> 0.9,		# UID must be below this percentage of the total userbase to metamoderate.
	comment_minscore	=> -1,		# Minimum score for a specific comment.
	comment_maxscore	=> 5,		# Maximum score for a specific comment.
	submission_bonus	=> 3,		# Bonus given to user if submission is used.
	goodkarma		=> 25,		# Users get bonus points for posts if karma above this value
	badkarma		=> -10,		# Users get penalized for posts if karma is below this value
	maxkarma		=> 50,		# Maximum karma a user can accumulate.
	metamod_sum		=> 3,		# sum of moderations 1 for release (deprecated)
	maxtokens		=> 40,		# Token threshold that must be hit to get any points
	tokensperpoint		=> 8,		# Number of tokens per point
	maxpoints		=> 5,		# The maximum number of points any moderator can have
	stir			=> 3,		# Number of days before unused moderator points expire
	tokenspercomment	=> 6,		# Number of tokens to feed the system for each comment
	down_moderations	=> -6,		# number of how many comments you can post that get down moderated

# comment posting and story submission abuse settings
	post_limit		=> 10,		# seconds delay before repeat posting
	max_posts_allowed	=> 30,		# maximum number of posts per day allowed
	max_submissions_allowed => 20,		# maximum number of submissions per timeframe allowed
	submission_speed_limit	=> 300,		# how fast they can submit
	formkey_timeframe 	=> 14400,	# the time frame that we check for a formkey

	# see Slash::fixHref()
	fixhrefs => [
		[
			qr/^malda/,
			sub {
				$_[0] =~ s|malda|http://cmdrtaco.net|;
				return(
					$_[0],
					"Everything that used to be in /malda is now located at http://cmdrtaco.net"
				);
			}
		],

		[
			qr/^linux/,
			sub {
				return(
					"http://cmdrtaco.net/$_[0]",
					"Everything that used to be in /linux is now located at http://cmdrtaco.net/linux"
				);
			}
		],

	],

	submit_categories => ['Back'],
);

# these keys dependent on values set above
$my_conf{rootdir}	= "http://$my_conf{basedomain}";
$my_conf{basedir}	= $my_conf{datadir} . "/public_html";
$my_conf{imagedir}	= "$my_conf{rootdir}/images";
$my_conf{rdfimg}	= "$my_conf{imagedir}/topics/topicslash.gif";
$my_conf{cookiepath}	= URI->new($my_conf{rootdir})->path . '/';
$my_conf{m2_mincheck} 	= int $my_conf{m2_comments} / 3;
$my_conf{m2_maxbonus}   = int $my_conf{goodkarma} / 2;

# who to send daily stats reports to (email => subject)
$my_conf{stats_reports} = {
	$my_conf{adminmail}	=> "$my_conf{sitename} Stats Report",
};

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
