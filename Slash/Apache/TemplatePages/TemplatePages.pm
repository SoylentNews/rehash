# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::Apache::TemplatePages;

use strict;
use Slash::Display;
use Slash::Utility;
use Apache::Constants qw(:common);
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# AMY: Leela's gonna kill me.
# BENDER: Naw, she'll probably have me do it.

sub handler {
	my($r) = @_;
	my $constants = getCurrentStatic();
	return NOT_FOUND unless dbAvailable();
	my $slashdb = getCurrentDB();
	my $page = $r->uri;
	$page =~ s|^/(.*)\.tmpl$|$1|;
	my $section = getCurrentForm('section');
	my $title = $slashdb->getTemplateByName('body', 'title', 1, $page, $section);
	if ($title) {
		header($title, $section) or return;
		my $display = slashDisplay('body', '', { Page => $page, Section => $section, Return => 1 });
		print $display;
		footer();
	} else {
		return NOT_FOUND;
	}

	return OK;
}


sub DESTROY { }

1;

__END__

=head1 NAME

Slash::Apache::TemplatePages - Handles logging for slashdot

=head1 SYNOPSIS

	use Slash::Apache::TemplatePages;

=head1 DESCRIPTION

Ever need to add pages to your site but hate dealing with shtml or don't want users 
to log in and do the editing from the files on disk? Welcome to template pages. Create
a page and then name it whatever you want it to be named. For instance, if you gave the
template a page name of "about" then the URL would be "/about.tmpl". The name of the
actual template has to be "body".

Anything you normally can do in a template can be done with one of these pages. 

The other caveat to using this is that you must provide a title for the template. This title will
be used by the system for the HTML title. If you do not provide a title then you will get a
404 when you try to access the page.

=head1 SEE ALSO

Slash(3), Slash::Display(3).

=cut
