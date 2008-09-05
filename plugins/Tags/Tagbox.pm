# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# The base class for all tagbox classes.  Each tagbox should be a
# direct subclass of Slash::Tagbox.

# This class's object creation methods are class methods:
#	new()		- checks isInstalled() and calls
#			  getTagboxes(no_objects) to initialize $self
#	isInstalled()
#	DESTROY()	- disconnect the dbh
#
# Information about tagboxes, including each tagbox's object, are
# returned by:
#	getTagboxes()		- pulls in data from tagboxes table, returns it as base hash
#	getTagboxObject()	- returns a Slash::Tagbox subclass object for the given tbid
#
# Each subclass must override these methods:
#	get_affected_type()	- 'globj' usually, but for some tagboxes 'user'
#	get_clid()		- a clout_type, either numeric or string
# and may override any or all of these:
#	get_nosy_gtids()
#	get_userkeyregex()
#	get_gtt_extralevels()
#	get_gtt_options()
#
# Its utility/convenience methods are these object methods:
#	getTagboxesNosyForGlobj()
#	userKeysNeedTagLog()
#	logDeactivatedTags()
#	logUserChange()
#	getMostImportantTagboxAffectedIDs()
#	addFeederInfo() - add a row to tagboxlog_feeder, later read by getMostImportantTagboxAffectedIDs()
#	forceFeederRecalc() - like addFeederInfo() but forced
#	markTagboxLogged()
#	markTagboxRunComplete()
#	info_log()
#	debug_log()
#
# An important object method worth mentioning is:
#	getTagboxTags() - recursively fetches tags of interest to a tagbox;
#		designed to be generic enough for almost any tagbox
#
# These are the main four methods of the tagbox API.  Overriding these, and
# run() in particular, is how a tagbox defines its algorithm;  it's what
# makes a tagbox a tagbox.  Two of these have separate *_process methods
# that are commonly what gets overridden:
#	feed_newtags()		- some subclasses will override feed_newtags_process(),
#				  many won't need to override at all
#	feed_deactivatedtags()	- most subclasses can leave alone
#	feed_userchanges()	- most subclasses can leave alone
#	run()			- most subclasses will override run_process(),
#				  all will need to override something
#
# I haven't attempted to segregate out a list of methods which could operate
# on a reader database, so for now assume everything requires a writer.

package Slash::Tagbox;

use strict;

use Slash;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# FRY: And where would a giant nerd be? THE LIBRARY!

#################################################################

sub new {
	my($class, $user, @extra_args) = @_;
	my $self = $class->SUPER::new($user, @extra_args);
	$self->init_tagfilters();
	$self;
}

sub isInstalled {
	my($class) = @_;
	my $constants = getCurrentStatic();
	return undef if !$constants->{plugin}{Tags};
	return 1 if $class eq 'Slash::Tagbox';
	my($tagbox_name) = $class =~ /^Slash::Tagbox::(\w+)$/;
	return $tagbox_name && $constants->{tagbox}{$tagbox_name} ? 1 : undef;
}

sub init {
	my($self) = @_;
	$self->SUPER::init() if $self->can('SUPER::init');

	my $class = ref $self;
	if ($class ne 'Slash::Tagbox') {
		my($tagbox_name) = $class =~ /(\w+)$/;
		my %self_hash = %{ $self->getTagboxes($tagbox_name, undef, { no_objects => 1 }) };
		for my $key (keys %self_hash) {
			$self->{$key} = $self_hash{$key};
		}
	}

	# Because 'nod' and 'nix' are used so often, their tagnameid's
	# are pre-loaded into every tagbox object for convenience, as
	# $self->{nodid} and $self->{nixid}.  Subclasses are encouraged
	# to use $self->{fooid} to store the tagnameid for any 'foo'
	# which is commonly used..
	my $constants = getCurrentStatic();
	my $tagsdb = getObject('Slash::Tags');
	$self->{nodid} = $tagsdb->getTagnameidCreate($constants->{tags_upvote_tagname}   || 'nod');
	$self->{nixid} = $tagsdb->getTagnameidCreate($constants->{tags_downvote_tagname} || 'nix');

	1;
}

sub init_tagfilters {
	my($self) = @_;
	# by default, filter out nothing
}

#################################################################
#################################################################

sub get_affected_type {
	my($class) = @_;
	# no default can be assumed
	die "Slash::Tagbox::get_affected_type called for '$class', needs to be overridden";
}

sub get_clid {
	my($class) = @_;
	# no default can be assumed
	die "Slash::Tagbox::get_clid called for '$class', needs to be overridden";
}

sub get_nosy_gtids {
	my($class) = @_;
	# by default, tagboxes are not nosy about any untagged globjs
	return [ ];
}

sub get_userkeyregex {
	my($class) = @_;
	# by default, tagboxes don't care about any user key changes
	return undef;
}

sub get_gtt_extralevels {
	my($class) = @_;
	# by default, tagboxes only want the first "level" of tags from
	# getTagboxTags()
	return 0;
}

sub get_gtt_options {
	my($class) =@_;
	# by default, tagboxes don't pass getTagboxTags() any options
	return { };
}

#################################################################

# Return information about tagboxes, from the 'tagboxes' table.
#
# If neither $id nor $field is specified, returns an arrayref of
# hashrefs, where each hashref has keys and values from the
# 'tagboxes' table, and additionally has the 'object' key which
# is a Slash::Tagbox subclass object.
#
# If $id is a true value, it must be a string, either the tbid or
# the name of a tagbox.  In this case only the hashref for that
# one tagbox's id is returned.
#
# If $field is a true value, it may be either a single string or
# an arrayref of strings.  In this case each hashref (or the one
# hashref) will have only the field(s) specified.  Requesting
# only the fields needed can have a very significant performance
# improvement (specifically, if the variant fields
# last_tagid_logged, last_userchange_logged, or last_run_completed
# are not needed, it will be much faster not to request them).

# This is a class method, not an object method.

{ # closure XXX this won't work with multiple sites, fix
my $tagboxes = undef;
sub getTagboxes {
	my($self, $id, $field, $options) = @_;
	my @fields = ( );
	if ($field) {
		@fields = ref($field) ? @$field : ($field);
	}
	my %fields = ( map { ($_, 1) } @fields );

	# Update the data to current if necessary;  load it all if necessary.
	if ($tagboxes) {
		# The data in these four columns is never cached.  Only load it
		# from the DB if it is requested (i.e. if $field was empty so
		# all fields are needed, or if $field is an array with any).
		if (!@fields
			|| $fields{last_run_completed}
			|| $fields{last_tagid_logged}
			|| $fields{last_tdid_logged}
			|| $fields{last_tuid_logged}
		) {
			my $new_hr = $self->sqlSelectAllHashref('tbid',
				'tbid, last_run_completed,
				 last_tagid_logged, last_tdid_logged, last_tuid_logged',
				'tagboxes');
			for my $hr (@$tagboxes) {
				$hr->{last_run_completed} = $new_hr->{$hr->{tbid}}{last_run_completed};
				$hr->{last_tagid_logged}  = $new_hr->{$hr->{tbid}}{last_tagid_logged};
				$hr->{last_tuid_logged}   = $new_hr->{$hr->{tbid}}{last_tuid_logged};
				$hr->{last_tdid_logged}   = $new_hr->{$hr->{tbid}}{last_tdid_logged};
			}
		}
	} else {
		# Get the raw data from the DB.
		$tagboxes = $self->sqlSelectAllHashrefArray('*', 'tagboxes', '', 'ORDER BY tbid');

		# Add each class's values for these parameters as returned by
		# its class methods.  (Because these are class methods, not
		# object methods, it doesn't matter that the class's new()
		# might re-invoke getTagboxes().)
		for my $hr (@$tagboxes) {
			my $class = "Slash::Tagbox::$hr->{name}";
			Slash::Utility::Environment::loadClass($class);
			$hr->{affected_type} = $class->get_affected_type();
			$hr->{userkeyregex} = $class->get_userkeyregex();
			$hr->{clid} = $class->get_clid();
			if ($hr->{clid} =~ /^[a-z]/) {
				# Allow subclasses' get_clid() class method
				# to optionally return the string (e.g. 'vote')
				# instead of the numeric equivalent.
				$hr->{clid} = $self->getCloutTypes()->{ $hr->{clid} };
			}
			my $nosy_gtids_ar = $class->get_nosy_gtids() || [ ];
			$nosy_gtids_ar = [ $nosy_gtids_ar ] if !ref $nosy_gtids_ar;
			if (grep { /^[a-z]/ } @$nosy_gtids_ar) {
				# Allow subclasses' get_nosy_gtids() class method
				# to optionally return strings (e.g. 'urls')
				# instead of the numeric equivalents.
				$nosy_gtids_ar = [ map {
					/^[a-z]/	? $self->getGlobjTypes()->{ $_ }
							: $_
				} @$nosy_gtids_ar ];
			}
			$hr->{nosy_gtids} = $nosy_gtids_ar;
		}

		# The getObject() below calls new() on each tagbox class,
		# which calls getTagboxes() with no_objects set.
		# XXX I'm pretty sure this has only worked because I've been
		# lucky enough to have getTagboxes() called normally before
		# any Slash::Tagbox::Foo->new() calls invoke
		# getTagboxes({no_objects}).  This logic needs to be changed
		# so that if a stray no_objects invocation appears first
		# the $tagboxes cache doesn't store an object-less hash.
		# That would be a particularly difficult bug to find.
		if (!$options->{no_objects}) {
			for my $hr (@$tagboxes) {
				my $object = getObject("Slash::Tagbox::$hr->{name}");
				$hr->{object} = $object;
			}
			# If any object failed to be created for some reason,
			# that tagbox never gets returned.
			$tagboxes = [ grep { $_->{object} } @$tagboxes ];
		}
	}

	# If one or more fields were asked for, then some of the
	# data in the other fields may not be current since we
	# may have skipped loading the last_* fields.  Make a
	# copy of the data so the $tagboxes closure is not
	# affected, then delete all but the fields requested
	# (returning stale data could lead to nasty bugs).
	my $tb = [ @$tagboxes ];

	# If just one specific tagbox was requested, take out all the
	# others.
	if ($id) {
		my @tb_tmp;
		if ($id =~ /^\d+$/) {
			@tb_tmp = grep { $_->{tbid} == $id } @$tb;
		} else {
			@tb_tmp = grep { $_->{name} eq $id } @$tb;
		}
		return undef if !@tb_tmp;
		$tb = [ $tb_tmp[0] ];
	}

	# Clone the data so we don't affect the $tagboxes persistent
	# closure variable.
	my $tbc = [ ];
	for my $tagbox (@$tb) {
		my %tagbox_hash = %$tagbox;
		push @$tbc, \%tagbox_hash;
	}

	# If specific fields were requested, go through the data
	# and strip out the fields that were not requested.
	if (@fields) {
		for my $tagbox (@$tbc) {
			my @unwanted = grep { !$fields{$_} } keys %$tagbox;
			delete @$tagbox{@unwanted};
		}
	}

	# If one specific tagbox was requested, return its hashref.
	# Otherwise return an arrayref of all their hashrefs.
	return $tbc->[0] if $id;
	return $tbc;
}
}

# This is a wrapper around getTagboxes that just gets the object.
# It's a lot like getObject() except it takes a tbid instead of a
# class name -- and of course it's a Slash::Tagbox method, not a
# utility function.

sub getTagboxObject {
	my($self, $tbid) = @_;
	# XXX I'm pretty sure this could be optimized.
	my $tagbox_hr = $self->getTagboxes($tbid, [qw( object )]);
	return $tagbox_hr ? $tagbox_hr->{object} : undef;
}

# A tagbox being "nosy" about a globj means that it wants a feederlog
# row inserted for a globjid when it is created, whether or not the
# globj has any tags applied yet.
#
# Right now the only way to filter globjs for nosiness is by gtid.
# (This may change in the future.)  If a tagbox is nosy for a gtid, it
# must set $self->{filter_gtid_nosy} in its init_tagfilters().
#
# Cache a list of which gtids map to which tagboxes, so we can quickly
# return a list of tagboxes that want a "nosy" entry for a given gtid.
# Input is a hashref with the globj fields (the only one this cares
# about at the moment is gtid, but that may change in future).  Output
# is an array of tagbox IDs.

{ # closure XXX this won't work with multiple sites, fix
my $gtid_to_tbids = { };
sub getTagboxesNosyForGlobj {
	my($self, $globj_hr) = @_;
	my $gtid;
	if (!keys %$gtid_to_tbids) {
		my $globj_types = $self->getGlobjTypes();
		for $gtid (grep /^\d+$/, keys %$globj_types) {
			$gtid_to_tbids->{ $gtid } = [ ];
		}
		my $tagboxes = $self->getTagboxes();
		for my $tb_hr (@$tagboxes) {
			my $nosy_ref = $tb_hr->{nosy_gtids};
			for $gtid (@$nosy_ref) {
				push @{ $gtid_to_tbids->{$gtid} }, $tb_hr->{tbid};
			}
		}
	}
	$gtid = $globj_hr->{gtid};
	return @{ $gtid_to_tbids->{$gtid} };
}
}

{ # closure XXX this won't work with multiple sites, fix
my $userkey_masterregex;
sub userKeysNeedTagLog {
	my($self, $keys_ar) = @_;

	if (!defined $userkey_masterregex) {
		my $tagboxes = $self->getTagboxes();
		my @regexes = ( );
		for my $tagbox (@$tagboxes) {
# XXX pull this from methods not data
			for my $regex (@{$tagbox->{userkeyregexes}}) {
				push @regexes, $regex;
			}
		}
		if (@regexes) {
			my $r = '(' . join('|', map { "($_)" } @regexes) . ')';
			$userkey_masterregex = qr{$r};
		} else {
			$userkey_masterregex = '';
		}
	}

	# If no tagboxes have regexes, nothing can match.
	return ( ) if !$userkey_masterregex;

	my @update_keys = ( );
	for my $k (@$keys_ar) {
		push @update_keys, $k if $k =~ $userkey_masterregex;
	}
	return @update_keys;
}
}

sub logDeactivatedTags {
	my($self, $deactivated_tagids) = @_;
	return 0 if !$deactivated_tagids;
	my $logged = 0;
	for my $tagid (@$deactivated_tagids) {
		$logged += $self->sqlInsert('tags_deactivated',
			{ tagid => $tagid });
	}
	return $logged;
}

sub logUserChange {
	my($self, $uid, $name, $old, $new) = @_;
	return $self->sqlInsert('tags_userchange', {
		-created_at =>	'NOW()',
		uid =>		$uid,
		user_key =>	$name,
		value_old =>	$old,
		value_new =>	$new,
	});
}

sub getMostImportantTagboxAffectedIDs {
	my($self, $options) = @_;
	my $num = $options->{num} || 10;
	my $min_weightsum = $options->{min_weightsum} || 1;

	if ($options->{try_to_reduce_rowcount}) {
		# XXX instead of sum_imp_weight, factor in COUNT(*)
	} else {
		return $self->sqlSelectAllHashrefArray(
			'tagboxes.tbid,
			 affected_id,
			 MAX(tfid) AS max_tfid,
			 SUM(importance*weight) AS sum_imp_weight',
			'tagboxes, tagboxlog_feeder',
			'tagboxes.tbid=tagboxlog_feeder.tbid',
			"GROUP BY tagboxes.tbid, affected_id
			 HAVING sum_imp_weight >= $min_weightsum
			 ORDER BY sum_imp_weight DESC LIMIT $num");
	}
}

sub getTagboxTags {
	my($self, $tbid, $affected_id, $extra_levels, $options) = @_;
	warn "no tbid for $self" if !$tbid;
	$extra_levels ||= 0;
	my $type = $options->{type} || $self->get_affected_type();
	$self->debug_log("getTagboxTags(%d, %d, %d), type=%s",
		$tbid, $affected_id, $extra_levels, $type);
	my $hr_ar = [ ];
	my $colname = ($type eq 'user') ? 'uid' : 'globjid';
	my $max_time_clause = '';
	if ($options->{max_time_noquote}) {
		$max_time_clause = " AND created_at <= $options->{max_time_noquote}";
	} elsif ($options->{max_time}) {
		my $mtq = $self->sqlQuote($options->{max_time});
		$max_time_clause = " AND created_at <= $mtq";
	}
	$hr_ar = $self->sqlSelectAllHashrefArray(
		'tags.*, tagname, UNIX_TIMESTAMP(created_at) AS created_at_ut',
		'tags, tagnames',
		"tags.tagnameid=tagnames.tagnameid
		 AND $colname=$affected_id $max_time_clause",
		'ORDER BY tagid');
	$self->debug_log("colname=%s pre_filter hr_ar=%d",
		$colname, scalar(@$hr_ar));
	$hr_ar = $self->feed_newtags_filter($hr_ar);
	$self->debug_log("colname=%s post_filter hr_ar=%d",
		$colname, scalar(@$hr_ar));

	# If extra_levels were requested, fetch them.  
	my $old_colname = $colname;
	while ($extra_levels) {
		$self->debug_log("el %d", $extra_levels);
		my $new_colname = ($old_colname eq 'uid') ? 'globjid' : 'uid';
		my %new_ids = ( map { ($_->{$new_colname}, 1) } @$hr_ar );
		my $new_ids = join(',', sort { $a <=> $b } keys %new_ids);

		$hr_ar = $self->sqlSelectAllHashrefArray(
			'tags.*, tagname, UNIX_TIMESTAMP(created_at) AS created_at_ut',
			'tags, tagnames',
			"tags.tagnameid=tagnames.tagnameid
			 AND $new_colname IN ($new_ids) $max_time_clause",
			'ORDER BY tagid');

		$self->debug_log("new_colname=%s pre_filter hr_ar=%d new_ids=%d (%.20s)",
			$new_colname, scalar(@$hr_ar), scalar(keys %new_ids), $new_ids);

		$hr_ar = $self->gtt_filter($hr_ar);

		$self->debug_log("new_colname=%s post_filter hr_ar=%d",
			$new_colname, scalar(@$hr_ar));
		$old_colname = $new_colname;
		--$extra_levels;
		$self->debug_log("el %d", $extra_levels);
	}
	$self->addGlobjEssentialsToHashrefArray($hr_ar);
	# XXX do we want to $tagsdb->addCloutsToTagArrayref($hr_ar, (globj type string)) here?
	return $hr_ar;
}

sub gtt_filter {
	my($self, $tags_ar) = @_;
	return $self->_do_default_filter($tags_ar);
}

sub addFeederInfo {
	my($self, $info_hr) = @_;
	# XXX make this a debug_log at some point, we don't need this much info
	$self->info_log("tbid=%d affected_id=%d importance=%f",
		$self->{tbid}, $info_hr->{affected_id}, $info_hr->{importance});
	$info_hr->{-created_at} = 'NOW()';
	$info_hr->{tbid} = $self->{tbid};
	return $self->sqlInsert('tagboxlog_feeder', $info_hr);
}

sub forceFeederRecalc {
	my($self, $affected_id) = @_;
	# XXX make this a debug_log maybe?
	$self->info_log("tbid=%d affected_id=%d",
		$self->{tbid}, $affected_id);
	my $info_hr = {
		-created_at =>	'NOW()',
		tbid =>		$self->{tbid},
		affected_id =>	$affected_id,
		importance =>	999999,
		tagid =>	undef,
		tdid =>		undef,
		tuid =>		undef,
	};
	return $self->sqlInsert('tagboxlog_feeder', $info_hr);
}

sub markTagboxLogged {
	my($self, $update_hr) = @_;
	$self->sqlUpdate('tagboxes', $update_hr, "tbid=$self->{tbid}");
}

sub markTagboxRunComplete {
	my($self, $affected_hr) = @_;

	# markTagboxRunComplete() is not specific to any tagbox subclass,
	# and so $self here might well be an object of the Slash::Tagbox
	# base class.  The $affected_hr defines which tagbox id needs to
	# have this operation performed, so we ignore $self's own tbid
	# and take $affected_hr's as authoritative.

	my $delete_clause = "tbid=$affected_hr->{tbid} AND affected_id=$affected_hr->{affected_id}";
	$delete_clause .= " AND tfid <= $affected_hr->{max_tfid}";

	$self->sqlDelete('tagboxlog_feeder', $delete_clause);
	$self->sqlUpdate('tagboxes',
		{ -last_run_completed => 'NOW()' },
		"tbid=$affected_hr->{tbid}");
}

sub info_log {
	my($self, $format, @args) = @_;
	my $caller_sub_full = (caller(1))[3];
	my($caller_sub) = $caller_sub_full =~ /::([^:]+)$/;
	my $class = ref($self);
	my $msg = sprintf("%s %s $format", $class, $caller_sub, @args);
	if (defined &main::tagboxLog) {
		main::tagboxLog($msg);
	} else {
		print STDERR scalar(gmtime) . " $msg";
	}
}

sub debug_log {
	my($self, $format, @args) = @_;
	return if !$self->{debug};
	$self->info_log($format, @args);
}

#################################################################
#################################################################

sub _do_default_filter {
	my($self, $tags_ar) = @_;

	$tags_ar = $self->_do_filter_activeonly($tags_ar);
	$tags_ar = $self->_do_filter_publiconly($tags_ar);
	$tags_ar = $self->_do_filter_firehoseonly($tags_ar);
	$tags_ar = $self->_do_filter_tagnameid($tags_ar);
	$tags_ar = $self->_do_filter_gtid($tags_ar);
	$tags_ar = $self->_do_filter_uid($tags_ar);

	return $tags_ar;
}

# "activeonly" is the simplest and ironically the trickiest of the
# filters.  Its mission is simply:  if the tagbox wants only
# still-active tags, eliminate any inactivated tags.
#
# However, when feed_newtags_filter is informed of the _de_activation
# of a tag, we probably _do_ want to know, because the tag being
# deactivated may be one we already processed as active in a previous
# invocation.  In those cases, the tag will have a {tdid} field and
# we will include it.
#
# When called by run_filter or gtt_filter, though, we probably don't,
# because run doesn't care what changed, it just cares what things
# look like now.  If an inactivated tag has no {tdid} field, either
# its deactivation was old news or we've been called from run/gtt,
# and either way we don't care and will exclude it.

sub _do_filter_activeonly {
	my($self, $tags_ar) = @_;
	if ($self->{filter_activeonly}) {
		$tags_ar = [ grep {
			   !$_->{inactivated}
			||  $_->{tdid}
		} @$tags_ar ];
	}
	return $tags_ar;
}

# "publiconly", if a tagbox has set that option, only allows tags
# with private='no'

sub _do_filter_publiconly {
	my($self, $tags_ar) = @_;
	if ($self->{filter_publiconly}) {
		$tags_ar = [ grep { $_->{private} eq 'no' } @$tags_ar ];
	}
	return $tags_ar;
}

# If a tag is applied to a globj that's in the firehose, we include
# it.  If its globj is not (yet) in the hose, we do not.

sub _do_filter_firehoseonly {
	my($self, $tags_ar) = @_;
	if ($self->{filter_firehoseonly}) {
		my %globjs = ( map { $_->{globjid}, 1 } @$tags_ar );
		my $globjs_str = join(', ', sort keys %globjs);
		my $fh_globjs_ar = $self->sqlSelectColArrayref(
			'globjid',
			'firehose',
			"globjid IN ($globjs_str)");
		return [ ] if !@$fh_globjs_ar; # if no affected globjs have firehose entries, short-circuit out
		my %fh_globjs = ( map { $_, 1 } @$fh_globjs_ar );
		$tags_ar = [ grep { $fh_globjs{ $_->{affected_id} } } @$tags_ar ];
	}
	return $tags_ar;
}

# If a tagnameid filter is in place, eliminate any tags with
# tagnames not on the list.

sub _do_filter_tagnameid {
	my($self, $tags_ar) = @_;
	if ($self->{filter_tagnameid}) {
		my $tagnameid_ar = ref($self->{filter_tagnameid})
			? $self->{filter_tagnameid} : [ $self->{filter_tagnameid} ];
		my %tagnameid_wanted = ( map { ($_, 1) } @$tagnameid_ar );
		$tags_ar = [ grep { $tagnameid_wanted{ $_->{tagnameid} } } @$tags_ar ];
	}
	return $tags_ar;
}

# If a gtid filter is in place, eliminate any tags on globjs
# not of those type(s).
#
# This requires a DB hit but it's a quick primary key lookup.

sub _do_filter_gtid {
	my($self, $tags_ar) = @_;
	if ($self->{filter_gtid}) {
		my $gtid_ar = ref($self->{filter_gtid})
			? $self->{filter_gtid} : [ $self->{filter_gtid} ];
		my $all_gtid_str = join(',', sort { $a <=> $b } @$gtid_ar);
		my %all_globjids = ( map { ($_->{globjid}, 1) } @$tags_ar );
		my $all_globjids_str = join(',', sort { $a <=> $b } keys %all_globjids);
		if ($all_gtid_str && $all_globjids_str) {
			my $globjids_wanted_ar = $self->sqlSelectColArrayref(
				'globjid',
				'globjs',
				"globjid IN ($all_globjids_str)
				 AND gtid IN ($all_gtid_str)");
			my %globjid_wanted = ( map { ($_, 1) } @$globjids_wanted_ar );
			$tags_ar = [ grep { $globjid_wanted{ $_->{globjid} } } @$tags_ar ];
		} else {
			$tags_ar = [ ];
		}
	}
	return $tags_ar;
}

# If a uid filter is in place, eliminate any tags not from those users.

sub _do_filter_uid {
	my($self, $tags_ar) = @_;
	if ($self->{filter_uid}) {
		my $uid_ar = ref($self->{filter_uid})
			? $self->{filter_uid} : [ $self->{filter_uid} ];
		my %uid_wanted = ( map { ($_, 1) } @$uid_ar );
		$tags_ar = [ grep { $uid_wanted{ $_->{uid} } } @$tags_ar ];
	}
	return $tags_ar;
}

#################################################################

sub feed_newtags {
	my($self, $tags_ar) = @_;
	$tags_ar = $self->feed_newtags_filter($tags_ar);
	$self->feed_newtags_pre($tags_ar);

	my $ret_ar = $self->feed_newtags_process($tags_ar);

	$self->feed_newtags_post($ret_ar);
	return $ret_ar;
}

sub feed_newtags_filter {
	my($self, $tags_ar) = @_;
	return $self->_do_default_filter($tags_ar);
}

sub feed_newtags_pre {
	my($self, $tags_ar) = @_;
	# XXX only if debugging is on
	# XXX note in log here, instead of feed_d_pre, if tdid's present
	my $count = scalar(@$tags_ar);
	if ($count < 9) {
		$self->info_log("filtered tags '%s'",
			 join(' ', map { $_->{tagid} } @$tags_ar));
	} else {
		$self->info_log("%d filtered tags '%s ... %s'",
			scalar(@$tags_ar), $tags_ar->[0]{tagid}, $tags_ar->[-1]{tagid});
	}
}

sub feed_newtags_post {
	my($self, $ret_ar) = @_;
	# XXX only if debugging is on
	$self->info_log("returning %d", scalar(@$ret_ar));
}

sub feed_newtags_process {
	my($self, $tags_ar) = @_;

	# By default, add importance of 1 for each tag that made it through filtering.
	# If a subclass calling up to this method has set an {importance} field for
	# any tag, use that instead.

	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
		my $ret_hr = {
			affected_id =>  $tag_hr->{globjid},
			importance =>   defined($tag_hr->{importance}) ? $tag_hr->{importance} : 1,
		};
		# Both new tags and deactivated tags are considered important.
		# Pass along either the tdid or the tagid field, depending on
		# which type each hashref indicates.
		if ($tag_hr->{tdid})    { $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else                    { $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}
	return $ret_ar;
}

#################################################################

sub feed_deactivatedtags {
	my($self, $tags_ar) = @_;
	$self->feed_deactivatedtags_pre($tags_ar);

	# by default, just pass along to feed_newtags (which will have to
	# check $tags_ar->[]{tdid} to determine whether the changes were
	# really new tags or just deactivated tags)
	return $self->feed_newtags($tags_ar);
}

sub feed_deactivatedtags_pre {
	my($self, $tags_ar) = @_;
	$self->info_log("tagids='%s'",
		join(' ', map { $_->{tagid} } @$tags_ar) );
}

#################################################################

sub feed_userchanges {
	my($self, $users_ar) = @_;
	$self->feed_userchanges_pre($users_ar);

	# by default, do not care about any user changes
	return [ ];
}

sub feed_userchanges_pre {
	my($self, $users_ar) = @_;
	$self->info_log("uids='%s'",
		join(' ', map { $_->{tuid} } @$users_ar) );
}

# XXX consider adapting this code, found in Top.pm, and making a
# default feed_userchanges_process that handles the standard
# /^tag_clout$/ regex

#sub feed_userchanges {
#	my($self, $users_ar) = @_;
#	my $constants = getCurrentStatic();
#	my $tagsdb = getObject('Slash::Tags');
#	main::tagboxLog("Top->feed_userchanges called: users_ar='" . join(' ', map { $_->{tuid} } @$users_ar) .  "'");
#
#	my %max_tuid = ( );
#	my %uid_change_sum = ( );
#	my %globj_change = ( );
#	for my $hr (@$users_ar) {
#		next unless $hr->{user_key} eq 'tag_clout';
#		$max_tuid{$hr->{uid}} ||= $hr->{tuid};
#		$max_tuid{$hr->{uid}}   = $hr->{tuid}
#			if $max_tuid{$hr->{uid}} < $hr->{tuid};
#		$uid_change_sum{$hr->{uid}} ||= 0;
#		$uid_change_sum{$hr->{uid}} += abs(($hr->{value_old} || 1) - $hr->{value_new});
#	}
#	for my $uid (keys %uid_change_sum) {
#		my $tags_ar = $tagsdb->getAllTagsFromUser($uid);
#		for my $tag_hr (@$tags_ar) {
#			$globj_change{$tag_hr->{globjid}}{max_tuid} ||= $max_tuid{$uid};
#			$globj_change{$tag_hr->{globjid}}{max_tuid}   = $max_tuid{$uid}
#				if $globj_change{$tag_hr->{globjid}}{max_tuid} < $max_tuid{$uid};
#			$globj_change{$tag_hr->{globjid}}{sum} ||= 0;
#			$globj_change{$tag_hr->{globjid}}{sum} += $uid_change_sum{$uid};
#		}
#	}
#	my $ret_ar = [ ];
#	for my $globjid (sort { $a <=> $b } keys %globj_change) {
#		push @$ret_ar, {
#			tuid =>         $globj_change{$globjid}{max_tuid},
#			affected_id =>  $globjid,
#			importance =>   $globj_change{$globjid}{sum},
#		};
#	}
#
#	$self->info_log("returning %d", scalar(@$ret_ar));
#	return $ret_ar;
#}

#################################################################

sub run {
	my($self, $affected_id, $options) = @_;
	$self->run_pre($affected_id);
	my $tags_ar = $self->run_gettags($affected_id);
	$tags_ar = $self->run_filter($tags_ar);
	$self->run_process($affected_id, $tags_ar, $options);
}

sub run_pre {
	my($self, $affected_id) = @_;
	$self->info_log("id %d", $affected_id);
}

sub run_gettags {
	my($self, $affected_id) = @_;
	# By default, make use of getTagboxTags().
	return $self->getTagboxTags(
		$self->{tbid},
		$affected_id,
		$self->get_gtt_extralevels(),
		$self->get_gtt_options());
}

sub run_filter {
	my($self, $tags_ar) = @_;
	return $self->_do_default_filter($tags_ar);
}

sub run_process {
	my($self, $tags_ar) = @_;
	# This method needs to be overridden by the subclass that implements
	# the tagbox.
	die "Slash::Tagbox::run_process called for $self, needs to be overridden";
}

#################################################################
#################################################################

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

1;

=head1 NAME

Slash::Tagbox - Slash Tagbox module

=head1 SYNOPSIS

	use Slash::Tagbox;

=head1 DESCRIPTION

This contains all of the routines currently used by Tagbox.

=head1 SEE ALSO

Slash(3).

=cut

