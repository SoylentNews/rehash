# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
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
# Called during an Apache request.  If the caller happens to have
# Apache->request already, pass it in and it'll be used, otherwise
# it'll just be generated.
sub buyingThisPage {
	my($self, $r) = @_;

        my $user = getCurrentUser();
        return 0 if !$user
                ||  !$user->{uid}
                ||   $user->{is_anon}
                ||  !$user->{hits_paidfor}
                || ( $user->{hits_bought}
			&& $user->{hits_bought} >= $user->{hits_paidfor} );

	if ($user->{"boughtpage_ALL"}) {
		if (getCurrentStatic('subscribe_debug')) {
			print STDERR "buyingThisPage $user->{uid} $user->{hits_bought} $user->{hits_paidfor} ALL\n";
		}
		return 1;
	}

        $r ||= Apache->request;
        my $uri = $r->uri;
        if ($uri eq '/') {
                $uri = 'index';
        } else {
                $uri =~ s{^.*/([^/]+)\.pl$}{$1};
        }
        if ($user->{"boughtpage_$uri"}) {
		if (getCurrentStatic('subscribe_debug')) {
			print STDERR "buyingThisPage $user->{uid} $user->{hits_bought} $user->{hits_paidfor} uri '$uri'\n";
		}
                return 1;
        }

        return 0;
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
