# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
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
sub getAd {
	my($num, $log) = @_;
	$num ||= 1;

	my $subscribe = getObject('Slash::Subscribe');
	if ($subscribe and $subscribe->buyingThisPage()) {
		return "\n<!-- subscriber, no ad -->\n";
	}

	unless ($ENV{SCRIPT_NAME}) {
		$log = $log ? " Slash::createLog('$log');" : "";
		return <<EOT;
<!--#perl sub="sub { use Slash;$log print Slash::getAd($num); }" -->
EOT
	}

	return $ENV{"AD_BANNER_$num"};
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
