package Slash;

###############################################################################
# Slash.pm  (aka, the BEAST)
# This is the primary perl module for the slash engine.
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
use strict;  # ha ha ha ha ha!
use Apache::SIG ();
use CGI ();
use DBI;
use Date::Manip;
use File::Spec::Functions;
use HTML::Entities;
use Mail::Sendmail;
use URI;

Apache::SIG->set;

BEGIN {
	# this is the worst damned warning ever, so SHUT UP ALREADY!
	$SIG{__WARN__} = sub { warn @_ unless $_[0] =~ /Use of uninitialized value/ };

	require Exporter;
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %I $CRLF);
	$VERSION = '1.0.5';
	@ISA	 = 'Exporter';
	@EXPORT  = qw(
		sqlSelectMany sqlSelect sqlSelectHash sqlSelectAll approveTag
		sqlSelectHashref sqlUpdate sqlInsert sqlReplace sqlConnect
		sqlTableExists sqlSelectColumns getSlash linkStory getSection
		selectForm selectGeneric selectTopic selectSection fixHref
		getvars getvar setvar newvar getblock getsid getsiddir getWidgetBlock
		writelog anonLog pollbooth stripByMode header footer pollItem
		prepEvalBlock prepBlock nukeBlockCache blockCache formLabel
		titlebar fancybox portalbox printComments displayStory
		sendEmail getOlderStories selectStories timeCalc
		getEvalBlock getTopic getAuthor dispStory lockTest getSlashConf
		getDateFormat dispComment getDateOffset linkComment redirect
		insertFormkey getFormkeyId checkSubmission checkTimesPosted
		updateFormkeyId formSuccess formAbuse formFailure errorMessage
	);
	$CRLF = "\015\012";
}

getSlashConf();

# The actual connect statement appears in this function.  Edit it.
sqlConnect();


###############################################################################
#
# Let's get this party Started
#

# Load in config for proper SERVER_NAME.  If you do not want to use SERVER_NAME,
# adjust here and in slashdotrc.pl
sub getSlashConf {
	my $serv = exists $Slash::home{lc $ENV{SERVER_NAME}}
		? lc $ENV{SERVER_NAME}
		: 'DEFAULT';

	require($Slash::home{$serv} ? catfile($Slash::home{$serv}, 'slashdotrc.pl')
		: 'slashdotrc.pl');

	$serv = exists $Slash::conf{lc $ENV{SERVER_NAME}}
		? lc $ENV{SERVER_NAME}
		: 'DEFAULT';

	*I = $Slash::conf{$ENV{SERVER_NAME} ? $serv : $$};

	$I{reasons} = [
		'Normal',	# "Normal"
		'Offtopic',	# Bad Responses
		'Flamebait',
		'Troll',
		'Redundant',
		'Insightful',	# Good Responses
		'Interesting',
		'Informative',
		'Funny',
		'Overrated',	# The last 2 are "Special"
		'Underrated'
	];

	$I{badreasons} = 4; # number of "Bad" reasons in @$I{reasons}, skip 0 (which is neutral)

	return \%I;
}


# Blank variables, get $I{r} (apache) $I{query} (CGI) $I{U} (User) and $I{F} (Form)
# Handles logging in, sql connection, and prints HTTP headers
sub getSlash {
	for (qw[r query F U SETCOOKIE]) {
		undef $I{$_} if $I{$_};
	}

	$I{r} = Apache->request if $ENV{GATEWAY_INTERFACE} =~ m|^CGI-Perl/|;
	sqlConnect();

	$I{query} = new CGI;

	# fields that are numeric only
	my %nums = map {($_ => 1)} qw(
		last next artcount bseclev cid clbig clsmall
		commentlimit commentsort commentspill commentstatus
		del displaystatus filter_id height
		highlightthresh isolate issue maillist max
		maxcommentsize maximum_length maxstories min minimum_length
		minimum_match ordernum pid
		retrieve seclev startat uid uthreshold voters width
		writestatus ratio
	);

	# regexes to match dynamically generated numeric fields
	my @regints = (qr/^reason_.+$/, qr/^votes.+$/);

	# special few
	my %special = (
		sid => sub { $_[0] =~ s|[^A-Za-z0-9/.]||g },
	);

	for ($I{query}->param) {
		$I{F}{$_} = $I{query}->param($_);

		# clean up numbers
		if (exists $nums{$_}) {
			$I{F}{$_} = fixint($I{F}{$_});
		} elsif (exists $special{$_}) {
			$special{$_}->($I{F}{$_});
		} else {
			for my $ri (@regints) {
				$I{F}{$_} = fixint($I{F}{$_}) if /$ri/;
			}
		}
	}

	$I{F}{ssi} ||= '';
	$ENV{SCRIPT_NAME} ||= '';

	($I{anon_name}) = sqlSelect('nickname', 'users', 'uid=-1') unless $I{anon_name};

	my $op = $I{query}->param('op') || '';

	if (($op eq 'userlogin' || $I{query}->param('rlogin') )
		&& length($I{F}{upasswd}) > 1) {

		$I{U} = getUser(userLogin($I{F}{unickname}, $I{F}{upasswd}));

	} elsif ($op eq 'userclose' ) {
		$I{SETCOOKIE} = setCookie('user', ' ');

	} elsif ($op eq 'adminclose') {
		$I{SETCOOKIE} = setCookie('session', ' ');

	} elsif ($I{query}->cookie('user')) {
		$I{U} = getUser(userCheckCookie($I{query}->cookie('user')));

	} else {
		$I{U} ||= getUser(-1);
	}

	return 1;
}

########################################################
# Quick Form Creation Functions

# Generic way to convert a table into a drop down list
sub selectGeneric {
	my($table, $label, $code, $name, $default, $where, $order, $limit) = @_;
	$default = '' unless defined $default;
	$code 	 = '' unless defined $code;

	print qq!\n<SELECT name="$label">\n!;

	my $sql	=  " SELECT $code,$name FROM $table ";
	$sql	.= "    WHERE $where" if $where;
	$sql	.= "	ORDER BY $name" unless $order;
	$sql	.= " ORDER BY $order" if $order;
	$sql	.= "    LIMIT $limit" if $limit;

	my $c	= $I{dbh}->prepare_cached($sql);
	$c->execute;

	while (my($code, $name) = $c->fetchrow) {
		my $selected = $default eq $code ? ' SELECTED' : '';
		print qq!\t<OPTION value="$code"$selected>$name</OPTION>\n!;
	}

	$c->finish;
	print "</SELECT>\n";
}

########################################################
# This really is an obsolete function for quick form generation
sub selectForm {
	my($table, $label, $default, $where) = @_;
	selectGeneric($table, $label, 'code', 'name', $default, $where, 'name');
}

########################################################
sub selectTopic {
	my($name, $tid) = @_;
	getTopicBank();

	my $o = qq!<SELECT NAME="$name">\n!;
	foreach my $thistid (sort keys %{$I{topicBank}}) {
		my $T = $I{topicBank}{$thistid};
		my $selected = $T->{tid} eq $tid ? ' SELECTED' : '';
		$o .= qq!\t<OPTION VALUE="$T->{tid}"$selected>$T->{alttext}</OPTION>\n!;
	}
	$o .= "</SELECT>\n";
	print $o;
}

########################################################
# Drop down list of available sections (based on admin seclev)
sub selectSection {
	my($name, $section, $SECT) = @_;
	getSectionBank();

	if ($SECT->{isolate}) {
		print qq!<INPUT TYPE="hidden" NAME="$name" VALUE="$section">\n!;
		return;
	}

	my $o = qq!<SELECT NAME="$name">\n!;
	foreach my $s (sort keys %{$I{sectionBank}}) {
		my $S = $I{sectionBank}{$s};
		next if $S->{isolate} && $I{U}{aseclev} < 500;
		my $selected = $s eq $section ? ' SELECTED' : '';
		$o .= qq!\t<OPTION VALUE="$s"$selected>$S->{title}</OPTION>\n!;
	}
	$o .= "</SELECT>";
	print $o;
}

########################################################
sub selectSortcode {
	# Get a sortcode hash
	unless ($I{sortcodeBank}) {
		my $c = sqlSelectMany('code,name', 'sortcodes');
		while (my($id, $desc) = $c->fetchrow) {
			$I{sortcodeBank}{$id} = $desc;
		}
		$c->finish;
	}

	my $o .= qq!<SELECT NAME="commentsort">\n!;
	foreach my $id (keys %{$I{sortcodeBank}}) {
		my $selected = $id eq $I{U}{commentsort} ? ' SELECTED' : '';
		$o .= qq!<OPTION VALUE="$id"$selected>$I{sortcodeBank}{$id}</OPTION>\n!;
	}
	$o .= "</SELECT>";
	return $o;
}

########################################################
sub selectMode {
	unless ($I{modeBank}) {
		my $c = sqlSelectMany('mode,name', 'commentmodes');
		while (my($id,$desc) = $c->fetchrow) {
			$I{modeBank}{$id} = $desc;
		}
		$c->finish;
	}

	my $o .= qq!<SELECT NAME="mode">\n!;
	foreach my $id (keys %{$I{modeBank}}) {
		my $selected = $id eq $I{U}{mode} ? ' SELECTED' : '';
		$o .= qq!<OPTION VALUE="$id"$selected>$I{modeBank}{$id}</OPTION>\n!;
	}
	$o .= "</SELECT>";
	return $o;
}

#############################################################################
# Functions for dealing with Blocks (big chunks of data)
sub getblock {
	my($bid) = @_;
	getBlockBank();
	return $I{blockBank}{$bid}; # unless $blockBank{$bid} eq "-1";
}


########################################################
# Blank the block cache.
sub nukeBlockCache {
	undef $I{blockBank};
}

########################################################
sub getBlockBank {
	return if $I{blockBank}{cached};
	$I{blockBank}{cached} = localtime;

	my $c = sqlSelectMany('bid,block', 'blocks');
	while (my($thisbid, $thisblock) = $c->fetchrow) {
		$I{blockBank}{$thisbid} = $thisblock;
	}
	$c->finish;
}

########################################################
# Gets a block.  Stores a block.  Returns a block.  Future requests read
# from cache.  Nice and quick.
sub blockCache {
	my($bid) = @_;
	getBlockBank();
	return $I{blockBank}{$bid}; # unless $blockBank{$bid} eq "-1");
}

########################################################
# Prep for evaling (no \r allowed)
sub prepEvalBlock {
	my($b) = @_;
	$b =~ s/\r//g;
	return $b;
}

########################################################
# Preps a block for evaling (escaping out " mostly)
sub prepBlock {
	my($b) = @_;
	$b =~ s/\r//g;
	$b =~ s/"/\\"/g;
	$b = qq!"$b";!;
	return $b;
}

########################################################
# Gets a block, and ready's it for evaling
sub getEvalBlock {
	my($name) = @_;
	my $block = getSectionBlock($name);
	my $execme = prepEvalBlock($block);
	return $execme;
}

########################################################
# Gets the appropriate block depending on your section
# or else fall back to one that exists
sub getSectionBlock {
	my $name = shift;
	my $thissect = $I{U}{light} ? 'light' : $I{currentSection};
	my $block;
	if ($thissect) {
		$block = blockCache($thissect . "_$name");
	}
	$block ||= blockCache($name);
	return $block;
}

########################################################
# Get a Block based on mode, section & name, and prep it for evaling
sub getWidgetBlock {
	my $name = shift;
	my $block = getSectionBlock($name);
	my $execme = prepBlock($block);
	return $execme;
}

###############################################################################
# Functions for dealing with vars (system config variables)

########################################################
sub getvars {
	my(@invars, @vars) = @_;

	for (@invars) {
		push @vars, sqlSelect('value', 'vars', "name='$_'");
	}

	return @vars;
}

########################################################
sub getvar {
	my($value, $desc) = sqlSelect('value,description', 'vars', "name='$_[0]'");
}

########################################################
sub setvar {
	my($name, $value) = @_;
	sqlUpdate('vars', {value => $value}, 'name=' . $I{dbh}->quote($name));
}

########################################################
sub newvar {
	my($name, $value, $desc) = @_;
	sqlInsert('vars', {name => $name, value => $value, description => $desc});
}

###############################################################################
#  Stuff for dealing with Logging In
#
# It does what it says, it says what it does.
########################################################
sub userLogin {
	my($name, $passwd) = @_;

	$passwd = substr $passwd, 0, 12;
	my($uid) = sqlSelect('uid', 'users',
		'passwd=' . $I{dbh}->quote($passwd) .
		' AND nickname=' . $I{dbh}->quote($name)
	);

	if ($uid > 0) {
		my $cookie = $uid . '::' . $passwd;
		$cookie =~ s/(.)/sprintf("%%%02x",ord($1))/ge;
		$I{SETCOOKIE} = setCookie('user', $cookie);
		return($uid, $passwd);
	} else {
		return(-1, '');
	}
}


########################################################
# Decode the Cookie: Cookies have all the special charachters encoded
# in standard URL format.  This converts it back.  then it is split
# on '::' to get the users info.
sub userCheckCookie {
	my($cookie) = @_;
	$cookie =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack('C', hex($1))/eg;
	my($uid, $passwd) = split('::', $cookie);
	return(-1, '') if $uid eq ' ';
	return($uid, $passwd);
}

########################################################
# Replace $_[0] with $_[1] || "0" in the User Hash
# users by getUser to allow form parameters to override user parameters
sub overRide {
	my($p, $d) = @_;
	if (defined $I{query}->param($p)) {
		$I{U}{$p} = $I{query}->param($p);
	} else {
		$I{U}{$p} ||= $d || '0';
	}
}

########################################################
# Add this hashref to $U
sub addToUser {
	my $H = shift;
	@{$I{U}}{ keys %$H } = values %$H;
}

########################################################
# Get users_$_ and at it to $U
sub getExtraStuff {
	my $s = shift;
	my $H = sqlSelectHashref('*', "users_$s", "uid=$I{U}{uid}");
	addToUser($H);
}

########################################################
# IF passed a valid uid & passwd, it logs in $U
# else $U becomes Anonymous Coward (eg UID -1)
sub getUser {
	my($uid, $passwd) = @_;
	undef $I{U};

	if ($uid > 0) { # Authenticate
		$I{U} = sqlSelectHashref('*', 'users',
			' uid = ' . $I{dbh}->quote($uid) .
			' AND passwd = ' . $I{dbh}->quote($passwd)
		);
	}

	if ($uid > 0 && $I{U}{uid}) { #  registered user
		# Get User Prefs
		getExtraStuff('prefs');

		# Get the Timezone Stuff
		unless (defined $I{timezones}) {
			my $c = sqlSelectMany('tz,offset', 'tzcodes');
			while (my($tzcode, $offset) = $c->fetchrow) {
				$I{timezones}{$tzcode} = $offset;
			}
			$c->finish;
		}

		$I{U}{offset} = $I{timezones}{ $I{U}{tzcode} };

		unless (defined $I{dateformats}) {
			my $c = sqlSelectMany('id,format', 'dateformats');
			while (my($dfid, $dateformat) = $c->fetchrow) {
				$I{dateformats}{$dfid} = $dateformat;
			}
			$c->finish;
		}

		$I{U}{'format'} = $I{dateformats}{ $I{U}{dfid} };

		# Do we want the comments stuff?
		if (!$ENV{SCRIPT_NAME}
			|| $ENV{SCRIPT_NAME} =~ /index|article|comments|metamod|search|pollBooth/) {
			getExtraStuff('comments');
		}

		# Do we want the index stuff?
		if (!$ENV{SCRIPT_NAME} || $ENV{SCRIPT_NAME} =~ /index/) {
			getExtraStuff('index');
		}

	} else {
		getAnonCookie();
		$I{SETCOOKIE} = setCookie('anon', $I{U}{anon_id}, 1);

		unless ($I{AC}) {
			# Get ourselves an AC if we don't already have one.
			# (we have to get it /all/ remember!)
			$I{AC} = sqlSelectHashref('*',
				'users, users_index, users_comments, users_prefs',
				'users.uid=-1 AND users_index.uid=-1 AND ' .
				'users_comments.uid=-1 AND users_prefs.uid=-1'
			);

			# timezone stuff
		 	$I{ACTZ} = sqlSelectHashref('*',
				'tzcodes,dateformats',
				"tzcodes.tz='$I{AC}{tzcode}' AND dateformats.id=$I{AC}{dfid}"
			);

			@{$I{AC}}{ keys %{$I{ACTZ}} } = values %{$I{ACTZ}};
		}

		addToUser($I{AC});

	}

	# Add On Admin Junk
	if ($I{F}{op} eq 'adminlogin') {
		($I{U}{aid}, $I{U}{aseclev}) =
			setAdminInfo($I{F}{aaid}, $I{F}{apasswd});

	} elsif (length($I{query}->cookie('session')) > 3) {
		(@{$I{U}}{qw[aid aseclev asection url]}) =
			getAdminInfo($I{query}->cookie('session'));

	} else {
		$I{U}{aid} = '';
		$I{U}{aseclev} = 0;
	}

	# Set a few defaults
	overRide('mode', 'thread');
	overRide('savechanges');
	overRide('commentsort');
	overRide('threshold');
	overRide('posttype');
	overRide('noboxes');
	overRide('light');


	$I{currentMode} = $I{U}{mode};

	$I{U}{seclev} = $I{U}{aseclev} if $I{U}{aseclev} > $I{U}{seclev};

	$I{U}{breaking}=0;

	if ($I{U}{commentlimit} > $I{breaking} && $I{U}{mode} ne 'archive') {
		$I{U}{commentlimit} = int($I{breaking} / 2);
		$I{U}{breaking} = 1;
	}

	# All sorts of checks on user data
	$I{U}{tzcode}	= uc($I{U}{tzcode});
	$I{U}{clbig}	||= 0;
	$I{U}{clsmall}	||= 0;
	$I{U}{exaid}	= testExStr($I{U}{exaid}) if $I{U}{exaid};
	$I{U}{exboxes}	= testExStr($I{U}{exboxes}) if $I{U}{exboxes};
	$I{U}{extid}	= testExStr($I{U}{extid}) if $I{U}{extid};
	$I{U}{points}	= 0 unless $I{U}{willing}; # No points if you dont want 'em

	return $I{U};
}

########################################################
# Handles admin logins (checks the sessions table for a cookie that
# matches).  Called by getSlash
sub getAdminInfo {
	my($session) = @_;

	$I{dbh}->do("DELETE from sessions WHERE now() > DATE_ADD(lasttime, INTERVAL $I{admin_timeout} MINUTE)");

	my($aid, $seclev, $section, $url) = sqlSelect(
		'sessions.aid, authors.seclev, section, url',
		'sessions, authors',
		'sessions.aid=authors.aid AND session=' . $I{dbh}->quote($session)
	);

	unless ($aid) {
		return('', 0, '', '');
	} else {
		$I{dbh}->do("DELETE from sessions WHERE aid = '$aid' AND session != " .
			$I{dbh}->quote($session)
		);
		sqlUpdate('sessions', {-lasttime => 'now()'},
			'session=' . $I{dbh}->quote($session)
		);
		return($aid, $seclev, $section, $url);
	}
}

########################################################
# Initial Administrator Login.
sub setAdminInfo {
	my($aid, $pwd) = @_;

	if (my($aid, $seclev) = sqlSelect('aid,seclev', 'authors',
			'aid=' . $I{dbh}->quote($aid) .
			' AND pwd=' . $I{dbh}->quote($pwd) ) ) {
		my $sid = generatesession($aid);
		my($title) = sqlSelect('lasttitle', 'sessions',
			'aid=' . $I{dbh}->quote($aid)
		);

		$I{dbh}->do('DELETE FROM sessions WHERE aid=' . $I{dbh}->quote($aid) );

		sqlInsert('sessions', { session => $sid, aid => $aid,
			-logintime => 'now()', -lasttime => 'now()',
			lasttitle => $title }
		);
		$I{SETCOOKIE} = setCookie('session', $sid);
		return($aid, $seclev);
	} else {
		return('', 0);
	}
}

###############################################################
#  What is it?  Where does it go?  The Random Leftover Shit

########################################################
sub setCookie {
	my($name, $val, $session) = @_;

	# domain must start with a . and have one more .
	# embedded in it, else we ignore it
	my $domain = $I{cookiedomain} &&
		$I{cookiedomain} =~ /^\..+\./ ? $I{cookiedomain} : '';

	my %cookie = (
		-name		=> $name,
		-path		=> $I{cookiepath},
		-value		=> $val,
	);

	$cookie{-expires} = '+1y' unless $session;
	$cookie{-domain}  = $domain if $domain;

	return {
		-date		=> CGI::expires(0, 'http'),
		-set_cookie	=> $I{query}->cookie(%cookie)
	};
}


########################################################
# Returns YY/MM/DD/HHMMSS all ready to be inserted
sub getsid {
	my($sec, $min, $hour, $mday, $mon, $year) = localtime;
	$year = $year % 100;
	my $sid = sprintf('%02d/%02d/%02d/%02d%0d2%02d',
		$year, $mon+1, $mday, $hour, $min, $sec);
	return $sid;
}

########################################################
# Get a unique string for an admin session
sub generatesession {
	my $newsid = crypt(rand(99999), shift);
	$newsid =~ s/[^A-Za-z0-9]//i;
	return $newsid;
}


########################################################
# Returns the directory (eg YY/MM/DD/) that stories are being written in today
sub getsiddir {
	my($mday, $mon, $year) = (localtime)[3, 4, 5];
	$year = $year % 100;
	my $sid = sprintf('%02d/%02d/%02d/', $year, $mon+1, $mday);
	return $sid;
}

########################################################
# writes error message to apache's error_log if we're running under mod_perl
# Called wherever we have errors.
sub apacheLog {
	if ($I{r}) {
		$I{r}->log_error("$ENV{SCRIPT_NAME}:@_");
	} else {
		print @_, "\n";
	}
	return 0;
}

########################################################
# Saves an entry to the access log for static pages
# typically called now as part of getAd()
sub anonLog {
	my($op, $data) = ('/', '');
	$I{U}{uid} = -1;

	$_ = $ENV{REQUEST_URI};
	s/(.*)\?/$1/;
	if (/404/) {
		$op = '404';
	} elsif (m[/(.*?)/(.*).shtml]) {
		($op, $data) = ($1,$2);
	} elsif (m[/(.*).shtml]) {
		$op = $1;
	} elsif (m[/(.+)]) {
		$data = $op = $1;
	} else {
		$data = $op = 'index';
	}

	$data =~ s/_F//;
	$op =~ s/_F//;

	writelog($op, $data);
}

########################################################
sub writelog {
	my $op = shift;
	my $dat = join("\t", @_);

	sqlInsert('accesslog', {
		host_addr	=> $ENV{REMOTE_ADDR} || '0',
		dat		=> $dat,
		uid		=> $I{U}{uid} || '-1',
		op		=> $op,
		-ts		=> 'now()',
		query_string	=> $ENV{QUERY_STRING} || '0',
		user_agent	=> $ENV{HTTP_USER_AGENT} || '0',
	}, 2);

	if ($dat =~ m[/]) {
		sqlUpdate('storiestuff', { -hits => 'hits+1' },
			'sid=' . $I{dbh}->quote($dat)
		);
	} elsif ($op eq 'index') {
		# Update Section Counter
	}
}


########################################################
# Takes the address, subject and an email, and does what it says
# used by dailyStuff, users.pl, and someday submit.pl
sub sendEmail {
	my($addr, $subject, $content) = @_;
	sendmail(
		smtp	=> $I{smtp_server},
		subject	=> $subject,
		to	=> $addr,
		body	=> $content,
		from	=> $I{mailfrom}
	) or apacheLog("Can't send mail '$subject' to $addr: $Mail::Sendmail::error");
}


########################################################
# The generic "Link a Story" function, used wherever stories need linking
sub linkStory {
	my $c = shift;
	my($l, $dynamic);

	if ($I{currentMode} ne 'archive' && ($ENV{SCRIPT_NAME} || !$c->{section})) {
		$dynamic = 1 if $c->{mode} || exists $c->{threshold} || $ENV{SCRIPT_NAME};
		$l .= '&mode=' . ($c->{mode} || $I{U}{mode});
		$l .= "&threshold=$c->{threshold}" if exists $c->{threshold};
	}

	return qq!<A HREF="$I{rootdir}/! .
		($dynamic ? "article.pl?sid=$c->{sid}$l" : "$c->{section}/$c->{sid}.shtml") .
		qq!">$c->{'link'}</A>!;
			# "$c->{section}/$c->{sid}$userMode".".shtml").
}

########################################################
# Sets the appropriate @fg and @bg color pallete's based
# on what section you're in.  Used during initialization
sub getSectionColors {
	my $color_block = shift;
	my @colors;

	# they damn well better be legit
	if ($I{F}{colorblock}) {
		@colors = map { s/[^\w#]+//g ; $_ } split m/,/, $I{F}{colorblock};
	} else {
		@colors = split m/,/, getSectionBlock('colors');
	}

	$I{fg} = [@colors[0..3]];
	$I{bg} = [@colors[4..7]];
}

########################################################
sub getSectionBank {
	return if keys %{$I{sectionBank}};
	my $c = sqlSelectMany('*', 'sections');
	while (my $S = $c->fetchrow_hashref) {
		$I{sectionBank}{ $S->{section} } = $S;
	}
	$c->finish;
}


########################################################
# Gets sections wherver needed.  if blank, gets settings for homepage, and
# if defined tries to use cache.
sub getSection {
	my $section = shift;
	return { title => $I{slogan}, artcount => $I{U}{maxstories} || 30, issue => 3 }
		unless $section;
	return $I{sectionBank}{$section} if $I{sectionBank}{$section};
	getSectionBank();
	return $I{sectionBank}{$section};
}

########################################################
sub getTopicBank {
	return if keys %{$I{topicBank}};
	my $c = sqlSelectMany('*', 'topics');
	while (my $T = $c->fetchrow_hashref) {
		$I{topicBank}{ $T->{tid} } = $T;
	}
	$c->finish;
}

########################################################
sub getTopic {
	my $topic = shift;
	return $I{topicBank}{$topic} if $I{topicBank}{$topic};
	getTopicBank();
	return $I{topicBank}{$topic};
}

########################################################
sub getAuthor {
	my $aid = shift;

	return $I{authorBank}{$aid} if $I{authorBank}{$aid};
	# Get all the authors and throw them in a hash for later use:
	my $c = sqlSelectMany('*', 'authors');
	while (my $A = $c->fetchrow_hashref) {
		$I{authorBank}{ $A->{aid} } = $A;
	}
	$c->finish;
	return $I{authorBank}{$aid};
}


################################################################################
# SQL Timezone things
sub getDateOffset {
	my $col = shift || return;
	return $col unless $I{U}{offset};
	return " DATE_ADD($col, INTERVAL $I{U}{offset} SECOND) ";
}

########################################################
sub getDateFormat {
	my $col = shift || return;
	my $as = shift || 'time';

	$I{U}{'format'} ||= '%W %M %d, @%h:%i%p ';
	unless ($I{U}{tzcode}) {
		$I{U}{tzcode} = 'EDT';
		$I{U}{offset} = '-14400';
	}

	$I{U}{offset} ||= '0';
	return ' CONCAT(DATE_FORMAT(' . getDateOffset($col) .
		qq!,"$I{U}{'format'}")," $I{U}{tzcode}") as $as !;
}

###############################################################################
# Dealing with Polls

########################################################
sub latestpoll {
	my($qid) = sqlSelect('qid', 'pollquestions', '', 'ORDER BY date DESC LIMIT 1');
	return $qid;
}

########################################################
sub pollbooth {
	my($qid, $notable) = @_;

	($qid) = getvar("currentqid") unless $qid;
	my $qid_dbi = $I{dbh}->quote($qid);
	my $qid_htm = stripByMode($qid, 'attribute');

	my $cursor = $I{dbh}->prepare_cached("
		SELECT question,answer,aid  from pollquestions, pollanswers
		WHERE pollquestions.qid=pollanswers.qid AND
			pollquestions.qid=$qid_dbi
		ORDER BY pollanswers.aid
	");
	$cursor->execute;

	my($x, $tablestuff) = (0);
	while (my($question, $answer, $aid) = $cursor->fetchrow) {
		if ($x == 0) {
			$tablestuff = <<EOT;
<FORM ACTION="$I{rootdir}/pollBooth.pl">
\t<INPUT TYPE="hidden" NAME="qid" VALUE="$qid_htm">
<B>$question</B>
EOT
			$tablestuff .= <<EOT if $I{currentSection};
\t<INPUT TYPE="hidden" NAME="section" VALUE="$I{currentSection}">
EOT
			$x++;
		}
		$tablestuff .= qq!<BR><INPUT TYPE="radio" NAME="aid" VALUE="$aid">$answer\n!;
	}

	my($voters) = sqlSelect('voters', 'pollquestions', " qid=$qid_dbi");
	my($comments) = sqlSelect('count(*)', 'comments', " sid=$qid_dbi");
	my $sect = "section=$I{currentSection}&" if $I{currentSection};

	$tablestuff .= qq!<BR><INPUT TYPE="submit" VALUE="Vote"> ! .
		qq![ <A HREF="$I{rootdir}/pollBooth.pl?${sect}qid=$qid_htm&aid=-1"><B>Results</B></A> | !;
	$tablestuff .= qq!<A HREF="$I{rootdir}/pollBooth.pl?$sect"><B>Polls</B></A> !
		unless $notable eq 'rh';
	$tablestuff .= "Votes:<B>$voters</B>" if $notable eq 'rh';
	$tablestuff .= " ] <BR>\n";
	$tablestuff .= "Comments:<B>$comments</B> | Votes:<B>$voters</B>\n" if $notable ne 'rh';
	$tablestuff .="</FORM>\n";
	$cursor->finish;

	return $tablestuff if $notable;
	fancybox(200, 'Poll', $tablestuff, 'c');
}


########################################################
# Useful SQL Wrapper Functions
########################################################

########################################################
sub sqlSelectMany {
	my($select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "   FROM $from " if $from;
	$sql .= "  WHERE $where " if $where;
	$sql .= "        $other" if $other;

	sqlConnect();
	my $c = $I{dbh}->prepare_cached($sql);
	if ($c->execute) {
		return $c;
	} else {
		$c->finish;
		apacheLog($sql);
		die;
		return undef;
	}
}

########################################################
sub sqlSelect {
	my($select, $from, $where, $other) = @_;
	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	sqlConnect();
	my $c = $I{dbh}->prepare_cached($sql) or die "Sql has gone away\n";
	if (!$c->execute) {
		apacheLog($sql);
		# print "\n<P><B>SQL Error</B><BR>\n";
		# kill 9,$$;
		return undef;
	}

	my @r = $c->fetchrow;
	$c->finish;
	return @r;
}

########################################################
sub sqlSelectHash {
	my $H = sqlSelectHashref(@_);
	return map { $_ => $H->{$_} } keys %$H;
}

##########################################################
# selectCount 051199
# inputs: scalar string table, scaler where clause
# returns: via ref from input
# Simple little function to get the count of a table
##########################################################
sub selectCount  {
	my $table = shift;
	my $where = shift;

	my $sql = "SELECT count(*) AS count FROM $table $where";
	# we just need one stinkin value - count
	my $c = $I{dbh}->selectall_arrayref($sql);
	return $c->[0][0];  # count
}

########################################################
sub sqlSelectHashref {
	my($select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	sqlConnect();
	my $c = $I{dbh}->prepare_cached($sql);
	# $c->execute or print "\n<P><B>SQL Hashref Error</B><BR>\n";

	unless ($c->execute) {
		apacheLog($sql);
		#kill 9,$$;
	}
	my $H = $c->fetchrow_hashref;
	$c->finish;
	return $H;
}

########################################################
# sqlSelectAll - this function returns the entire
# array ref of all records selected. Use this in the case
# where you want all the records and have to do a time consuming
# process that would tie up the db handle for too long.
#
# inputs:
# select - columns selected
# from - tables
# where - where clause
# other - limit, asc ...
#
# returns:
# array ref of all records
sub sqlSelectAll {
	my($select, $from, $where, $other) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM $from " if $from;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	sqlConnect();
	my $H = $I{dbh}->selectall_arrayref($sql);
	return $H;
}

########################################################
sub sqlUpdate {
	my($table, $data, $where, $lp) = @_;
	$lp = 'LOW_PRIORITY' if $lp;
	$lp = '';
	my $sql = "UPDATE $lp $table SET";
	foreach (keys %$data) {
		if (/^-/) {
			s/^-//;
			$sql .= "\n  $_ = $data->{-$_},";
		} else {
			# my $d=$I{dbh}->quote($data->{$_}) || "''";
			$sql .= "\n $_ = " . $I{dbh}->quote($data->{$_}) . ',';
		}
	}
	chop $sql;
	$sql .= "\nWHERE $where\n";
	return $I{dbh}->do($sql) or apacheLog($sql);
}

########################################################
sub sqlReplace {
	my($table, $data) = @_;
	my($names, $values);

	foreach (keys %$data) {
		if (/^-/) {
			$values .= "\n  $data->{$_},";
			s/^-//;
		} else {
			$values .= "\n  " . $I{dbh}->quote($data->{$_}) . ',';
		}
		$names .= "$_,";
	}

	chop($names);
	chop($values);

	my $sql = "REPLACE INTO $table ($names) VALUES($values)\n";
	sqlConnect();
	return $I{dbh}->do($sql) or apacheLog($sql);
}

########################################################
sub sqlInsert {
	my($table, $data, $delay) = @_;
	my($names, $values);

	foreach (keys %$data) {
		if (/^-/) {
			$values .= "\n  $data->{$_},";
			s/^-//;
		} else {
			$values .= "\n  " . $I{dbh}->quote($data->{$_}) . ',';
		}
		$names .= "$_,";
	}

	chop($names);
	chop($values);

	my $p = 'DELAYED' if $delay;
	my $sql = "INSERT $p INTO $table ($names) VALUES($values)\n";
	sqlConnect();
	return $I{dbh}->do($sql) or apacheLog($sql) && kill 9, $$;
}

########################################################
sub sqlTableExists {
	my $table = shift or return;

	my $c = $I{dbh}->prepare_cached(qq!SHOW TABLES LIKE "$table"!);
	$c->execute;
	my $te = $c->rows;
	$c->finish;
	return $te;
}

########################################################
sub sqlSelectColumns {
	my $table = shift or return;

	my $c = $I{dbh}->prepare_cached("SHOW COLUMNS FROM $table");
	$c->execute;
	my @ret;
	while (my @d = $c->fetchrow) {
		push @ret, $d[0];
	}
	$c->finish;
	return @ret;
}

########################################################
sub sqlConnect {
	$I{dbh} ||= DBI->connect(@I{qw[dsn dbuser dbpass]}) or die $DBI::errstr;

	kill 9, $$ unless $I{dbh};	 # The Suicide Die
	# return \$dbh;
}

###############################################################################
#
# Some Random Dave Code for HTML validation
# (pretty much the last legacy of daveCode[tm] by demaagd@imagegroup.com
#

########################################################
sub stripByMode {
	my $str = shift;
	my $fmode = shift || 'nohtml';

	$str =~ s/(\S{90})/$1 /g;
	if ($fmode eq 'literal' || $fmode eq 'exttrans' || $fmode eq 'attribute') {
		# Encode all HTML tags
		$str =~ s/&/&amp;/g;
		$str =~ s/</&lt;/g;
		$str =~ s/>/&gt;/g;
	}

	# this "if" block part of patch from Ben Tilly
	if ($fmode eq 'plaintext' || $fmode eq 'exttrans') {
		$str = stripBadHtml($str);
		$str =~ s/\n/<BR>/gi;  # pp breaks
		$str =~ s/(?:<BR>\s*){2,}<BR>/<BR><BR>/gi;
		# Preserve leading indents
		$str =~ s/\t/    /g;
		$str =~ s/<BR>\n?( +)/"<BR>\n" . ("&nbsp; " x length($1))/ieg;

	} elsif ($fmode eq 'nohtml') {
		$str =~ s/<.*?>//g;
		$str =~ s/<//g;
		$str =~ s/>//g;

	} elsif ($fmode eq 'attribute') {
		$str =~ s/"/&#22;/g;

	} else {
		$str = stripBadHtml($str);
	}

	return $str;
}

########################################################
sub stripBadHtml  {
	my $str = shift;

	$str =~ s/<(?!.*?>)//gs;
	$str =~ s/<(.*?)>/approveTag($1)/sge;

	$str =~ s/></> </g;

	return $str;
}

########################################################
sub fixHref {
	my($rel_url, $print_errs) = @_;
	my $abs_url; # the "fixed" URL
	my $errnum; # the errnum for 404.pl

	for my $qr (@{$I{fixhrefs}}) {
		if ($rel_url =~ $qr->[0]) {
			my @ret = $qr->[1]->($rel_url);
			return $print_errs ? @ret : $ret[0];
		}
	}

	if ($rel_url =~ /^www\.\w+/) {
		# errnum 1
		$abs_url = "http://$rel_url";
		return($abs_url, 1) if $print_errs;
		return $abs_url;

	} elsif ($rel_url =~ /^ftp\.\w+/) {
		# errnum 2
		$abs_url = "ftp://$rel_url";
		return ($abs_url, 2) if $print_errs;
		return $abs_url;

	} elsif ($rel_url =~ /^[\w\-\$\.]+\@\S+/) {
		# errnum 3
		$abs_url = "mailto:$rel_url";
		return ($abs_url, 3) if $print_errs;
		return $abs_url;

	} elsif ($rel_url =~ /^articles/ && $rel_url =~ /\.shtml$/) {
		# errnum 6
		my @chunks = split m|/|, $rel_url;
		my $file = pop @chunks;

		if ($file =~ /^98/ || $file =~ /^0000/) {
			$rel_url = "$I{rootdir}/articles/older/$file";
			return ($rel_url, 6) if $print_errs;
			return $rel_url;
		} else {
			return;
		}

	} elsif ($rel_url =~ /^features/ && $rel_url =~ /\.shtml$/) {
		# errnum 7
		my @chunks = split m|/|, $rel_url;
		my $file = pop @chunks;

		if ($file =~ /^98/ || $file =~ /~00000/) {
			$rel_url = "$I{rootdir}/features/older/$file";
			return ($rel_url, 7) if $print_errs;
			return $rel_url;
		} else {
			return;
		}

	} elsif ($rel_url =~ /^books/ && $rel_url =~ /\.shtml$/) {
		# errnum 8
		my @chunks = split m|/|, $rel_url;
		my $file = pop @chunks;

		if ($file =~ /^98/ || $file =~ /^00000/) {
			$rel_url = "$I{rootdir}/books/older/$file";
			return ($rel_url, 8) if $print_errs;
			return $rel_url;
		} else {
			return;
		}

	} elsif ($rel_url =~ /^askslashdot/ && $rel_url =~ /\.shtml$/) {
		# errnum 9
		my @chunks = split m|/|, $rel_url;
		my $file = pop @chunks;

		if ($file =~ /^98/ || $file =~ /^00000/) {
			$rel_url = "$I{rootdir}/askslashdot/older/$file";
			return ($rel_url, 9) if $print_errs;
			return $rel_url;
		} else {
			return;
		}

	} else {
		# if we get here, we don't know what to
		# $abs_url = $rel_url;
		return;
	}

	# just in case
	return $abs_url;
}

########################################################
sub approveTag {
	my $tag = shift;

	$tag =~ s/^\s*?(.*)\s*?$/$1/; # trim leading and trailing spaces

	$tag =~ s/\bstyle\s*=(.*)$//i; # go away please

	# Take care of URL:foo and other HREFs
	if ($tag =~ /^URL:(.+)$/i) {
		my $url = fixurl($1);
		return qq!<A HREF="$url">$url</A>!;
	} elsif ($tag =~ /href\s*=(.+)$/i) {
		my $url = fixurl($1);
		return qq!<A HREF="$url">!;
	}

	# Validate all other tags
	$tag =~ s|^(/?\w+)|\U$1|;
	foreach my $goodtag (@{$I{approvedtags}}) {
		return "<$tag>" if $tag =~ /^$goodtag$/ || $tag =~ m|^/$goodtag$|;
	}
}

########################################################
sub fixurl {
	my $url = shift;
	$url =~ s/[" ]//g;
	$url =~ s/^'(.+?)'$/$1/g;
	# encode all non-safe, non-reserved characters
	$url =~ s/([^\w.+!*'(),;?:@=&\$\/%#-])/sprintf "%%%02X", ord $1/ge;
	$url = fixHref($url) || $url;
	my $decoded_url = decode_entities($url);
	return $decoded_url =~ s|^\s*\w+script\b.*$||i ? undef : $url;
}

########################################################
sub fixint {
	my $int = shift;
	$int =~ s/^\+//;
	$int =~ s/^(-?[\d.]+).*$/$1/ or return;
	return $int;
}

###############################################################################
# Look and Feel Functions Follow this Point

########################################################
sub ssiHead {
	(my $dir = $I{rootdir}) =~ s|^http://[^/]+||;
	print "<!--#include virtual=\"$dir/";
	print "$I{currentSection}/" if $I{currentSection};
	print "slashhead$I{userMode}",".inc\"-->\n";
}

########################################################
sub ssiFoot {
	(my $dir = $I{rootdir}) =~ s|^http://[^/]+||;
	print "<!--#include virtual=\"$dir/";
	print "$I{currentSection}/" if $I{currentSection};
	print "slashfoot$I{userMode}",".inc\"-->\n";
}

########################################################
sub adminMenu {
	my $seclev = $I{U}{aseclev};
	return unless $seclev;
	print <<EOT;

<TABLE BGCOLOR="$I{bg}[2]" BORDER="0" WIDTH="100%" CELLPADDING="2" CELLSPACING="0">
	<TR><TD><FONT SIZE="${\( $I{fontbase} + 2 )}">
EOT

	print <<EOT if $seclev > 0;
	[ <A HREF="$I{rootdir}/admin.pl?op=adminclose">Logout $I{U}{aid}</A>
	| <A HREF="$I{rootdir}/">Home</A>
	| <A HREF="$I{rootdir}/getting_started.shtml">Help</A>
	| <A HREF="$I{rootdir}/admin.pl">Stories</A>
	| <A HREF="$I{rootdir}/topics.pl?op=listtopics">Topics</A>
EOT

	print <<EOT if $seclev > 10;
	| <A HREF="$I{rootdir}/admin.pl?op=edit">New</A>
EOT

	my($cnt) = sqlSelect('count(*)', 'submissions',
		"(length(note)<1 or isnull(note)) and del=0" .
		($I{articles_only} ? " and section='articles'" : '')
	);

	print <<EOT if $seclev > 499;
	| <A HREF="$I{rootdir}/submit.pl?op=list">$cnt Submissions</A>
	| <A HREF="$I{rootdir}/admin.pl?op=blocked">Blocks</A>
	| <A HREF="$I{rootdir}/admin.pl?op=colored">Site Colors</A>
EOT

	print <<EOT if $seclev > 999 || ($I{U}{asection} && $seclev > 499);
	| <A HREF="$I{rootdir}/sections.pl?op=list">Sections</A>
	| <A HREF="$I{rootdir}/admin.pl?op=listfilters">Comment Filters</A>
EOT

	print <<EOT if $seclev >= 10000;
	| <A HREF="$I{rootdir}/admin.pl?op=authors">Authors</A>
	| <A HREF="$I{rootdir}/admin.pl?op=vars">Variables</A>
EOT

	print "] </FONT></TD></TR></TABLE>\n";
}

########################################################
sub formLabel {
	return qq!<P><FONT COLOR="$I{bg}[3]"><B>!, shift, "</B></FONT>\n",
		(@_ ? ('(', @_, ')') : ''), "<BR>\n";
}

########################################################
sub currentAdminUsers {
	my $o;
	my $c = sqlSelectMany('aid,now()-lasttime,lasttitle', 'sessions',
			      'aid=aid GROUP BY aid'
#		'aid!=' . $I{dbh}->quote($I{U}{aid}) . ' GROUP BY aid'
	);

	while (my($aid, $lastsecs, $lasttitle) = $c->fetchrow) {
		$o .= qq!\t<TR><TD BGCOLOR="$I{bg}[3]">\n!;
		$o .= qq!\t<A HREF="$I{rootdir}/admin.pl?op=authors&thisaid=$aid">!
			if $I{U}{aseclev} > 10000;
		$o .= qq!<FONT COLOR="$I{fg}[3]" SIZE="${\( $I{fontbase} + 2 )}"><B>$aid</B></FONT>!;
		$o .= '</A> ' if $I{U}{aseclev} > 10000;

		if ($aid eq $I{U}{aid}) {
		    $lastsecs = "-";
		} elsif ($lastsecs <= 99) {
		    $lastsecs .= "s";
		} elsif ($lastsecs <= 99*60) {
		    $lastsecs = int($lastsecs/60+0.5) . "m";
		} else {
		    $lastsecs = int($lastsecs/3600+0.5) . "h";
		}

		$lasttitle = "&nbsp;/&nbsp;$lasttitle" if $lasttitle && $lastsecs;

		$o .= qq!</TD><TD BGCOLOR="$I{bg}[2]"><FONT COLOR="$I{fg}[1]" SIZE="${\( $I{fontbase} + 2 )}">! .
		    "$lastsecs$lasttitle</FONT>&nbsp;</TD></TR>";
	}

	$c->finish;
	$o = <<EOT;
<TABLE HEIGHT="100%" BORDER="0" CELLPADDING="2" CELLSPACING="0">$o</TABLE>
EOT
	return $o;
}

########################################################
sub getAd {
	return "<!--#perl sub=\"sub { require Slash; use Slash; print Slash::getAd(); }\" -->"
		unless $ENV{SCRIPT_NAME};

	anonLog() unless $ENV{SCRIPT_NAME} =~ /\.pl/; # Log non .pl pages

	my $ad .= <<EOT;
<center>
$ENV{AD_BANNER_1}
</center>
<p>
EOT
	return $ad;
}

########################################################
sub redirect {
	my $url = URI->new_abs(shift, $I{rootdir})->canonical->as_string;

	my %params = (
		-type		=> 'text/html',
		-status		=> '302 Moved',
		-location	=> $url,
		($I{SETCOOKIE} ? %{$I{SETCOOKIE}} : ())
	);

	print CGI::header(%params), <<EOT;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML><HEAD><TITLE>302 Moved</TITLE></HEAD><BODY>
<P>You really want to be on <A HREF="$url">$url</A> now.</P>
</BODY>
EOT
}

########################################################
sub header {
	my($title, $section, $status) = @_;
	my $adhtml = '';
	$title ||= '';

	unless ($I{F}{ssi}) {
		my %params = (
			-cache_control => 'private',
			-type => 'text/html',
			($I{SETCOOKIE} ? %{$I{SETCOOKIE}} : ())
		);
		$params{-status} = $status if $status;
		$params{-pragma} = "no-cache"
			unless $I{U}{aseclev} || $ENV{SCRIPT_NAME} =~ /comments/;

		print CGI::header(%params);
	}

	$I{userMode} = $I{currentMode} eq 'flat' ? '_F' : '';
	$I{currentSection} = $section || '';
	getSectionColors();

	$title =~ s/<(.*?)>//g;

	print <<EOT if $title;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML><HEAD><TITLE>$title</TITLE>
EOT

	# ssi = 1 IS NOT THE SAME as ssi = 'yes'
	if ($I{F}{ssi} eq 'yes') {
		ssiHead($section);
		return;
	}

	if ($I{run_ads}) {
		$adhtml = getAd();
	}

	my $topics;
	unless ($I{U}{noicons} || $I{U}{light}) {
		$topics = blockCache('topics');
	}

	my $vertmenu = blockCache('mainmenu');
	my $menu = eval prepBlock($vertmenu);

	my $horizmenu = $menu;
	$horizmenu =~ s/^\s*//mg;
	$horizmenu =~ s/^-\s*//mg;
	$horizmenu =~ s/\s*$//mg;
	$horizmenu =~ s/<HR(?:>|\s[^>]*>)//g;
	$horizmenu = sprintf "[ %s ]", join ' | ', split /<BR>/, $horizmenu;

	my $sectionmenu = getSectionMenu();
	my $execme = getWidgetBlock('header');

	print eval $execme;
	print "\nError:$@\n" if $@;
	adminMenu();
}

########################################################
sub getSectionMenu {
	my $menu = getblock('sectionindex_html1');

	# the reason this is three calls is that sectionindex regularly is
	# updated by portald, so it's a more dynamic block
	$menu .= getblock('sectionindex');
	$menu .= getblock('sectionindex_html2');

	my $org_code = getEvalBlock('organisation');
	my $execme = prepEvalBlock($org_code);

	eval $execme;

	if ($@) {
		$menu .= "\n\n<!-- problem with eval of organisation:\n$@\nis the error. -->\n\n";
	}

	return $menu;
}

########################################################
sub footer {
	if ($I{F}{ssi}) {
		ssiFoot();
		return;
	}

	my $motd = '';
	if ($I{U}{aseclev}) {
		$motd .= currentAdminUsers();
	} else {
		$motd .= blockCache('motd');
	}

	my $vertmenu = blockCache('mainmenu');
	my $menu = prepBlock($vertmenu);

	my $horizmenu = eval $menu;
	$horizmenu =~ s/^\s*//mg;
	$horizmenu =~ s/^-\s*//mg;
	$horizmenu =~ s/\s*$//mg;
	$horizmenu =~ s/<HR(?:>|\s[^>]*>)//g;
	$horizmenu = sprintf "[ %s ]", join ' | ', split /<BR>/, $horizmenu;

	my $execme = getWidgetBlock('footer');
	print eval $execme;
	print "\nError:$@\n" if $@;
}

########################################################
sub titlebar {
	my($width, $title) = @_;
	my $execme = getWidgetBlock('titlebar');
	print eval $execme;
	print "\nError:$@\n" if $@;
}

########################################################
sub fancybox {
	my($width, $title, $contents) = @_;
	return unless $title && $contents;

	my $mainwidth = $width-4;
	my $insidewidth = $mainwidth-8;
	my $execme = getWidgetBlock('fancybox');
	print eval $execme;
	print "\nError:$@\n" if $@;
}

########################################################
sub portalbox {
	my($width, $title, $contents, $bid, $url) = @_;
	return unless $title && $contents;

	$title = qq!<FONT COLOR="$I{fg}[3]">$title</FONT>!
		if $url && !$I{U}{light};
	$title = qq!<A HREF="$url">$title</A>! if $url;

	unless ($I{U}{exboxes}) {
		fancybox($width, $title, $contents);
		return;
	}

	my $execme = getWidgetBlock('portalmap');
	$title = eval $execme if $bid;

	my $mainwidth = $width-4;
	my $insidewidth = $mainwidth-8;

	$execme = getWidgetBlock('fancybox');
	my $e = eval $execme;
	print "\nError:$@\n" if $@;
	return $e;
}

########################################################
# Behold, the beast that is threaded comments
sub selectComments {
	my($sid, $cid) = @_;
	$I{shit} = 0 if $I{F}{ssi};
	my $sql = "SELECT cid," . getDateFormat('date', 'time' ) . ",
				subject,comment,
				nickname,homepage,fakeemail,
				users.uid as uid,sig,
				comments.points as points,pid,sid,
				lastmod, reason
			   FROM comments,users
			  WHERE sid=" . $I{dbh}->quote($sid) . "
			    AND comments.uid=users.uid";
	$sql .= "	    AND comments.cid >= $I{F}{pid} " if $I{F}{pid} && $I{shit}; # BAD
	$sql .= "	    AND comments.cid >= $cid " if $cid && $I{shit}; # BAD
	$sql .= "	    AND (";
	$sql .= "		comments.uid=$I{U}{uid} OR " if $I{U}{uid} > 0;
	$sql .= "		cid=$cid OR " if $cid;
	$sql .= "		comments.points >= " . $I{dbh}->quote($I{U}{threshold}) . " OR " if $I{U}{hardthresh};
	$sql .= "		  1=1 )   ";
	$sql .= "	  ORDER BY ";
	$sql .= "comments.points DESC, " if $I{U}{commentsort} eq '3';
	$sql .= " cid ";
	$sql .= ($I{U}{commentsort} == 1 || $I{U}{commentsort} == 5) ? 'DESC' : 'ASC';

	$sql .= "		LIMIT $I{shit}" if ! ($I{F}{pid} || $cid) && $I{shit} > 0;

	my $thisComment = $I{dbh}->prepare_cached($sql) or apacheLog($sql);
	$thisComment->execute or apacheLog($sql);

	my $comments; # One bigass struct full of comments
	foreach my $x (0..6) { $comments->[0]{totals}[$x] = 0 }

	while (my $C = $thisComment->fetchrow_hashref) {
		$C->{pid} = 0 if $I{U}{commentsort} > 3; # Ignore Threads

		$C->{points}++ if length($C->{comment}) > $I{U}{clbig}
			&& $C->{points} < 5 && $I{U}{clbig} != 0;

		$C->{points}-- if length($C->{comment}) < $I{U}{clsmall}
			&& $C->{points} > -1 && $I{U}{clsmall};

		# fix points in case they are out of bounds
		$C->{points} = $C->{points} < -1 ? -1 : $C->{points} > 5 ? 5 : $C->{points};

		my $tmpkids = $comments->[$C->{cid}]{kids};
		my $tmpvkids = $comments->[$C->{cid}]{visiblekids};
		$comments->[$C->{cid}] = $C;
		$comments->[$C->{cid}]{kids} = $tmpkids;
		$comments->[$C->{cid}]{visiblekids} = $tmpvkids;

		push @{$comments->[$C->{pid}]{kids}}, $C->{cid};
		$comments->[0]{totals}[$C->{points} + 1]++;
		$comments->[$C->{pid}]{visiblekids}++
			if $C->{points} >= $I{U}{threshold};

		$I{U}{points} = 0 if $C->{uid} == $I{U}{uid}; # Mod/Post Rule
	}

	my $count = $thisComment->rows;
	$thisComment->finish;

	getCommentTotals($comments);
	updateCommentTotals($sid, $comments) if $I{F}{ssi};
	reparentComments($comments);
	return($comments,$count);
}

########################################################
sub getCommentTotals {
	my $comments = shift;
	foreach my $x (0..5) {
		$comments->[0]{totals}[5-$x] += $comments->[0]{totals}[5-$x+1];
	}
}

########################################################
sub updateCommentTotals {
	return unless $I{F}{ssi}; # Don't bother unless we're making static.
	my($sid, $comments) = @_;
	my $hp = join ',', @{$comments->[0]{totals}};
	sqlUpdate("stories", {
			hitparade	=> $hp,
			writestatus	=> 0,
			commentcount	=> $comments->[0]{totals}[0]
		}, 'sid=' . $I{dbh}->quote($sid)
	);
}

########################################################
sub reparentComments {
	my $comments = shift;
	my $depth = $I{max_depth} || 7;

	return unless $depth || $I{U}{reparent};

	# adjust depth for root pid or cid
	if (my $cid = $I{F}{cid} || $I{F}{pid}) {
		while ($cid && (my($pid) =
			sqlSelect('pid', 'comments',
				"sid='$I{F}{sid}' and cid=$cid")
		)) {
			$depth++;
			$cid = $pid;
		}
	}

	for (my $x = 1; $x < @$comments; $x++) {
		next unless $comments->[$x];

		my $pid = $comments->[$x]{pid};
		my $reparent;

		# do threshold reparenting thing
		if ($I{U}{reparent} && $comments->[$x]{points} >= $I{U}{threshold}) {
			my $tmppid = $pid;
			while ($tmppid && $comments->[$tmppid]{points} < $I{U}{threshold}) {
				$tmppid = $comments->[$tmppid]{pid};
				$reparent = 1;
			}

			if ($reparent && $tmppid >= ($I{F}{cid} || $I{F}{pid})) {
				$pid = $tmppid;
			} else {
				$reparent = 0;
			}
		}

		if ($depth && !$reparent) { # don't reparent again!
			# set depth of this comment based on parent's depth
			$comments->[$x]{depth} = ($pid ? $comments->[$pid]{depth} : 0) + 1;

			# go back each pid until we find one with depth less than $depth
			while ($pid && $comments->[$pid]{depth} >= $depth) {
				$pid = $comments->[$pid]{pid};
				$reparent = 1;
			}
		}

		if ($reparent) {
			# remove child from old parent
			if ($pid >= ($I{F}{cid} || $I{F}{pid})) {
				@{$comments->[$comments->[$x]{pid}]{kids}} =
					grep { $_ != $x }
					@{$comments->[$comments->[$x]{pid}]{kids}}
			}

			# add child to new parent
			$comments->[$x]{realpid} = $comments->[$x]{pid};
			$comments->[$x]{pid} = $pid;
			push @{$comments->[$pid]{kids}}, $x;
		}
	}
}

########################################################
sub selectThreshold  {
	my($counts) = @_;

	my $s = qq!<SELECT NAME="threshold">\n!;
	foreach my $x (-1..5) {
		my $select = ' SELECTED' if $x == $I{U}{threshold};
		$s .= qq!\t<OPTION VALUE="$x"$select>$x: $counts->[$x+1] comments\n!;
	}
	$s .= "</SELECT>\n";
}

########################################################
sub printComments {
	# return;
	my($sid, $pid, $cid, $commentstatus) = @_;

	$pid ||= '0';
	my $lvl = 0;

	# Get the Comments
	my($comments, $count) = selectComments($sid, $cid || $pid);

	# Should I index or just display normally?
	my $cc = 0;
	if ($comments->[$cid || $pid]{visiblekids}) {
		$cc = $comments->[$cid || $pid]{visiblekids};
	}

	$lvl++ if $I{U}{mode} ne 'flat' && $I{U}{mode} ne 'archive'
		&& $cc > $I{U}{commentspill}
		&& ($I{U}{commentlimit} > $cc || $I{U}{commentlimit} > $I{U}{commentspill});

	print qq!<TABLE WIDTH="100%" BORDER="0" CELLSPACING="1" CELLPADDING="2">\n!;

	if ($I{U}{mode} ne 'archive') {
		print qq!\t<TR><TD BGCOLOR="$I{bg}[3]" ALIGN="CENTER">!,
			qq!<FONT SIZE="${\( $I{fontbase} + 2 )}" COLOR="$I{fg}[3]">!;

		my($title, $section);
		# Print Story Name if Applicable
		if ($I{storyBank}{$sid}) {
			my $TS = $I{storyBank}{$sid};
			($title, $section) = ($TS->{title}, $TS->{section});
		} else {
			($title, $section) = sqlSelect('title,section', 'newstories',
				'sid=' . $I{dbh}->quote($sid));
		}

		if ($title) {
			printf "'%s'", linkStory({
				'link'	=> qq!<FONT COLOR="$I{fg}[3]">$title</FONT>!,
				sid	=> $sid,
				section	=> $section
			});
		} else {
			print linkComment({
				sid => $sid, pid => 0, op => '',
				color => $I{fg}[3], subject => 'Top'
			});
		}

		print ' | ';

		if ($I{U}{uid} < 0) {
			print qq!<A HREF="$I{rootdir}/users.pl"><FONT COLOR="$I{fg}[3]">!,
				qq!Login/Create an Account</FONT></A> !;
		} elsif ($I{U}{uid} > 0) {
			print qq!<A HREF="$I{rootdir}/users.pl?op=edituser">!,
				qq!<FONT COLOR="$I{fg}[3]">Preferences</FONT></A> !
		}

		print ' | ' . linkComment({
			sid => $sid, pid => 0, op => '',
			color=> $I{fg}[3], subject => 'Top'
		}) if $pid;

		print " | <B>$I{U}{points}</B> ",
			qq!<A HREF="$I{rootdir}/moderation.shtml"><FONT COLOR="$I{fg}[3]">!,
			"moderator</FONT></A> points " if $I{U}{points};

		print " | <B>$count</B> comments " if $count;
		# print " | <B>$cc</B> siblings " if $cc;
		print " (Spill at <B>$I{U}{commentspill}</B>!)",
			" | Index Only " if $lvl && $I{U}{mode} eq 'thread';

		print " | Starting at #$I{F}{startat}" if $I{F}{startat};

		print <<EOT;
 | <A HREF="$I{rootdir}/search.pl?op=comments&sid=$sid">
<FONT COLOR="$I{fg}[3]">Search Discussion</FONT></A></FONT>
	</TD></TR>

	<TR><TD BGCOLOR="$I{bg}[2]" ALIGN="CENTER"><FONT SIZE="${\( $I{fontbase} + 2 )}">
		<FORM ACTION="$I{rootdir}/comments.pl">
		<INPUT TYPE="HIDDEN" NAME="sid" VALUE="$sid">
		<INPUT TYPE="HIDDEN" NAME="cid" VALUE="$cid">
		<INPUT TYPE="HIDDEN" NAME="pid" VALUE="$pid">
		<INPUT TYPE="HIDDEN" NAME="startat" VALUE="$I{F}{startat}">
EOT

		print "Threshold: ", selectThreshold($comments->[0]{totals}),
			selectMode(), selectSortcode();

		#selectGeneric("commentmodes","mode","mode","name",$I{U}{mode});
		#selectForm("sortcodes","commentsort",$I{U}{commentsort});

		print qq!\t\tSave:<INPUT TYPE="CHECKBOX" NAME="savechanges">!
			if $I{U}{uid} > 0;

		print <<EOT;
		<INPUT TYPE="submit" NAME="op" VALUE="Change">
		<INPUT TYPE="submit" NAME="op" VALUE="Reply">
	</TD></TR>
	<TR><TD BGCOLOR="$I{bg}[3]" ALIGN="CENTER">
		<FONT COLOR="$I{fg}[3]" SIZE="${\( $I{fontbase} + 2 )}">
EOT

		print blockCache('commentswarning'), "</FONT></FORM></TD></TR>";

		if ($I{U}{mode} eq 'nocomment') {
			print "</TABLE>";
			return;
		}
	} else {
		print <<EOT;
	<TR><TD BGCOLOR="$I{bg}[3]"><FONT COLOR="$I{fg}[3]" SIZE="${\( $I{fontbase} + 2 )}">
			This discussion has been archived.
			No new comments can be posted.
	</TD></TR>
EOT
	}

	print <<EOT if $I{U}{aseclev} || $I{U}{points};
	<FORM ACTION="$I{rootdir}/comments.pl" METHOD="POST">
	<INPUT TYPE="HIDDEN" NAME="sid" VALUE="$sid">
	<INPUT TYPE="HIDDEN" NAME="cid" VALUE="$cid">
	<INPUT TYPE="HIDDEN" NAME="pid" VALUE="$pid">
EOT

	if ($cid) {
		my $C = $comments->[$cid];
		dispComment($C);

		# Next and previous.
		my($n, $p);
		if (my $sibs = $comments->[$C->{pid}]{kids}) {
			for (my $x=0; $x< @$sibs; $x++) {
				($n,$p) = ($sibs->[$x+1], $sibs->[$x-1])
					if $sibs->[$x] == $cid;
			}
		}
		print qq!\t</TD></TR>\n\t<TR><TD BGCOLOR="$I{bg}[2]" ALIGN="CENTER">\n!;
		print "\t\t&lt;&lt;", linkComment($comments->[$p], 1) if $p;
		print ' | ', linkComment($comments->[$pid], 1) if $C->{pid};
		print ' | ', linkComment($comments->[$n], 1), "&gt;&gt;\n" if $n;
		print qq!\t</TD></TR>\n\t<TR><TD ALIGN="CENTER">!;
		moderatorCommentLog($sid, $cid);
		print "\t</TD></TR>\n";
	}

	my $lcp = linkCommentPages($sid, $pid, $cid, $cc);
	print $lcp;
	print "\t<TR><TD>\n" if $lvl; #|| $I{U}{mode} eq "nested" and $lvl);
	displayThread($sid, $pid, $lvl, $comments, $cid);
	print "\n\t</TD></TR>\n" if $lvl; # || ($I{U}{mode} eq "nested" and $lvl);
	print $lcp;

	print <<EOT if ($I{U}{aseclev} || $I{U}{points}) && $I{U}{uid} > 0;
	<TR><TD>
		<P>Have you read the
		<A HREF="$I{rootdir}/moderation.shtml">Moderator Guidelines</A>
		yet? (<B>Updated 9.9</B>)
		<INPUT TYPE="SUBMIT" NAME="op" VALUE="moderate">
	</TD></TR></FORM>
EOT

	print "</TABLE>\n";
}

########################################################
sub moderatorCommentLog {
	my($sid, $cid) = @_;
	my $c = sqlSelectMany(  "comments.sid as sid,
				 comments.cid as cid,
				 comments.points as score,
				 subject, moderatorlog.uid as uid,
				 users.nickname as nickname,
				 moderatorlog.val as val,
				 moderatorlog.reason as reason",
				"moderatorlog, users, comments",
				"moderatorlog.active=1
				 AND moderatorlog.sid='$sid'
			     AND moderatorlog.cid=$cid
			     AND moderatorlog.uid=users.uid
			     AND comments.sid=moderatorlog.sid
			     AND comments.cid=moderatorlog.cid"
	);

	my(@reasonHist, $reasonTotal);
	if ($c->rows > 0) {
		print <<EOT if $I{U}{aseclev} > 1000;
<TABLE BGCOLOR="$I{bg}[2]" ALIGN="CENTER" BORDER="0" CELLPADDING="2" CELLSPACING="0">
	<TR BGCOLOR="$I{bg}[3]">
		<TH><FONT COLOR="$I{fg}[3]"> val </FONT></TH>
		<TH><FONT COLOR="$I{fg}[3]"> reason </FONT></TH>
		<TH><FONT COLOR="$I{fg}[3]"> moderator </FONT></TH>
	</TR>
EOT

		while (my $C = $c->fetchrow_hashref) {
			print <<EOT if $I{U}{aseclev} > 1000;
	<TR>
		<TD> <B>$C->{val}</B> </TD>
		<TD> $I{reasons}[$C->{reason}] </TD>
		<TD> $C->{nickname} ($C->{uid}) </TD>
	</TR>
EOT

			$reasonHist[$C->{reason}]++;
			$reasonTotal++;
		}

		print "</TABLE>\n" if $I{U}{aseclev} > 1000;
	}

	$c->finish;
	return unless $reasonTotal;

	print qq!<FONT COLOR="$I{bg}[3]"><B>Moderation Totals</B></FONT>:!;
	foreach (0 .. @reasonHist) {
		print "$I{reasons}->[$_]=$reasonHist[$_], " if $reasonHist[$_];
	}
	print "<B>Total=$reasonTotal</B>.";
}

########################################################
sub linkCommentPages {
	my($sid, $pid, $cid, $total) = @_;
	my($links, $page);
	return if $total < $I{U}{commentlimit} || $I{U}{commentlimit} < 1;

	for (my $x = 0; $x < $total; $x += $I{U}{commentlimit}) {
		$links .= ' | ' if $page++ > 0;
		$links .= "<B>(" if $I{F}{startat} && $x == $I{F}{startat};
		$links .= linkComment({
			sid => $sid, pid => $pid, cid => $cid,
			subject => $page, startat => $x
		});
		$links .= ")</B>" if $I{F}{startat} && $x == $I{F}{startat};
	}
	if ($I{U}{breaking}) {
		$links .= " ($I{sitename} Overload: CommentLimit $I{U}{commentlimit})";
	}

	return <<EOT;
	<TR><TD BGCOLOR="$I{bg}[2]" ALIGN="CENTER"><FONT SIZE="${\( $I{fontbase} + 2 )}">
		$links
	</FONT></TD></TR>
EOT
}

########################################################
sub linkComment {
	my($C, $comment, $date) = @_;
	my $x = qq!<A HREF="$I{rootdir}/comments.pl?sid=$C->{sid}!;
	$x .= "&op=$C->{op}" if $C->{op};
	$x .= "&threshold=" . ($C->{threshold} || $I{U}{threshold});
	$x .= "&commentsort=$I{U}{commentsort}";
	$x .= "&mode=$I{U}{mode}";
	$x .= "&startat=$C->{startat}" if $C->{startat};

	if ($comment) {
		$x .= "&cid=$C->{cid}";
	} else {
		$x .= "&pid=" . ($C->{realpid} || $C->{pid});
		$x .= "#$C->{cid}" if $C->{cid};
	}

	my $s = $C->{color}
		? qq!<FONT COLOR="$C->{color}">$C->{subject}</FONT>!
		: $C->{subject};

	$x .= qq!">$s</A>!;
	$x .= " by $C->{nickname}" if $C->{nickname};
	$x .= qq! <FONT SIZE="-1">(Score:$C->{points})</FONT> !
		if !$I{U}{noscores} && $C->{points};
	$x .= qq! <FONT SIZE="-1"> $C->{'time'} </FONT>! if $date;
	$x .= "\n";
	return $x;
}

########################################################
sub displayThread {
	my($sid, $pid, $lvl, $comments, $cid) = @_;

	my $displayed = 0;
	my $skipped = 0;
	my $hidden = 0;
	my $indent = 1;
	my $full = !$lvl;
	my $cagedkids = $full;

	if ($I{U}{mode} eq 'flat' || $I{U}{mode} eq 'archive') {
		$indent = 0;
		$full = 1;
	} elsif ($I{U}{mode} eq 'nested') {
		$indent = 1;
		$full = 1;
	}


	foreach my $cid (@{$comments->[$pid]{kids}}) {
		my $C = $comments->[$cid];

		$skipped++;
		$I{F}{startat} ||= 0;
		next if $skipped < $I{F}{startat};

		$I{F}{startat} = 0; # Once We Finish Skipping... STOP

		if ($C->{points} < $I{U}{threshold}) {
			if ($I{U}{uid} < 0 || $I{U}{uid} != $C->{uid})  {
				$hidden++;
				next;
			}
		}

		my $highlight = 1 if $C->{points} >= $I{U}{highlightthresh};
		my $finish_list = 0;

		if ($full || $highlight) {
			print "<TABLE>" if $lvl && $indent;
			dispComment($C);
			print "</TABLE>" if $lvl && $indent;
			$cagedkids = 0 if $lvl && $indent;
			$displayed++;
		} else {
			my $pcnt = @{$comments->[$C->{pid}]{kids} } + 0;
			printf "\t\t<LI>%s\n",
				linkComment($C, $pcnt > $I{U}{commentspill}, "1");
			$finish_list++;
		}

		if ($C->{kids}) {
			print "\n\t<TR><TD>\n" if $cagedkids;
			print "\n\t<UL>\n" if $indent;
			displayThread($sid, $C->{cid}, $lvl+1, $comments);
			print "\n\t</UL>\n" if $indent;
			print "\n\t</TD></TR>\n" if $cagedkids;
		}

		print "</LI>\n" if $finish_list;

		last if $displayed >= $I{U}{commentlimit};
	}

	if ($hidden && !$I{U}{hardthresh} && $I{U}{mode} ne 'archive') {
		print qq!\n<TR><TD BGCOLOR="$I{bg}[2]">\n! if $cagedkids;
		print qq!<LI><FONT SIZE="${\( $I{fontbase} + 2 )}"><B> !,
			linkComment({
				sid => $sid, threshold => -1, pid => $pid,
				subject => "$hidden repl" . ($hidden > 1 ? 'ies' : 'y')
			}) . ' beneath your current threshold.</B></FONT>';
		print "\n\t</TD></TR>\n" if $cagedkids;
	}
	return $displayed;
}

########################################################
sub dispComment  {
	my($C) = @_;
	my $subj = $C->{subject};
	my $time = $C->{'time'};
	my $username;

	$username = $C->{fakeemail} ? <<EOT : $C->{nickname};
<A HREF="mailto:$C->{fakeemail}">$C->{nickname}</A>
<B><FONT SIZE="${\( $I{fontbase} + 2 )}">($C->{fakeemail})</FONT></B>
EOT

	(my $nickname  = $C->{nickname}) =~ s/ /+/g;
	my $userinfo = <<EOT unless $C->{nickname} eq $I{anon_name};
(<A HREF="$I{rootdir}/users.pl?op=userinfo&nick=$nickname">User Info</A>)
EOT

	my $userurl = qq!<A HREF="$C->{homepage}">$C->{homepage}</A><BR>!
		if length($C->{homepage}) > 8;

	my $score = '';
	unless ($I{U}{noscores}) {
		$score  = " (Score:$C->{points}";
		$score .= ", $I{reasons}[$C->{reason}]" if $C->{reason};
		$score .= ")";
	}

	$C->{comment} .= "<BR>$C->{sig}" unless $I{U}{nosigs};

	if ($I{F}{mode} ne 'archive' && length($C->{comment}) > $I{U}{maxcommentsize}
		&& $I{F}{cid} ne $C->{cid}) {

		$C->{comment} = substr $C->{comment}, 0, $I{U}{maxcommentsize};
		$C->{comment} .= sprintf '<P><B>%s</B>', linkComment({
			sid => $C->{sid}, cid => $C->{cid}, pid => $C->{cid},
			subject => "Read the rest of this comment..."
		}, 1);
	}

	my $comment = $C->{comment}; # Old Compatibility Thing

	my $execme = getWidgetBlock('comment');
	print eval $execme;
	print "\nError:$@\n" if $@;

	if ($I{U}{mode} ne 'archive') {
		my $pid = $C->{realpid} || $C->{pid};
		my $m = sprintf '%s | %s', linkComment({
			sid => $C->{sid}, pid => $C->{cid}, op => 'Reply',
			subject => 'Reply to This'
		}), linkComment({
			sid => $C->{sid},
			cid => $pid,
			pid => $pid,
			subject => 'Parent'
		}, $pid);

		# UID -MUST- be positive for moderator access.
		if (((	   $I{U}{willing}
			&& $I{U}{points} > 0
			&& $C->{uid} ne $I{U}{uid}
			&& $C->{lastmod} ne $I{U}{uid})
		    || ($I{U}{aseclev} > 99 && $I{authors_unlimited}))
			&& $I{U}{uid} > 0) {

			my $o;
			foreach (0 .. @{$I{reasons}} - 1) {
				$o .= qq!\t<OPTION VALUE="$_">$I{reasons}[$_]</OPTION>\n!;
			}

			$m.= qq! | <SELECT NAME="reason_$C->{cid}">\n$o</SELECT> !;
		    }

		$m .= qq! | <INPUT TYPE="CHECKBOX" NAME="del_$C->{cid}"> !
			if $I{U}{aseclev} > 99;
		print qq!\n\t<TR><TD><FONT SIZE="${\( $I{fontbase} + 2 )}">\n! .
			qq![ $m ]\n\t</FONT></TD></TR>\n<TR><TD>!;
	}
}

##############################################################################
#  Functions for dealing with Story selection and Display

########################################################
sub dispStory {
	my($S, $A, $T, $full) = @_;
	my $title = $S->{title};
	if (!$full && index($S->{title}, ':') == -1
		&& $S->{section} ne $I{defaultsection}
		&& $S->{section} ne $I{F}{section}) {

		# Need Header
		my $SECT = getSection($S->{section});

		# Until something better can be done we manually
		# fix title for the appropriate mode. This is an
		# UGLY hack, but until something more configurable
		# comes along (and using a block, here might be an
		# even uglier hack...but would solve the immediate
		# problem.
		$title = $I{U}{light} ? <<LIGHT : <<NORMAL;
\t\t\t<A HREF="$I{rootdir}/$S->{section}/">$SECT->{title}</A>: $S->{title}
LIGHT
\t\t\t<A HREF="$I{rootdir}/$S->{section}/"><FONT COLOR="$I{fg}[3]">$SECT->{title}</FONT></A>: $S->{title}
NORMAL
	}

	titlebar($I{titlebar_width}, $title);

	my $bt = $full ? "<P>$S->{bodytext}</P>" : '<BR>';
	my $author = qq!<A HREF="$A->{url}">$S->{aid}</A>!;

	my $topicicon = '';
	$topicicon .= ' [ ' if $I{U}{noicons};
	$topicicon .= qq!<A HREF="$I{rootdir}/search.pl?topic=$T->{tid}">!;

	if ($I{U}{noicons}) {
		$topicicon .= "<B>$T->{alttext}</B>";
	} else {
		$topicicon .= <<EOT;
<IMG SRC="$I{imagedir}/topics/$T->{image}" WIDTH="$T->{width}" HEIGHT="$T->{height}"
	BORDER="0" ALIGN="RIGHT" HSPACE="20" VSPACE="10" ALT="$T->{alttext}">
EOT
	}

	$topicicon .= '</A>';
	$topicicon .= ' ] ' if $I{U}{noicons};

        $S->{introtext} =~ s|__CPANURL__|http://www.perl.com/CPAN|g;
        $S->{introtext} =~ s|__CPANMOD__|http://search.cpan.org/search?module=|g;
        $S->{introtext} =~ s|__CPANDIST__|http://search.cpan.org/search?dist=|g;

        if ($S->{bodytext}) {
            $S->{bodytext} =~ s|__CPANURL__|http://www.perl.com/CPAN|g;
            $S->{bodytext} =~ s|__CPANMOD__|http://search.cpan.org/search?module=|g;
            $S->{bodytext} =~ s|__CPANDIST__|http://search.cpan.org/search?dist=|g;
        }

	my $execme = getWidgetBlock('story');
	print eval $execme;
	print "\nError:$@\n" if $@;

	if ($full && ($S->{bodytext} || $S->{books_publisher})) {
		my $execme = getWidgetBlock('storymore');
		print eval $execme;
		print "\nError:$@\n" if $@;
#	} elsif ($full) {
#		print $S->{bodytext};
	}
}

########################################################
sub displayStory {
	# caller is the pagename of the calling script
	my($sid, $full, $caller) = @_;

	# we need this for time stamping
	$I{code_time} = time;

	# this is a timestamp, in memory of this apache child
	# process, in raw seconds since 1970
	$I{storyBank}{timestamp} ||= $I{code_time};

	# set this to 0 if the calling page is index.pl and it's not
	# already defined
	# index.pl is the only script that loops through all of the stories
	# so this is the only script that will allow us to increment an array
	# to hold the proper count and sequence of the stories and their sids .
	$I{StoryCount} ||= 0 if $caller eq 'index';

	# this array is to store sids of the stories that are displayed on the front
	# index page. This is used for anonymous coward in article.pl to get the next
	# and previous query without hitting the database
	$I{sid_array}[$I{StoryCount}] = $sid
		if !$I{sid_array}[$I{StoryCount}] && $caller eq 'index';

	# difference between the timestamp on storyBank and the time this
	# code is executing
	my $diff = $I{code_time} - $I{storyBank}{timestamp};

	# this will force the storyBank to refresh if one of it's members is
	# older than the value we set for $story_expire
	if ($I{code_time} - $I{storyBank}{timestamp} > $I{story_expire} && $I{story_refresh} != 1) {
		$I{story_refresh} = 1;

		# gotta toast it because there may be sid keys that aren't part
		# of the upcoming query (old stories) and it could end up
		# getting bigger, and bigger, and bigger
		undef $I{storyBank};

		# smack a time stamp on it with the current time (this is the new timestamp)
		$I{storyBank}{timestamp} = $I{code_time};
	}

	# query the database only if there's not member in storyBank with this sid and it's not time to refresh storyBank
	$I{storyBank}{$sid} = sqlSelectHashref(
		'title,dept,time as sqltime,time,introtext,sid,commentstatus,bodytext,aid,' .
		'tid,section,commentcount, displaystatus,writestatus,relatedtext,extratext',
		'stories', 'stories.sid=' . $I{dbh}->quote($sid)
	) unless $I{storyBank}{$sid} && $I{story_refresh} != 1;

	# give this member of storyBank the current iteration of
	# StoryCount if it's not already defined and the calling page is
	# index.pl
	$I{storyBank}{$sid}{story_order} = $I{StoryCount}
		if !$I{storyBank}{$sid}{story_order} && $caller eq 'index';

	# increment if the calling page was index.pl
	$I{StoryCount}++ if $caller eq 'index';

	my $S = $I{storyBank}{$sid};

	# convert the time of the story (this is mysql format)
	# and convert it to the user's prefered format
	# based on their preferences
	$I{U}{storytime} = timeCalc($S->{'time'});

	if ($full && sqlTableExists($S->{section}) && $S->{section}) {
		my $E = sqlSelectHashref('*', $S->{section}, "sid='$S->{sid}'");
		foreach (keys %$E) {
			$S->{$_} = $E->{$_};
		}
	}

	getTopic($S->{tid});
	getAuthor($S->{aid});

	dispStory($S, $I{authorBank}{$S->{aid}}, $I{topicBank}{$S->{tid}}, $full);
	return($S, $I{authorBank}{$S->{aid}}, $I{topicBank}{$S->{tid}});
}

#######################################################################
# timeCalc 051199 PMG
# inputs: raw date from mysql
# returns: formatted date string from dateformats in mysql, converted to
# time strings that Date::Manip can format
#######################################################################
# interpolative hash for converting
# from mysql date format to perl
# the key is mysql's format,
# the value is perl's format
# Date::Manip format
my $timeformats = {
	'%M' => '%B',
	'%W' => '%A',
	'%D' => '%E',
	'%Y' => '%Y',
	'%y' => '%y',
	'%a' => '%a',
	'%d' => '%d',
	'%e' => '%e',
	'%c' => '%f',
	'%m' => '%m',
	'%b' => '%b',
	'%j' => '%j',
	'%H' => '%H',
	'%k' => '%k',
	'%h' => '%I',
	'%I' => '%I',
	'%l' => '%i',
	'%i' => '%M',
	'%r' => '%r',
	'%T' => '%T',
	'%S' => '%S',
	'%s' => '%S',
	'%p' => '%p',
	'%w' => '%w',
	'%U' => '%U',
	'%u' => '%W',
	'%%' => '%%'
};

sub timeCalc {
	# raw mysql date of story
	my $date = shift;

	# lexical
	my(@dateformats, $err);

	# I put this here because
	# when they select "6 ish" it
	# looks really stupid for it to
	# display "posted by xxx on 6 ish"
	# It looks better for it to read:
	# "posted by xxx around 6 ish"
	# call me anal!
	if ($I{U}{'format'} eq '%l ish' || $I{U}{'format'} eq '%h ish') {
		$I{U}{aton} = " around ";
	} else {
		$I{U}{aton} = " on ";
	}

	# find out the user's time based on personal offset
	# in seconds
	$date = DateCalc($date, "$I{U}{offset} SECONDS", \$err);

	# create a new U{} hash key member for storing the new format
	$I{U}{perlformat} = $I{U}{'format'};

	# interpolate from mysql format to perl format
	$I{U}{perlformat} =~ s/(\%\w)/$timeformats->{$1}/g;

	# convert the raw date to pretty formatted date
	$date = UnixDate($date, $I{U}{perlformat});

	# return the new pretty date
	return $date;
}

########################################################
sub pollItem {
	my($answer, $imagewidth, $votes, $percent) = @_;

	my $execme = getWidgetBlock('pollitem');
	print eval $execme;
	print "\nError:$@\n" if $@;
}

########################################################
sub testExStr {
	local $_ = shift;
	$_ .= "'" unless m/'$/;
	return $_;
}

########################################################
sub selectStories {
	my($SECT, $limit, $tid) = @_;

	my $s = "SELECT sid, section, title, date_format(" .
		getDateOffset('time') . ',"%W %M %d %h %i %p"),
			commentcount, to_days(' . getDateOffset('time') . "),
			hitparade
		   FROM newstories
		  WHERE 1=1 "; # Mysql's Optimize gets this.

	$s .= " AND displaystatus=0 " unless $I{F}{section};
	$s .= " AND time < now() "; # unless $I{U}{aseclev};
	$s .= "	AND (displaystatus>=0 AND '$SECT->{section}'=section)" if $I{F}{section};
	$I{F}{issue} =~ s/[^0-9]//g; # Kludging around a screwed up URL somewhere
	$s .= "   AND $I{F}{issue} >= to_days(" . getDateOffset("time") . ") "
		if $I{F}{issue};
	$s .= "	AND tid='$tid'" if $tid;

	# User Config Vars
	$s .= "	AND tid not in ($I{U}{extid})"		if $I{U}{extid};
	$s .= "	AND aid not in ($I{U}{exaid})"		if $I{U}{exaid};
	$s .= "	AND section not in ($I{U}{exsect})"	if $I{U}{exsect};

	# Order
	$s .= "	ORDER BY time DESC ";

	if ($limit) {
		$s .= "	LIMIT $limit";
	} elsif ($I{currentSection} eq 'index') {
		$s .= "	LIMIT $I{U}{maxstories}";
	} else {
		$s .= "	LIMIT $SECT->{artcount}";
	}
#	print "\n\n\n\n\n<-- stories select $s -->\n\n\n\n\n";

	my $cursor = $I{dbh}->prepare($s) or apacheLog($s);
	$cursor->execute or apacheLog($s);
	return $cursor;
}

########################################################
sub getOlderStories {
	my($cursor, $SECT)=@_;
	my($today, $stuff);

	$cursor ||= selectStories($SECT);

	unless($cursor->{Active}) {
		$cursor->finish;
		return "Your maximum stories is $I{U}{maxstories} ";
	}

	while (my($sid, $section, $title, $time, $commentcount, $day) = $cursor->fetchrow) {
		my($w, $m, $d, $h, $min, $ampm) = split m/ /, $time;
		if ($today ne $w) {
			$today  = $w;
			$stuff .= '<P><B>';
			$stuff .= <<EOT if $SECT->{issue} > 1;
<A HREF="$I{rootdir}/index.pl?section=$SECT->{section}&issue=$day&mode=$I{currentMode}">
EOT
			$stuff .= qq!<FONT SIZE="${\( $I{fontbase} + 4 )}">$w</FONT>!;
			$stuff .= '</A>' if $SECT->{issue} > 1;
			$stuff .= " $m $d</B></P>\n";
		}

		$stuff .= sprintf "<LI>%s ($commentcount)</LI>\n", linkStory({
			'link' => $title, sid => $sid, section => $section
		});
	}

	if ($SECT->{issue}) {
		# KLUDGE:Should really get previous issue with stories;
		my($yesterday) = sqlSelect('to_days(now())-1')
			unless $I{F}{issue} > 1 || $I{F}{issue};
		$yesterday ||= int($I{F}{issue}) - 1;

		my $min = $SECT->{artcount} + $I{F}{min};

		$stuff .= qq!<P ALIGN="RIGHT">! if $SECT->{issue};
		$stuff .= <<EOT if $SECT->{issue} == 1 || $SECT->{issue} == 3;
<BR><A HREF="$I{rootdir}/search.pl?section=$SECT->{section}&min=$min">
<B>Older Articles</B></A>
EOT
		$stuff .= <<EOT if $SECT->{issue} == 2 || $SECT->{issue} == 3;
<BR><A HREF="$I{rootdir}/index.pl?section=$SECT->{section}&mode=$I{currentMode}&issue=$yesterday">
<B>Yesterday's Edition</B></A>
EOT
	}
	$cursor->finish;
	return $stuff;
}

########################################################
# use lockTest to test if a story is being edited by someone else
########################################################
sub getImportantWords {
	my $s = shift;
	$s =~ s/[^A-Z0-9 ]//gi;
	my @w = split m/ /, $s;
	my @words;
	foreach (@w) {
		if (length($_) > 3 || (length($_) < 4 && uc($_) eq $_)) {
			push @words, $_;
		}
	}
	return @words;
}

########################################################
sub matchingStrings {
	my($s1, $s2)=@_;
	return '100' if $s1 eq $s2;
	my @w1 = getImportantWords($s1);
	my @w2 = getImportantWords($s2);
	my $m = 0;
	return 0 if @w1 < 2 || @w2 < 2;
	foreach my $w (@w1) {
		foreach (@w2) {
			$m++ if $w eq $_;
		}
	}
	return int($m / @w1 * 100) if $m;
	return 0;
}

########################################################
sub lockTest {
	my $subj = shift;
	return unless $subj;
	my $c = sqlSelectMany('lasttitle,aid', 'sessions');
	my $msg;
	while (my($thissubj, $aid) = $c->fetchrow) {
		if ($aid ne $I{U}{aid} && (my $x = matchingStrings($thissubj, $subj))) {
			$msg .= <<EOT
<B>$x%</B> matching with <FONT COLOR="$I{fg}[1]">$thissubj</FONT> by <B>$aid</B><BR>
EOT
		}
	}
	$c->finish;
	return $msg;
}

########################################################
sub getAnonCookie {
	if (my $cookie = $I{query}->cookie('anon')) {
		$I{U}{anon_id} = $cookie;
		$I{U}{anon_cookie} = 1;
	} else {
		$I{U}{anon_id} = getAnonId();
	}
}

########################################################
sub getAnonId {
	return '-1-' . getFormkey();
}

########################################################
sub getFormkey {
	my @rand_array = ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 );
	return join("", map { $rand_array[rand @rand_array] }  0 .. 9);
}

########################################################
sub whereFormkey {
	my $formkey_id = shift;
	my $where;

	# anonymous user without cookie, check host, not formkey id
	if ($I{U}{anon_id} && ! $I{U}{anon_cookie}) {
		$where = "host_name = '$ENV{REMOTE_ADDR}'";
	} else {
		$where = "id='$formkey_id'";
	}

	return $where;
}

########################################################
sub updateFormkeyId {
	if ($I{U}{uid} > 0 && $I{query}->param('rlogin') && length($I{F}{upasswd}) > 1) {
		sqlUpdate("formkeys", {
			id	=> $I{U}{uid},
			uid	=> $I{U}{uid},
		}, "formname='comments' AND uid = -1 AND formkey=" .
			$I{dbh}->quote($I{F}{formkey}));
	}
}

########################################################
sub getFormkeyId {
	my $uid = shift;

	# this id is the key for the commentkey table, either UID or
	# unique hash key generated by IP address
	my $id;

	# if user logs in during submission of form, after getting
	# formkey as AC, check formkey with user as AC
	if ($I{U}{uid} > 0 && $I{query}->param('rlogin') && length($I{F}{upasswd}) > 1) {
		getAnonCookie();
		$id = $I{U}{anon_id};
	} elsif ($uid > 0) {
		$id = $uid;
	} else {
		$id = $I{U}{anon_id};
	}
	return($id);
}

########################################################
sub insertFormkey {
	my($formname, $id, $sid) = @_;

	$I{F}{formkey} = getFormkey();

	# insert the fact that the form has been displayed, but not submitted at this point
	sqlInsert("formkeys", {
		formkey		=> $I{F}{formkey},
		formname 	=> $formname,
		id 		=> $id,
		sid		=> $sid,
		uid		=> $I{U}{uid},
		host_name	=> $ENV{REMOTE_ADDR},
		value		=> 0,
		ts		=> time()
	});
}

########################################################
sub checkFormkey {
	my($formkey_earliest, $formname, $formkey_id) = @_;

	my $where = whereFormkey($formkey_id);
	my($is_valid) = sqlSelect('count(*)', 'formkeys',
		'formkey = ' . $I{dbh}->quote($I{F}{formkey}) .
		" AND $where " .
		"AND ts >= $formkey_earliest AND formname = '$formname'");
	return($is_valid);
}

########################################################
sub intervalString {
	# Ok, this isn't necessary, but it makes it look better than saying:
	#  "blah blah submitted 23333332288 seconds ago"
	# call me anal.
	my $interval = shift;
	my $interval_string = "";

	if ($interval > 60) {
		my($hours, $minutes) = 0;
		if ($interval > 3600) {
			$hours = int($interval/3600);
			if ($hours > 1) {
				$interval_string = "$hours hours ";
			} elsif ($hours > 0) {
				$interval_string = "$hours hour ";
			}
			$minutes = int(($interval % 3600) / 60);

			} else {
				$minutes = int($interval / 60);
			}
			if ($minutes > 0) {
				$interval_string .= ", " if $hours;
				if ($minutes > 1) {
					$interval_string .= " $minutes minutes ";
				} else {
					$interval_string .= " $minutes minute ";
				}
			}
		} else {
			$interval_string = "$interval seconds ";
		}
		return($interval_string);
}
##################################################################
sub checkTimesPosted {
	my($formname, $max, $id, $formkey_earliest) = @_;

	my $where = whereFormkey($id);
	my($times_posted) = sqlSelect(
		"count(*) as times_posted",
		"formkeys",
		"$where AND submit_ts >= $formkey_earliest AND formname = '$formname'");

	return $times_posted >= $max ? 0 : 1;
}

##################################################################
sub submittedAlready {
	my($formkey, $formname) = @_;

	my $cant_find_formkey_err = <<EOT;
<P><B>We can't find your formkey.</B></P>
<P>You must fill out a form and submit from that
form as required.</P>
EOT

	# find out if this form has been submitted already
	my($submitted_already, $submit_ts) = sqlSelect(
		"value,submit_ts",
		"formkeys", "formkey='$formkey' and formname = '$formname'")
		or errorMessage($cant_find_formkey_err) and return(0);

		if ($submitted_already) {
			# interval of when it was submitted (this won't be used unless it's already been submitted)
			my $interval_string = intervalString(time() - $submit_ts);
			my $submitted_already_err = <<EOT;
<B>Easy does it!</B>
<P>This comment has been submitted already, $interval_string ago.
No need to try again.</P>
EOT

			# else print an error
			errorMessage($submitted_already_err);
		}
		return($submitted_already);
}

##################################################################
# nice little function to print out errors
sub errorMessage {
	my $error_message = shift;
	print qq|$error_message\n|;
	return;
}

##################################################################
# logs attempts to break, fool, flood a particular form
sub formAbuse {
	my $reason = shift;
	# logem' so we can banem'
	sqlInsert("abusers", {
		host_name	=> $ENV{REMOTE_ADDR},
		pagename	=> $ENV{SCRIPT_NAME},
		querystring	=> $ENV{QUERY_STRING},
		reason		=> $reason,
		-ts		=> 'now()',
	});

	return;
}

##################################################################
# the form has been submitted, so update the formkey table
# to indicate so
sub formSuccess {
	my($formkey, $cid, $length) = @_;

	# update formkeys to show that there has been a successful post,
	# and increment the value from 0 to 1 (shouldn't ever get past 1)
	# meaning that yes, this form has been submitted, so don't try i t again.
	sqlUpdate("formkeys", {
		-value		=> 'value+1',
		cid		=> $cid,
		submit_ts	=> time(),
		content_length	=> $length,
	}, "formkey=" . $I{dbh}->quote($formkey));
}

##################################################################
sub formFailure {
	my $formkey = shift;
	sqlUpdate("formkeys", {
		value 	=> -1,
	}, "formkey=" . $I{dbh}->quote($formkey));
}

##################################################################
# make sure they're not posting faster than the limit
sub checkSubmission {
	my($formname, $limit, $max, $id) = @_;
	my $formkey_earliest = time() - $I{formkey_timeframe};
	my $where = whereFormkey($id);

	my($last_submitted) = sqlSelect(
		"max(submit_ts)",
		"formkeys",
		"$where AND formname = '$formname'");
	$last_submitted ||= 0;

	my $interval = time() - $last_submitted;

	if ($interval < $limit) {
		my $limit_string = intervalString($limit);
		my $interval_string = intervalString($interval);
		my $speed_limit_err = <<EOT;
<B>Slow down cowboy!</B><BR>
<P>$I{sitename} requires you to wait $limit_string between
each submission of $ENV{SCRIPT_NAME} in order to allow everyone to have a fair chance to post.</P>
<P>It's been $interval_string since your last submission!</P>
EOT
		errorMessage($speed_limit_err);
		return(0);

	} else {
		if (checkTimesPosted($formname, $max, $id, $formkey_earliest)) {
			undef $I{F}{formkey} unless $I{F}{formkey} =~ /^\w{10}$/;

			unless ($I{F}{formkey} && checkFormkey($formkey_earliest, $formname, $id)) {
				formAbuse("invalid form key");
				my $invalid_formkey_err = "<P><B>Invalid form key!</B></P>\n";
				errorMessage($invalid_formkey_err);
				return(0);
			}

			if (submittedAlready($I{F}{formkey}, $formname)) {
				formAbuse("form already submitted");
				return(0);
			}

		} else {
			formAbuse("max form submissions $max reached");
			my $timeframe_string = intervalString($I{formkey_timeframe});
			my $max_posts_err =<<EOT;
<P><B>You've reached you limit of maximum submissions to $ENV{SCRIPT_NAME} :
$max submissions over $timeframe_string!</B></P>
EOT
			errorMessage($max_posts_err);
			return(0);
		}
	}
	return(1);
}



########################################################
sub CLOSE { $I{dbh}->disconnect if $I{dbh} }
########################################################
sub handler { 1 }
########################################################
1;
