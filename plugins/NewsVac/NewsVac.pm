# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::NewsVac;

=head1 NewsVac

Slash::NewsVac - The URL database tree class

=head1 DESCRIPTION

Implements a database handle that has some extra functionality.
That functionality allows for clean and easy insertion to,
updating of, and selection from the database of URLs and the
relationships between them.

Important terms:  process, request, analyze, parse, spider.

To request a URL is to retrieve its data from the net and to
update the url_info and url_content SQL tables.

To analyze a URL is to determine which parse modules need to
be called and then to call them, updating the url_analysis
table and other tables as appropriate (url_content to store
plaintext data, rel to store links).  Only done if request is
successful.

A parse module is identified by a text keyword which
associates to a method.  The method does some (possibly
computation-intensive) work to update other tables and fields
in the database.

To process a URL is to request it and then analyze it.

The spider method takes a hash of conditions, an SQL query to
determine an initial URL set, and then a series of tuples that
define which "rel" links to follow to expand the URL set.

=head1 BUGS

Sometimes a cookie that's the single-line LWP comment gets
stored; the regex should weed these out. Doesn't do much harm
but is a little annoying.

=head1 METHOD DESCRIPTIONS

=cut

use strict;
use vars qw($VERSION @EXPORT);

use Slash 2.003;	# require Slash 2.3
use 5.006;		# requires some 5.6-specific stuff, like our()

use Fcntl;
use File::Path;
use File::Spec::Functions;
use File::Temp 'tempfile';
use Safe;

use Time::HiRes;
use Time::Local;

use Digest::MD5 'md5_base64';
use LWP;
use LWP::RobotUA;
use HTML::Entities;
use HTML::LinkExtor;
use URI::Escape;
use HTTP::Cookies;
use XML::RSS;

use Slash::Display;
use Slash::Utility;

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

use vars qw($VERSION $callback_ref);

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

# We use custom descriptions with derivative names since we are using
# variants based on the 1.x scheme, for now.
my %nvdescriptions = (
	'authornames' => sub {
		$_[0]->sqlSelectMany(
			'nickname,nickname',
			'authors_cache'
		)
	},

	'progresscodes' => sub {
		$_[0]->sqlSelectMany(
			'name,name', 'code_param', "type='nvprogress'"
		)
	},
);

############################################################

sub new {
	my($class, $user, %conf) = @_;

	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'NewsVac'};

	$self = {
		ua_class	=> 'LWP::UserAgent',
		hp_class	=> 'HTML::Parser',
		debug		=> 2,
		using_lock	=> 0,
		callback	=> {},
		hp_parsedtext	=> [],
	};

	# Allow a var to override default User Agent class.
	$self->{ua_class} = $conf{ua_class} if $conf{ua_class};

	# bless() must occur before call to base class methods.
	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	# Establish the options for use in the constructor of
	# $self->{hp}.
	$self->{hp_options} = {
		api_version	=> 3,
		text_h		=> [ $self->{hp_parsedtext}, 'dtext' ],
	};

	# Now perform class initializations.
	$self->Reset;

	return $self;
}

############################################################
# Clean up object and reset all member variables.
sub Reset {
	my($self) = @_;

	# Remove the lock file.
	if ($self->{using_lock}) {
		_doLockRelease('newsvac');
		$self->{using_lock} = 0;
		# Give the filesystem time to remove the PID file.
		sleep 1;
	}

	# Use any resetting procedures defined by the super-class.
	$self->init if $self->can('init');

	# Delete stale data members.
	delete $self->{sd};

	# Reinitialize our sub-classes.
	delete $self->{ua};
	delete $self->{hp};

	my($ua_class, $hp_class) = @{$self}{qw(ua_class hp_class)};

	# User-Agent Class initialization.
	$self->{ua} = $ua_class->new;
	$self->{ua}->agent(getData('spider_useragent', {
		version => $VERSION,
	}));
	$self->{ua}->cookie_jar(new HTTP::Cookies);

	# Parser Class initialization.
	$self->{hp} = $hp_class->new(%{$self->{hp_options}});

	# we shouldn't ever have a problem with ignoring these;
	# they come through as plain text if we don't ignore them
	$self->{hp}->ignore_elements(qw(script style));
}

############################################################

=head2 lockNewsVac

The caller determins whether or not to put NewsVac into this mode, and it
is an all or nothing affair, at this time. If you can't get a lock, your code
dies. Once a lock has been obtained, NewsVac is locked and any other code
that needs to lock NewsVac will gracefully drop until the lock is removed
(either by graceful code termination, or the forceful fingers of your nearest
BOFH).

=over 4

=item Parameters

=over 4

=item None.

=back

=item Return value

If the lock succeeds, this routine returns logical true. Any other situation
returns logical false. If logical false is returned, caller should be able
to gracefully back out of whatever operation was in progress (caller will
need to use eval {} to catch the die() calls).

=item Side effects

If lock succeeds, a newsvac.pid file will be created in the site's log
diretory.

=item Dependencies

Unknown.

=back

=cut

sub lockNewsVac {
	my($self) = @_;

	eval {
		_doLogInit('newsvac');
		_doLock();
	};
	# This is not an equality test. This is an assignment-null test.
	if ($_ = $@) {
		# If we've trapped an error, then either another process is
		# using NewsVac....
		die getData('newsvac_locked', {
				error_message => $@,
			}, 'newsvac')
		if /^Please stop existing/;

		# or we've caught something terminal, either way stop
		# execution.
		die getData('unexpected_init_err', {
				error_message => $@,
		}, 'newsvac');
	}

	# If we're here, we've go the resource all to ourselves, woo-hoo!
	return($self->{using_lock} = 1);
}

############################################################

=head2 _Die(message_list)

Removes lock and forcibly terminates NewsVac with a message sent to the logs.
Used in place of C<die()> to terminate on an error condition.

=over 4

=item Parameters

=over 4

=item @message_list

List of messages to send to the logs. These are written out to the logs in
the given order.

=back

=item Return value

None.

=item Side effects

Lock file is removed and execution forcibly terminated.

=item Dependencies

None.

=back

=cut

sub _Die {
	my($self, @message_list) = @_;

	$self->_doLockRelease if $self->{using_lock};
	die join "\n", @message_list;
}

############################################################

=head2 getNVDescriptions(code)

Foooooooo.

=over 4

=item Parameters

=over 4

=item code

String containing the name of the description to use. NewsVac defines
descriptions private to itself, and does NOT inherit from Slash::DB. The
following descriptions are currently defined:

=over 4

=item authornames

Retrieves list of author names.

=item progresscodes

Retrieves list of valid progress codes (admin)

=back

=back

=item Return value

None.

=item Side effects

None.

=item Dependencies

Unknown.

=back

=cut

sub getNVDescriptions {
	my($self, $code) = @_;

	return $self->getDescriptions($code, '', 1, \%nvdescriptions);
}


############################################################

=head2 canonical(url)

Converts the given URL into its canonical form.

=over 4

=item Parameters

=over 4

=item $url

String containing URL to be canonicalized.

=back

=item Return value

The URL in its canonicalized form.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub canonical {
	my($self, $url) = @_;

	$url = URI->new($url)->canonical;
	# Don't clean out the fragment if it contains useful information.
	$url->fragment(undef) if length $url->fragment == 0;

	return $url;
}

############################################################

=head2 add_url(url)

Adds URL and URL metadata into the NewsVac database. URLs using the "javascript" or
"mailto" scheme/protocol will not be added.

=over 4

=item Parameters

=over 4

=item $url

URL to add.

=back

=item Return value

None.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub add_url {
	my($self, $url) = @_;

	$url = $self->canonical($url)->as_string;
	if (!$url || $url =~ /^(javascript|mailto):/) {
		$self->errLog(getData('add_url_noadderr', {
			url	=> $url,
			reason	=> $1,
		}));

		return;
	}

	my $digest = md5_base64($url);

	my $rc = $self->sqlInsert('url_info', {
		url 		=> $url,
		url_digest 	=> $digest,
	});
	my $url_id = $self->getLastInsertId;

	my $rcb = $self->sqlInsert('url_message_body', {
		url_id		=> $url_id,
		message_body	=> '',
	});

	$self->errLog(getData('add_url_result', {
		url	=> $url,
		rc 	=> $rc,
		rcbody  => $rcb,
	})) if $self->{debug} > 1;
}

############################################################

=head2 add_spider(spider_data)

Adds a spider entry into the 'spider' table assuming
we have all of the needed data and that said data appears
to be valid.

=over 4

=item Parameters

=over 4

=item $spider_data

Hashref containing the data describing the spider.

=back

=item Return value

	Scalar context = Logical value represening success/non-success.
	List context = List of (Logical success, Error Message)

=item Side effects

Inserts a record to the 'spider' table if successful.

=item Dependencies

=back

=cut

sub add_spider {
	my($self, $spider_name, $spider_data) = @_;

	return if !$spider_name;

	# Check for another spider of the same name.
	my $spider_id = $self->sqlSelect(
		'spider_id', 'spider', 'name=' . $self->sqlQuote($spider_name)
	);

	return if $spider_id;

	# Set appropriate default values.
	$spider_data->{name} = $spider_name;
	$spider_data->{commands} ||= <<EOT;
[ [ 0, 1, q{ rel.parse_code = 'miner' }, "LIMIT 3000" ], [ 1, 2, q{ rel.parse_code = 'nugget' }, "LIMIT 3000" ], [ 2, 3, q{ 1 = 0 }, "LIMIT 0" ] ]
EOT

	my $rc = $self->sqlInsert('spider', $spider_data);

	return $rc ? $self->getLastInsertId : 0;
}


############################################################

=head2 url_to_miner(url_id)

Get original miner ID from url's url_id, by way of original nugget url
and mined url.  May return multiple values.

=cut

sub url_to_miner {
	my($self, $url_id) = @_;

	my $columns = 'miner.miner_id';
	my $tables  = 'miner, rel as rel1, rel as rel2';
	my $where   = join(' AND ',
		'rel1.to_url_id   = ' . $self->sqlQuote($url_id),
		'rel1.parse_code  = "nugget"',
		'rel1.type        = "nugget"',
		'rel1.from_url_id = rel2.to_url_id',
		'rel2.parse_code  = "miner"',
		'rel2.type        = miner.name'
	);

	my $other   = 'ORDER BY rel1.first_verified DESC';

	my $miners = $self->sqlSelectColArrayref($columns, $tables, $where, $other) || [];
	return @$miners;
}


############################################################

=head2 url_to_id(url)

Converts a URL to it's associated ID.

=over 4

=item Parameters

=over 4

=item $url

String containing URL we wish to search on.

=back

=item Return value

The ID of the URL, if it exists in the NewsVac database.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub url_to_id {
	# This should keep a cache for efficiency.
	my($self, $url) = @_;
	my $url_id = 0;

	my $ary_ref = $self->sqlSelectColArrayref(
		'url_id', 'url_info', 'url=' . $self->sqlQuote($url)
	);
	$url_id = $ary_ref->[0] if $ary_ref;

	return $url_id;
}

############################################################

=head2 urls_to_ids(urls)

Converts a list of URLs to their associated IDs in the NewsVac database.

=over 4

=item Parameters

=over 4

=item @urls

A list of URLs to be converted.

=back

=item Return value

A list of IDs representing the converted list of URLs.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub urls_to_ids {
	my($self, @urls) = @_;

	if (!@urls) {
		$self->errLog(getData('urls_to_ids_nourls'));

		return;
	}

	my $url_list = sprintf '(%s)',
		join(', ', map { $self->sqlQuote($_) } @urls);
	my $ary_ref = $self->sqlSelectAll(
		'url, url_id',
		'url_info',
		"url IN $url_list"
	);

	my %hash;
	$hash{$_->[0]} = $_->[1] for @{$ary_ref};
	my @url_ids = map { $hash{$_} || 0 } @urls;

	return @url_ids;
}

############################################################

=head2 id_to_url(url_id)

Converts a URL ID to its URL form.

=over 4

=item Parameters

=over 4

=item Numeric ID of URL to convert.

=back

=item Return value

String of URL associated with the given ID.

=item Side effects

None.

=item Dependencies

None

=back

=cut

sub id_to_url {
	# This should keep a cache for efficiency.
	my($self, $url_id) = @_;

	my $url = undef;
	$url_id = $self->sqlQuote($url_id);
	$url = $self->sqlSelect('url', 'url_info', "url_id=$url_id");

	return $url;
}

############################################################

=head2 ids_to_urls(urls)

Converts a list of IDs to URLs. This is the list form of id_to_url().

=over 4

=item Parameters

=over 4

=item @urls

List of URL IDs to convert.

=back

=item Return value

List containing the converted URL IDs.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub ids_to_urls {
	my($self, @url_ids) = @_;
	my %hash;

	if (!@url_ids) {
		$self->errLog(getData('ids_to_urls_noids'));
		return;
	}

	my $id_list = sprintf '(%s)', join(',', @url_ids);
	my $ar = $self->sqlSelectAll(
		'url_id, url',
		'url_info',
		"url_id IN $id_list"
	);
	$hash{$_->[0]} = $_->[1] for @{$ar};
	my @urls = map { $hash{$_} || '' } @url_ids;
	$self->errLog(getData('ids_to_urls', {
		url_hash	=> \%hash,
		size_urls	=> scalar @urls,
		size_urlids	=> scalar @url_ids,
	})) if $self->{debug} > 1;

	return @urls;
}

############################################################

=head2 add_urls_return_ids(urls)

Add a list of URLs to the NewsVac database and return the
corresponding URL IDs to the caller.

=over 4

=item Parameters

=over 4

=item @urls

List of URLs to add.

=back

=item Return value

List of URL IDs corresponding to the URLs added. For example, given:

	@url_ids = add_urls_return_ids(@urls);

$url[1] is the URL and $url_ids[1] is its corresponding URL ID #.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub add_urls_return_ids {
	my($self, @urls) = @_;

	my %digest = map { ( $_, md5_base64($_) ) }
		map { ref($_) ? $_->as_string : $_ }
		@urls;

	for (keys %digest) {
		my $rc = $self->sqlInsert('url_info', {
			url		=> $_,
			url_digest	=> $digest{$_},
		}, { ignore => 1 });
	}

	$self->urls_to_ids(@urls);
}

############################################################

=head2 add_rels_mark_valid(rels)

Adds relationships to the NewsVac database and markes them as VALID.

=over 4

=item Parameters

=over 4

=item @rels

List of relationships to add to the NewsVac database, each element of the list
should be an array reference containing the following data:

	[ from_url_id, to_url_id, parse_code, type, first_verified ]

=back

=item Return value

Nothing useful. Return value is the result of the last Slash::DB::sqlUpdate command
which is the one that sets all relationships as valid.

=item Side effects

Alters the 'rel' table based on given input.

=item Dependencies

None.

=back

=cut

sub add_rels_mark_valid {
	my($self, @rels) = @_;

	for (@rels) {
		$self->sqlInsert('rel', {
			from_url_id	=> $_->[0],
			to_url_id	=> $_->[1],
			parse_code	=> $_->[2],
			type		=> $_->[3],
			first_verified	=> $_->[4],
		}, { ignore => 1 });
	}

	my @parts;
	for (@rels) {
		push @parts, "(from_url_id=$_->[0]   AND
			         to_url_id=$_->[1]   AND
			        parse_code='$_->[2]' AND
			              type='$_->[3]')";
	}
	my $where_clause = join(' OR ', @parts);

	$self->sqlUpdate('rel', { mark => 'valid' }, $where_clause);
}

############################################################
=head2 add_rel(from_url_id, to_url_id, parse_code, type, first_verified)

Add a relationship to the NewsVac database. This is the singular equivalent of
C<add_rels_mark_valid()> and may be deprecated in the future.

=over 4

=item Parameters

=over 4

=item $from_url_id

=item $to_url_id

=item $parse_code

=item $type

=item $first_verified

=back

=item Return value

None.

=item Side effects

Adds a record to the 'rel' table and marks it as VALID.

=item Dependencies

=back

=cut

sub add_rel {
	my($self, $from_url_id, $to_url_id, $parse_code, $type,
		$first_verified) = @_;

	my $first_verified_string = unix_to_sql_datetime($first_verified);

	my($rc1, $rc2);
	$rc1 = $self->sqlInsert('rel', {
		from_url_id	=> $from_url_id,
		to_url_id	=> $to_url_id,
		parse_code	=> $parse_code,
		type 		=> $type,
		first_verified 	=> $first_verified_string,
	});

	if (!$rc1) {
		$rc2 = $self->sqlUpdate('rel', {
			mark	=> 'valid',
		}, "from_url_id=$from_url_id AND to_url_id=$to_url_id AND " .
			"parse_code=$parse_code AND type=$type");
	}

	$self->errLog(getData('add_rel_result', {
		rc1		=> $rc1,
		rc2		=> $rc2,
		from_url_id	=> $from_url_id,
		to_url_id	=> $to_url_id,
		parse_code	=> $parse_code,
		type		=> $type,
	})) if $self->{debug} > 1;
}

############################################################

=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub rels_to_ids {
	# This isn't actually used anywhere!
	#
	# Good, because the Slash:DB::MySQL call below wouldn't work anyways!
	# - Cliff
	my($self, $from_url_id, $to_url_id, $tagname, $tagattr) = @_;

	my @where;
	push @where, 'from_url_id=' . $self->sqlQuote($from_url_id)
		if defined $from_url_id;
	push @where, 'to_url_id='   . $self->sqlQuote($to_url_id)
		if defined $to_url_id;
	push @where, 'tagname='     . $self->sqlQuote($tagname)
		if defined $tagname;
	push @where, 'tagattr='     . $self->sqlQuote($tagattr)
		if defined $tagattr;

	my $ary_ref = $self->sqlSelectColArrayref(
		'rel_id',
		'rel',
		join(' AND ', @where),
		'ORDER BY rel_id'
	);
	$self->errLog(getData('rels_to_ids_result', {
		from_url_id	=> $from_url_id,
		to_url_id	=> $to_url_id,
		tagname		=> $tagname,
		tagattr		=> $tagattr,
		rel_ids		=> $ary_ref,
	})) if $self->{debug} > 1;

	return @{$ary_ref};
}

############################################################

=head2 id_to_rel(rel_id)

Obtains the relationship from the NewsVac database associated with the given ID.

=over 4

=item Parameters

=over 4

=item $rel_id

Numeric value representing the ID of the relationship in question.

=back

=item Return value

An array reference containing relationship data. The form of the returned array is:

	[ from_url_id, to_url_id, tagname, tagattr ]

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub id_to_rel {
	# This should keep a cache for efficiency.
	my($self, $rel_id) = @_;
	my($ary_ref);
	my $q_rel_id = $self->sqlQuote($rel_id);

	my $select_text = <<EOT;
from_url_id, to_url_id, tagname, tagattr FROM rel WHERE rel_id=$q_rel_id
EOT

	my $sth = $self->select_cached($select_text);
	if ($sth) {
		$ary_ref = $sth->fetchrow_arrayref;
		$sth->finish;
	}

	$self->errLog(getData('id_ro_rel_result', {
		row => $ary_ref,
	})) if $self->{debug} > 1;

	return @{$ary_ref};
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub add_miner_and_urls {
	# This parameter list needs to be simplified, somehow.
	my($self, $minername, $last_edit_aid,
		$pre_stories_text, $post_stories_text, $pre_stories_regex, $post_stories_regex,
		$pre_story_text, $post_story_text, $pre_story_regex, $post_story_regex,
		$extract_vars, $extract_regex, $tweak_code, @urls) = @_;

	my $owner_aid = $last_edit_aid;

	$self->sqlInsert('miner', {
		name			=> $minername,
		owner_aid		=> $owner_aid,
		last_edit_aid		=> $last_edit_aid,
		pre_stories_text	=> $pre_stories_text,
		post_stories_text	=> $post_stories_text,
		pre_stories_regex	=> $pre_stories_regex,
		post_stories_regex	=> $post_stories_regex,
		pre_story_text		=> $pre_story_text,
		post_story_text		=> $post_story_text,
		pre_story_regex		=> $pre_story_regex,
		post_story_regex	=> $post_story_regex,
		extract_vars		=> $extract_vars,
		extract_regex		=> $extract_regex,
		tweak_code		=> $tweak_code,
	});

	@urls = grep { length($_) } @urls;
	$self->correlate_miner_to_urls($minername, @urls) if @urls;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub correlate_miner_to_urls {
	my($self, $minername, @urls) = @_;

	my $miner_id = $self->minername_to_id($minername);
	unless ($miner_id) {
		$self->errLog(getData('correlate_miner_to_url_noid', {
			miner_name => $minername,
		}));

		return;
	}

	# Redundant, information is printed with the next call to errLog().
	#$self->errLog("miner_id '$miner_id' for name '$minername'")
	#	if $self->{debug} > 1;

	# We might not need these locks any further.
	#$self->sqlTransactionStart('LOCK TABLES url_info WRITE');
	my(@url_ids);
	for (@urls) {
		$self->add_url($_);
		my $url_id = $self->url_to_id($_);
		push @url_ids, $url_id;
		$self->sqlUpdate('url_info', {
			miner_id => $miner_id,
		}, "url_id=$url_id");
	}
	#$self->sqlDo('UNLOCK TABLES');

	$self->errLog(getData('correlate_miner_to_urls_result', {
		miner_name	=> $minername,
		miner_id	=> $miner_id,
		url_ids		=> \@url_ids,
	})) if $self->{debug} > 1;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub minername_to_id {
	# This should keep a cache for efficiency.
	my($self, $minername) = @_;

	my $miner_id = $self->sqlSelect(
		'miner_id', 'miner', "name=" . $self->sqlQuote($minername)
	);

	$self->errLog(getData('minername_to_id', {
		miner_name	=> $minername,
		miner_id	=> $miner_id,
	})) if $self->{debug} > 1;

	return $miner_id;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub id_to_minername {
	# This should keep a cache for efficiency.
	my($self, $miner_id) = @_;

	my $minername = $self->sqlSelect('name', 'miner', "miner_id=$miner_id");

	$self->errLog(getData('id_to_minername', {
		miner_id	=> $miner_id,
		miner_name	=> $minername,
	})) if $self->{debug} > 1;

	return $minername;
}

############################################################

=head2 delete_url_ids(id_list)

Delete the URL IDs from the NewsVac database. Rows that reference a URN which is
unassociated with a miner will NOT be deleted from the 'url_info' table, but will be
from all other tables.

=over 4

=item Parameters

=over 4

=item @id_list
Entire parameter list represents IDs to be deleted from the database.

=back

=item Return value

None.

=item Side effects

May delete rows from the following tables:
	'nugget_sub'
	'rel'
	'url_analysis'
	'url_content'
	'url_info'
	'url_message_body'
	'url_plaintext'

=item Dependencies

None.

=back

=cut

sub delete_url_ids {
	my($self, @id_list) = @_;

	my $id_list = sprintf '(%s)', join(',', @id_list);

	$self->sqlDo("DELETE FROM url_content      WHERE url_id IN $id_list");
	$self->sqlDo("DELETE FROM url_message_body WHERE url_id IN $id_list");
	$self->sqlDo("DELETE FROM url_plaintext    WHERE url_id IN $id_list");
	$self->sqlDo("DELETE FROM nugget_sub       WHERE url_id IN $id_list");

	# Make sure to check both sides of the relationship.
	$self->sqlDo(<<EOT);
DELETE FROM rel WHERE from_url_id IN $id_list OR to_url_id IN $id_list
EOT

	# Yes, we want to delete url IDs, but NOT ones associated with a miner.
	# That would be bad (since as long as this record is in place, all
	# content in the remaining NewsVac tables can be refreshed if need be).
	$self->sqlDo(<<EOT);
DELETE FROM url_info WHERE url_id IN $id_list AND miner_id=0
EOT

	$self->sqlDo("DELETE FROM url_analysis WHERE url_id IN $id_list");
	$self->errLog(getData('delete_url_ids', {
		id_list => $id_list,
	})) if $self->{debug} > 1;
}

############################################################

=head2 delete_rel_ids(ids)

Deletes relationships from the NewsVac database given a list of relationship IDs.

=over 4

=item Parameters

=over 4

=item @ids

List containing relationship IDs that are to be deleted.

=back

=item Return value

None.

=item Side effects

Deletes matching rows from the 'rel' table.

=item Dependencies

None.

=back

=cut

sub delete_rel_ids {
	my($self, @ids) = @_;

	my $id_list = sprintf '(%s)', join(',', @ids);
	$self->sqlDo("DELETE FROM rel WHERE rel_id IN $id_list");

	$self->errLog(getData('delete_rel_ids', {
		id_list => $id_list,
	})) if $self->{debug} > 1;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub info_to_nugget_url {
	my($self, $dest_url, $title, $source, $slug) = @_;

	$dest_url	= $self->canonical($dest_url)->as_string;
	$title		= tag_space_squeeze($title);
	$source		= tag_space_squeeze($source);
	$slug		= tag_space_squeeze($slug);

	my %nugget_data = (
		url	=> $dest_url,
		title	=> $title,
		source	=> $source,
		slug	=> $slug,
	);

	my $nugget_url = $self->canonical(
		'nugget://' .
		join('&',
			map { "$_=" . uri_escape($nugget_data{$_}, '\W') }
			sort keys %nugget_data
		)
	);

	return $nugget_url;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub nugget_url_to_info {
	my($self, $nugget_url) = @_;
	my %info;

	$nugget_url =~ s{^nugget://}{};
	while ($nugget_url =~ /(url|title|source|slug)=([^&]+)/g) {
		$info{$1} = uri_unescape($2);
	}

	return \%info;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub add_nuggets_return_ids {
	my($self, $miner_name, @nugget_hashes) = @_;

	my @dest_urls;
	for my $nh (@nugget_hashes) {
		$nh->{dest_url} = $self->canonical($nh->{dest_url})->as_string;
		push @dest_urls, $nh->{dest_url};
	}

	# This transaction needs to be better defined. Before it only included
	# the url_info table, however the rels table is also involved here, it
	# seems.
	#
	# For now, let's turn this off. I see no accompanying UNLOCK TABLES
	# here, either. -- Cliff
	#
	#$self->sqlTransactionStart('LOCK TABLES url_info WRITE, rel WRITE');

	my @dest_url_ids = $self->add_urls_return_ids(@dest_urls);
	$self->errLog(getData('add_nuggets_returl_ids_desturlids', {
		dest_url_ids	=> \@dest_url_ids,
		dest_urls	=> \@dest_urls,
	})) if $self->{debug} > 1;

	my @nugget_urls;
	for my $nh (@nugget_hashes) {
		my $nugget_url = $self->info_to_nugget_url(
			$nh->{dest_url},
			$nh->{title},
			$nh->{source},
			$nh->{slug}
		);

		push @nugget_urls, $nugget_url;
	}
	my @nugget_url_ids = $self->add_urls_return_ids(@nugget_urls);
	$self->errLog(getData('add_nuggets_return_ids_nugurlids', {
		nugget_url_ids	=> \@nugget_url_ids,
		nugget_urls	=> \@nugget_urls,
	})) if $self->{debug} > 1;

	my @rels;
	for (0..$#dest_url_ids) {
		my $nughash = $nugget_hashes[$_];

		if (!$nughash->{source_url_id} ||
		    !$nugget_url_ids[$_]       ||
		    !$nughash->{response_timestamp})
		{
			$self->errLog(getData('add_rel_components_missing', {
				src_url_id	=> $nughash->{source_url_id},
				dest_url_id 	=> $dest_url_ids[$_],
				nugget_dest_url => $nughash->{dest_url},
				nugget_url_ids 	=> $nugget_url_ids[$_],
				response_timestamp =>
					$nughash->{response_timestamp},
			})) if $self->{debug} > 1;
		}
		push @rels, [
			$nughash->{source_url_id},
			$nugget_url_ids[$_],
			'miner',
			$miner_name,
			unix_to_sql_datetime($nughash->{response_timestamp}),
		];
	}

	$self->add_rels_mark_valid(@rels);
	#$self->sqlTransactionFinish('UNLOCK TABLES');

	return(@nugget_url_ids);
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub process_urls {
	my($self, $conditions_ref, @urls) = @_;
	my @url_ids = $self->urls_to_ids(@urls);

	$self->errLog(getData('process_urls', {
		urls	=> \@urls,
		url_ids	=> \@url_ids,
	})) if $self->{debug} > 1;

	$self->process_urls_and_ids($conditions_ref, \@urls, \@url_ids);
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub process_url_ids {
	my($self, $conditions_ref, @url_ids) = @_;
	my @urls = $self->ids_to_urls(@url_ids);

	$self->errLog(getData('process_url_ids', {
		urls	=> \@urls,
		url_ids	=> \@url_ids,
	})) if $self->{debug} > 1;
	$self->process_urls_and_ids($conditions_ref, \@urls, \@url_ids);
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub process_urls_and_ids {
	my($self, $conditions_ref, $urls_ar, $ids_ar) = @_;
	my $start_time;

	$self->errLog(getData('process_urls_and_ids_listids', {
		num_urls	=> scalar @$urls_ar,
		url_ids		=> $ids_ar,
	})) if $self->{debug} > 1;

	for (0..$#$urls_ar) {
		my($url, $url_id) = ($urls_ar->[$_], $ids_ar->[$_]);
		my(%update_info, %update_content, %update_other);

		if (!$url || !$url_id) {
			$self->errLog(getData('process_urls_and_ids_missing', {
				'index' => $_,
			}));
			next;
		}

		$start_time = Time::HiRes::time();
		$self->request(
			$url_id,
			$url,
			\%update_info,
			\%update_content,
			\%update_other,
			$conditions_ref
		);
		$self->errLog(getData('process_urls_and_ids_reqresult', {
			success	=> $update_info{is_success},
			url	=> $url,
			url_id	=> $url_id,
		})) if $self->{debug} > 0;

		if ($update_info{is_success}) {
			$start_time = Time::HiRes::time();
			$self->analyze(
				$url_id,
				$url,
				\%update_info,
				\%update_content,
				\%update_other,
				$conditions_ref
			);
		}
	}
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub request {
	my($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
		$conditions_ref) = @_;

	my $start_time = Time::HiRes::time();

	# Set the cookie jar, which will be empty unless we get cookies from
	# the db.
	$self->{ua}->cookie_jar->clear;

	my $old_info_ref = $self->sqlSelectHashref(
		'*', 'url_info', "url_id=$url_id"
	);
	my $current_time = $conditions_ref->{use_current_time} || time;

	if ($old_info_ref) {
		$self->errLog(getData('request_oldinfodisplay', {
			old_info	=> $old_info_ref,
		})) if $self->{debug} > 1;

		my $believed_fresh_until;
		if ($old_info_ref->{believed_fresh_until}) {
			$believed_fresh_until = sql_to_unix_datetime(
				$old_info_ref->{believed_fresh_until}
			);
		} else {
			$believed_fresh_until = $current_time;
		}

		if (!$conditions_ref->{force_request}) {
			if ($believed_fresh_until > $current_time) {
				$self->errLog(getData('request_urlfresh', {
					url_id	=> $url_id,
					dur	=> $believed_fresh_until -
						   $current_time,
				})) if $self->{debug} > 1;

				@{$info_ref}{keys %$old_info_ref} = values %$old_info_ref;
				my $new_content_ref = $self->sqlSelectHashref(
					'url_content.url_id, response_header,
					cookies, message_body, plaintext',

					'url_content, url_message_body,
					url_plaintext',

					"url_content.url_id      = $url_id AND
					 url_message_body.url_id = $url_id AND
					 url_plaintext.url_id    = $url_id"
				);
				%$content_ref = %$new_content_ref if $new_content_ref;
				$other_ref->{response_timestamp} = sql_to_unix_datetime(
					$info_ref->{last_success}
				);

				$self->errLog(getData('request_urlkeysinfo', {
					url_id	=> $url_id,
					info 	=> $info_ref,
					content	=> $content_ref,
					other	=> $other_ref,
				})) if $self->{debug} > 0;

				return;
			} else {
				$self->errLog(getData('request_urlstale', {
					url_id	=> $url_id,
				})) if $self->{debug} > 1;
			}
		}

		my $ar = $self->sqlSelectColArrayref(
			'cookies', 'url_content', "url_id = $url_id"
		);
		if ($ar and defined($ar->[0])) {
			my $cookies = $ar->[0];
			if ($cookies =~ /\A((\#.*|\s*)\n)*\Z/m) {
				# Don't bother writing the cookies if the only
				# data is a single line of comment.
			} else {
				# We have real cookie text. Write it to a file
				# and zap it into the cookie_jar.  (The only
				# reliable way of getting it into a
				# HTTP::Cookies object, unfortunately).
				my($fh, $filename) = tempfile();
				print $fh $cookies;
				close $fh;
				$self->{ua}->cookie_jar->load($filename);
				unlink $filename;
			}
		}
	}

	if ($url =~ /^nugget:\/\//) {
		$other_ref->{response_timestamp} = $current_time;
		$other_ref->{freshness_lifetime} = 86_400 * 365;
		$other_ref->{response_timestamp_string} = unix_to_sql_datetime(
			$other_ref->{response_timestamp}
		);

		$info_ref->{is_success}           = 1;
		$info_ref->{last_attempt}         = $other_ref->{response_timestamp_string};
		$info_ref->{last_success}         = $info_ref->{last_attempt};
		$info_ref->{status_code}          = 200;
		$info_ref->{reason_phrase}        = "OK Nugget";
		$info_ref->{believed_fresh_until} = unix_to_sql_datetime(
			$other_ref->{response_timestamp} +
			$other_ref->{freshness_lifetime}
		);

		my $ni = $self->nugget_url_to_info($url);
		$info_ref->{title} = $ni->{title} if $ni->{title};
		$info_ref->{content_type} = 'application/nugget';
	} else {
		# There should be a way to specify GET vs. POST; other
		# arguments should be available to be passed in -- cookies for
		# one example, form data for POSTs for another.
		my $request = new HTTP::Request('GET', $url);

		# Set the LWP::UserAgent's parameters.
		my $timeout  = $conditions_ref->{timeout} || 20;
		my $max_size = 0;
#		$max_size = exists($conditions_ref->{max_size}) ?
#			$conditions_ref->{max_size} : 200_000;
		$self->{ua}->timeout($timeout);
		$self->{ua}->max_size($max_size) if $max_size;

		# Instead of pulling into a variable, saving to a unique
		# filename for large responses might be nice.
		my $response = '';
		eval {
			# This die() is legal.
			local $SIG{ALRM} = sub { die 'timeout' };
			alarm $timeout + 1;
			$response = $self->{ua}->request($request);
			alarm 0;
		};
		$self->errLog(getData('request_uaerror', {
			err => $@, url_id => $url_id, url => $url,
		})) if $@;

		if (!$response) {
			$info_ref->{is_success}          = 0;
			$info_ref->{status_code}         = 599;
			$info_ref->{reason_phrase}       = "UDBT timeout $timeout";
			$other_ref->{response_timestamp} = $current_time;
			$other_ref->{freshness_lifetime} = 300;
		} else {
			$info_ref->{is_success}          = $response->is_success ? 1 : 0;
			$other_ref->{response_timestamp} =
				$response->date || $response->client_date || $current_time;

			# Don't accept responses coded as being from the future
			# (TCP doesn't work with tachyons).
			$other_ref->{response_timestamp} = $current_time
				if $other_ref->{response_timestamp} > $current_time;
			$other_ref->{freshness_lifetime} =
				$response->freshness_lifetime;

			# negative freshness doesn't make sense
			$other_ref->{freshness_lifetime} = 0
				if $other_ref->{freshness_lifetime} < 0;
			$info_ref->{status_code}         = $response->code;
			$info_ref->{reason_phrase}       = $response->message;
		}

		$other_ref->{response_timestamp_string} = unix_to_sql_datetime(
			$other_ref->{response_timestamp}
		);

		$info_ref->{last_attempt} = $other_ref->{response_timestamp_string};
		$info_ref->{believed_fresh_until} = unix_to_sql_datetime(
			$other_ref->{response_timestamp} +
			$other_ref->{freshness_lifetime}
		);
		$info_ref->{believed_fresh_until} = unix_to_sql_datetime(
			$current_time + 300
		) if !$info_ref->{believed_fresh_until} or
		      $other_ref->{response_timestamp} +
		      $other_ref->{freshness_lifetime} < $current_time + 300;

		if (!$info_ref->{is_success}) {
			$self->errLog(getData('request_nosuccess', {
				url_id		=> $url_id,
				url		=> $url,
				response	=> $response ?
					$response->error_as_HTML : '',
			})) if $self->{debug} > 1;
		} else {
			# The request succeeded;  update lots of stuff.
			$info_ref->{last_success} = $info_ref->{last_attempt};
			$info_ref->{url_base}     = $response->base;
			$info_ref->{content_type} = $response->header('content-type');
			$info_ref->{title}        = $response->header('title');
#			$info_ref->{value}	  = $self->aged_value(
#				$old_info_ref->{value},
#				$other_ref->{response_timestamp} -
#			) if $old_info_ref->{value};

			$content_ref->{response_header} = $response->headers_as_string;
			$content_ref->{message_body}    = $response->content;

			my($fh, $filename) = tempfile();
			close $fh;
			$self->{ua}->cookie_jar->save($filename);
			if (open($fh, $filename)) {
				local $/ = undef;
				$content_ref->{cookies} = <$fh>;
				close $fh;
			}
			unlink $filename;
		}
	}

	# If the url_base is the same as the url, delete it.
	if ($info_ref->{url_base}) {
		my $url_base_obj = URI->new($info_ref->{url_base});
		my $url_base_str = $url_base_obj->as_string;

		$self->errLog(getData('request_delurlbase', {
			url		=> $url,
			url_base	=> $info_ref->{url_base},
			url_base_str	=> $url_base_str,
		})) if $self->{debug} > 1;
		$info_ref->{url_base} = undef if $url eq $url_base_str;
	}

	$self->sqlUpdate("url_info", $info_ref, "url_id = $url_id")
		if keys %$info_ref;
	if (keys %$content_ref) {
		# This simplifies the INSERT/UPDATE logic: do blind INSERTS
		# on the ID and then UPDATE it later.
		for (qw(url_content url_message_body url_plaintext)) {
			$self->sqlInsert($_, {
				url_id => $url_id
			}, { ignore => 1 });
		}

		# For url_content table, copy all from the update reference,
		# but the 'message_body' and 'plaintext' fields.
		my $temp_ref = {};
		$temp_ref->{$_} = $content_ref->{$_}
			for grep !/message_body|plaintext/, keys %$content_ref;
		$self->sqlUpdate('url_content', $temp_ref, "url_id=$url_id");
		# Now update the plaintext.
		if (exists $content_ref->{plaintext}) {
			$self->sqlUpdate("url_plaintext", {
				plaintext => $content_ref->{plaintext}
			}, "url_id=$url_id");
		}
		# Now update the message body.
		if (exists $content_ref->{message_body}) {
			# This was found using test inserts of content created
			# from /dev/urandom and trying subsequent inserts into
			# the database to see where the upper limit was. To my
			# knowledge, this limit IS imposed by MySQL, not DBI,
			# according to Krow. No workaround is known at this time
			# except to prevent this from occuring by establishing
			# a limit.
			#
			# The max limit on data inserted is just shy over 2
			# megs:
			# 	(dd if=/dev/urandom of=test bs=1024 count=2007)
			# or some 2055168 bytes. Insert anything over this size
			# then perl scripts go *boom*.  -- Cliff
			if (length($content_ref->{message_body}) < 2007*1024) {
				$self->sqlUpdate('url_message_body', {
					message_body => $content_ref->{message_body}
				}, "url_id=$url_id");
			} else {
				$self->errLog(getData('request_overflow', {
					message_body => $content_ref->{message_body},
				}));
			}
		}
	}

	# Carry over the previous SQL data into the info_ref hash.
	$info_ref->{$_} ||= $old_info_ref->{$_} for keys %$old_info_ref;

	my $duration = Time::HiRes::time() - $start_time;
	$self->errLog(getData('request_durtoolong', {
		content_length	=> length($content_ref->{message_body}),
		dur		=> round($duration),
			# int($duration * 1000 + 0.5) / 1000,
		url_id		=> $url_id,
	})) if $duration > 43;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub analyze {
	my($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
		$conditions_ref) = @_;

	$self->errLog(getData('analyze_contentlength', {
		content_length => length($content_ref->{message_body}),
	})) if $self->{debug} > 0;

	# Remember that get_parse_codes() is parameter compatible with this
	# routine only for parameters 1-4 (not counting $self).
	my @parse_codes = $self->get_parse_codes(@_[1 .. 4]);

	for my $parse_code (@parse_codes) {
		my $ua_start = Time::HiRes::time();
		my $ary_ref = $self->sqlSelectColArrayref(
			'UNIX_TIMESTAMP(ts)',
			'url_analysis',
			"url_id=$url_id AND parse_code='$parse_code' AND
			 is_success=1",
			'ORDER BY ts DESC LIMIT 1'
		);

		my $last_success = 0;
		$last_success = $ary_ref->[0] if $ary_ref;
		$self->errLog(getData('analyze_urlid', {
			url_id		=> $url_id,
			parse_code	=> $parse_code,
			last_success	=> $last_success,
			response_ts	=> $other_ref->{response_timestamp},
			url		=> $url,
		})) if $self->{debug} > 1;

		if ($last_success < $other_ref->{response_timestamp}
			|| $conditions_ref->{force_analyze}
			|| $conditions_ref->{"force_analyze_$parse_code"}
		) {
			# The last successful analysis using this parse_code
			# took place before the last successful request (or
			# never took place). Or, we're being told to force
			# it...either way we need to re-analyze it.
			my $parse_method = $self->get_parse_code_method($parse_code);
			if ($parse_method) {
				# This marks "related URL" records as 'invalid' in
				# anticipation of fresh data.
				$self->sqlUpdate('rel', {
					mark => 'invalid'
				}, "from_url_id='$url_id' AND
				    parse_code='$parse_code'"
				);
				$self->errLog(getData('content_ref_length', {
					content_length =>
					length($content_ref->{message_body}),
				})) if $self->{debug} > 0;

				my $start_time = Time::HiRes::time();
				# Do the work!
				my $return_hr = $parse_method->(@_);

				my $duration =
					Time::HiRes::time() - $start_time;

				my $is_success = 'NULL';
				$is_success = $return_hr->{is_success}
					if defined($return_hr->{is_success});

				my $miner_id = 0;
				$miner_id = $return_hr->{miner_id}
					if $return_hr->{miner_id};

				my $n_nuggets = 'NULL';
				$n_nuggets = $return_hr->{n_nuggets}
					if defined($return_hr->{n_nuggets});

				$self->sqlInsert('url_analysis', {
					url_id		=> $url_id,
					parse_code	=> $parse_code,
					is_success	=> $is_success,
					duration	=> $duration,
					miner_id	=> $miner_id,
					nuggets		=> $n_nuggets,
				});

				$self->errLog(getData('analyze_results', {
					url_id		=> $url_id,
					parse_code	=> $parse_code,
					is_success	=> $is_success,
					duration	=> $duration,
					miner_id	=> $miner_id,
					num_nuggets	=> $n_nuggets,
				})) if $self->{debug} > 0;
			} else {
				$self->errLog(getData('analyze_noparse', {
					parse_code	=> $parse_code,
				}));
			}
		}
	}

	$self->sqlDo(<<EOT);
DELETE FROM rel WHERE from_url_id='$url_id' AND mark='invalid'
EOT

}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub get_parse_codes {
	my($self, $url_id, $url, $update_info_ref, $update_content_ref,
		$response_timestamp) = @_;

	my @codes;

	# If invoked with a false url_id, return a list of all possible parse
	# codes.
	return qw(html_linkextor miner nugget plaintext) if !$url_id;

	# Sometime in the future, there will be a way to decide which URLs
	# get which codes.  For now, every URL with an appropriate content
	# type gets exactly one parsing function and it's this one.
#	push @codes, 'html_linkextor'
#		if ($update_info_ref->{content_type} and
#		    $update_info_ref->{content_type} =~ /^text\/html\b/;

	push @codes, 'miner'
		if $update_info_ref->{miner_id};

	push @codes, 'plaintext'
		if $update_info_ref->{content_type} and
		   $update_info_ref->{content_type} =~ /^text\/(plain|html)\b/;

	push @codes, 'nugget'
		if $update_info_ref->{content_type} and
		   $update_info_ref->{content_type} eq 'application/nugget';

	$self->errLog(getData('get_parse_codes', {
		url_id	=> $url_id,
		codes	=> \@codes,
	})) if $self->{debug} > 0;

	return @codes;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub get_parse_code_method {
	my($self, $code) = @_;

	return \&parse_html_linkextor	if $code eq 'html_linkextor';
	return \&parse_miner		if $code eq 'miner';
	return \&parse_plaintext	if $code eq 'plaintext';
	return \&parse_nugget		if $code eq 'nugget';

	return undef;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub get_rel_types {
	my($self, $parse_code) = @_;
	my(@types);

	if ($parse_code eq 'html_linkextor') {
		while (my($tagname, $tagattr) =
			each %HTML::LinkExtor::LINK_ELEMENT
		) {
			if (ref $tagattr eq 'ARRAY') {
				push @types, map { "${tagname}_$_" } @$tagattr;
			} else {
				push @types, "${tagname}_$tagattr";
			}
		}
	} elsif ($parse_code eq 'miner') {
		push @types, 'miner';
	} elsif ($parse_code eq 'plaintext') {
		# Plaintext parsing doesn't add any types.
	} elsif ($parse_code eq 'nugget') {
		push @types, 'nugget';
	}

	return @types;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

# You know, I don't think this is even used. See get_parse_codes
# which is basically a straight port from UDBT.pm
sub parse_html_linkextor {
	my($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
		$conditions_ref) = @_;

	$self->errLog(getData('parse_html_linkextor_start', {
		url_id => $url_id,
	})) if $self->{debug} > 1;

	my $base_url = $info_ref->{url_base} || $url;
	$self->errLog(getData('parse_html_linkextor_baseurl', {
		base_url	=> $base_url,
	})) if $self->{debug} > 1;
	my $response_timestamp =
		$other_ref->{response_timestamp} ||
		sql_to_unix_datetime($info_ref->{last_success});
	$self->errLog(getData('parse_html_linkextor_nots', {
		last_ts	=> $info_ref->{last_success},
	})) if !$response_timestamp;

	# Use HTML::LinkExtor to parse the body text.
	my $hle = HTML::LinkExtor->new(\&parse_html_linkextor_callback);
	local($callback_ref) = {
		base_url	=> $base_url,
		link_ref	=> {},
	};
	$self->errLog(getData('parse_html_linkextor_preparse', {
		url_id		=> $url_id,
		callback	=> $callback_ref,
	})) if $self->{debug} > 1;
	$hle->parse($content_ref->{message_body});
	$self->errLog(getData('parse_html_linkextor_postparse', {
		url_id		=> $url_id,
		content_length	=> length($content_ref->{message_body}),
		callback_link	=> $callback_ref->{link_ref},
	})) if $self->{debug} > 1;

	# Now add those URLs and relations tying them to our source URL.
	#$self->sqlTransactionStart("LOCK TABLES url_info WRITE");
	for (sort keys %{$callback_ref->{link_ref}}) {
		my($tagname, $tagattr, $new_url) = /^(\w+) (\w+) (.+)$/;

		# The URL is canonicalized in the parse_html_linkextor_callback
		# according to URI.pm, but UDBT.pm's canonical() may be
		# slightly different so we must do it again.
		$new_url = $self->canonical($new_url);
		$self->add_url($new_url);
		my $new_url_id = $self->url_to_id($new_url);
		$self->add_rel(
			$url_id,
			$new_url_id,
			'html_linkextor',
			"${tagname}_$tagattr",
			$response_timestamp
		);
	}
	#$self->sqlDo("UNLOCK TABLES");

	# Naked Hashref. I wonder if it will do lunch?
	return { is_success => 1 };
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub parse_html_linkextor_callback {
	my($self, $tagname, %attr) = @_;

	for (keys %attr) {
		my $new_url = URI->new_abs(
			$attr{$_}, $callback_ref->{base_url}
		)->canonical->as_string;

		my $key = "$tagname $_ $new_url";
		$callback_ref->{link_ref}{$key}++;
	}
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub trim_body {
	my($self, $miner_id, $body_ref, $pre_text, $pre_regex, $post_text,
		$post_regex) = @_;
	my $orig_body_length = length($$body_ref);

	my $the_reg = '';
	if ($pre_text) {
		my $cs = $pre_text =~ s{^\(\?i\)}{};
		$the_reg = "\Q$pre_text\E";
		# In the text field, " " is aliased to mean "any amount of
		# whitespace."
		$the_reg =~ s/\\ /\\s+/g;
		$the_reg = "(?i)$the_reg" if $cs;
	}
	if ($pre_regex) {
		$self->errLog(getData('trim_body_bothdefined', {
			miner_id => $miner_id,
		})) if $the_reg;
		$the_reg = $pre_regex;
	}
	if ($the_reg) {
		$the_reg =~ s{^(\(\?i\))?(.*)}{$1\\A[\\000-\\377]*?$2};
		$self->errLog(getData('trim_body_thereg', {
			the_reg => $the_reg,
			miner_id=> $miner_id,
			type 	=> 'pre',
		})) if $self->{debug} > 0;
		$$body_ref =~ s{$the_reg}{}m;
	}

	$the_reg = '';
	if ($post_text) {
		my $cs = $post_text =~ s{^\(\?i\)}{};
		$the_reg = "\Q$post_text\E";
		# In the text field, " " is aliased to mean "any amount of
		# whitespace."
		$the_reg =~ s/\\ /\\s+/g;
		$the_reg = "(?i)$the_reg" if $cs;
	}
	if ($post_regex) {
		$self->errLog(getData('trim_body_bothpostdefined', {
			miner_id => $miner_id,
		})) if $the_reg;
		$the_reg = $post_regex;
	}
	if ($the_reg) {
		$the_reg .= "[\\000-\\377]*\\Z";
		$self->errLog(getData('trim_body_thereg', {
			the_reg	=> $the_reg,
			miner_id=> $miner_id,
			type	=> 'post',
		})) if $self->{debug} > 0;
		$$body_ref =~ s{$the_reg}{}m;
	}

	$self->errLog(getData('trim_body', {
		miner_id	=> $miner_id,
		orig_body_length=> $orig_body_length,
		body_length	=> length($$body_ref),
	})) if $self->{debug} > 0;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub parse_miner {
	my($self, $url_id, $url_orig, $info_ref, $content_ref, $other_ref,
		$conditions_ref) = @_;

	$self->errLog(getData('parse_miner_info', {
		url_id	=> $url_id,
		url	=> $url_orig,
		miner_id=> $info_ref->{miner_id},
	})) if $self->{debug} > 0;
	return { is_success => 0 } unless $info_ref->{miner_id};

	my $start_time = Time::HiRes::time();
	my($mid_time_1, $mid_time_2) = ($start_time, $start_time);

	my $response_timestamp =
		$other_ref->{response_timestamp} ||
		sql_to_unix_datetime($info_ref->{last_success});
	$self->errLog(getData('parse_miner_nots', {
		timestamp => $info_ref->{last_success},
	})) if !$response_timestamp;

	my $base_url = $info_ref->{url_base} || $url_orig;

	my $hr = $self->sqlSelectHashref(
		'*', 'miner', "miner_id=$info_ref->{miner_id}"
	);
	if ($hr->{name} eq 'none') {
		$self->errLog(getData('parse_miner_ignore', {
			url_id	=> $url_id,
			url	=> $url_orig,
		})) if $self->{debug} > 0;

		return {
			is_success	=> 0,
			n_nuggets	=> 0,
			miner_id	=> $info_ref->{miner_id}
		};
	}

	my $message_body = $content_ref->{message_body};
	$self->errLog(getData('parse_miner_emptybody', {
		url	=> $url_orig,
		url_id	=> $url_id,
		miner_id=> $info_ref->{miner_id},
	})) if !$message_body;

	my @extraction_keys		= qw( url title source slug body );
	my $extraction_key_regex	= '^(' . join('|', @extraction_keys) . ')$';
	my @extract_vars		= grep /$extraction_key_regex/,
					  split / /, $hr->{extract_vars};
	my $extract_regex		= $hr->{extract_regex};
	my $tweak_code			= $hr->{tweak_code} || '';
	my($count, $url, $title, $source, $slug, $body, $key, %nugget) = (0);

	if ($content_ref->{content_type} =~ /xml|rss|rdf/i || $info_ref->{url} =~ /(?:rss|rdf|xml)$/i) {
		my $rss = new XML::RSS;
		(my $data = $message_body) =~ s/&(?!#?[a-zA-Z0-9]+;)/&amp;/g;
		eval { $rss->parse($data) };

		if ($@) {
			$self->errLog($@) if $self->{debug} > -1;
			return {
				is_success	=> 0,
				n_nuggets	=> 0,
				miner_id	=> $info_ref->{miner_id}
			};
		}

		for my $item (@{$rss->{items}}) {
			for (keys %{$item}) {
			    $item->{$_} = xmldecode($item->{$_});
			}
			next unless $item->{'link'};
			++$count;
			$key = join "\n", (
				$count,
				$item->{'link'},
				$item->{title},
				$rss->{channel}{title},
				$item->{description},
				""
			);
			$nugget{$key}++;
		}

	} else {

		$self->trim_body(
			$info_ref->{miner_id},
			\$message_body,
			$hr->{pre_stories_text},
			$hr->{pre_stories_regex},
			$hr->{post_stories_text},
			$hr->{post_stories_regex}
		);


		if (!$extract_regex) {
			$self->errLog(getData('parse_miner_noregex', {
				hr	=> $hr,
			})) if $self->{debug} > -1;

			return {
				is_success	=> 0,
				n_nuggets 	=> 0,
				miner_id 	=> $info_ref->{miner_id}
			};
		}

		my $regex_err = $self->check_regex($extract_regex, 'x');
		if ($regex_err) {
			$self->errLog(getData('parse_miner_regexerr', {
				error	=> $regex_err,
				miner_id=> $info_ref->{miner_id},
				url	=> $url_orig,
				url_id	=> $url_id,
			})) if $self->{debug} > -1;

			return {
				is_success => 0,
				n_nuggets => 0,
				miner_id => $info_ref->{miner_id}
			};
		}

		$self->errLog(getData('parse_miner_minerdata', {
			extraction_key_regex 	=> $extraction_key_regex,
			body_length		=> length($message_body),
			extract_vars 		=> \@extract_vars,
			extract_regex 		=> $extract_regex,
			tweak_code 		=> $tweak_code,
			base_url 		=> $base_url,
		})) if $self->{debug} > 1;

		$message_body =~ s{\s+}{ }g;
		$self->errLog(getData('parse_miner_bodystats', {
			message_body => $message_body,
		})) if $self->{debug} > 1;
		while ($message_body =~ /$extract_regex/gx) {
			my %extractions;
			for (my $i = 0; $i < @extract_vars; ++$i) {
				# note: $1 eq substr($message_body, $-[1], $+[1] - $-[1])
				# and   $2 eq substr($message_body, $-[2], $+[2] - $-[2])
				# etc.
				my $str = substr($message_body, $-[$i+1], $+[$i+1] - $-[$i+1]);
				$extractions{$extract_vars[$i]} = $str if length $str;
			}

			next unless $extractions{url} || $extractions{body};
			++$count;
			$key = join "\n", (
				$count,
				$extractions{url},
				$extractions{title},
				$extractions{source},
				$extractions{slug},
				$extractions{body}
			);
			$nugget{$key}++;
		}
	}


	# If the hash is empty, time to bail, but the success flag is still
	# set.
	return {
		is_success 	=> 1,
		n_nuggets 	=> 0,
		miner_id	=> $info_ref->{miner_id}
	} if ! keys %nugget;

	my @nugget_keys = keys %nugget;
	$self->errLog("nugget keys: @nugget_keys") if $self->{debug} > 1;

	for (@nugget_keys) {
		delete $nugget{$_};
		($count, $url, $title, $source, $slug, $body) = split "\n", $_;
		$url =~ s/\s+//g;

		if ($url) {
			$self->errLog(getData('parse_miner_showurl', {
				url		=> $url,
				url_base	=> $info_ref->{url_base},
				url_orig	=> $url_orig,
				base_url	=> $base_url,
			})) if $self->{debug} > 1;

			$url = URI->new_abs(
				$url,
				$base_url
			)->canonical->as_string;
		}

		if ($url !~ /^(http|ftp):/) {
			my($origurl, $etc) = split "\n", $_;

			$self->errLog(getData('parse_miner_badproto', {
				url		=> $url,
				url_orig	=> $origurl,
				base_url	=> $base_url,
			})) if $self->{debug} > 1;
			next;
		}

		$title  = tag_space_squeeze($title);
		$source = tag_space_squeeze($source);
		$slug   = tag_space_squeeze($slug);
		$body   = tag_space_squeeze($body);
		$key    = join "\n", $count, $url, $title, $source, $slug, $body;
		$nugget{$key}++;
	}

	@nugget_keys =  map	{ $_->[0] }
			sort	{ $a->[1] <=> $b->[1] }
			map	{ [ $_, (split "\n", $_)[0] ] }
			keys %nugget;

	my %seen_url;
	$self->errLog(getData('parse_miner_nuggetkeys', {
		nugget_keys => \@nugget_keys,
	})) if $self->{debug} > 1;

	if ($tweak_code) {
		for my $key (@nugget_keys) {
			our $cancel = 0;
			# make lexical globals so we can share them with
			# our safe compartment
			our($count, $url, $title, $source, $slug, $body) = split "\n", $key;
			my $seen_url = defined($seen_url{$url}) ? 1 : 0;

			my $cpt = new Safe;
			$cpt->permit(qw(:base_core :base_mem :base_loop));
			$cpt->share(qw($cancel $count $url $title $source $slug $body));
			$cpt->reval($tweak_code);

			delete $nugget{$key};
			if (!$cancel) {
				$key = join "\n", $count, $url, $title, $source, $slug, $body;
				$nugget{$key}++;
				$seen_url{$url} = 1;
			}
		}
	}

	# From this point on, we don't want the "count" because all hits
	# with the same data should be counted only once.
	@nugget_keys = keys %nugget;
	for (@nugget_keys) {
		delete $nugget{$_};
		# "$count\n$title\n$source\n$slug\n$body"
		s/^(\d+)\n//;
		$nugget{$_}++;
	}

	@nugget_keys = sort keys %nugget;
	$self->errLog(getData('parse_miner_nuggetinfo', {
		miner_id	=> $info_ref->{miner_id},
		miner_name	=> $hr->{name},
		nugget_keys	=> \@nugget_keys,
	})) if $self->{debug} > 1;
	if ($self->{debug} > 0) {
		$self->errLog(getData('parse_miner_preaddnugget'));
	}

	my(@nugget_hashes, @bodies);
	for (@nugget_keys) {
		($url, $title, $source, $slug, $body) = split "\n", $_;

		push @nugget_hashes, {
			source_url_id		=> $url_id,
			source_url		=> $url_orig,
			dest_url		=> $url,
			title			=> $title,
			source			=> $source,
			slug			=> $slug,
			response_timestamp	=> $response_timestamp,
		};
		push @bodies, $body;
	}
	$self->errLog(getData('parse_miner_shownuggets', {
		nuggets	=> \@nugget_hashes,
		bodies	=> \@bodies,
	})) if $self->{debug} > 1;
	@bodies = ();

	$mid_time_1 = Time::HiRes::time() - $start_time;
	$self->errLog(getData('parse_miner_addnuggetstart', {
		miner_id	=> $info_ref->{miner_id},
		url_id		=> $url_id,
		num		=> scalar @nugget_hashes,
	})) if $self->{debug} > 1;
	my @nugget_url_ids = $self->add_nuggets_return_ids(
		$hr->{name}, @nugget_hashes
	);
	$self->errLog(getData('parse_miner_addnuggetend', {
		nugget_url_ids	=> \@nugget_url_ids,
	})) if $self->{debug} > 1;
	$mid_time_2 = Time::HiRes::time() - $start_time;

	$self->errLog(getData('parse_miner_processurlstart', {
		miner_id	=> $info_ref->{miner_id},
		url_id		=> $url_id,
	})) if $self->{debug} > 1;
	# This is kinda unusual.  Adding a nugget means processing it
	# automatically. This is computationally cheap because there's
	# no need to hit the network or do a ton of processing;
	# basically this is the canonical way to go ahead and add the
	# dest_url and link the nugget_url to it.

	# Let's try not doing this...
#	$self->process_url_ids(
#		{ use_current_time => $response_timestamp },
#		@nugget_url_ids
#	);
	if ($self->{debug} > 0) {
		$self->errLog(getData('parse_miner_processurlend'));
	}

	my $duration = Time::HiRes::time() - $start_time;
	$self->errLog(getData('parse_miner_longdur', {
		miner_id	=> $info_ref->{miner_id},
		miner_name	=> $hr->{name},
		url_id		=> $url_id,
		message_len	=> length($message_body),
		midtime_1	=> round($mid_time_1),
			#int($mid_time_1*1000+0.5)/1000 .
		midtime_2	=> round($mid_time_2),
			#int($mid_time_2*1000+0.5)/1000 .
		nuggets		=> scalar keys %nugget,
		duration	=> round($duration),
			#int($duration*1000+0.5)/1000
	})) if $duration > 40;

	return {
		is_success 	=> 1,
		n_nuggets	=> scalar(keys %nugget),
		miner_id 	=> $info_ref->{miner_id},
	};
}

############################################################

=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub parse_plaintext {
	my($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
		$conditions_ref) = @_;
	$content_ref->{plaintext} = '';

	$self->errLog(getData('parse_plaintext_start', { url_id => $url_id }))
		if $self->{debug} > 1;

	my $changed = 0;
	my $timeout =	$conditions_ref->{timeout} ||
			$self->{ua}->timeout 	   ||
			20;

	if ($info_ref->{content_type} =~ /^text\/html\b/) {
		# first, trim body
		# just take first miner; in the future, perhaps try
		# to get first miner that has regexes
		my($miner_id) = $self->url_to_miner($url_id);
		my $regexps = $self->getMinerRegexps($miner_id);

		my $msg_body = $content_ref->{message_body};
		$self->trim_body(
			$miner_id,
			\$msg_body,
			$regexps->{pre_story_text},
			$regexps->{pre_story_regex},
			$regexps->{post_story_text},
			$regexps->{post_story_regex}
		);

		eval {
			# This die() is legal.
			local $SIG{ALRM} = sub { die "timeout" };
			alarm $timeout;

			# Uses our HTML Parser to strip out plaintext from the
			# HTML.
			#
			# This is a cute trick, see below.
			$#{$self->{hp_parsedtext}} = -1;
			$self->{hp}->parse($msg_body);
			$content_ref->{plaintext} = join('',
				map { join("", @$_) }
				@{$self->{hp_parsedtext}}
			);
			$changed = 1 if $content_ref->{plaintext};
			# By assigning a -1 to the index of class arrayref
			# 'hp_parsedtext', we effectively clear the array WITHOUT
			# reallocating it, which is important since our HTML Parser
			# class needs this.
			$#{$self->{hp_parsedtext}} = -1;

			alarm 0;
		};
		if ($@) {
			if ($@ =~ /timeout/) {
				my $outlen = length($content_ref->{plaintext});
				$self->errLog(
					getData('parse_plaintext_lynxlate', {
						url_id		=> $url_id,
						output_len	=> $outlen,
					})
				) if $self->{debug} > 0;
			} else {
				$self->errLog(
					getData('parse_plaintext_lynxerr', {
						error => $@,
					})
				) if $self->{debug} > -1;
			}
		}

	} elsif ($info_ref->{content_type} eq 'text/plain') {
		$content_ref->{plaintext} = $content_ref->{message_body};

		# trim body
		# just take first miner; in the future, perhaps try
		# to get first miner that has regexes
		my($miner_id) = $self->url_to_miner($url_id);
		my $regexps = $self->getMinerRegexps($miner_id);

		my $msg_body = $content_ref->{message_body};
		$self->trim_body(
			$miner_id,
			\$content_ref->{plaintext},
			$regexps->{pre_story_text},
			$regexps->{pre_story_regex},
			$regexps->{post_story_text},
			$regexps->{post_story_regex}
		);

		$changed = 1;
	}

	if ($changed) {
		$content_ref->{plaintext} =~ s/\s*\n\s*\n\s*/\n\n/g;
		$content_ref->{plaintext} =~ s/[ \t]*\n[ \t]*/\n/g;
		$content_ref->{plaintext} =~ s/[ \t]{2,}/  /g;

		$self->sqlUpdate('url_plaintext', {
			plaintext => $content_ref->{plaintext},
		}, "url_id=$url_id");
	}

	$self->errLog(getData('parse_plaintext_result', {
		url_id		=> $url_id,
		changed		=> $changed,
		timeout		=> $timeout,
		bodylen		=> length($content_ref->{message_body}),
		plainlen	=> length($content_ref->{plaintext}),
	})) if $self->{debug} > ($changed ? 0 : -1);

	return { is_success => 1 };
}

############################################################

=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub parse_nugget {
	my($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
		$conditions_ref) = @_;

	my $nugget = $self->nugget_url_to_info($url);
	my $nugget_url_id = $self->url_to_id($nugget->{url});
	my $response_timestamp =
		$other_ref->{response_timestamp} ||
		sql_to_unix_datetime($info_ref->{last_success}) ||
		time;

	$self->add_rel(
		$url_id,
		$nugget_url_id,
		'nugget',
		'nugget',
		$response_timestamp
	);

	$self->errLog(getData('parse_nugget', {
		url_id		=> $url_id,
		nugget_url	=> $nugget_url_id,
		timestamp	=> $response_timestamp,
	})) if $self->{debug} > 1;

	$self->sqlUpdate('url_info', {
		title => $nugget->{title}
	}, "url_id=$url_id");

	return { is_success => 1 };
}

############################################################

=head2 spider_by_name(name)

Executes the spider of a given name, if it exists.

=over 4

=item Parameters

=over 4

=item $name

String containing name of spider to execute.

=back

=item Return value

True if success, false if failure.

=item Side effects

All NewsVac tables will be modified by this routine assuming that this spider
exists. URL relationships will be recomputed and all stored content, reanalyzed.

=item Dependencies

None.

=back

None.

=cut

sub spider_by_name {
	my($self, $name) = @_;
	my $name_quoted = $self->sqlQuote($name);

	my $spider_ar = $self->sqlSelectAll(
		'conditions, group_0_selects, commands',
		'spider',
		"name = $name_quoted"
	);

	if (!$spider_ar || !$spider_ar->[0]) {
		$self->errLog(getData('spiderbyname_invalidname', {
			name		=> $name,
			name_quoted	=> $name_quoted,
		}, 'newsvac'));

		return;
	}
	my($conditions_text, $group_0_selects_text, $commands_text) =
		@{$spider_ar->[0]};

	# log errors?
	my $cpt = new Safe;
	$cpt->permit(qw(:base_core :base_mem :base_loop));
	my $conditions_ref	= $cpt->reval($conditions_text);
	my $group_0_selects_ref	= $cpt->reval($group_0_selects_text);
	my $commands_ref	= $cpt->reval($commands_text);

	$self->errLog(getData('spiderbyname_start', {
		name			=> $name,
		name_quoted		=> $name_quoted,
		group_0_selects_text	=> $group_0_selects_text,
		commands_text		=> $commands_text,
		conditions_ref		=> $conditions_ref,
		group_o_selects_ref	=> $group_0_selects_ref,
		commands_ref		=> $commands_ref,
	}, 'newsvac')) if $self->{debug} > 0;

	# Right now, $spider_result is useless, but we should use it
	# to trap error conditions that occur (so we can return undef 
	# on an error condition.
	#
	# Right now, with no error handling in spider(), we are left with 
	# just assuming all went well.
	my $spider_result = $self->spider(
		$conditions_ref, $group_0_selects_ref, @{$commands_ref}
	);

	if ($self->{debug} > -1) {
		$self->errLog(getData('spiderbyname_end', {
			name => $name,
		}));
	}

	return 1;
}

############################################################

=head2 spider($condition_ref, $group0_selects_ref, @spider_commants)

Executes a spider. Callers will most likely use spider_by_name() as an
entry point, as it does most everything for you. This routine depends
on the actual data associated with the spider.

Given a certain set of initial data, we start looking across a list of sites
(using miners) searching for nuggets of data that match keywords in NewsVac's
tables.

=over 4

=item Parameters

=over 4

=item $conditions_ref
	Ref to hash of conditions for this spider (timeout, max depth, etc.)

=item $group_0_selects_ref
	Ref to array of SQL SELECT statements to collect url_id's for group 0
	("SELECT url_id FROM " prefixed to all statements)

=item @spider_commands
	One or more spider_commands (see below for format)

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub spider {
	my($self, $conditions_ref, $group_0_selects_ref, @spider_commands) = @_;

	# request() won't request any pages timestamped as fresh at this time.
	# Passing in an older time value will allow it to use copies in the DB.
	# Defaults to the time that the spider was started.
	$conditions_ref->{use_current_time} ||= time;

	my %processed;
	my $dest_ids_ar = [];
	$self->spider_init($conditions_ref, $group_0_selects_ref);

	# Jamie, I think I know why you did this, but I think MySQL has changed
	# a lot since you wrote this code. Now, once ANY table is locked, you
	# lock everything except the "mask" specified in the LOCK TABLES
	# statement. Ergo: locking spider lock means that *ONLY WRITES TO
	# spiderlock* can occur until UNLOCK TABLES is called. This can't be
	# the intent of the following code, my guess is that you only wanted a
	# spider to execute if the lock could successfully be placed, which
	# would make sense.
	#
	# So after our talk, I'm going to remove this and just cross my
	# fingers.
	# - Cliff
	#my $sth = $self->sqlTransactionStart("LOCK TABLES spiderlock WRITE");

	# sc = "spider command" of course ...
	for my $sc (@spider_commands) {
		my($src_ar, $dest_ar, $where, $extra) = @{$sc};

		$self->errLog(getData('spider_command', {
			src_ar	=> $src_ar,
			dest_ar	=> $dest_ar,
			where	=> $where,
			extra	=> $extra,
		}, 'newsvac')) if $self->{debug} > 0;

		$extra = '' if !$extra;
		$src_ar  = [ $src_ar  ] if !ref $src_ar;
		$dest_ar = [ $dest_ar ] if !ref $dest_ar;

		for my $dest (@$dest_ar) {
			# src_ar is an array ref pointing to the group or
			# groups whose IDs to use as source
			my %src;

			for (@{$src_ar}) {
				$self->{sd}{$_} ||= [];
				map { $src{$_} = 1 } @{$self->{sd}{$_}};
			}
			$src_ar = [
				sort { $a <=> $b } grep !$processed{$_},
				keys %src
			];
			undef %src;

			# now src_ar is an array ref pointing to the IDs we
			# need to process. Process them.
			if (@{$src_ar}) {
				$self->errLog(getData('spider_processingitem', {
					ids	=> $src_ar,
				})) if $self->{debug} > 1;

				$self->process_url_ids(
					$conditions_ref, @$src_ar
				);

				for (@$src_ar) {
					$processed{$_} = 1;
				}
				my $select_text =
					'rel.to_url_id FROM rel, url_info
					 WHERE rel.from_url_id IN ' .
					'(' . join(', ', @{$src_ar}) . ') ' .
					'AND rel.to_url_id = url_info.url_id ' .
					"AND ( $where ) $extra";

				$self->errLog(getData('spider_selecttext', {
					select_text => $select_text,
				})) if $self->{debug} > 0;

				$dest_ids_ar = $self->sqlSelectColArrayref(
					'rel.to_url_id',
					'rel, url_info',
					'rel.from_url_id IN ' .
					'(' . join(', ', @{$src_ar}) . ') ' .
					'AND rel.to_url_id = url_info.url_id ' .
					"AND ( $where )",
					$extra
				);

				$dest_ids_ar = [] if !$dest_ids_ar;
				$self->errLog(getData('spider_destids', {
					dest_ids	=> $dest_ids_ar,
				})) if $self->{debug} > 0;
				$self->{sd}{$dest} = $dest_ids_ar;
			}
			$src_ar = [ $dest ];
		}
	}
	delete $self->{sd};
	#$sth = $self->sqlDo("UNLOCK TABLES");

	if (wantarray) {
		return($dest_ids_ar, [ keys %processed ]);
	} else {
		return $dest_ids_ar;
	}
}

############################################################

=head2 spider_init(conditions_ref, group_0_wheres_ref)

Initializes a spider before it is run.

=over 4

=item Parameters

=over 4

=item conditions_ref

=item group_0_wheres_ref

=back

=item Return value

None.

=item Side effects

Modifies the class variable 'sd', which I assume means "spider data".

=item Dependencies

None.

=back

=cut

sub spider_init {
	my($self, $conditions_ref, $group_0_wheres_ref) = @_;

	# sd = spider data
	$self->{sd} = {};
	$self->{sd}{$_} = $conditions_ref->{$_} for keys %{$conditions_ref};

	# Blown query.
	my $excluded_cond;
	my $none_miner_id = $self->sqlSelect(
		'miner_id', 'miner', 'name="none"'
	);
	$excluded_cond = "url_info.miner_id != $none_miner_id"
		if $none_miner_id;

	my %group_0_ids;
	for my $where_text (@$group_0_wheres_ref) {

		# The naked '20' here refers to the miner "none" and REALLY
		# shouldn't be here. This logic should be based on name since
		# that doesn't couple us to a specific ID which may or may
		# not exist across all systems.
		#
		#my $ar = $self->sqlSelectColArrayref(
		#	'url_info.url_id',
		#	'url_info, miner',
		#	"url_info.miner_id != 20 AND ($where_text)"
		#);

		my @where;
		push @where, $excluded_cond if $excluded_cond;
		push @where, "($where_text)";

		my $ar = $self->sqlSelectColArrayref(
			'url_info.url_id',

			'url_info, miner',

			join(' AND ', @where)
		);

		map { $group_0_ids{$_} = 1 } @{$ar} if $ar;
		$self->errLog(getData('spider_init_where', {
			where_text => $where_text,
		})) if $self->{debug} > 1;
	}
	$self->{sd}{0} = [ sort { $a<=>$b } keys %group_0_ids ];
	$self->errLog(getData('spider_init_ids', {
		ids => $self->{sd}{0},
	})) if $self->{debug} > 0;
}

############################################################

=head2 garbage_collect()

Removes stale data from the NewsVac data, based on time-based
criterion.

=over 4

=item Parameters

No parameters.

=item Return value

None.

=item Side effects

Deletes the first 10,000 rows from the following tables that are older than a
certain age or satisfy a condition:

	'rel' 		- older than 45 days.
	'url_info'	- not associated with any miner or relationship

	All tables 	- refers to a non-miner URL ID that is over a week old

=item Dependencies

None.

=back

=cut
sub garbage_collect {
	my($self) = @_;

	my($n_rels, $n_urls, $n_mbs) = (0, 0, 0);

	my $ary_ref = $self->sqlSelectColArrayref(
		'rel_id',
		'rel',
		'first_verified < DATE_SUB(NOW(), INTERVAL 45 DAY)',
		'ORDER BY rel_id LIMIT 10000'
	);

	$self->delete_rel_ids(@{$ary_ref});
	$n_rels = scalar(@{$ary_ref}) if $ary_ref;

	$ary_ref = $self->sqlSelectColArrayref(
		'url_id',

		'url_info LEFT JOIN rel ON
		 url_info.url_id=rel.to_url_id OR
		 url_info.url_id=rel.from_url_id',

		'url_info.miner_id=0 AND rel.rel_id IS NULL',

		'LIMIT 10000'
	);

	$self->delete_url_ids(@{$ary_ref}) if $ary_ref and $ary_ref->[0];
	$n_urls = scalar(@{$ary_ref}) if $ary_ref;

	$ary_ref = $self->sqlSelectColArrayref(
		'url_info.url_id',

		'url_info LEFT JOIN url_message_body ON
		 url_info.url_id=url_message_body.url_id AND
		 miner_id=0 AND
		 last_attempt < DATE_SUB(NOW(), INTERVAL 7 DAY) AND
		 message_body IS NOT NULL',

		'',

		'ORDER BY last_attempt,url_id LIMIT 10000'
	);

	$self->delete_url_ids(@{$ary_ref}) if $ary_ref and $ary_ref->[0];
	$n_mbs = scalar(@{$ary_ref}) if $ary_ref;

	if ($self->{debug} > -1) {
		$self->errLog(getData('garbage_collect', {
			num_rels	=> $n_rels,
			num_urls	=> $n_urls,
			num_bodies	=> $n_mbs,
		}));
	}
}

############################################################

=head2 robosubmit()

Scour the NewsVac database for worthy submissions based on the stored keywords.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value

Returns an array reference containing the following: 
	(# worthy submissions, # unworthy submissions)

=item Side effects

This routine will add rows to the 'submissions' table, along with the relative
weight of each.

=item Dependencies

=back

=cut

sub robosubmit {
	my($self) = @_;

	my($master_sql_regex, $master_sql_regex_encoded,
		%keywords, @keyword_keys);
	my $start_time = Time::HiRes::time();
	my $constants = getCurrentStatic();

	$self->load_keywords(
		\%keywords,
		\@keyword_keys,
		\$master_sql_regex,
		\$master_sql_regex_encoded
	);

	# These locks used to mean one thing, MySQL has made them into another
	# and they will just have to go, for now. Hopefully we won't have any
	# contention.
	#
	#my $sth = $self->sqlTransactionStart("robosubmitlock WRITE");

	$self->errLog(getData('robosubmit_regex', {
		regex => $master_sql_regex,
	})) if ($self->{debug} > 0);


	my $fields = <<EOT;
miner.name, ui2.url_id, ui2.url, ui3.url, ui3.title, ui3.last_success,
up3.plaintext,
	(CONCAT(ui2.title, '  ', up3.plaintext) REGEXP '$master_sql_regex'
	  OR
	 ui2.url REGEXP 'slug=[^=]*$master_sql_regex_encoded') AS matches
EOT

	my $tables = <<EOT;
url_info as ui1, url_info as ui2, url_info as ui3, url_plaintext as up3, rel as rel1, rel as rel2, miner
LEFT JOIN nugget_sub ON ui2.url_id = nugget_sub.url_id
EOT

	my $where = <<EOT;
 nugget_sub.submitworthy IS NULL
    AND ui1.url_id = rel1.from_url_id
    AND rel1.parse_code = 'miner'
    AND miner.miner_id = ui1.miner_id
    AND ui2.url_id = rel1.to_url_id
    AND rel1.to_url_id = rel2.from_url_id
    AND ui2.url_id = rel2.from_url_id
    AND rel2.parse_code = 'nugget'
    AND ui3.url_id = rel2.to_url_id
    AND rel2.to_url_id = up3.url_id
    AND ui3.url_id = up3.url_id
    AND ui1.is_success
    AND ui2.is_success
    AND ui3.is_success
EOT

	my $other = <<EOT;
GROUP BY rel2.from_url_id ORDER BY rel2.from_url_id LIMIT 2000
EOT

	my $sth = $self->sqlSelectMany($fields, $tables, $where, $other);

	my($i, %submitworthy, @sub) = (0);
	while (my($miner_name, $nugget_url_id, $nugget_url, $url, $title,
		$time, $plaintext, $matches) = $sth->fetchrow
	) {
		if (!$matches) {
			$submitworthy{$nugget_url_id} = 0 if $nugget_url_id;
			next;
		}

		my $nugget_info = $self->nugget_url_to_info($nugget_url);
		$plaintext =~ s{\s+}{ }g;
		$sub[$i]{subj}          = $nugget_info->{title} || $title;
		$sub[$i]{name}          = $nugget_info->{source} || '';
		$sub[$i]{miner}         = $miner_name || '';
		$sub[$i]{nugget_url_id} = $nugget_url_id;
		$sub[$i]{url_title}     = $nugget_info->{source} || '';
		$sub[$i]{url}           = $nugget_info->{url} || '';

		# Find what keywords match, and for each one that does, record
		# how many times it does (and some other nice info)
		my(%match, %weight);
		$sub[$i]{weight} = find_matches(
			\%match,
			\%weight,
			\%keywords,
			\@keyword_keys,
			$plaintext
		);

		$sub[$i]{weight} += 1.5 * find_matches(
			\%match,
			\%weight,
			\%keywords,
			\@keyword_keys,
			$nugget_info->{slug}
		) if $nugget_info->{slug};

		$sub[$i]{weight} += 2.0 * find_matches(
			\%match,
			\%weight,
			\%keywords,
			\@keyword_keys,
			$sub[$i]{subj}
		) if $sub[$i]{subj};

		my @match_keys = sort {
			($weight{$b} <=> $weight{$a})
			|| ($a cmp $b)
		} keys %weight;

		my %seen_keyword;
		$sub[$i]{keywords} = '';
		for my $keyword (
			map { $keywords{$_}[1] }
			sort {
				($weight{$b} <=> $weight{$a})
				|| ($a cmp $b)
			}
			grep { $weight{$_} >= 3 or $_ eq $match_keys[0] }
			@match_keys
		) {
			next if $seen_keyword{$keyword}++;
			$sub[$i]{keywords} .= " $keyword";
		}
		$sub[$i]{keywords} =~ s/^ //;

		# From here on out, we are building the excerpts and only care
		# about the first three (at most) match_keys
		$#match_keys = 2 if $#match_keys > 2;
		my %excerpts;
			# report the first 2 matches of the best keyword
		my %excerpt_keywords = ( $match_keys[0], 2 );
			# and the first 2 of the second-best
		$excerpt_keywords{$match_keys[1]} = 2 if $match_keys[1];
			# and one of the third-best if it seems important
		$excerpt_keywords{$match_keys[2]} = 1
			if $match_keys[2] and $weight{$match_keys[2]} > 5;
		for my $keynum (0..$#match_keys) {
			my $keyword = $match_keys[$keynum];
			my @location_keys = keys %{$match{$keyword}};
			$#location_keys = $excerpt_keywords{$keyword} - 1
				if $#location_keys >
				   $excerpt_keywords{$keyword} - 1;

			for my $location (@location_keys) {
				my @matches =
					sort
					keys %{$match{$keyword}{$location}};

				for (@matches) {
					my($before, $excerpt, $after) =
						split "\n";
					$before =~ s{^\S*\s+}{}
						if length($before) > 20;
					$after	=~ s{\s+\S*$}{}
						if length($after) > 20;
					$before	 = encode_entities($before);
					$excerpt = encode_entities($excerpt);
					$after	 = encode_entities($after);

					$excerpts{"$location$keynum"} =
						getData('excerptdata', {
							before	=> $before,
							excerpt => $excerpt,
							after	=> $after,
						})
				}
			}
		}
		my @excerpts =	map { $excerpts{$_} }
				sort { $a <=> $b }
				keys %excerpts;

		my $slug = '';
		$slug = "$nugget_info->{slug} " if $nugget_info->{slug};
		$sub[$i]{story} = getData('formatted_excerpt', {
			url	=> $url,
			slug	=> $slug,
			excerpts=> \@excerpts,
		});

		$self->errLog(getData('robosubmit_worth', {
			'index' => $i,
			miner	=> $sub[$i]{miner},
			weight	=> $sub[$i]{weight},
		})) if $self->{debug} > 2;

		++$i;
	}

	for (@sub) {
		if ($_->{weight} < ($constants->{newsvac_min_weight} || 10)) {
			$submitworthy{$_->{nugget_url_id}} = 0;
			next;
		}

		# Create submission.
		my $subid = $self->createSubmission({
			email		=> $_->{miner},
			uid		=> $constants->{anonymous_coward_uid},
			name		=> $_->{name},
			story		=> $_->{story},
			subj		=> $_->{subj},
			tid		=> $constants->{newsvac_topic},
			section		=> $constants->{newsvac_section},
			weight		=> $_->{weight},
		});
		$self->setSubmission($subid, {
			separate	=> 1,
			storyonly	=> 1,
			keywords	=> $_->{keywords},
			url		=> $_->{url},
			url_title	=> $_->{url_title},
		});

		$submitworthy{$_->{nugget_url_id}} = 1;
	}

	my($worthy, $unworthy) = (0, 0);

	for (sort { $a <=> $b } keys %submitworthy) {
		$self->sqlInsert('nugget_sub', {
			url_id		=> $_,
			submitworthy	=> $submitworthy{$_}
		}, { ignore => 1 });
		$submitworthy{$_} ? ++$worthy : ++$unworthy;
	}
	$sth->finish; # not really necessary

	# Not table locking anymore. See above.
	#$sth = $self->sqlDo("UNLOCK TABLES");

	my $elapsed_time = Time::HiRes::time() - $start_time;
	$self->errLog(getData('robosubmit_result', {
		total	=> scalar keys %submitworthy,
		worthy	=> $worthy,
		unworthy=> $unworthy,
		duration=> round($elapsed_time),
			#int($elapsed_time * 1000 + 0.5) / 1000
	})) if $self->{debug} > 1;

	return [$worthy, $unworthy];
}

############################################################
=head2 load_keywords(kw_ref, keys_ref, m_regex_ref, m_regex_enc_ref)

Loads keywords from the NewsVac database into various data structures.

=over 4

=item Parameters

=over 4

=item $kw_ref

Hash reference containing keyword representation. Data is organized in the hash
as follows:

	regex => [ weight, tag, id ]

=item $keys_ref

List of keys from $kw_ref in a special sort order: numerically by weight, then by
length of key, then by string sort of key.

=item $m_regex_ref

Scalar which, upon return, will contain a reference to a string containing the
master regular expression formed from the keywords table.

=item $m_regex_enc_ref

The value of $m_regex_ref with all spaces encoded to '%20'

=back

=item Return value

Nothing useful. Returned is the result of the last regular expression of this
routine.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub load_keywords {
	my($self, $kw_ref, $keys_ref, $m_regex_ref, $m_regex_enc_ref) = @_;

	my $cursor = $self->sqlSelectMany(
		'id,regex,weight,tag', 'newsvac_keywords'
	);

	while (my($id, $regex, $weight, $tag) = $cursor->fetchrow) {
		$kw_ref->{$regex} = [$weight, $tag, $id];
	}

	@{$keys_ref} = sort {
		($kw_ref->{$b}[0] <=> $kw_ref->{$a}[0]) ||
		(length($b) <=> length($a)) ||
		($a cmp $b)
	} keys %{$kw_ref};

	${$m_regex_ref} = '(' . (join ')|(', @{$keys_ref}) . ')';
	(${$m_regex_enc_ref} = ${$m_regex_ref}) =~ s/ /\%20/g;
}

############################################################

=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

# Unused routine. Possibly deprecated.
sub source_name {
	my($self, $long_form) = @_;

	my $source_name = 'DBI:mysql:' . $self->{dbname};
	$source_name .= ';host=' . $self->{dbhost} if $long_form;

	return $source_name;
}

############################################################

=head2 check_regex(regex [, flags])

Checks a given regex for errors.

=over 4

=item Parameters

=over 4

=item $regex

String containing a regular expression.

=item $flags

String containing flag modifiers for the given regular expression.

=back

=item Return value

If no errors on regular expression, no value is returned. If there is an error,
then the return value contains the error message obtained when the regular expression
was checked.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub check_regex {
	my($self, $regex, $flags) = @_;

	$flags = '' if !$flags;
	my $err = '';
	$flags =~ tr{gimosk}{}cd;
	$regex =~ s{/}{\\/}g;

	my $cpt = new Safe;
	$cpt->permit(qw(:base_core :base_mem :base_loop));

	# catch compile-time errors; don't actually execute regex
	$cpt->reval("sub { 'foo' =~ /$regex/$flags; }");
	if ($@) {
		$err = $@;
		$err =~ s{.*/: (.+) in regexp at.*}{$1};
		$err =~ s{.*/: (Sequence .*)}{$1};
	}

	return $err;
}

############################################################

=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub getWeekCounts {
	my($self) = @_;
	my($results, $returnable);

	$results = $self->sqlSelectAll(
		"miner.miner_id, count(rel.rel_id)",
		"miner, rel",
		"rel.type = miner.name
		 AND rel.parse_code = 'miner'
		 AND rel.first_verified > DATE_SUB(NOW(), INTERVAL 7 DAY)",
		"GROUP BY miner.miner_id
		 ORDER BY name"
	);

	$returnable->{$_->[0]} = $_->[1] for @{$results};

	return $returnable;
}

############################################################

=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub getDayCounts {
	my($self) = @_;
	my(@days) = (1, 3, 7);
	my($results, $returnable);

	for my $day (@days) {
		$results = $self->sqlSelectAll(
			'miner.miner_id, AVG(url_analysis.nuggets)',

			'miner, url_info, url_analysis',

			"url_info.miner_id = miner.miner_id AND
			 url_info.url_id = url_analysis.url_id AND
			 url_analysis.ts > DATE_SUB(NOW(), INTERVAL $day DAY)",

			'GROUP BY miner.miner_id ORDER BY miner.name'
		);

		$returnable->{$_->[0]}{$day} =
			int($_->[1] + 0.5) for @{$results};
	}

	return $returnable;
}

############################################################

=head2 getMinerList()

Returns the lists of defined miners. Two lists are returned
becuase we need to separate miners that are using any
of the defined URLs from new or unused miners that may not
have any assigned.

=over 4

=item Parameters

None.

=item Return value

A list containing 2 array references, they are respectively:
	List of miners with referneced URLs
	List of miners with NO refernenced URLs

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getMinerList {
	my($self) = @_;

	my $columns = <<EOT;
miner.miner_id, name, last_edit, last_edit_aid, owner_aid,
progress, comment, count(url_info.url_id) as url_count
EOT

	my $returnable1 = $self->sqlSelectAllHashrefArray(
		$columns,

		'miner, url_info',

		'url_info.miner_id = miner.miner_id',

		'GROUP BY miner.miner_id ORDER BY name'
	);

	my $returnable2 = $self->sqlSelectAllHashrefArray(
		$columns,

		'miner LEFT JOIN url_info ON
		 miner.miner_id=url_info.miner_id',

		 'url_info.miner_id IS NULL',

		 'GROUP BY miner.miner_id ORDER BY name'
	);

	return ($returnable1, $returnable2);
}

############################################################

=head2 getMiner(miner_id)

Gets all data associated with a NewsVac miner.

=over 4

=item Parameters

=over 4

=item $miner_id

Numeric ID for the miner in question.

=back

=item Return value

Hash ref containing data from the 'miner' table if the associated ID exists.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getMiner {
	my($self, $miner_id) = @_;

	my $returnable = $self->sqlSelectHashref(
		'*', 'miner', 'miner_id=' . $self->sqlQuote($miner_id)
	);

	return $returnable;
}

############################################################

=head2 getMinerURLs(miner_id)

Gets all URLs associated with a given NewsVac miner.

=over 4

=item Parameters

=over 4

=item $miner_id

Numeric ID of the miner in question.

=back

=item Return value

List of array references, each array reference containing:

	[ url_id, url ]

Where $url_id is the ID of a given URL
	and
$url is the string containing the complete URL.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getMinerURLs {
	my($self, $miner_id) = @_;

	my $returnable = $self->sqlSelectAll(
		'url_id, url',
		'url_info',
		'miner_id=' . $self->sqlQuote($miner_id),
		'ORDER BY url'
	);

	return $returnable;
}

############################################################

=head2 setMiner(miner_id, data)

Sets the data for a given miner.

=over 4

=item Parameters

=over 4

=item $miner_id

Numeric ID associated with the miner to update.

=item $data

Hash reference containing the update data.

=back

=item Return value

Result of Slash::DB::sqlUpdate() command.

=item Side effects

Modifies the 'miner' table.

=item Dependencies

None.

=back

=cut

sub setMiner {
	my($self, $miner_id, $data) = @_;

	$self->sqlUpdate(
		'miner', $data, 'miner_id=' . $self->sqlQuote($miner_id)
	);
}

############################################################

=head2 deleteMiner(miner_id)

Removes the given miner from the NewsVac database.

=over 4

=item Parameters

=over 4

=item $miner_id - Numeric ID associated with the miner to be removed.

=back

=item Return value

Result of Slash::DB::sqlDelete() call.

=item Side effects

If successful, removes a row from the 'miner' table.

=item Dependencies

None.

=back

=cut

sub deleteMiner {
	my($self, $miner_id) = @_;

	$self->sqlDelete('miner', 'miner_id=' . $self->sqlQuote($miner_id));
}

############################################################

=head2 deleteSpider(spider_id)

Removes the given spider from the NewsVac

=over 4

=item Parameters

=over 4

item $spider_id - Numeric ID associated with the spider to be removed.

=back

=item Return value

Result of Slash::DB::sqlDelete() call.

=item Side effects

If successful, removes a row from the 'spider' table.

=item Dependencies

None.

=back

=cut

sub deleteSpider {
	my($self, $spider_id) = @_;

	$self->sqlDelete('spider', 'spider_id=' . $self->sqlQuote($spider_id));
}

############################################################

=head2 deleteURL(miner_id)

Removes the given URL from the NewsVac database. Unlike delete_url_ids(), no
checks are performed on the URL to be deleted and only one URL is deleted at
a time.

=over 4

=item Parameters

=over 4

=item $url_id - Numeric ID associated with the URL to be removed.

=back

=item Return value

Result of the FINAL Slash::DB::sqlDelete() call, which is to the 'url_info'
table. Better error checking here would be a good thing, however, what would
be the best way to handle them?

=item Side effects

If successful, removes all rows from the following table that reference the
given URL ID:
	url_analysis
	url_content
	url_info
	url_message_body
	url_plaintext
	rel
	nugget_sub

=item Dependencies

None.

=back

=cut

sub deleteURL {
	my($self, $url_id) = @_;

	my $q_id = $self->sqlQuote($url_id);
	my $where = "url_id=$q_id";
	my $where2 = "from_url_id=$q_id or to_url_id=$q_id";

	$self->sqlDelete('url_analysis', $where);
	$self->sqlDelete('url_content', $where);
	$self->sqlDelete('url_message_body', $where);
	$self->sqlDelete('url_plaintext', $where);
	$self->sqlDelete('nugget_sub', $where);

	$self->sqlDelete('rel', $where2);

	$self->sqlDelete('url_info', $where);
}

############################################################

=head2 getUrlList([match, owner, start, limit])

Gets the list of URLs associated with any defined miner over the entire NewsVac database.

=over 4

=item Parameters

=over 4

=item $match

Optional. Substring to match against in URLs.

=item $owner

Optional. Limit returned values to URLs associated with miners owned by a given
NewsVac admin. Note that this uses the author NAME, not the Author ID. This may
be changed at a later date.

=item $start

Optional. Number of records to offset before start of result set. Default is 0.

=item $limit

Optional. Limits the number of results returned. Default is 500. Maximum allowed value
is 9,999.

=back

=item Return value

Returns a list of hash references representing URL data associated with a miner.
Data returned for each array element is as follows:

=over 4

=item url_id

ID of URL

=item url

String containing complete URL

=item is_success

Was the last request made to this URL successful?

=item last_success

Date of last successful connection to this URL.

=item last_success_formatted

Formatted value of above date according to current user preferences.

=item miner_id

Miner associated with this URL.

=item name

Name of miner associated with this URL.

=item message_body_length

Length of the content data available at this URL upon last successful connection.

=item referencing

Number of relationships associated with this URL.

=back

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getUrlList {
	my($self, $match, $owner, $start, $limit) = @_;

	my @where = ('miner.miner_id = url_info.miner_id');
	push @where, 'url_info.url LIKE ' .  $self->sqlQuote("%$match%")
		if $match;
	push @where, "miner.owner_aid = '$1'"
		if $owner and $owner =~ /(\w{1,20})/;
	my $qwhere = join ' AND ', @where;

	my($qstart, $qlimit) = (0, 500);
	$qlimit = $1   if $limit and $limit =~ /(\d+)/;
	$qlimit = 1    if $qlimit < 1;
	$qlimit = 9999 if $qlimit > 9999;
	$qstart = $1   if $start and $start =~ /^(\d+)$/;

	$qlimit = "$qstart,$qlimit" if $qstart;
	my $returnable = $self->sqlSelectAllHashrefArray(
		'url_info.url_id, url_info.url, url_info.is_success,
		 url_info.last_success, miner.miner_id, miner.name,
		 length(url_message_body.message_body) as message_body_length',

		'url_info, miner LEFT JOIN url_message_body
		 ON url_info.url_id = url_message_body.url_id',

		$qwhere,

		"ORDER BY url_info.url LIMIT $qlimit"
	);

	for (@{$returnable}) {
		$_->{is_success} = $_->{is_success} == 0;
		$_->{last_success_formatted} = timeCalc($_->{last_success})
			if $_->{last_success};

		$_->{referencing} = $self->sqlCount(
			'rel',
			"from_url_id=$_->{url_id} AND
			 parse_code='miner'",
			'GROUP BY to_url_id'
		);
	}


	return $returnable;
}

############################################################

=head2 getMinerURLIds(miner_id)

Obtains the list of URL IDs associated with a given miner.

=over 4

=item Parameters

=over 4

=item $miner_id

Numeric value containing the ID of the miner in question.

=back

=item Return value

Array containing the list of URL IDs associated with the given miner.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getMinerURLIds {
	my($self, $miner_id) = @_;

	my $returnable = $self->sqlSelectColArrayref(
		'url_id',
		'url_info',
		'miner_id=' . $self->sqlQuote($miner_id)
	);

	return $returnable;
}

############################################################

=head2 getMinerRegexps(miner_id)

Obtains the regular expressions associated with a given NewsVac Miner.

=over 4

=item Parameters

=over 4

=item $miner_id

Numeric value containing the ID of the miner in question.

=back

=item Return value

Hash reference containing the following keys:

	pre_stories_text
	pre_stories_regex
	post_stories_text
	post_stories_regex
	pre_story_text
	pre_story_regex
	post_story_text
	post_story_regex

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getMinerRegexps {
	my($self, $miner_id) = @_;

	my $returnable = $self->sqlSelectHashref(
		'pre_stories_text, pre_stories_regex,
		 post_stories_text, post_stories_regex,
		 pre_story_text, pre_story_regex,
		 post_story_text, post_story_regex',
		'miner', 'miner_id=' . $self->sqlQuote($miner_id)
	);

	return $returnable;
}

############################################################

=head2 getURLRelationships(url_id[, max_results])

Obtains URL relationship data associated with a given NewsVac URL ID.

=over 4

=item Parameters

=over 4

=item $url_id

Numeric ID associated with the URL in question.

=item $max_results

Number limiting the size of the result set.

=back

=item Return value

An array of hash references representing relationship data. Each element of the
array being one relationship. The following keys should be defined in each
array element:

	url_id
	url
	title
	last_attempt
	last_success

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getURLRelationships {
	my($self, $url_ids, $max_results) = @_;
	@{$url_ids} = grep { /^\d+$/ } @{$url_ids};
	return 0 if !scalar @{$url_ids};

	my $where_clause = sprintf "(%s) AND
		rel.to_url_id = url_info.url_id AND
		parse_code = 'miner'",
		join ' OR ', map { "rel.from_url_id=$_" } @{$url_ids};

	my $limit = (defined $max_results) ?  "LIMIT $max_results" : '';
	my $returnable = $self->sqlSelectAllHashrefArray(
		"url_info.url_id, url_info.url, url_info.title,
		 url_info.last_attempt, url_info.last_success",
		 
		'url_info, rel',

		$where_clause,

		"ORDER BY rel.from_url_id, url_info.url_id $limit"
	);

	return $returnable;
}

############################################################

=head2 getURLData(url_id)

Obtains all relevant data associated with a given URL ID.

=over 4

=item Parameters

=over 4

=item $url_id

Numeric value representing the ID of the URL in question.

=back

=item Return value

Depending on context, either an array containing the URL data or a Hash reference.
If this routine is called in list context the return value will be of the following form:

	(url_id, url, title, miner_id, last_attempt, last_success, status_code,
	reason_phrase, size of URL content [message body size])

If called in a scalar contect, the return value is a hashref which uses the above
names as keys for the specific fields, be aware that the key name for the last value
above is "message_body".

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getURLData {
	my($self, $url_id) = @_;
	my $returnable;

	my $columns = <<EOT;
url_info.url_id, url_info.url, url_info.title,
url_info.miner_id, url_info.last_attempt,
url_info.last_success, url_info.status_code,
url_info.reason_phrase, length(url_message_body.message_body) as message_body
EOT

	my $tables = <<EOT;
url_info LEFT JOIN url_message_body ON
url_info.url_id = url_message_body.url_id
EOT

	my $where = 'url_info.url_id = ' . $self->sqlQuote($url_id);

	return wantarray ?
		$self->sqlSelect($columns, $tables, $where) :
		$self->sqlSelectHashref($columns, $tables, $where);
}

############################################################
=head2 getURLRelationCount(url_id)

Obtain the number of relationships in the NewsVac URL Database associated with a
given URL ID.

=over 4

=item Parameters

=over 4

=item $url_id

ID associated with the URL whose relationship count we wish to determine.

=back

=item Return value

Number representing the number of relationships for the given URL ID.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getURLRelationCount {
	my($self, $url_id) = @_;

	my $returnable = $self->sqlSelectColArrayref(
		'count(*)', 'rel',

		'from_url_id=' . $self->sqlQuote($url_id) .
		" AND parse_code='miner'",

		'GROUP BY to_url_id'
	);

	return $returnable;
}

############################################################

=head2 getURLCounts()

Obtain the following information from the NewsVac URL database: the number of total
URLs, and the number of URLs that ARE NOT associated with any miner.

=over 4

=item Parameters

None.

=item Return value

List containing the requested values:

	(number of URLs, number of URLs with no miner)

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getURLCounts {
	my($self) = @_;

	my @returnable = (
		$self->sqlCount('url_info'),
		$self->sqlCount('url_info', 'miner_id=0')
	);

	return @returnable;
}

############################################################

=head2 getURLBody(url_id)

Retrieves the content associated with a given NewsVac URL ID.

=over 4

=item Parameters

=over 4

=item $url_body

Numeric ID of the URL one wishes to retrieve a body for.

=back

=item Return value

The message body associated with the given URL ID. Be careful, sometimes this value
can be very large as the entire content of the webpage will be returned in this scalar!

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getURLBody {
	my($self, $url_id) = @_;

	# Previously this was a sqlSelectAll(). We only use one record
	# anyways, so why not give the dB a break.
	my $returnable = $self->sqlSelectArrayRef(
		'url, message_body',
		'url_info, url_message_body',
		"url_info.url_id=$url_id and url_message_body.url_id=$url_id"
	);

	return $returnable;
}


############################################################

=head2 getSpiderList([match])

Obtains the list of spiders currently defined in the NewsVac database.

=over 4

=item Parameters

=over 4

=item $match

If present, forces the returned list to only return spiders matching the substring
given in this variable.

=back

=item Return value

An array of has references, each hash representing spider data.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getSpiderList {
	my($self, $match) = @_;

	my $where;
	$where = "name LIKE " . $self->sqlQuote("%$match%")
		if $match;

	my $returnable = $self->sqlSelectAllHashrefArray(
		'spider_id, name, last_edit, last_edit_aid, conditions,
		 group_0_selects, commands',
		'spider',
		$where,
		'LIMIT 50'
	);

	for (@{$returnable}) {
		$_->{last_edit_formatted} = timeCalc($_->{last_edit});
	}

	return $returnable;
}

############################################################

=head2 getSpider(spider_id)

Obtains the data for a NewsVac spider given its ID.

=over 4

=item Parameters

=over 4

=item $spider_id

Numeric value containing ID of spider in question.

=back

=item Return value

Depending on context, will return either an array or a hash reference.

For the array context, the following is returned:

	(name, last_edit, last_edit_aid, conditions, group_0_selects, commands)

For the scalar context, a hash reference is returned with key value pairs corresponding
to the list above.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getSpider {
	my($self, $spider_id) = @_;
	my $returnable;

	my $table = 'spider';
	my $where = 'spider_id=' . $self->sqlQuote($spider_id);
	my $columns = <<EOT;
name, last_edit, last_edit_aid, conditions, group_0_selects, commands
EOT

	return wantarray ?
		$self->sqlSelect($columns, $table, $where) :
		$self->sqlSelectHashref($columns, $table, $where);
}

############################################################

=head2 setSpider(spider_id, data)

Update's the data for a given spider in the NewsVac database.

=over 4

=item Parameters

=over 4

=item $spider_id - ID associated with the spider to update.

=item $data - Hashref containing spider data.

=back

=item Return value

Result of Slash::DB::sqlUpdate() call that sets the spider data.

=item Side effects

Updates the 'spider' table with new information.

=item Dependencies

None.

=back

=cut

sub setSpider {
	my($self, $spider_id, $data) = @_;

	my $clean_data;
	$clean_data->{$_} = $data->{$_} for qw(
		name
		last_edit
		last_edit_aid
		conditions
		group_0_selects
		commands
	);

	$self->sqlUpdate(
		'spider', $clean_data, 'spider_id=' . $self->sqlQuote($spider_id)
	);
}

############################################################

=head2 markTimespecAsRun(timespec_id, duration [, results ])

Marks a given timespec in the 'spider_timespec' table with
the current timestamp indicating that its run has been
successful at this time.

=over 4

=item Parameters

=over 4

=item timespec_id

Numeric value containing ID of timespec that was used in spider run.

=item duration

Time taken for this spidering run.

=item results

Scalar containing string message noting the number of worthy and unworthy
submissions generated by the spider associated with the given timespec_id.

=back

=item Return value

Result of Slash::DB::sqlUpdate() call that sets the spider data.

=item Side effects

Updates the 'last_run' field and (if given) the 'results' field of the 
corresponding row in the 'spider_timespec' table.

=item Dependencies

None.

=back

=cut

sub markTimespecAsRun {
	my($self, $timespec_id, $duration, $results) = @_;

	my $update = {
		-last_run	=> 'UNIX_TIMESTAMP()',
		-duration	=> $duration,
	};
	$update->{'results'} = $results if $results;

	my $where = 'timespec_id=' . $self->sqlQuote($timespec_id);

	$self->sqlUpdate('spider_timespec', $update, $where);
}

############################################################

=head2 setSpiderTimespecs(spider_id, timespecs)

Update's the data for a given spider in the NewsVac database.

=over 4

=item Parameters

=over 4

=item spider_id

ID associated with the spider to update.

=item data

Hashref of hasrefs containing the timespec data. Each element of the hashref
is arranged as follows:

	timespec_id =>	{
		timespec	=> string containing time specification
		spider name	=> name of spider associated with this spec
		del 		=> Logical true if this timespec is to be
				   removed.
	}

If a timespec_id of 0 is given, then the data for that key is inserted into
the 'spider_timespec' table. Only one insert per call to this method is
performed.

=back

=item Return value

None.

=item Side effects

Updates the 'spider_timespec' table with new information.

=item Dependencies

None.

=back

=cut

sub setSpiderTimespecs {
	my($self, $spider_id, $timespecs) = @_;
	return if !$timespecs || !%{$timespecs};

	for (keys %{$timespecs}) {
		if ($timespecs->{$_}{del}) {
			$self->sqlDelete(
				'spider_timespec',
				'timespec_id=' . $self->sqlQuote($_)
			);
		} elsif (!$_) {
			# If the timespec_id is 0, this is a new record to be
			# inserted. There can only be one insert per call
			# to this routine.
			$self->sqlInsert('spider_timespec', {
				name 		=> $timespecs->{$_}{name},
				timespec	=> $timespecs->{$_}{timespec},
				-last_run	=> 'unix_timestamp()',
			});
		} else {
			$self->sqlReplace('spider_timespec', {
				timespec_id	=> $_,
				name		=> $timespecs->{$_}{name},
				timespec	=> $timespecs->{$_}{timespec},
			});
		}
	}
}

############################################################

=head2 getSpiderTimespecs(spider_id)

Retrieves time specifications associated with a given spider ID.

=over 4

=item Parameters

=over 4

=item $spider_id - ID associated with the spider of inquiry.

=back

=item Return value

Returns an array of hashrefs containing timespec information.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getSpiderTimespecs {
	my($self, $spider_id) = @_;

	my $spider_name = $self->getSpiderName($spider_id);
	my $returnable = $self->sqlSelectAllHashrefArray(
		'*',
		'spider_timespec',
		'name=' . $self->sqlQuote($spider_name),
		'order by timespec_id'
	);

	return $returnable;
}

############################################################

=head2 getAllSpiderTimespecs()

Retrieves all time specifications and stores the data into a hash reference using
the spider names as keys.

=over 4

=item Parameters

None.

=item Return value

Returns a hashref with spider names as keys and an array reference of timespec
data as the associated value. Each element in the array ref represents a distinct time
specification for that spider.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getAllSpiderTimespecs {
	my($self) = @_;

	# Grab spider timespecs list from database.
	my $returnable;
	my $st_list = $self->sqlSelectAllHashrefArray(
		'*', 'spider_timespec'
	);

	# And because there may be more than one timespec per miner, we
	# arrange it all by hash of array-refs.
	push @{$returnable->{$_->{name}}}, $_ for @{$st_list};

	return $returnable;
}

############################################################

=head2 getSpiderName(spider_id)

Get's the name associated with a given NewsVac Spider ID.

=over 4

=item Parameters

=over 4

=item $spider_id - ID associated with the spider of inquiry.

=back

=item Return value

String containing the name of the spider. The return value is undefined if
no spider is associated with the given ID.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getSpiderName {
	my($self, $spider_id) = @_;

	my $returnable = $self->sqlSelect(
		'name', 'spider', 'spider_id=' . $self->sqlQuote($spider_id)
	);

	return $returnable;
}

############################################################

=head2 getKeywordTags()

Obtain a list of distinct tags used in NewsVac keywords.

=over 4

=item Parameters

None.

=item Return value

Array containing the list of tags.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getKeywordTags {
	my($self) = @_;

	my $returnable = $self->sqlSelectColArrayref(
		'distinct tag',
		'newsvac_keywords'
	);

	return $returnable;
}

############################################################

=head2 getTagKeywords(tag)

Obtain the list of keyword data associated with a given arbitrary tag.

=over 4

=item Parameters

=over 4

=item $tag

String containing the tag we wish to match with keyword data.

=back

=item Return value

List of hashrefs containing keyword data matching the given tag. Each hash reference
contains the fields of the 'newsvac_keywords' table as keys:

	id
	regex
	weight
	tag

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getTagKeywords {
	my($self, $tag) = @_;

	my $returnable = $self->sqlSelectAllHashrefArray(
		'*',

		'newsvac_keywords',

		'tag=' . $self->sqlQuote($tag),

		'order by weight desc'
	);

	return $returnable;
}

############################################################

=head2 getKeyword(keyword_id)

Obtain the keyword data associated with a given NewsVac keyword ID.

=over 4

=item Parameters

=over 4

=item $keyword_id

Numeric value representing the ID of the keyword.

=item Return value

Hashref containing the keyword data. The keys are the fields of the 'newsvac_keywords'
table.

=item Side effects

None.

=item Dependencies

None.

=back

=cut

sub getKeyword {
	my($self, $keyword_id) = @_;

	my $returnable = $self->sqlSelectHashref(
		'*',

		'newsvac_keywords',

		'id=' . $self->sqlQuote($keyword_id)
	);

	return $returnable;
}

############################################################

=head2 setKeyword(keyword_id, data)

Sets keyword data. If keyword_id is non-zero, an update operation is implied, if the
keyword is zero, then an insert operation is performed instead and the new
ID is returned to the caller.

=over 4

=item Parameters

=over 4

=item $keyword_id

Numeric value representing the ID of the keyword to update.

=item $data

Hash reference containing update data for the keyword. Expected keys are:
	regex
	tag
	weight

=item Return value

If the given $keyword_id is zero, then the returned value is the ID of the inserted row.
If $keyword_id is non-zero, then the returned value is the result of the update
operation.

=item Side effects

Updates the corresponding row (if any) of the 'newsvac_keywords' table.

=item Dependencies

None.

=back

=cut

sub setKeyword {
	my($self, $keyword_id, $data) = @_;

	# Insure we pass only the right data to sqlUpdate().
	my $clean_data;
	$clean_data->{$_} = $data->{$_} for qw(
		regex
		tag
		weight
	);

	if (!$keyword_id) {
		$self->sqlInsert(
			'newsvac_keywords',
			$clean_data
		);

		return $self->getLastInsertId;
	} else {
		$self->sqlUpdate(
			'newsvac_keywords',
			$clean_data,
			'id=' . $self->sqlQuote($keyword_id)
		);

		return;
	}
}

############################################################

=head2 deleteKeyword(keyword_id)

Deletes the keyword of the given ID from the NewsVac database.

=over 4

=item Parameters

=over 4

=item $keyword_id

Numeric value containing the ID of the keyword to be deleted.

=back

=item Return value

Result of the call to C<Slash::DB::sqlDelete()>.

=item Side effects

If the given ID exists, the corresponding row is deleted from the 'newsvac_keywords'
table.

=item Dependencies

None.

=back

=cut

sub deleteKeyword {
	my($self, $keyword_id) = @_;

	$self->sqlDelete('newsvac_keywords', 'id=' . $self->sqlQuote($keyword_id));
}

############################################################

=head2 sqlInsert($table, $data, [, $extra])

DEPRECATED! TO BE REMOVED IN NEXT COMMIT ASSUMING ALL STILL WORKS!

Overrides Slash::DB::Utility::sqlInsert() to allow for the
	INSERT INTO x IGNORE ...
Format, specific to MySQL. This should be back-ported to
Slash::DB::MySQL if it hasn't been, already.

=over 4

=item Parameters

=over 4

=item $table

Name of table to insert into.

=item $data

Hashref of insert data where the keys are the fieldnames.

=item $extra

Comma separated list of any from set of ('IGNORE', 'DELAYED').

	IGNORE  - Any SQL errors are ignored
	DELAYED - INSERT is delayed until a suitably idle time.

=back

=item Return value

None.

=item Side effects

Inserts rows into the table specified.

=item Dependencies

=back

=cut

#sub sqlInsert {
#	my($self, $table, $data, $extra) = @_;
#	my($names, $values);
#
#	my %extra;
#	$extra{lc $_} = 1 for split /,\s*/, $extra;
	# We can now reuse $extra.
#	$extra = '';
#	$extra .= ' /*! DELAYED */' if $extra{delayed};
#	$extra .= ' IGNORE' if $extra{ignore};
#
#	for (keys %$data) {
#		if (/^-/) {
#			$values .= "\n  $data->{$_},";
#			s/^-//;
#		} else {
#			$values .= "\n  " . $self->sqlQuote($data->{$_}) . ',';
#		}
#		$names .= "$_,";
#	}
#
#	chop($names);
#	chop($values);
#
#	my $sql = "INSERT$extra INTO $table ($names) VALUES($values)\n";
#	$self->sqlConnect;
#	return $self->sqlDo($sql);
#}

##############################################################

=head2 errLog(message_list)

Writes an error message to the proper log file. If this module
has been locked, the messages will go to a private NewsVac
log, if unlocked, these messages will go to STDERR.

=over 4

=item Parameters

=over 4

=item message_list

Either a list (which will be joined) or a scalar containing the message to
output.

=back

=item Return value

None

=item Side effects

None.

=item Dependencies

=back

=cut

sub errLog {
	my($self) = shift;

	if ($self->{use_locking}) {
		_doLog([@_]);
		return;
	}

	chomp(@_);
	printf STDERR "%s\n", join "\n", @_;
}


=head1 UTILITY FUNCTIONS

These functions are part of NewsVac, but are not exported and are considered
private.

=cut

############################################################
# These are not methods, but utility functions.  Don't pass them $self!
# These should probably be private.
############################################################

=head2 _doLogInit()

Creates a NewsVac log file (newsvac.log) in the Slash data directory for
the running site.

=over 4

=item Parameters

None.

=item Return value

None

=item Side effects

Creates $DATADIR/newsvac.log on the local filesystem.

=item Dependencies

None.

=back

=cut

sub _doLogInit {
	my($fname) = 'newsvac';

	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.log");

	# This die is also acceptable because _doLogInit() is called BEFORE
	# any lock file is written to disk.
	mkpath $dir, 0, 0775;
	open(STDERR, ">> $file\0") or die "Can't append STDERR to $file: $!";
	_doLog(["Placing lock $fname"]);
}

=head2 _doLock()

Creates a NewsVac LOCK file in the Slash data directory for the running site.
If another lock file is present, then it is expected that another process
is running this same code. This represents a fatal error and this code
will terminate in favor of the other one. In the case that this code
failed to clean up after itself and there is no other process running, you
should be safe to delete the lock file and then restart a new instance.

=over 4

=item Parameters

None.

=item Return value

None

=item Side effects

Creates $DATADIR/newsvac.lock on the local filesystem. Creates SIGINT and
SIGTERM handlers which will delete the lock file if situations allow such
signals to be caught.

=item Dependencies

None.

=back

=cut

sub _doLock {
	my($fname) = 'newsvac';

	my $fh      = gensym();
	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.lock");

	# By the end of this routine, the lock file has been created and
	# no further die()s can be called within the call flow of this
	# object. Please use _Die() instead, as that properly removes the
	# lock file.

	# Test for lock file existence. If it does, die(), but the caller
	# should be trapping this.
	if (-r $file) {
		my $lockfh = gensym();
		open($lockfh, $file) or
			die "Cannot read lock file $file: $!";
		chomp(my $lock = <$lockfh>);
		close $lockfh;
		# This isn't 100% but WILL prevent us from restarting
		# a daemon over an existing copy, which was the
		# intent, right?
		die "$file already exists; you will need " .
		    "to remove it before $fname can start";
	}

	open $fh, "> $file\0" or die "Can't create lock $file: $!";
	printf $fh "$$ %s", scalar localtime;
	close $fh;

	# Make best attempt to catch fatal signals and Do The Right Thing.
	$SIG{TERM} = $SIG{INT} = sub {
		_doLog(["Removing lock on $fname"]);
		unlink $file;
		exit 0;
	};
}

=head2 _doLockRelease()

Removes existing NewsVac LOCK if one exists.

=over 4

=item Parameters

None.

=item Return value

None

=item Side effects

Removes $DATADIR/newsvac.lock from the local filesystem if it exists.

=item Dependencies

None.

=back

=cut

sub _doLockRelease {
	my($fname) = 'newsvac';

	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.lock");

	_doLog(["Releasing lock $fname"]);
	# fails silently even if $file does not exist
	unlink $file;
}

=head2 _doLog(msg, stdout, sname)

Writes data to the NewsVac log file. This routine is a modified form of the
logging routines in Slash::Utility::System. Please do not use this routine
directly, use C<errLog()> instead.

=over 4

=item Parameters

=over 4

=item $fname

=item @$msg

An array reference containing the list of messages to be appended to the log
file.

=item $stdout

=item $sname

=back

The use of the $stdout and $sname parameters is deprecated and this code
and is left for possible future use.

=item Return value

None

=item Side effects

Appends an entry to $DATADIR/newsvac.log

=item Dependencies

None.

=back

=cut

sub _doLog {
	my($msg, $stdout, $sname) = @_;
	my $fname = 'newsvac';
	chomp(my @msg = @$msg);

	$sname    ||= '';
	$sname     .= ' ' if $sname;
	my $fh      = gensym();
	my $dir     = getCurrentStatic('logdir');
	my $file    = catfile($dir, "$fname.log");
	my $log_msg = scalar(localtime) . " $sname@msg\n";

	open $fh, ">> $file\0" or
		warn "Can't append to $file: $!\nmsg: @msg\n";
	print $fh $log_msg;
	print     $log_msg if $stdout;
	close $fh;
}


############################################################

=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut
sub find_matches {
	my($match_ref, $weight_ref, $keywords_ref, $keyword_keys_ref,
		$plaintext) = @_;
	my $weight_total = 0;

	$keyword_keys_ref = [ keys %$keywords_ref ] if !$keyword_keys_ref;
	for my $keyword (@{$keyword_keys_ref}) {
		my $keyword_score = $keywords_ref->{$keyword}[0];
		my $n_matches = 0;

		while ($plaintext =~ m/(.{0,50})\b($keyword)(.{0,50})/g) {
			my($before, $excerpt, $after) = ($1, $2, $3);
			my $location = pos $plaintext;
			my $key = "$before\n$excerpt\n$after";

			++$n_matches;
			$match_ref->{$keyword}{$location}{$key} = 1;
		}

		$weight_total +=
			$keyword_score * (log($n_matches) + 1)
		if $n_matches;

		$weight_ref->{$keyword} =
			$keyword_score * (log($n_matches) + 1)
		if $n_matches;
	}

	return $weight_total;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut
sub tag_space_squeeze {
	my($text) = @_;

	$text =~ s/<[^>]*>/ /g;
	$text =~ s/\s+/ /g;
	$text =~ s/^\s*(.*?)\s*$/$1/;

	return $text;
}

############################################################
=head2 foo( [, ])

Foooooooo.

=over 4

=item Parameters

=over 4

=item

=back

=item Return value


=item Side effects


=item Dependencies

=back

=cut
sub unix_to_sql_datetime {
	my($time) = @_;
	my($sec, $min, $hour, $mday, $mon, $year) = gmtime($time);

	$mon++; $year += 1900;
	$sec = substr("0$sec", -2, 2);
	$min = substr("0$min", -2, 2);
	$hour = substr("0$hour", -2, 2);
	$mday = substr("0$mday", -2, 2);
	$mon = substr("0$mon", -2, 2);

	return "$year-$mon-$mday $hour:$min:$sec";
}

############################################################
=head2 sql_to_unix_datetime($string)

Given a date in database format, convert it into a format acceptable by the
code, in this case epoch-seconds.

=over 4

=item Parameters

=over 4

=item $string

The date to convert (which is usually 'YYYY-MM-DD min:sec', but may vary across
implementations)

=back

=item Return value

The given date as epoch-seconds.

=item Side effects

None.

=item Dependencies

=back

=cut
sub sql_to_unix_datetime {
	my($string) = @_;
	return 0 if !$string;

	my($year, $mon, $mday, $hour, $min, $sec) = $string =~
		/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;
	$mon += 0;

	return 0 if !defined($sec) or !$mon or !$year;
	return timegm($sec, $min, $hour, $mday, $mon - 1, $year);
}

############################################################

=head2 round($num , $sig)

Rounds number to the nearest given significant digit.

=over 4

=item Parameters

=over 4

=item $num

The number to be rounded.

=item $sig

This could be done a little better, if $sig is not given, we'll attempt to round
to the nearest one. If $sig is 2, we'll attempt to round to the nearest 10,
if 3, the nearest 100 and so on. Negative values are accepted, but results
have not been tested yet. If it's broken, please submit diffs. :)

=back

=item Return value

The rounded value.

=item Side effects

None.

=item Dependencies

=back

=cut

# Might be better if this becomes part of Slash::Utility::Data, that way
# other things (like newsvac.pl) can use it.
sub round {
	my($num, $sig) = @_;
	return 0 if $num == 0;
	$sig = 1 if !defined $sig;

	my $exp = int(log($num) / log(10));
	my $sign = ($exp >= 0) ? -1 : 1;
	my $base = ($sign == 1) ? 10 ** ($sign * abs($exp) + 1) : 1;
	my $adjnum = ($sign == 1) ? $num * $base : $num;

	# I think this is being applied incorrectly, for now, just round to the
	# nearest 1 and see how things look
	#my $rounder = 0.5 * (10 ** ($sig - 1));
	my $rounder = 0.5;

	return int($adjnum + $rounder) / $base;
}


1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
