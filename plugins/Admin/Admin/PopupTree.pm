# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Admin::PopupTree;

=head1 NAME

Slash::Admin::PopupTree


=head1 SYNOPSIS

	# basic example of usage


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
#use HTML::PopupTreeSelect '1.4';

use base 'HTML::PopupTreeSelect';
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

#========================================================================

=head2 getPopupTree( [, ])

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

sub getPopupTree {
	my($stid, $options, $param) = @_;
	my $reader	= getObject('Slash::DB', { db_type => 'reader' });
	my $constants	= getCurrentStatic();
	my $tree_withpg	= $reader->getTopicTree;

	my $tree = { };
	for my $tid (keys %$tree_withpg) {
		$tree->{$tid} = $tree_withpg->{$tid}
			if $tid # just in case someone added a bad tid
			&& (
				# filter out product guide topics
				$tid < ($constants->{product_guide_tid_lower_limit} || 10_000)
				||
				$tid > ($constants->{product_guide_tid_upper_limit} || 20_000)
			);
	}

	$param   ||= {};
	$options ||= {};

	$constants->{topic_popup_open} = 1 unless defined $constants->{topic_popup_open};

	my $data;
	my %topics_added;
	my @tids =	map  { $_->[0] }
			sort { $a->[1] cmp $b->[1] }
			map  { [ $_, lc $tree->{$_}{textname} ] }
			keys %$tree;

	# Set up %topics except for parents and children
	my %topics;
	for my $tid (@tids) {
		my $topic = $tree->{$tid};
		@{$topics{$tid}}{qw(value label height width image open)} = (
			$tid, @{$topic}{qw(textname height width image)},
			$constants->{topic_popup_open} ? 1 : 0
		);
	}

	while (1) {
#print STDERR "getPopupTree added=" . scalar(keys %topics_added) . " tree=" . scalar(@tids) . "\n";
		last if scalar(keys %topics_added) == scalar(keys %$tree);
		my $topic;
		for my $tid (@tids) {
			next if $topics_added{$tid}; # skip if already added
			$topic = $tree->{$tid};

			my $linked_in = 0;
			if (scalar keys %{$topic->{parent}}) {
				$topics{$tid}{parent} = $topic->{parent};
				for my $pid (keys %{$topic->{parent}}) {
					# Don't include topics whose connection to their
					# parent is negative, i.e. which forbid their
					# parent topic.
#print STDERR "topic tid='$topic->{tid}' parent='$pid' conn='$topic->{parent}{$pid}'\n";
					next if $topic->{parent}{$pid} < 0;
					push @{$topics{$pid}{children}}, $topics{$tid};
					$linked_in = 1;
				}
			} else {
#print STDERR "topic tid='$topic->{tid}' ROOT\n";
				push @$data, $topics{$tid};
				$linked_in = 1;
			}
			$topics_added{$tid} = 1 if $linked_in;
#print STDERR "topic tid='$topic->{tid}' NOT_LINKED_IN\n" if !$linked_in;
		}
		# Some topics may not have been added.  Start a new subtree
		# at the bottom and continue.
		# To find the root of the new subtree, start by taking the
		# first numerical tid that hasn't been added.
		my @not_added = (
			sort { $a <=> $b }
			grep { !$topics_added{$_} }
			@tids
		);
#print STDERR "not_added: '@not_added'\n";
		next unless @not_added;
		my $tid = $not_added[0];
		$topic = $tree->{$tid};
		# Then walk up the tree until we get to the top of a subtree
		# that hasn't been added.
		while (keys %{$topic->{parent}}) {
			my $pid = (
				sort { $a <=> $b }
				grep { !$topics_added{$_} }
				keys %{$topic->{parent}}
			)[0];
			last unless $pid;
			$tid = $pid;
			$topic = $tree->{$tid};
		}
#print STDERR "top-not-added: '$tid'\n";
		# Then add it and continue.
		push @$data, $topics{$tid};
		$topics_added{$tid} = 1;
	}

	# children
	my $stcid = delete $param->{stcid};

	HTML::PopupTreeSelect::reset_id();

	# most of the stuff below (name, title, etc.) should be in vars or getData
	my $select = Slash::Admin::PopupTree->new(
		_template_options	=> $options,
		name			=> ['st', 'stc'],
		data			=> $data,
		slashtopics		=> \%topics,
		stid			=> $stid,
		stcid			=> $stcid,
		slashorig		=> $tree,
		title			=> 'Select Topics',
		button_label		=> 'Choose',
		onselect		=> 'st_main_add',
		form_field_form		=> 'slashstoryform',
		hide_selects		=> 0,
		scrollbars		=> 1,
		width			=> 300,
		height			=> 450,
		image_path		=> $constants->{imagedir} . '/',
	);

	return $select->output;
}

sub output {
	my($self, $template) = @_;
	return $self->SUPER::output(1);
}

sub _output_generate {
	my($self, $template, $param) = @_;
	$param->{slashtopics} = $self->{slashtopics};
	$param->{stid}        = $self->{stid} || {};
	$param->{stcid}       = $self->{stcid} || {};

	for my $key (qw(stid stcid)) {
		$param->{"${key}_ordered"} = [
			map  { $_->[0] }
			sort { $b->[1] <=> $a->[1] }
			map  { [ $_, $param->{$key}{$_} ] }
			keys %{$param->{$key}}
		];
	}

	$self->{_template_options}{type} = 'ui' if
		!$self->{_template_options}{type} || $self->{_template_options}{type} !~ /^tree|js|css|ui(?:_\w+)?$/;

	my $template_name = sprintf('topic_popup_%s', $self->{_template_options}{type});
	my $nocomm = $self->{_template_options}{Nocomm} || 0;

	return slashDisplay($template_name, $param, { Return => 1, Page => 'admin', Nocomm => $nocomm });
}

# there's a little black spot on the sun today
{
	my $id = 1;
	no warnings 'redefine';
	sub HTML::PopupTreeSelect::next_id { $id++ }
	sub HTML::PopupTreeSelect::reset_id { $id = 1 }
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
