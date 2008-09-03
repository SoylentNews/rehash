#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

# This tagbox's output isn't yet used anywhere and was basically
# written as a proof-of-concept.  It doesn't really hurt anything
# but we might end up removing it.
#
# Maybe it could be retooled to generate more-useful information
# for each user, like median tags applied per globj, number of
# unique tagnames, ratio of common to uncommon tagnames, etc.
# I'm not exactly sure what the use of that would be but I can
# see that having more value.

package Slash::Tagbox::TagCountUser;

=head1 NAME

Slash::Tagbox::TagCountUser - simple tagbox to count users' active tags

=head1 SYNOPSIS

	my $tagbox_tcu = getObject("Slash::Tagbox::TagCountUser");
	my $feederlog_ar = $tagbox_tcu->feed_newtags($tags_ar);
	$tagbox_tcu->run($affected_uid);

=cut

use strict;

use Slash;

our $VERSION = $Slash::Constants::VERSION;

use base 'Slash::Tagbox';

sub init_tagfilters {
	my($self) = @_;
	$self->{filter_activeonly} = 1;
}

sub get_affected_type	{ 'user' }
sub get_clid		{ 'describe' }

sub feed_newtags_process {
	my($self, $tags_ar) = @_;
	my $ret_ar = [ ];
	for my $tag_hr (@$tags_ar) {
                # affected_id and importance work the same whether this is
		# "really" newtags or deactivatedtags.
		my $days_old = (time - $tag_hr->{created_at_ut}) / 86400;
		my $importance =  $days_old <  1	? 1
				: $days_old < 14	? 1.1**-$days_old
				: 1.1**-14;
		my $ret_hr = {
			affected_id =>  $tag_hr->{uid},
			importance =>   $importance,
		};
		# We identify this little chunk of importance by either
		# tagid or tdid depending on whether the source data had
		# the tdid field (which tells us whether feed_newtags was
		# "really" called via feed_deactivatedtags).
		if ($tag_hr->{tdid})    { $ret_hr->{tdid}  = $tag_hr->{tdid}  }
		else                    { $ret_hr->{tagid} = $tag_hr->{tagid} }
		push @$ret_ar, $ret_hr;
	}
	return $ret_ar;
}

sub run_process {
	my($self, $affected_id, $tags_ar) = @_;
	my $count = $self->sqlCount('tags', "uid=$affected_id AND inactivated IS NULL");
	$self->info_log("uid %d count %d", $affected_id, $count);
	$self->setUser($affected_id, { tag_count => $count });
}

1;

