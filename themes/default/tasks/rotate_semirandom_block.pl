#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;

use Slash::Constants ':slashd';

use vars qw( %task $me );

$task{$me}{timespec} = '0-59/5 * * * *';
$task{$me}{timespec_panic_1} = ''; # not that important
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {

        my($virtual_user, $constants, $slashdb, $user) = @_;
        
        my @choices = qw/askslashdot developers interview science yro firehose topcomments books activetags idle_pics idle_video/;
        my $choice;
        my $lastchoice = $slashdb->getVar('lastsrandsec', 'value', 1);
       
        do { $choice = $choices[int(rand(scalar @choices))]; } while ($choice eq $lastchoice);

        $slashdb->setVar('lastsrandsec', $choice);
        my $title = ucfirst($choice);

	my $url = '';

        if ($choice eq 'askslashdot') { $title = 'Ask Slashdot'; $url = "//ask.slashdot.org" }
        if ($choice eq 'interview')   { $title = 'Interviews';   $url = "//interviews.slashdot.org" }
        if ($choice eq 'bsd')         { $title = 'BSD';          $url = "//bsd.slashdot.org" }
        if ($choice eq 'science')     { $title = 'Science';      $url = "//science.slashdot.org" }
        if ($choice eq 'yro')         { $title = 'YRO';          $url = "//yro.slashdot.org" }
        if ($choice eq 'firehose')    { $title = 'Firehose';     $url = "//slashdot.org/firehose/" }
        if ($choice eq 'topcomments') { $title = 'Hot Comments'; $url = '' }
        if ($choice eq 'books')       { $title = 'Book Reviews'; $url = "//books.slashdot.org"}
        if ($choice eq 'activetags')  { $title = 'Recent Tags';  $url = "/tags" }
        if ($choice eq 'idle_video')  { $title = 'Idle Video';   $url = "//idle.slashdot.org" }
        if ($choice eq 'idle_pics')   { $title = 'Idle Pics';    $url = "//idle.slashdot.org" }

        $slashdb->sqlUpdate("blocks",{ block=>$slashdb->getBlock($choice, 'block'), title => $title, url => $url }, "bid='srandblock'");

	my $dynamic_blocks = getObject("Slash::DynamicBlocks");
        $dynamic_blocks->syncPortalBlocks('srandblock') if $dynamic_blocks;
        
	return ;
};

1;

