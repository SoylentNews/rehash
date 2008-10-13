# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Console;

=head1 NAME

Slash::Console - Perl extension for Console


=head1 SYNOPSIS

	use Slash::Console;


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Slash;
use Slash::Display;

use base 'Slash::Plugin';

our $VERSION = $Slash::Utility::VERSION;


sub ajaxConsoleUpdate {
	my($slashdb, $constants, $user, $form, $options) = @_;
	$options->{content_type} = 'application/json';
	my $html = {};
	my $admindb 	= getObject('Slash::Admin');
	$html->{'storyadmin-content'}	= $admindb->showStoryAdminBox("", { contents_only => 1});
	$html->{'performancebox-content'}	= $admindb->showPerformanceBox({ contents_only => 1});
	$html->{'authoractivity-content'}	= $admindb->showAuthorActivityBox({ contents_only => 1});
	$html->{'admintodo-wrap'}		= $admindb->showAdminTodo();
	if (my $tagsdb = getObject('Slash::Tags')) {
		$html->{'recenttagnames-content'} = $tagsdb->showRecentTagnamesBox({ contents_only => 1 });
	}
	return Data::JavaScript::Anon->anon_dump({
		html	=> 	$html
	});
}

sub consoleBoxes {
	my($self) = @_;
	my $admindb 	= getObject('Slash::Admin');
	my $storyadmin 	= $admindb->showStoryAdminBox("");
	my $perfbox	= $admindb->showPerformanceBox();
	my $authorbox	= $admindb->showAuthorActivityBox();
	my $admintodo	= $admindb->showAdminTodo();
	my $tagnamesbox = '';
	my $tags = getObject('Slash::Tags');
	if ($tags) {
		$tagnamesbox = $tags->showRecentTagnamesBox({ box_only => 1});
	}

	slashDisplay('console_boxes', {
		storyadmin 	=> $storyadmin,
		perfbox		=> $perfbox,
		authorbox	=> $authorbox,
		tagnamesbox	=> $tagnamesbox,
	}, { Return => 1});
	
}

1;

__END__


=head1 SEE ALSO

Slash(3).
