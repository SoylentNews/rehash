# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::PollBooth;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants qw(:people :messages);
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION @EXPORT);
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

#Right, this is not needed at the moment but will be in the near future
sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'PollBooth'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub createAutoPollFromStory {
	my ($options) = @_;
	my $slashdb = getCurrentDB();
	my $story = $options->{story};
	my $qid = $slashdb->sqlSelect('qid', 'auto_poll', "section = '$story->{section}'");
	if ($qid) {
		my $question = $slashdb->getPollQuestion($qid, 'question');
		my $answers = $slashdb->getPollAnswers($qid, [ qw| answer | ]);
		my $newpoll = {
			section => $story->{section},
			topic => $story->{tid},
			question  => $question,
			autopoll => 'yes',
		};
		
		my $x =1;
		for (@$answers) {
			$newpoll->{'aid' . $x} = $_->[0];
			$x++;
		}
		my $qid = $slashdb->savePollQuestion($newpoll);
		$slashdb->setStory($story->{sid}, { qid => $qid, writestatus => 'dirty' });
	}

	return 1;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::PollBooth - PollBooth system splace

=head1 SYNOPSIS

	use Slash::PollBooth;

=head1 DESCRIPTION

This is a port of Tangent's journal system.

Blah blah blah.

=head1 AUTHOR

Brian Aker, brian@tangent.org

=head1 SEE ALSO

perl(1).

=cut
