# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Subscribe;

use strict;
use Slash;
use Slash::Utility;
use Slash::DB::Utility;

use vars qw($VERSION);

use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
        my($class) = @_;
        my $self = { };

	my $slashdb = getCurrentDB();
        my $plugins = $slashdb->getDescriptions('plugins');
        return unless $plugins->{Subscribe};

        bless($self, $class);

        return $self;
}

########################################################
# Internal.
sub _subscribeDecisionPage {
	my($self, $trueOnOther, $r) = @_;

        my $user = getCurrentUser();
	my $uid = $user->{uid} || 0;
        return 0 if !$user
                ||  !$uid
                ||   $user->{is_anon};

	return 0 if !$user->{hits_paidfor}
                || ( $user->{hits_bought}
			&& $user->{hits_bought} >= $user->{hits_paidfor} );

	my $decision = 0;
        $r ||= Apache->request;
        my $uri = $r->uri;
        if ($uri eq '/') {
                $uri = 'index';
        } else {
                $uri =~ s{^.*/([^/]+)\.pl$}{$1};
        }
	if ($uri =~ /^(index|article|comments)$/) {
		$decision = 1 if $user->{"buypage_$uri"};
	} elsif ($trueOnOther) {
		$decision = 1 if $user->{buypage_index}
			or $user->{buypage_article}
			or $user->{buypage_comments};
	}
	if (getCurrentStatic('subscribe_debug')) {
		print STDERR "_subscribeDecisionPage $trueOnOther $decision $user->{uid}"
			. " $user->{hits_bought} $user->{hits_paidfor}"
			. " uri '$uri'\n";
	}
	return $decision;
}

sub adlessPage {
	my($self, $r) = @_;
	return $self->_subscribeDecisionPage(1, $r);
}

sub buyingThisPage {
	my($self, $r) = @_;
	return $self->_subscribeDecisionPage(0, $r);
}

1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Subscribe - Let users buy adless pages

=head1 SYNOPSIS

	use Slash::Subscribe;

=head1 DESCRIPTION

This plugin lets users purchase adless pages at /subscribe.pl.

Understanding its code will be easier after recognizing that one of its
design goals was to distinguish the act of "paying for" adless pages,
in which money (probably) trades hands, from the act of "buying," in
which adless pages are actually viewed.  After "paying for" a page, you
can still get your money back, but after you "bought" it, no refund.

=head1 AUTHOR

Jamie McCarthy, jamie@mccarthy.vg

=head1 SEE ALSO

perl(1).

=cut
