# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
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
use Apache::Constants ':http';
use Digest::MD5 'md5_hex';
use Slash::Display;
use Slash::Utility::Data;
use Slash::Utility::Display;
use Slash::Utility::Environment;

use base 'Exporter';
use vars qw($VERSION @EXPORT);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;
@EXPORT	   = qw(
	http_send
	header
	footer
	redirect
	ssiHeadFoot
	prepAds
	getAd
);

# really, these should not be used externally, but we leave them
# here for reference as to what is in the package
# @EXPORT_OK = qw(
# 	getSectionBlock
# 	getSectionColors
# );

#========================================================================

=head2 header([DATA, SECTION, OPTIONS])

Prints the header for the document.

=over 4

=item Parameters

=over 4

=item DATA

If a plain scalar, the title for the HTML document.  The HTML header won't
print without this.  You can also pass in a hashref, with "title" as one
key, and any other variables you want passed to the header template.

=item SECTION

The section to handle the header.  This sets the
currentSection constant, too.

=item OPTIONS

A Hash with different options (it includes the abiltity to pass along
slashDisplay() parameters).

=back

=item Return value

None, unless the Return option has value. In this case it will return
the output instad of printing standard out.

=item Side effects

Sets currentSection constant.

=item Dependencies

The 'html-header' and 'header' template blocks.

=back

=cut

sub header {
	my($data, $section, $options) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $adhtml = '';
	my $display;
	$data = { title => $data } unless ref($data) eq 'HASH';
	$data->{title} = strip_notags($data->{title} || '');

	unless ($form->{ssi}) {
		my $r = Apache->request;

		$r->content_type($constants->{content_type_webpage}
			|| $options->{content_type}
			|| 'text/html');

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
		return if $r->header_only;
	}

	$user->{currentSection} = $section || $constants->{section};
	getSectionColors();

	# This is ALWAYS displayed. Let the template handle title.
	my $template_vars = { title => $data->{title} };
	$template_vars->{meta_desc} = $options->{meta_desc} if $options->{meta_desc};
	slashDisplay('html-header', $template_vars, { Nocomm => 1,  Return => $options->{Return}, Page => $options->{Page} })
		unless $options->{noheader};

	$user->{state}{mt}{curcol} = 0;
	$user->{state}{mt}{currow} = 0;
	$user->{state}{mt}{cols} = [ ];

	# ssi = 1 IS NOT THE SAME as ssi = 'yes'
	# ...which is silly. - Jamie 2002/06/26
	if ($form->{ssi} && $form->{ssi} eq 'yes') {
		ssiHeadFoot('header', $section, $options);
		# Since $form->{ssi} is set by freshenup.pl, we're being run
		# from a task.  We do want to generate the rest of the page,
		# so return true.
		return 1;
	}

	# if ($constants->{run_ads}) {
	#	$adhtml = getAd(1);
	# }

	# figure out which admin menu to display and which
	# tab to highlight
	$data->{adminmenu} = $options->{adminmenu} || 'admin';
	# Should we also pass thru {page} here or is that outdated?
#print STDERR "header(options->page) defined: '$options->{page}' for title '$data->{title}'\n" if defined($options->{page});
	$data->{tab_selected} = $options->{tab_selected} if $options->{tab_selected};

	if ($options->{admin} && $user->{is_admin}) {
		$user->{state}{adminheader} = 1;
		$display = slashDisplay('header-admin', $data, { Return => $options->{Return}, Page => $options->{Page} });
	} else {
		$display = slashDisplay('header', $data, { Return => $options->{Return}, Page => $options->{Page} });
	}

	# I bet someday we end up with an SSI bug from this -Brian
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
	
	return $display;
}

#========================================================================

=head http_send(OPTIONS)

Prints an HTTP header like L<header>, but more generic, and then optionally
prints content.

=over 4

=item Parameters

=item OPTIONS

=back

=item Return value

True upon success, false upon failure.

=back

=cut

sub http_send {
	my($opt) = @_;

	$opt->{status}        ||= HTTP_OK;
	$opt->{content_type}  ||= 'text/plain';
	$opt->{cache_control} ||= 'private'  unless defined $opt->{cache_control};
	$opt->{pragma}        ||= 'no-cache' unless defined $opt->{pragma};

	my $r = Apache->request;
	$r->content_type($opt->{content_type});
	$r->header_out('Cache-Control', $opt->{cache_control}) if $opt->{cache_control};
	$r->header_out('Pragma', $opt->{pragma}) if $opt->{pragma};

	if ($opt->{etag} || $opt->{do_etag}) {
		if ($opt->{do_etag} && $opt->{content}) {
			$opt->{etag} = md5_hex($opt->{content});
		}
		$r->header_out('ETag', $opt->{etag});

		my $match = $r->header_in('If-None-Match');
		if ($match && $match eq $opt->{etag}) {
			$r->status(HTTP_NOT_MODIFIED);
			$r->send_http_header;
			return 1;
		}
	}

	if ($opt->{filename}) {
		$opt->{filename} =~ s/[^\w_.-]/_/g;
		my $val = "filename=$opt->{filename}";
		$val = "attachment; $val" if $opt->{attachment};
		$r->header_out('Content-Disposition', $val);
	}

	$r->status($opt->{status});
	$r->send_http_header;
	$r->rflush;
	return 1 if $r->header_only;

	if ($opt->{content}) {
		print $opt->{content};
		$r->rflush;
	}

	return 1;
}



#========================================================================

=head2 footer(OPTIONS)

Prints the footer for the document.

=over 4

=item Parameters

=over 4

=item OPTIONS

Collection of options that can be used to change the behavior of templates

=back

=item Return value

None, unless the Return option has value. In this case it will return the
output instad of printing standard out.

=item Dependencies

The 'footer' template block.

=back

=cut

sub footer {
	my($options) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $display;

        if ($form->{ssi} && $form->{ssi} eq 'yes') {
		my $section = $user->{currentSection} || $constants->{section};
                ssiHeadFoot('footer', $section, $options);
                return 1;
        }

	if ($user->{state}{adminheader}) {
		$display = slashDisplay('footer-admin', '', { Return => $options->{Return}, Page => $options->{Page} });
	} else {
		$display = slashDisplay('footer', '', { Return => $options->{Return}, Page => $options->{Page} });
	}
	
	return $display;
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
	my $constants = getCurrentStatic();
	$url = url2abs($url);
	my $r = Apache->request;

	$r->content_type($constants->{content_type_webpage} || 'text/html');
	$r->header_out(Location => $url);
	$r->status(302);
	$r->send_http_header;

	slashDisplay('html-redirect', { url => $url });
}

#========================================================================

=head2 ssiHeadFoot()

Prints the head for server-parsed HTML pages.

=over 4

=item Return value

The SSI head.

=item Dependencies

The 'ssihead' template block.

=back

=cut

sub ssiHeadFoot {
	my($headorfoot, $section, $options) = @_;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	my $slashdb = getCurrentDB();
	(my $dir = $constants->{rootdir}) =~ s|^(?:https?:)?//[^/]+||;
#	my $hostname = $slashdb->getSection($user->{currentSection}, 'hostname')
#		if $user->{currentSection};
	my $page = $options->{Page} || $user->{currentPage} || 'misc';

	# if there's a special .inc header for this page, use it, else it's
	# business as usual.
	$page = '' unless ($page ne 'misc' && $slashdb->existsTemplate({
		name    => $headorfoot,
	        section => $user->{currentSection},
	        page    => $user->{currentPage} }));

	my $ssiheadorfoot = 'ssi' . substr($headorfoot, 0, 4);

	slashDisplay($ssiheadorfoot, {
		dir	=> $dir,
		section => $user->{currentSection} ? "$user->{currentSection}/" : "",
		page    => $page,
	}, { Return => $options->{Return}, Page => $options->{Page} });
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
	# Again, short-circuit if possible.
	if (!$constants->{run_ads}) {
		$user->{state}{ad} = { };
		return;
	}

	my $ad_messaging_num = $constants->{ad_messaging_num} || 6;
	my $ad_max = $constants->{ad_max} || $ad_messaging_num;
	my $ad_messaging_prob = $constants->{ad_messaging_prob} || 0.5;

	my $adless = $user->{state}{page_adless} ? 1 : 0;

	# Let's lay out some representative possibilities so we
	# get the logic right:
	#
	# case	messads ok?	$ENV{SCRIPT_NAME}	$ENV{REQUEST_URI}
	# 1	no		/index.pl		/
	# 2	no		/index.pl		/index.pl
	# 3	yes		/article.pl		/article.pl
	# 4	no		/slashhead.inc		/
	# 5	no		/slashhead.inc		/index.shtml
	# 6	no		/slashhead.inc		/faq/foo.shtml (or similar)
	# 7	yes		/articles/slashhead.inc	/articles/12/34/56/7890.shtml
	# 8	no		/articles/slashhead.inc	/articles/
	# 9	no		/articles/slashhead.inc	/articles/index.shtml
	# 10	n/a		/index.shtml		/
	# 11	n/a		/index.shtml		/index.shtml
	# 12	n/a		/faq/foo.shtml		/faq/foo.shtml
	#
	# Cases 8 thru 10 (and many others similar) don't matter, since
	# prepAds() will be called in their .inc header, so the
	# decision will be made in cases 4, 5 and 6.
	#
	# Note that distinguishing 6 from 7 is nontrivial:  we can't tell
	# the difference between "faq" and "articles", since we can't
	# rely on the DB being available at this stage.  Any alphanumeric
	# first-level directory may be a valid section name.  And we
	# don't want to limit ourselves by looking for the "12/34/56"
	# subdirectories within genuine article directories, that gets
	# hackish very fast.  What we *can* do is assume that case 6
	# and case 7 will continue to be distinguished by 6's use of
	# the root-level /slashhead.inc and 7's use of section-specific
	# /articles/slashhead.inc.  So if e.g. /faq/slashhead.inc is
	# created in future, this logic will need to be revisited.
	#
	# Note also that this logic depends on ssihead;misc;default
	# keeping its <!--#include--> line the same.

	my $use_messaging = 0;
	$use_messaging = 1 if !$adless
		&& $ENV{"AD_BANNER_$ad_messaging_num"}
		&& rand(1) < $ad_messaging_prob
		&& $ENV{SCRIPT_NAME}
		&& $ENV{REQUEST_URI}
		&& $ENV{REQUEST_URI} !~ m{\bindex\.\b}	# disable case 9 (also 2,5)
		&& $ENV{REQUEST_URI} !~ m{/$}		# disable case 8 (also 1,4,10)
		&& (
				# enable case 3
			   $ENV{SCRIPT_NAME} =~ m{\barticle\.pl\b}
				# enable cases 7,8,9 (but 8,9 eliminated above)
			|| $ENV{SCRIPT_NAME} =~ m{/(\w+)/slashhead\.inc$}
		);
	my $section = "(n/a)";
	my $form;
	if ($use_messaging
		&& $constants->{ad_messaging_sections}
		&& ref($constants->{ad_messaging_sections}) eq 'HASH'
		&& %{$constants->{ad_messaging_sections}}
		&& ($form = getCurrentForm())
		&& $form->{sid}
	) {
		my $slashdb;
		if ($slashdb = getCurrentDB()) {
			# DB available and the form includes "sid=01/23/45/6789"
			# or "sid=12345".  Query the DB about which section that
			# sid belongs to, and if it's not one where we want to
			# deliver messaging ads, turn off that possibility.
			# That's all cached of course.
			if ($form->{sid} !~ /^\d+$/) {
				my $story = $slashdb->getStory($form->{sid});
				$section = $story->{section};
			} else {
				my $discussion = $slashdb->getDiscussion($form->{sid});
				$section = $discussion->{section};
			}
			$use_messaging = 0 if !$constants->{ad_messaging_sections}{$section};
		} else {
			# DB is unavailable, no ads.  (We must have been called
			# from a <!--#perl--> line in an .inc or .shtml file.)
			$use_messaging = 0;
		}
	}
	if ($constants->{ad_debug}) {
		print STDERR join(" ",
			"use_messaging '$use_messaging'",
			"adless '$adless' num '$ad_messaging_num'",
			"banlength '" . length($ENV{"AD_BANNER_$ad_messaging_num"}) . "'",
			"prob '$ad_messaging_prob'",
			"section '$section'",
			"ad_m_s{section} '$constants->{ad_messaging_sections}{$section}'",
			"SCRIPT_NAME '$ENV{SCRIPT_NAME}'",
			"REQUEST_URI '$ENV{REQUEST_URI}'\n"
		);
	}

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
		# Subscriber?  No ads.
		$use_this_ad = 0 if $adless;
		# If we're showing a messaging ad, no other ads get shown.
		$use_this_ad = 0 if $use_messaging && $num != $ad_messaging_num;
		# If we're not showing a messaging ad, it doesn't get shown.
		$use_this_ad = 0 if !$use_messaging && $num == $ad_messaging_num;
		# If there's no ad here, it doesn't get shown obviously.
		# But if we're testing, assume there could be ads everywhere.
		if (!$constants->{debug_adtext}) {
			$use_this_ad = 0 if !$ENV{"AD_BANNER_$num"};
		}
		if ($use_this_ad) {
			if ($constants->{debug_adtext}) {
				$user->{state}{ad}{$num} = "\n<FONT SIZE=\"+3\" COLOR=\"#888888\">AD $num HERE</FONT>\n";
			} else {
				$user->{state}{ad}{$num} = $ENV{"AD_BANNER_$num"};
			}
		} elsif ($num == 1 && $ENV{AD_PAGECOUNTER}) {
			if ($constants->{debug_adtext}) {
				$user->{state}{ad}{$num} = "\n<FONT SIZE=\"+2\" COLOR=\"#888888\">PAGECOUNTER</FONT>\n";
			} else {
				$user->{state}{ad}{$num} = $ENV{AD_PAGECOUNTER};
			}
		} else {
			if ($constants->{debug_adtext}) {
				$user->{state}{ad}{$num} = "\n<FONT SIZE=\"+3\" COLOR=\"#888888\">no ad $num here</FONT>\n";
			} else {
				$user->{state}{ad}{$num} = "\n<!-- no ad $num -->\n";
			}
		}
	}
}

########################################################
sub getAd {
	my($num, $need_box) = @_;
	$num ||= 1;
	$need_box ||= 0;
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	# sometimes, when this is called from shtml, the section is not
	# in $user like we'd like it to be. This attempts to remedy this.
	# 					--Pater
	$user->{currentSection} = $constants->{static_section} if $user->{currentSection} eq '';

	unless ($ENV{SCRIPT_NAME}) {
		# When run from a slashd task (or from the command line in
		# general), don't generate the actual ad, just generate some
		# shtml code which *will* generate the actual ad when it's
		# executed later.
		return <<EOT;
<!--#perl sub="sub { use Slash; print Slash::getAd($num, $need_box); }" -->
EOT
	}

	# If this is the first time that getAd() is being called, we have
	# to set up all the ad data at once before we can return anything.
	if (!defined $user->{state}{ad}) {
		if ($constants->{use_minithin} && $constants->{plugin}{MiniThin}) {
			# new way
			my $minithin = getObject('Slash::MiniThin', { db_type => 'reader' });
			$minithin->minithin;
		} else {
			# old way
			prepAds();
		}
	}

	if ($num == 2 && $need_box) {
		# we need the ad wrapped in a fancybox
		if (defined $user->{state}{ad}{$num}
			&& $user->{state}{ad}{$num} !~ /^<!-- no pos/
			&& $user->{state}{ad}{$num} !~ /^<!-- place/) {
			# if we're called from shtml, we won't have colors
			# set, so we should get some set before making a
			# box.				-- Pater
			getSectionColors() unless $user->{bg};

			return fancybox($constants->{fancyboxwidth}, 'Advertisement', "<CENTER>" . $user->{state}{ad}{$num} . "</CENTER>", 1, 1);
		} else { return ""; }
	} else {
		return $user->{state}{ad}{$num} || "";
	}
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
	if ($thissect && $thissect ne 'index') {
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

	my $n_colors = scalar(@colors);
	$user->{fg} = [@colors[0..$n_colors/2-1]];
	$user->{bg} = [@colors[$n_colors/2..$n_colors-1]];
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::Utility(3).

=head1 VERSION

$Id$
