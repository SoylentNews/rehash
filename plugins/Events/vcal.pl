#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

##################################################################
sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();

	#Yeah, I am being lazy and paranoid  -Brian
	if (!($user->{author} or $user->{is_admin}) and !$slashdb->checkStoryViewable($form->{sid})) {
		$story = '';
	} else {
		$story = $slashdb->getStory($form->{sid});
	}

	if ($story) {
		my $content = qq|BEGIN: VCALENDAR
TZ: PST
DTSTART: $story->{Begintime}
DTEND: $story->{Endtime}
SUMMARY: $story->{title}
DESCRIPTION;QUOTED-PRINTABLE: $story->{introtext}
URL: http://exploitseattle.com/article.pl?sid=$story->{sid}
UID: $story->{sid}
END: VEVENT
END: VCALENDAR
|;
		my $r = Apache->request;
		$r->header_out('Cache-Control', 'private');
		$r->content_type('text/x-vcalendar');
		$r->status(200);
		$r->send_http_header;
		$r->rflush;
		$r->print($content);
		$r->status(200);
		return 1;
	}

}

createEnvironment();
main();
1;
