#!/usr/bin/perl -w
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

use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';
use Fcntl;
use POSIX qw( tmpnam );
use FileHandle;
use Time::HiRes;
use Time::Local;
use Digest::MD5;
use LWP;
use LWP::RobotUA;
use HTML::Entities;
use HTML::LinkExtor;
use URI::Escape;
use HTTP::Cookies;

use Slash::Display;
use Slash::Utility;
 
($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;      

use vars qw($VERSION $callback_ref);

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
	my ($class, $user, %conf) = @_;
    
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'NewsVac'};   

	$self = {
		ua_class        =>	'LWP::UserAgent',
		hp_class	=>	'HTML::Parser',
		debug           =>      2,
		using_lock	=>	0,
		callback	=>	{},
	};
 
 	# Allow a var to override default User Agent class.
	$self->{ua_class} = $conf{ua_class} if $conf{ua_class};

	# bless() must occur before call to base class methods.
	bless ($self,$class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;                   

	# Create the user agent.
	my $ua_class = $self->{ua_class};
	$self->{ua} = $ua_class->new();
	$self->{ua}->agent(getData('spider_useragent', {
		version => $VERSION,
	}));
	$self->{ua}->cookie_jar(new HTTP::Cookies);

	# and the parsing object.
	$self->{hp_parsedtext} = [ ];
	my $hp_class = $self->{hp_class};

	$self->{hp} = $hp_class->new(
		api_version	=> 3,
		text_h		=> [$self->{hp_parsedtext}, 'dtext'],
	);

	return $self;
}

############################################################

# Destructor which formally removes the lock.
sub DESTROY { 
	my($self) = @_;
	doLogExit('newsvac') if $self->{using_lock}; 
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
		doLogInit('newsvac');
	};
	# This is not an equality test. This is an assignment-null test.
	if ($_ = $@) {
		# Die with a detailed locking message.
		die getData('newsvac_locked', {
			error_message => $@,
		}, 'newsvac') if /^Please stop existing/;
		# Otherwise we've caught something terminal
		die getData('unexpected_init_err', {
			error_message => $@,
		}, 'newsvac');
	}

	return ($self->{using_lock} = 1);
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

=head2 timing(cmd [, duration])

Foooooooo.

=over 4

=item Parameters

None.

=item Return value

n/a

=item Side effects

n/a

=item Dependencies

n/a

=back

=cut

sub timing {
	my($self, $cmd, $duration) = @_;

	$self->{timing_data}{$cmd}{total} += $duration;
    
# 	Let's replace this with something a bit more concise.
#
#    if ($duration < 0.055) {
#	$duration = int($duration*100+0.5)/100;
#    } elsif ($duration < 0.55) {
#	$duration = int($duration*10+0.5)/10;
#    } elsif ($duration < 5.5) {
#	$duration = int($duration+0.5);
#    } else {
#	$duration = int($duration+5);
#    }

	# Round to an extra significant digit for small numbers and to the 
	# nearest 5 for larger values. See helper function round() for how
	# it all works.
	my $sig = 1;
	$sig++ if $duration >= 5.5;
	$duration = round($duration, $sig);

	$self->{timing_data}{$cmd}{$duration}++;
}

############################################################

=head2 timing_clear( )

Foooooooo.

=over 4

=item Parameters

=over 4

=item None.

=back


=item Return value


=item Side effects


=item Dependencies

=back

=cut

sub timing_clear {
    my($self) = @_;

    delete $self->{timing_data};
    $self->{timing_data} = {};
}

############################################################

=head2 timing_dump( )

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

sub timing_dump {
	my($self) = @_;
	my(@timing_data, @durations);

	# Timestamp unnecessary, since it's automatically done by errLog().
	#my $ts = scalar(localtime);
    	for my $cmd (sort keys %{$self->{timing_data}}) {
		my $total = round($self->{timing_data}{$cmd}{total}, 3);
		my $total_n = 0;
		my @dur = ($cmd);

		delete $self->{timing_data}{$cmd}{total};

		for (sort {$a<=>$b} keys %{$self->{timing_data}{$cmd}}) {
			my $n = $self->{timing_data}{$cmd}{$_};
			$total_n += $n;

			# Be aware that @dur, position 1, is an array ref that
			# contains individual command timings.
			push @{$dur[1]}, [$_, round($_ * $n, 3), $n];
		}
		my $mean = round($total/$total_n);

		# We push totals and averages onto @dur, then @dur gets added
		# to our main list of durations.
		push @dur, ($total, $total_n, $mean);
		push @durations, \@dur;
	}

	$self->errLog(getData('timing_dump', {
		durations	=> \@durations,
		show_ts		=> !$self->{using_lock},
		timestamp	=> scalar localtime,
	}));

	$self->timing_clear();
}

############################################################

=head2 canonical(url)

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

sub canonical {
	my($self, $url) = @_;

	$url = URI->new($url)->canonical();
	# Don't clean out the fragment if it contains useful information.
	$url->fragment(undef) if length $url->fragment == 0;

	return $url;
}

############################################################

=head2 add_url(url)

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

sub add_url {
	my ($self, $url) = @_;

	$url = $self->canonical($url)->as_string();
	if (!$url || $url =~ /^(javascript|mailto):/) {
		$self->errLog(getData('add_url_noadderr', {
			url	=> $url,
			reason	=> $1,
		}));

		return;
	}

	my $digest = Digest::MD5::md5_base64($url);

	my $rc = $self->sqlInsert('url_info', { 
		url 		=> $url,
		url_digest 	=> $digest,
	});
	my $url_id = $self->getLastInsertId();

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

	return $rc ? $self->getLastInsertId('spider') : 0;
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

sub urls_to_ids {
	my ($self, @urls) = @_;

	if (!@urls) {
		$self->errLog(getData('urls_to_ids_nourls'));

		return ( );
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

sub id_to_url {
	# This should keep a cache for efficiency.
	my ($self, $url_id) = @_;

	my $url = undef;
	$url_id = $self->sqlQuote($url_id);
	$url = $self->sqlSelect('url', 'url_info', "url_id=$url_id");

	return $url;
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

sub ids_to_urls {
	my ($self, @url_ids) = @_;
	my %hash;

	if (!@url_ids) {
		$self->errLog(getData('ids_to_urls_noids'));

		return ( );
	}

	my $id_list = sprintf '(%s)', join(',', @url_ids);
	my $ar = $self->sqlSelectAll(
		'url_id, url', 
		'url_info', 
		"url_id IN $id_list"
	);
	$hash{$_->[0]} = $_->[1] for @{$ar};
	my @urls = map { $hash{$_} ? $hash{$_} : '' } @url_ids;
	$self->errLog(getData('ids_to_urls', {
		url_hash	=> \%hash,
		size_urls	=> scalar @urls,
		size_urlids	=> scalar @url_ids,
	})) if $self->{debug} > 1;

	return @urls;
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

sub add_urls_return_ids {
	my ($self, @urls) = @_;

	my %digest = map { ( $_, Digest::MD5::md5_base64($_) ) } @urls;

	for (keys %digest) {
		my $rc = $self->sqlInsert('url_info', {
			url		=> $_,
			url_digest	=> $digest{$_},
		}, 'IGNORE'); 
	}
   	$self->urls_to_ids(@urls);
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

sub add_rels_mark_valid {
	my ($self, @rels) = @_;
			
	for (@rels) {
		$self->sqlInsert('rel', {
			from_url_id	=> $_->[0],
			to_url_id	=> $_->[1],
			parse_code	=> $_->[2],
			type		=> $_->[3],
			first_verified	=> $_->[4],
		}, 'IGNORE');
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

sub add_rel {
	my ($self, $from_url_id, $to_url_id, $parse_code, $type,
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
		}, "from_url_id=$from_url_id AND to_url_id=$to_url_id AND
                    parse_code=$parse_code AND type=$type");
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
	my ($self, $from_url_id, $to_url_id, $tagname, $tagattr) = @_;

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

sub id_to_rel {
	# This should keep a cache for efficiency.
	my ($self, $rel_id) = @_;
	my ($ary_ref);
	my $q_rel_id = $self->sqlQuote($rel_id);

	my $select_text = <<EOT;
from_url_id, to_url_id, tagname, tagattr FROM rel WHERE rel_id=$q_rel_id
EOT

	my $sth = $self->select_cached($select_text);
	if ($sth) {
		$ary_ref = $sth->fetchrow_arrayref();
		$sth->finish();
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
	my ($self, $minername, $last_edit_aid, $pre_stories_text, 
	    $post_stories_text, $pre_stories_regex, $post_stories_regex,
	    $extract_vars, $extract_regex, $tweak_code, @urls) = @_;

	my $owner_aid = $last_edit_aid;

	$self->sqlInsert('miner', {
		name			=> $minername,
		owner_aid 		=> $owner_aid,
		last_edit_aid	 	=> $last_edit_aid,
		pre_stories_text	=> $pre_stories_text,
		post_stories_text	=> $post_stories_text,
		pre_stories_regex	=> $pre_stories_regex,
		post_stories_regex 	=> $post_stories_regex,
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
	my ($self, $minername, @urls) = @_;

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
	my ($self, $minername) = @_;

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
	my ($self, $miner_id) = @_;

	my $minername = $self->sqlSelect('name', 'miner', "miner_id=$miner_id");
	
	$self->errLog(getData('id_to_minername', {
		miner_id	=> $miner_id,
		miner_name	=> $minername,
	})) if $self->{debug} > 1;

	return $minername;
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

sub delete_url_ids {
	my($self) = @_;

	my $id_list = sprintf '(%s)', join(',', @_[1..$#_]);

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

sub delete_rel_ids {
	my($self) = @_;

	my $id_list = sprintf '(%s)', join(',', @_[1..$#_]);
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
	my ($self, $dest_url, $title, $source, $slug) = @_;

	$dest_url = $self->canonical($dest_url)->as_string();
	$title = tag_space_squeeze($title);
	$source = tag_space_squeeze($source);
	$slug = tag_space_squeeze($slug);
	
	my %nugget_data = (
		url     =>      $dest_url,
		title   =>      $title,
		source  =>      $source,
		slug    =>      $slug,
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
	my ($self, $nugget_url) = @_;
	my %info = ( );

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
	my ($self, $miner_name, @nugget_hashes) = @_;
    
	my @dest_urls = ( );
	for my $nh (@nugget_hashes) {
		$nh->{dest_url} = $self->canonical($nh->{dest_url})->as_string();
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

	my @nugget_urls = ( );
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

	my @rels = ( );
	for (0..$#dest_url_ids) {
		my $nughash = $nugget_hashes[$_];

		if (!$nughash->{source_url_id} or
		    !$nugget_url_ids[$_]       or
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
	my ($self, $conditions_ref, @url_ids) = @_;
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
	my ($self, $conditions_ref, $urls_ar, $ids_ar) = @_;
	my $start_time;
    
	$self->errLog(getData('process_urls_and_ids_listids', {
		num_urls	=> scalar @{$urls_ar},
		url_ids		=> $ids_ar,
	})) if $self->{debug} > 1;
	
	for (0..$#$urls_ar) {
		my($url, $url_id) = ($urls_ar->[$_], $ids_ar->[$_]);
		my(%update_info, %update_content, %update_other);
		%update_info = %update_content = %update_other = ();

		if (!$url or !$url_id) {
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
        $self->timing('request', Time::HiRes::time() - $start_time);
        
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

		$self->timing('analyze', Time::HiRes::time() - $start_time);
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
	my ($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
	    $conditions_ref) = @_;
    
	my $start_time = Time::HiRes::time();

	# Set the cookie jar, which will be empty unless we get cookies from
	# the db.
	$self->{ua}->cookie_jar()->clear();
    
	my $old_info_ref = $self->sqlSelectHashref(
		'*', 'url_info', "url_id=$url_id"
	);
	my $current_time = $conditions_ref->{use_current_time} || time;

	if ($old_info_ref) {
		$self->errLog(getData('request_oldinfodisplay', {
			old_info	=> $old_info_ref,
		})) if $self->{debug} > 1;

		my $believed_fresh_until = $current_time;
		$believed_fresh_until = sql_to_unix_datetime(
			$old_info_ref->{believed_fresh_until}
		) if $old_info_ref->{believed_fresh_until};

		if (!$conditions_ref->{force_request}) {
			if ($believed_fresh_until > $current_time) {
				$self->errLog(getData('request_urlfresh', {
					url_id => $url_id,
					   dur => $believed_fresh_until - 
					          $current_time,
				})) if $self->{debug} > 1;

				$info_ref->{$_} = $old_info_ref->{$_}
					for keys %{$old_info_ref};
				my $new_content_ref = $self->sqlSelectHashref(
					'url_content.url_id, response_header, 
					cookies, message_body, plaintext',
			
					'url_content, url_message_body,
					url_plaintext',

				    	"url_content.url_id      = $url_id AND
					 url_message_body.url_id = $url_id AND
				    	 url_plaintext.url_id    = $url_id"
				);
				%{$content_ref} = %{$new_content_ref}
					if $new_content_ref;
				$other_ref->{response_timestamp} =
					sql_to_unix_datetime(
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
				# HTTP::Cookies object, unfortunately). For 
				# other info on the next few lines of code, see 
				# "perldoc -q temporary file" and "perldoc 
				# perlref" (search on "autovivification", new 
				# to perl5.6).
				my($fh, $filename);
				$fh = new FileHandle;
				do { $filename = tmpnam() } 
					until open $fh, ">$filename";
				print $fh $cookies;
				close $fh;
				$self->{ua}->cookie_jar()->load($filename);
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

    		$info_ref->{is_success} = 1;
		$info_ref->{last_attempt} = 
			$other_ref->{response_timestamp_string};
		$info_ref->{last_success} = $info_ref->{last_attempt};
		$info_ref->{status_code} = 200;
		$info_ref->{reason_phrase} = "OK Nugget";
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
			local $SIG{ALRM} = sub { die 'timeout' };
			alarm $timeout + 1;
			$response = $self->{ua}->request($request);
			alarm 0;
		};
		$self->errLog(getData('request_uaerror', {
			err => $@, url_id => $url_id, url => $url,
		})) if $@;
        
		if (!$response) {
			$info_ref->{is_success} = 0;
			$other_ref->{response_timestamp} = $current_time;
			$other_ref->{freshness_lifetime} = 300;
			$info_ref->{status_code} = 599;
			$info_ref->{reason_phrase} = "UDBT timeout $timeout";
		} else {
			$info_ref->{is_success} = 
				$response->is_success() ? 1 : 0;
			$other_ref->{response_timestamp} = 
				$response->date() || $response->client_date || 
				$current_time;
			
			# Don't accept responses coded as being from the future 
			# (TCP doesn't work with tachyons).
			$other_ref->{response_timestamp} = $current_time 
				if $other_ref->{response_timestamp} >
				   $current_time;
			$other_ref->{freshness_lifetime} = 
				$response->freshness_lifetime();
			# negative freshness doesn't make sense
			$other_ref->{freshness_lifetime} = 0 
				if $other_ref->{freshness_lifetime} < 0;
			$info_ref->{status_code} = $response->code();
			$info_ref->{reason_phrase} = $response->message();
		}
		$other_ref->{response_timestamp_string} = unix_to_sql_datetime(
			$other_ref->{response_timestamp}
		);
		$info_ref->{last_attempt} = 
			$other_ref->{response_timestamp_string};
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
				url_id 	=> $url_id, 
				url	=> $url,
				response=> $response ?
					$response->error_as_HTML() : '',
			})) if $self->{debug} > 1;
		} else {
			# The request succeeded;  update lots of stuff.
			$info_ref->{last_success} = $info_ref->{last_attempt};
			$info_ref->{url_base}     = $response->base();
			$info_ref->{content_type} = 
				$response->header('content-type');
			$info_ref->{title}        = $response->header('title');
#			$info_ref->{value}	  = $self->aged_value(
#				$old_info_ref->{value}, 
#				$other_ref->{response_timestamp} - 
#			) if $old_info_ref->{value};
		
			$content_ref->{response_header} = 
				$response->headers_as_string();
			$content_ref->{message_body}    = $response->content();
			my ($filename, $fh);
			$fh = new FileHandle;
			do { $filename = tmpnam() } 
				until open($fh, ">$filename");
			close $fh;
			$self->{ua}->cookie_jar()->save($filename);
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
	        my $url_base_str = $url_base_obj->as_string();
	        $self->errLog(getData('request_delurlbase', {
			url 		=> $url,  
			url_base	=> $info_ref->{url_base}, 
			url_base_str 	=> $url_base_str,
		})) if $self->{debug} > 1;
		$info_ref->{url_base} = undef if $url eq $url_base_str;
    	}

	$self->sqlUpdate("url_info", $info_ref, "url_id = $url_id")
		if keys %$info_ref;
	if (keys %$content_ref) {
		# This simplifies the INSERT/UPDATE logic: do blind INSERTS
		# on the ID and then UPDATE it later.
		$self->sqlInsert('url_content', { 
			url_id => $url_id 
		}, 'IGNORE');
		$self->sqlInsert('url_message_body', {
			url_id => $url_id 
		}, 'IGNORE');
        	$self->sqlInsert('url_plaintext', {
			url_id => $url_id
		}, 'IGNORE');

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
					message_body =>
						$content_ref->{message_body}
				}, "url_id=$url_id");
			} else {
				$self->errLog(getData('request_overflow', {
					message_body =>
						$content_ref->{message_body},
				}));
			}
		}
	}

	# Carry over the previous SQL data into the info_ref hash.
	$info_ref->{$_} ||= $old_info_ref->{$_} for keys %{$old_info_ref};
    
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
	my ($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
	    $conditions_ref) = @_;

	$self->errLog(getData('analyze_contentlength', {
		content_length => length($content_ref->{message_body}),
	})) if $self->{debug} > 0;

	# Remember that get_parse_codes() is parameter compatible with this
	# routine only for parameters 1-4 (not counting $self).
	my @parse_codes = $self->get_parse_codes(@_[1 .. 4]);

	for my $parse_code (@parse_codes) {
		# Redundant. Information printed with next call to errLog().
		#$self->errLog("parse_code $parse_code") if $self->{debug} > 1;
		
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
			or $conditions_ref->{force_analyze}
			or $conditions_ref->{"force_analyze_$parse_code"}
		) {
			# The last successful analysis using this parse_code
			# took place before the last successful request (or
			# never took place). Or, we're being told to force 
			# it...either way we need to re-analyze it.
			my $parse_method =
				$self->get_parse_code_method($parse_code);
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
				$self->timing("parse_$parse_code", $duration);

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
					parse_code 	=> $parse_code, 
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
    my ($self, $url_id, $url, $update_info_ref, $update_content_ref,
        $response_timestamp) = @_;
    
	my @codes = ( );
    
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
	my ($self, $code) = @_;

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
		while (my ($tagname, $tagattr) = 
		       each %HTML::LinkExtor::LINK_ELEMENT)
		{
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
	my ($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
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
		base_url => $base_url,
	        link_ref => { },
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
	my ($self, $tagname, %attr) = @_;

	for (keys %attr) {
		my $new_url = URI->new_abs(
			$attr{$_}, $callback_ref->{base_url}
		)->canonical()->as_string();

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
	my ($self, $miner_id, $body_ref, $pre_text, $pre_regex, $post_text,
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
		# What the hell are THESE for? The sole purpose, as I see it, is to
		# break any pre regexp entered!
		#$the_reg =~ s{^(\(\?i\))?(.*)}{$1\\A[\\000-\\377]*$2};

		$self->errLog(getData('trim_body_thereg', {
			the_reg => $the_reg,
			miner_id=> $miner_id,
			type 	=> 'pre',
		})) if $self->{debug} > 0;
		${$body_ref} =~ s{$the_reg}{}m;
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
		# What the hell are THESE for? The sole purpose, as I see it, is to
		# break any post regexp entered!
        	#$the_reg .= "[\\000-\\377]*\\Z";
		$self->errLog(getData('trim_body_thereg', {
			the_reg	=> $the_reg,
			miner_id=> $miner_id,
			type	=> 'post',
		})) if $self->{debug} > 0;
		${$body_ref} =~ s{$the_reg}{}m;
    	}
    
    	$self->errLog(getData('trim_body', {
		miner_id	=> $miner_id,
		orig_body_length=> $orig_body_length,
		body_length	=> length(${$body_ref}),
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
	my ($self, $url_id, $url_orig, $info_ref, $content_ref, $other_ref,
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

	$self->trim_body(
		$info_ref->{miner_id}, 
		\$message_body,
		$hr->{pre_stories_text}, 
		$hr->{pre_stories_regex},
		$hr->{post_stories_text}, 
		$hr->{post_stories_regex}
	);

#	my $fh = new FileHandle;
#	my $tmp_filename = "/tmp/body_$url_id";
#	if (open($fh, ">$tmp_filename")) { print $fh $message_body; close $fh }
    
	my @extraction_keys = qw( url title source slug body );
	my $extraction_key_regex = '^(' . join('|', @extraction_keys) . ')$';
	my @extract_vars = grep /$extraction_key_regex/,
	
	split / /, $hr->{extract_vars};
	my $extract_regex = $hr->{extract_regex};
	my $tweak_code = $hr->{tweak_code} || '';

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

	my %nugget = ( );
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
	
	my %extractions = ( );
	my @extractions;
	my $get_extractions = "\@extractions = (";
	$get_extractions .= "\$" . ($_ + 1) . ", " for (0..$#extract_vars);
	$get_extractions =~ s/, $/\);/;
	$self->errLog(getData('parse_miner_extractions', {
		extractions => $get_extractions,
	})) if $self->{debug} > 1;

	$message_body =~ s{\s+}{ }g;
	$self->errLog(getData('parse_miner_bodystats', {
		message_body => $message_body,
	})) if $self->{debug} > 1;
	my($count, $url, $title, $source, $slug, $body, $key) = (0);
	while ($message_body =~ /$extract_regex/gx) {
		# Kinda redundant.
		#$self->errLog("pos " . pos($message_body))
		#	if $self->{debug} > 1;
		@extractions = ( );
		eval $get_extractions;

		$self->errLog(getData('parse_miner_trackextract', {
			url_id		=> $url_id,
			miner_id	=> $info_ref->{miner_id},
			'pos'		=> pos($message_body),
			extractions	=> \@extractions,
		})) if $self->{debug} > 2;

		$extractions{$_} = '' for @extraction_keys;
		for my $i (0..$#extract_vars) {
			$extractions{$extract_vars[$i]} = $extractions[$i]
				if $extractions[$i] and not
				   $extractions{$extract_vars[$i]};
		}
		next unless $extractions{url} or $extractions{body};
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

	# If the hash is empty, time to bail, but the success flag is still
	# set.
	return {
		is_success 	=> 1,
		n_nuggets 	=> 0,
		miner_id	=> $info_ref->{miner_id}
	} if !%nugget;

	my @nugget_keys = keys %nugget;
	$self->errLog("nugget keys: @nugget_keys") if $self->{debug} > 1;
	for (@nugget_keys) {
		delete $nugget{$_};
		($count, $url, $title, $source, $slug, $body) =
			split("\n", $_);
		$url =~ s/\s+//g;
		if ($url) {
			$self->errLog(getData('parse_miner_showurl', {
				url		=> $url,
				base_url	=> $base_url,
				url_base	=> $info_ref->{url_base},
				url_orig	=> $url_orig,
			})) if $self->{debug} > 1;

			$url = URI->new_abs(
				$url, 
				$base_url
			)->canonical()->as_string();
		}
		if ($url !~ /^(http|ftp):/) {
			my($origurl, $etc) = split("\n", $_);

			$self->errLog(getData('parse_miner_badproto', {
				url	=> $url,
				url_orig=> $origurl,
				base_url=> $base_url,
			})) if $self->{debug} > 1;
			next ;
		}
		$title  = tag_space_squeeze($title);
		$source = tag_space_squeeze($source);
		$slug   = tag_space_squeeze($slug);
		$body   = tag_space_squeeze($body);
		$key    = join "\n",
			($count, $url, $title, $source, $slug, $body);
		$nugget{$key}++;
       	}

	@nugget_keys =  map { $_->[0] } 
			sort { $a->[1] <=> $b->[1] }
			map { [ $_, (split "\n", $_)[0] ] }
			keys %nugget;

	my %seen_url = ( );
	$self->errLog(getData('parse_miner_nuggetkeys', {
		nugget_keys => \@nugget_keys,
	})) if $self->{debug} > 1;
	if ($tweak_code) {
		die "tweak_code contains attempted system call!!!"
			if $tweak_code =~ /`|(system|exec|open) /;
		for (@nugget_keys) {
			my $cancel = 0;

			($count, $url, $title, $source, $slug, $body) = 
				split("\n", $_);
			my $seen_url = defined($seen_url{$url}) ? 1 : 0;
			eval $tweak_code;
			delete $nugget{$_};
			if (!$cancel) {
				$nugget{$_}++;
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
		$self->timing_dump();
	}

	my(@nugget_hashes, @bodies);
	for (@nugget_keys) {
		($url, $title, $source, $slug, $body) = split("\n", $_);
		
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
			$self->timing_dump();
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
	   
	$self->errLog(getData('parse_plaintext_start', {url_id => $url_id}))
		if $self->{debug} > 1;

	my $changed = 0;
	my $timeout =	$conditions_ref->{timeout} || 
			$self->{ua}->timeout() 	   || 
			20;

	if ($info_ref->{content_type} =~ /^text\/html\b/) {
		eval {
			local $SIG{ALRM} = sub { die "timeout" };
			alarm $timeout;

			$#{$self->{hp_parsedtext}} = -1;
			$self->{hp}->parse($content_ref->{message_body});
			$content_ref->{plaintext} = join('',
				map { join("", @$_) }
				@{$self->{hp_parsedtext}}
			);
			$changed = 1 if $content_ref->{plaintext};
			$#{$self->{hp_parsedtext}} = -1;
	
#			my $lynx_cmd = qq
#[lynx -dump -nolist -width=75 -term=vt102 $filename.htm];
#			if (!open($fh, "$lynx_cmd |")) {
#				$self->errLog("could not run $lynx_cmd, $!")
#					if $self->{debug} > -1;
#			} else {
#				while (defined(my $line = <$fh>)) {
#					chomp $line;
#					$line =~ s/\s+$//;
#					$content_ref->{plaintext} .= "$line\n";
#					$changed = 1;
#					$self->errLog("lynx output: $line") 
#						if $self->{debug} > 2;
#				}
#			}

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
#		unlink "$filename.htm";
	} elsif ($info_ref->{content_type} eq 'text/plain') {
		$content_ref->{plaintext} = $content_ref->{message_body};
		$changed = 1;
	}

	if ($changed) {
		$content_ref->{plaintext} =~ s/\s*\n\s*\n\s*/\n\n/g;
		$content_ref->{plaintext} =~ s/[ \t]*\n[ \t]*/\n/g;
		$content_ref->{plaintext} =~ s/[ \t]{2,}/  /g;

		$self->sqlUpdate('url_plaintext', {
			plaintext => $self->sqlQuote($content_ref->{plaintext}),
		}, "url_id=$url_id");
	}

	$self->errLog(getData('parse_plaintext_result', {
		url_id	=> $url_id,
		changed	=> $changed,
		timeout	=> $timeout,
		bodylen => length($content_ref->{message_body}),
	       plainlen => length($content_ref->{plaintext}),
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
	my ($self, $url_id, $url, $info_ref, $content_ref, $other_ref,
	    $conditions_ref) = @_;

	my $nugget = $self->nugget_url_to_info($url);
	my $nugget_url_id = $self->url_to_id($nugget->{url});
	my $response_timestamp =
		$other_ref->{response_timestamp} ||
		sql_to_unix_datetime($info_ref->{last_success}) ||
		time; # hack, hack

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

sub spider_by_name {
	my($self, $name) = @_;
	my $name_quoted = $self->sqlQuote($name);
    
	my $spider_ar = $self->sqlSelectAll(
		'conditions, group_0_selects, commands', 
		'spider',
		"name = $name_quoted"
	);

	if (!$spider_ar or !$spider_ar->[0]) {
		$self->errLog(getData('spiderbyname_invalidname', {
			name		=> $name,
			name_quoted	=> $name_quoted,
		}, 'newsvac'));

		return 0;
	}
	$self->timing_clear() if $self->{debug} > -1;

	my($conditions_text, $group_0_selects_text, $commands_text) =
		@{$spider_ar->[0]};

	my $conditions_ref          = eval $conditions_text;
	my $group_0_selects_ref     = eval $group_0_selects_text;
	my $commands_ref            = eval $commands_text;

	$self->errLog(getData('spiderbyname_start', {
		name			=> $name,
		name_quoted		=> $name_quoted,
		group_0_selects_text	=> $group_0_selects_text,
		commands_text		=> $commands_text,
		conditions_ref		=> $conditions_ref,
		group_o_selects_ref	=> $group_0_selects_ref,
		commands_ref		=> $commands_ref,
	}, 'newsvac')) if $self->{debug} > 0;

	$self->spider($conditions_ref, $group_0_selects_ref, @{$commands_ref});

	if ($self->{debug} > -1) {
		$self->timing_dump();
		$self->errLog(getData('spiderbyname_end', {
			name => $name,
		}));
	}
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
    
	my %processed = ( );
	my $dest_ids_ar = [ ];
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

	# sc = "spider command" of course 
	for my $sc (@spider_commands) {
		my($src_ar, $dest_ar, $where, $extra) = @{$sc};

		$self->errLog(getData('spider_command', {
			src_ar	=>
			dest_ar	=>
			where	=> $where,
			extra	=> $extra,
		}, 'newsvac')) if $self->{debug} > 0;

        	$extra = '' if !$extra;
	        $src_ar  = [ $src_ar ]  if !ref $src_ar;
	        $dest_ar = [ $dest_ar ] if !ref $dest_ar;

	        for my $dest (@$dest_ar) {
			# src_ar is an array ref pointing to the group or 
			# groups whose IDs to use as source
			my %src;

			for (@{$src_ar}) {
				$self->{sd}{$_} = [ ] if !$self->{sd}{$_};
				map { $src{$_} = 1 } @{$self->{sd}{$_}}
			}
			$src_ar = [ 
				sort { $a<=>$b } grep !$processed{$dest}, 
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
					$conditions_ref, @{$src_ar}
				);

				map { $processed{$_} = 1 } @{$src_ar};
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
		my $processed_ids_ar = [ keys %processed ];
		
		return ($dest_ids_ar, $processed_ids_ar);
	} else {
		return $dest_ids_ar;
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

sub spider_init {
	my ($self, $conditions_ref, $group_0_wheres_ref) = @_;
    
	# sd = spider data
	$self->{sd} = { };
	$self->{sd}{$_} = $conditions_ref->{$_} for keys %{$conditions_ref};

	# Blown query.
	my $excluded_cond;
	my $none_miner_id = $self->sqlSelect(
		'miner_id', 'miner', 'name="none"'
	);
	$excluded_cond = "url_info.miner_id != $none_miner_id"
		if $none_miner_id;
    
	my %group_0_ids = ( );
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

=head2 garbage_collect( )

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

	my ($n_rels, $n_urls, $n_mbs) = (0, 0, 0);
	$self->timing_clear() if $self->{debug} > -1;

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

		$self->timing_dump();
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

sub robosubmit {
	my($self) = @_;

	my($master_sql_regex, $master_sql_regex_encoded);
	my %keywords = ( );
	my(@keyword_keys) = ( );
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

	my($sec, $min, $hour, $mday, $mon, $year) = localtime(int($start_time)); 
        my($i, %submitworthy, @sub) = (0);
        while (my ($miner_name, $nugget_url_id, $nugget_url, $url, $title, 
		   $time, $plaintext, $matches) = $sth->fetchrow())
	{
                if (!$matches) {              
                        $submitworthy{$nugget_url_id} = 0 if $nugget_url_id;
                        next;
                }

                my $nugget_info = $self->nugget_url_to_info($nugget_url);
                $plaintext =~ s{\s+}{ }g;
                $sub[$i]{subid} = "$hour$min$sec$i.$mon$mday$year";
                $sub[$i]{'time'} = $time;
                $sub[$i]{subj} = $nugget_info->{title} || $title;
                $sub[$i]{name} = $nugget_info->{source} || '';
                $sub[$i]{miner} = $miner_name || '';
                $sub[$i]{nugget_url_id} = $nugget_url_id;

                # Find what keywords match, and for each one that does, record
		# how many times it does (and some other nice info)
                my %match = ( );
                my %weight = ( );
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

                my %seen_keyword = ( );
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
                my %excerpts = ( );
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
                                        $after  =~ s{\s+\S*$}{} 
						if length($after) > 20;
					$before  = encode_entities($before);
					$excerpt = encode_entities($excerpt);
					$after   = encode_entities($after);

                                        $excerpts{"$location$keynum"} = 
						getData('excerptdata', {
							before  => $before,
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
			'index'	=> $i,
			miner	=> $sub[$i]{miner},
			weight	=> $sub[$i]{weight},
		})) if $self->{debug} > 2;

                ++$i;            
        }

        for (@sub) {
                if (!$_->{weight}) {             
                        $submitworthy{$_->{nugget_url_id}} = 0;
                        next;
                }

		# Create submission.
		my $subid =  $_->{subid};
		$self->sqlInsert("submissions", { subid => $subid });
		$self->setSubmission($subid, {
                        email 		=> $_->{miner},
			uid 		=> $constants->{anonymous_coward_uid},
			name 		=> $_->{name},
			story 		=> $_->{story},
			time 		=> $_->{'time'},
			subj 		=> $_->{subj},
			tid 		=> $constants->{newsvac_topic},
			section 	=> $constants->{newsvac_section},
			weight 		=> $_->{weight},
			keywords 	=> $_->{keywords}
		});
			
                $submitworthy{$_->{nugget_url_id}} = 1;            
        }

        my ($worthy, $unworthy) = (0, 0);

        for (sort { $a <=> $b } keys %submitworthy) {
		$self->sqlInsert('nugget_sub', {
			url_id 		=> $_,
                        submitworthy 	=> $submitworthy{$_}
		}, 'IGNORE');
                $submitworthy{$_} ? ++$worthy : ++$unworthy;
        }
        $sth->finish(); # not really necessary

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
sub load_keywords {
	my ($self, $kw_ref, $keys_ref, $m_regex_ref, $m_regex_enc_ref) = @_;

	my $cursor = $self->sqlSelectMany(
		'regex,weight,tag', 'newsvac_keywords'
	);

	while (my ($regex, $weight, $tag) = $cursor->fetchrow) {
		$kw_ref->{$regex} = [$weight, $tag];
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
sub check_regex {
	my ($self, $regex, $flags) = @_;

	$flags = '' if !$flags;
	my $err = '';
	$flags =~ tr{gimosk}{}cd;
	$regex =~ s{/}{\\/}g;

	my $eval_string = "'foo' =~ /$regex/$flags;";
	eval $eval_string;
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
	my(@days) = (1,3,7);
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

=head2 getMinerList( )

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
sub getMiner {
	my($self, $miner_id) = @_;

	my $returnable = $self->sqlSelectHashref(
		'*', 'miner', 'miner_id=' . $self->sqlQuote($miner_id)
	);

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
	my ($self, $url_id) = @_;

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
sub getMinerRegexps {
	my($self, $miner_id) = @_;

	my $returnable = $self->sqlSelectHashref(
		'pre_stories_text, pre_stories_regex,
		 post_stories_text, post_stories_regex',
		'miner', 'miner_id=' . $self->sqlQuote($miner_id)
	);

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
sub getURLRelationships {
	my($self, $url_ids, $max_results) = @_;
	@{$url_ids} = grep { /^\d+$/ } @{$url_ids};
	return 0 if !scalar @{$url_ids};

	my $where_clause = sprintf "(%s) AND
		 	 	    rel.to_url_id = url_info.url_id AND
				    parse_code = 'miner'",

				    join ' OR ', map { "rel.from_url_id=$_" } 
				    		 @{$url_ids};

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
sub getURLCounts {
	my($self) = @_;

	my @returnable = (
		$self->sqlCount('url_info'),
		$self->sqlCount('url_info', 'miner_id=0')
	);

	return @returnable;
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
        	my $a = $_->{last_edit} =~
			/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;

                $_->{last_edit_formatted} = timeCalc("$1-$2-$3 $4:$5:$6")
			if $a
        }

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

	$self->sqlUpdate(
		'spider', $data, 'spider_id=' . $self->sqlQuote($spider_id)
	);
}

############################################################

=head2 setSpiderTimespecs(spider_id, timespecs)

Update's the data for a given spider in the NewsVac database.

=over 4

=item Parameters

=over 4

=item $spider_id
ID associated with the spider to update.

=item %$data
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
				-last_run	=> 'now()',
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
		'name=' . $self->sqlQuote($spider_name)
	);

	return $returnable;
}


############################################################

=head2 getSpiderName(spider_id)

Foooooooo.

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
=head2 sqlInsert($table, $data, [, $extra])

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
sub sqlInsert {
	my($self, $table, $data, $extra) = @_;
	my($names, $values);

	my %extra;
	$extra{lc $_} = 1 for split /,\s*/, $extra;
	# We can now reuse $extra.
	$extra = '';
	$extra .= ' /*! DELAYED */' if $extra{delayed};
	$extra .= ' IGNORE' if $extra{ignore};

	for (keys %$data) {
		if (/^-/) {
			$values .= "\n  $data->{$_},";
			s/^-//;
		} else {
			$values .= "\n  " . $self->sqlQuote($data->{$_}) . ',';
		}
		$names .= "$_,";
	}

	chop($names);
	chop($values);

	my $sql = "INSERT$extra INTO $table ($names) VALUES($values)\n";
	$self->sqlConnect();
	return $self->sqlDo($sql);
}

############################################################
=head2 setSubmission($subid, $data)

Overrides Slash::DB::MySQL::setSubmission

This may eventually get backported to the core. I hope so.

=over 4

=item Parameters

=over 4

=item $subid

The submission ID to update.

=item $data

Hashref containing the data to update, with keys in the hash matching to the
fieldnames of the 'submission' table. Any element in the hashref that does
not match a field name in that table will be an assumed parameter and stored
in the 'submissions_param' table.

=back

=item Return value

None.

=item Side effects

Changes the associated record in the 'submissions' and/or 'submission_param'
tables.

=item Dependencies

=back

=cut
sub setSubmission {
	my($self, $subid, $data) = @_;
	my(@param, %update_tables, $cache);

	my $param_table = 'submission_param';

	$cache = _genericGetCacheName($self, 'submissions');
	my %update_data;
	for (keys %{$data}) {
		my($clean_val);

		($clean_val = $_) =~ s/^-//;
		my $key = $self->{$cache}{$clean_val};

		# $update_table{$key} should either be null or 'submissions'.
		if ($key) {
			$update_data{$_} = $data->{$_} if defined $data->{$_};
		} else {
			push @param, [$_, $data->{$_}];
		}
	}

	# Write to main table.
	$self->sqlUpdate(
		'submissions', 
		\%update_data, 
		'subid=' . $self->sqlQuote($subid)
	) if keys %update_data;

	# Write to param table.
	for (@param) {
		$self->sqlReplace($param_table, {
			subid	=> $subid,
			name	=> $_->[0],
			value	=> $_->[1],
		}) if defined $_->[1];
	}
}

############################################################
=head2 _genericGetCacheName($tables)

This re-implements the private Slash::DB necessary for cache
access for our overrides, above. See Slash::DB::_getGenericCacheName()
for more details

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

# I don't know why this wasn't inherited, but it might be due to the fact that
# it's "private" in Slash::DB::MySQL.
sub _genericGetCacheName {
	my($self, $tables) = @_;
	my $cache;

	if (ref($tables) eq 'ARRAY') {
		$cache = '_' . join ('_', sort(@{$tables}), 'cache_tables_keys');
		unless (keys %{$self->{$cache}}) {
			for my $table (@{$tables}) {
				my $keys = $self->getKeys($table);
				for (@{$keys}) {
					$self->{$cache}{$_} = $table;
				}
			}
		}
	} else {
		$cache = '_' . $tables . 'cache_tables_keys';
		unless (keys %{$self->{$cache}}) {
			my $keys = $self->getKeys($tables);
			for (@{$keys}) {
				$self->{$cache}{$_} = $tables;
			}
		}
	}
	return $cache;
}


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
	my($self) = @_;

	# We get a little obtuse to avoide the allergic reactions from use
	# of shift().
	if ($self->{use_locking}) {
		doLog('newsvac', [ @_[1..$#_] ]);
		return;
	}

	chomp($_) for @_[1..$#_];
	printf STDERR "%s\n", join "\n", @_[1..$#_];
}


############################################################
# These are not methods, but utility functions.  Don't pass them $self!
# These should probably be private.
############################################################

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
	my $rounder = 0.5 * (10 ** ($sig - 1));
	
	return int($adjnum + $rounder) / $base;
}


1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
