# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Apache::TemplatePages;

use strict;
use Slash::Display;
use Slash::Utility;
use Apache::Constants qw(:common);

our $VERSION = $Slash::Constants::VERSION;

# AMY: Leela's gonna kill me.
# BENDER: Naw, she'll probably have me do it.

sub handler {
	my($r) = @_;
	my $constants = getCurrentStatic();
	return NOT_FOUND unless dbAvailable();
	my $slashdb = getCurrentDB();
	my $page = $r->uri;
	$page =~ s|^/(.*)\.tmpl$|$1|;
	my $skin = getCurrentSkin('name');
	my $title = $slashdb->getTemplateByName('body', {
		values          => 'title',
		cache_flag      => 1,
		page            => $page,
		skin            => $skin
	});
	if ($title) {
		header($title, $skin) or return;
		my $display = slashDisplay('body', '', { Page => $page, Skin => $skin, Return => 1 });
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
