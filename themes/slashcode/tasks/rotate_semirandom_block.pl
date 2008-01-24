#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '0-59/5 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

        my($virtual_user, $constants, $slashdb, $user) = @_;
        
        my @choices = qw/askslashdot developers interview science yro firehose topcomments books activetags/;
        my $choice;
        my $lastchoice = $slashdb->getVar('lastsrandsec', 'value', 1);
       
        do { $choice = $choices[int(rand(scalar @choices))]; } while ($choice eq $lastchoice);

        $slashdb->setVar('lastsrandsec', $choice);
        my $title = ucfirst($choice);

        my $url = "http://slashdot.org/index.pl?section=$choice";

        if ($choice eq 'askslashdot') { $title = 'Ask Slashdot'; }
        if ($choice eq 'interview')   { $title = 'Interviews'; }
        if ($choice eq 'bsd')         { $title = 'BSD'; }
        if ($choice eq 'yro')         { $title = 'YRO'; }
        if ($choice eq 'firehose')    { $title = 'Firehose'; $url = "http://slashdot.org/firehose/" }
        if ($choice eq 'topcomments') { $title = 'Hot Comments'; $url = '' }
        if ($choice eq 'books')       { $title = 'Book Reviews'; }
        if ($choice eq 'activetags')  { $title = 'Recent Tags'; $url = "/tags" }

        $slashdb->sqlUpdate("blocks",{ block=>$slashdb->getBlock($choice, 'block'), title=>$title, url=> $url }, "bid='srandblock'");
        
	return ;
};

1;

