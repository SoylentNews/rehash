# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Utility::Anchor;

=head1 NAME

Slash::Utility::Anchor - SHORT DESCRIPTION for Slash


=head1 SYNOPSIS

	use Slash::Utility;
	# do not use this module directly

=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Apache;
use Slash::Display;
use Slash::Utility::Data;
use Slash::Utility::Display;
use Slash::Utility::Environment;

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(
	header
	footer
	redirect
	ssiHead
	ssiFoot
	getAd
);

# really, these should not be used externally, but we leave them
# here for reference as to what is in the package
# @EXPORT_OK = qw(
# 	getSectionBlock
# 	getSectionColors
# );

#========================================================================

=head2 header([TITLE, SECTION, STATUS])

Prints the header for the document.

=over 4

=item Parameters

=over 4

=item TITLE

The title for the HTML document.  The HTML header won't
print without this.

=item SECTION

The section to handle the header.  This sets the
currentSection constant, too.

=item STATUS

A special status to print in the HTTP header.

=back

=item Return value

None.

=item Side effects

Sets currentSection constant.

=item Dependencies

The 'html-header' and 'header' template blocks.

=back

=cut

sub header {
	my($title, $section, $status, $noheader) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $adhtml = '';
	if (ref($title)) {
		$title->{title} ||= '';
	} else {
		$title ||= '';
		$title = { title => $title };
	}

	unless ($form->{ssi}) {
		my $r = Apache->request;

		$r->content_type('text/html');

		# Caching used to be Cache-Control: private but that doesn't
		# seem to be correct; let's hope switching to no-cache
		# causes few complaints.
		$r->header_out('Cache-Control', 'no-cache');
		# And while Pragma: no-cache is not really correct (it's
		# to be used for requests and the RFC doesn't define it to
		# mean anything for responses) it probably doesn't hurt
		# anything and allegedly has stopped users from complaining.
		$r->header_out('Pragma', 'no-cache')
			# This is here for historical reasons, my best guess
			# is that it's silly and unnecessary but I'm not
			# going to take it out and break stuff.
			unless $ENV{SCRIPT_NAME} =~ /comments/ || $user->{seclev} > 1;

# 		unless ($user->{seclev} || $ENV{SCRIPT_NAME} =~ /comments/) {
# 			$r->header_out('Cache-Control', 'no-cache');
# 		} else {
# 			$r->header_out('Cache-Control', 'private');
# 		}

		$r->send_http_header;
	}

	$user->{currentSection} = $section || '';
	getSectionColors();

	$title->{title} =~ s/<(.*?)>//g;

	# This is ALWAYS displayed. Let the template handle $title.
	slashDisplay('html-header', { title => $title->{title} }, { Nocomm => 1 })
		unless $noheader;

	# ssi = 1 IS NOT THE SAME as ssi = 'yes'
	if ($form->{ssi} eq 'yes') {
		ssiHead($section);
		return;
	}

	# if ($constants->{run_ads}) {
	#	$adhtml = getAd(1);
	# }

	slashDisplay('header', $title);

	print createMenu('admin') if $user->{is_admin};
	if ($constants->{admin_check_clearpass}
		&& ($user->{state}{admin_clearpass_thisclick} || $user->{admin_clearpass})
	) {
		if ($user->{currentPage} eq 'users'
			&& $form->{op} eq 'savepasswd') {
			# The user is trying to save a new password with this
			# very click. They may or may not succeed. Their admin
			# privs for this click were already taken away in
			# prepareUser() but just in case the savepasswd
			# succeeded, don't print the warning message this time.
		} else {
			print slashDisplay('data',
				{ value => 'clearpass-warning',
				  moreinfo => $user->{admin_clearpass} },
				{ Return => 1, Nocomm => 1, Page => 'admin' }
			);
		}
	}
}

#========================================================================

=head2 footer()

Prints the footer for the document.

=over 4

=item Return value

None.

=item Dependencies

The 'footer' template block.

=back

=cut

sub footer {
	my $form = getCurrentForm();

	if ($form->{ssi}) {
		ssiFoot();
		return;
	}

	slashDisplay('footer', {}, { Nocomm => 1 });
}

#========================================================================

=head2 redirect(URL)

Redirect browser to URL.

=over 4

=item Parameters

=over 4

=item URL

URL to redirect browser to.

=back

=item Return value

None.

=item Dependencies

The 'html-redirect' template block.

=back

=cut

sub redirect {
	my($url) = @_;
	$url = url2abs($url);
	my $r = Apache->request;

	$r->content_type('text/html');
	$r->header_out(Location => $url);
	$r->status(302);
	$r->send_http_header;

	slashDisplay('html-redirect', { url => $url });
}

#========================================================================

=head2 ssiHead()

Prints the head for server-parsed HTML pages.

=over 4

=item Return value

The SSI head.

=item Dependencies

The 'ssihead' template block.

=back

=cut

sub ssiHead {
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	(my $dir = $constants->{rootdir}) =~ s|^(?:https?:)?//[^/]+||;

	slashDisplay('ssihead', {
		dir	=> $dir,
		section => $user->{currentSection} ? "$user->{currentSection}/" : "",
	});
}

#========================================================================

=head2 ssiFoot()

Prints the foot for server-parsed HTML pages.

=over 4

=item Return value

The SSI foot.

=item Dependencies

The 'ssifoot' template block.

=back

=cut

sub ssiFoot {
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	(my $dir = $constants->{rootdir}) =~ s|^(?:https?:)?//[^/]+||;

	slashDisplay('ssifoot', {
		dir	=> $dir,
		section => $user->{currentSection} ? "$user->{currentSection}/" : "",
	});
}

########################################################
sub prepAds {

	# If invoked from a slashd task or from the command line in general,
	# just skip it since $user->{state}{ad} won't be used anyway, this
	# would just be a waste of time.  Store something in the field so
	# prepAds() doesn't get called again.
	my $user = getCurrentUser();
	if (!$ENV{SCRIPT_NAME}) {
		$user->{state}{ad} = { };
		return;
	}

	my $constants = getCurrentStatic();
	my $ad_messaging_num = $constants->{ad_messaging_num} || 6;
	my $ad_max = $constants->{ad_max} || $ad_messaging_num;
	my $ad_messaging_prob = $constants->{ad_messaging_prob} || 0.5;

	my $adless = 0;
	if ($constants->{subscribe}) {
		my $subscribe = getObject('Slash::Subscribe');
		$adless = 1 if $subscribe && $subscribe->adlessPage();
	}

	# $ENV{SCRIPT_NAME} is e.g. 1) "/index.pl", 2) "/article.pl",
	# 3) "/slashhead.inc", 4) "/articles/slashhead.inc",
	# 5) "/index.shtml", or 6) "/12/34/56/7890.shtml".  But prepAds()
	# will not be called for 5 or 6 because it will have already been
	# invoked by the ad header in 3 or 4 respectively.  And the
	# messaging ads are only relevant to 2, 4 and 6.  So we need to
	# be sure that messaging ads can be set up in {state}{ads} in
	# cases 2 or 4.  And since in case 4 we can't assume that the DB
	# is up, we have to treat any SCRIPT_NAME in the format
	# /foo/slashhead.inc as if "foo" is a valid section (so let's not
	# create /faq/slashhead.inc or there is mild potential for ad
	# confusion).  And cases 2 thru 6 depend on ssihead;misc;default
	# keeping its <!--#include--> line the same.
	my $use_messaging = 0;
	$use_messaging = 1 if !$adless
		&& $ENV{"AD_BANNER_$ad_messaging_num"}
		&& rand(1) < $ad_messaging_prob
		&& (
			(     $ENV{SCRIPT_NAME}			# case 2
			   && $ENV{SCRIPT_NAME} =~ m{\barticle\.pl\b}
			) || (
			      $ENV{SCRIPT_NAME}			# case 4
			   && $ENV{SCRIPT_NAME} =~ m{/(\w+)/slashhead\.inc$}
			)
		);
	# If it is desirable to only display messaging ads on article.pl
	# stories that have bodytext, here would be the place to do that
	# test.  It should just be a simple case of testing
	# length(getStory($form->{sid}, "bodytext")) since I believe
	# createCurrentForm() must always be called before getAds()
	# (haven't checked this).  That's not a cheap test since it will
	# do a decent-sized DB hit but that DB hit would have to be done
	# anyway and doing it here just gets it into the cache a little
	# earlier.  But it's not that easy.  Right now we can just dump
	# the <!--#perl--> line into every relevant place in .shtml files
	# (and .inc files) but if we start doing this, since getStory()
	# can't be called when the DB is down and shouldn't be called on
	# an .shtml page, dispStory;misc;default will have to know to
	# check [% story.bodytext %] and not call Slash.getAd()!

	for my $num (1..$ad_max) {
		my $use_this_ad = 1;
		# If we're showing a messaging ad, no other ads get shown.
		$use_this_ad = 0 if $use_messaging && $num != $ad_messaging_num;
		# If we're not showing a messaging ad, it doesn't get shown.
		$use_this_ad = 0 if !$use_messaging && $num == $ad_messaging_num;
		# If there's no ad here, it doesn't get shown obviously.
		$use_this_ad = 0 if !$ENV{"AD_BANNER_$num"};
		if ($use_this_ad) {
			$user->{state}{ad}{$num} = $ENV{"AD_BANNER_$num"};
		} elsif ($num == 1 && $ENV{AD_PAGECOUNTER}) {
			$user->{state}{ad}{$num} = $ENV{AD_PAGECOUNTER};
		} else {
			$user->{state}{ad}{$num} = "\n<!-- no ad $num -->\n";
		}
	}
}

########################################################
sub getAd {
	my($num, $log) = @_;
	$num ||= 1;
	my $user = getCurrentUser();

	unless ($ENV{SCRIPT_NAME}) {
		# When run from a slashd task (or from the command line in
		# general), don't generate the actual ad, just generate some
		# shtml code which *will* generate the actual ad when it's
		# executed later.
		$log = $log ? " Slash::createLog('$log');" : "";
		return <<EOT;
<!--#perl sub="sub { use Slash;$log print Slash::getAd($num); }" -->
EOT
	}

	# If this is the first time that getAd() is being called, we have
	# to set up all the ad data at once before we can return anything.
	prepAds() if !defined($user->{state}{ad});

	return $user->{state}{ad}{$num};
}


########################################################
# Gets the appropriate block depending on your section
# or else fall back to one that exists
sub getSectionBlock {
	my($name) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $thissect = $user->{light}
		? 'light'
		: $user->{currentSection};

	my $block;
	if ($thissect and ($thissect ne 'index')) {
		$block = $slashdb->getBlock("${thissect}_${name}", 'block');
	}

	$block ||= $slashdb->getBlock($name, 'block');
	return $block;
}


########################################################
# Sets the appropriate @fg and @bg color pallete's based
# on what section you're in.  Used during initialization
sub getSectionColors {
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my @colors;
	my $colorblock = getCurrentForm('colorblock');

	# they damn well better be legit
	if ($colorblock) {
		@colors = map { s/[^\w#]+//g ; $_ } split m/,/, $colorblock;
	} else {
		@colors = split m/,/, getSectionBlock('colors') || $constants->{colors};
	}

	$user->{fg} = [@colors[0..4]];
	$user->{bg} = [@colors[5..9]];
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

=head1 VERSION

$Id$
