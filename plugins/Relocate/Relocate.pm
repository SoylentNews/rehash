# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Relocate;

use strict;
use DBIx::Password;
use Slash;
use Slash::Utility;
use HTML::TokeParser ();
use Digest::MD5 'md5_hex';

use vars qw($VERSION);
use base 'Slash::DB::Utility';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Relocate'};

	my $self = bless({}, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;
	$self->{'_table'} = "links";
	$self->{'_prime'} = "id";

	return $self;
}

sub create {
	my($self, $values) = @_;
	my $table = $self->{'_table'};
	my $prime = $self->{'_prime'};

	my $id = md5_hex($values->{url});

	my $where = "$prime='$id'";

	my $found  = $self->sqlSelect($prime, $table, $where);
	if (!$found) {
		$values->{$prime} = $id;
		$self->sqlInsert($table, {
				id => $id,
				-last_seen => 'now()',
				url => $values->{url},
				});
	}

	if ($values->{sid}) {
		my $where = "$prime='$id' AND sid='$values->{sid}'";
		my $found  = $self->sqlSelect($prime, 'links_for_stories', $where);
		$self->sqlInsert('links_for_stories', {
				id => $id,
				sid => $values->{sid},
				}) unless $found;
	}

	return $id ;
}

sub getStoriesForLinks {
	my ($self) = @_;
	$self->sqlSelectAllHashrefArray('*', 'links_for_stories', '', "ORDER BY sid");
}

#========================================================================
sub href2SlashTag {
	my($self, $text, $sid, $options) = @_;
	my $user = getCurrentUser();
	return $text unless $text && $sid;
	my $tokens = HTML::TokeParser->new(\$text);
	if ($tokens) {
		while (my $token = $tokens->get_tag(qw| a slash |)) {
			# Go on and test to see if URL's have changed
			if ($token->[0] eq 'slash') {
				#Skip non HREF links
				next unless $token->[1]->{href};
				if (!$token->[1]->{id}) {
					my $link = $self->create({ sid => $sid, url => $token->[1]->{href}});
					my $href = strip_attribute($token->[1]->{href});
					my $title = strip_attribute($token->[1]->{title});
					$text =~ s#\Q$token->[3]\E#<SLASH HREF="$href" ID="$link" TITLE="$title" TYPE="LINK">#is;
				} else {
					my $url = $self->get($token->[1]->{id}, 'url');
					next if $url eq $token->[1]->{href};
					my $link = $self->create({ sid => $sid, url => $token->[1]->{href}});
					my $href = strip_attribute($token->[1]->{href});
					my $title = strip_attribute($token->[1]->{title});
					$text =~ s#\Q$token->[3]\E#<SLASH HREF="$href" ID="$link" TITLE="$title" TYPE="LINK">#is;
				}
			# New links to convert!!!!
			} else {
				# We ignore some types of href
				next if $token->[1]->{name};
				next if $token->[1]->{href} eq '__SLASHLINK__';
				next if ($token->[1]->{href} =~ /^mailto/i);
				#This allows you to have a link bypass this system
				next if ($token->[1]->{FORCE} && $user->{is_admin});
				my $link = $self->create({ sid => $sid, url => $token->[1]->{href}});
				my $data = $tokens->get_text("/a");
				my $href = strip_attribute($token->[1]->{href});
				my $title = strip_attribute($token->[1]->{title});
				$text =~ s#\Q$token->[3]$data</a>\E#<SLASH HREF="$href" ID="$link" TITLE="$title" TYPE="LINK">$data</SLASH>#is;
			}
		}
	}

	return $text;
}


sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Relocate - Relocate system splace

=head1 SYNOPSIS

	use Slash::Relocate;

=head1 DESCRIPTION

This is a port of Tangent's journal system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut
