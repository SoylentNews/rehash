#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use File::Path;
use File::Temp;
use File::Copy;
use Slash::Constants ':slashd';

use strict;

use vars qw( %task $me $task_exit_flag );

$task{$me}{timespec} = '* * * * *';
$task{$me}{timespec_panic_1} = '* * * * *';
$task{$me}{timespec_panic_2} = '';
$task{$me}{on_startup} = 1;
$task{$me}{fork} = SLASHD_NOWAIT;
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user, $info, $gSkin) = @_;
	
	my $file_queue_cmds = [];
	my $cmd;
	while (!$task_exit_flag) {
		if(!@$file_queue_cmds) {
			$file_queue_cmds = $slashdb->getNextFileQueueCmds();
		}
		$cmd = shift @$file_queue_cmds;
		if($cmd) {
			handleFileCmd($cmd);
		}
		last if $task_exit_flag;
		sleep(10);
	}
};

sub handleFileCmd {
	my($cmd) = @_;
	my $slashdb = getCurrentDB();
	if ($cmd->{action} eq "upload") {
		uploadFile($cmd);
	}
	$slashdb->deleteFileQueueCmd($cmd->{fqid});
	if (verifyFileLocation($cmd->{file})) {
		unlink $cmd->{file};
	}
}

sub getStoryFileDir {
	my($sid) = @_;
	my $bd = getCurrentStatic("basedir");
	my $yearid  = substr($sid, 0, 2);
	my $monthid = substr($sid, 3, 2);
	my $dayid   = substr($sid, 6, 2);
	my $path = catdir($bd, "images", "articles", $yearid, $monthid, $dayid);
	return $path;
}

sub getFireHoseFileDir {
	my($fhid) = @_;
	my $bd = getCurrentStatic("basedir");
	my ($numdir) = sprintf("%09d",$fhid);
	my ($i,$j) = $numdir =~ /(\d\d\d)(\d\d\d)\d\d\d/;
	my $path = catdir($bd, "images", "firehose", $i, $j);
	return $path;
}

sub makeFileDir {
	my($dir) = @_;
	mkpath $dir, 0, 0775;
}

# verify any file we're copying or deleting meets our expectations
sub verifyFileLocation {
    my($file) = @_;
    return $file =~ /^\/tmp\/upload\/\w+(\.\w+)?$/
}

sub uploadFile {
	my($cmd) = @_;
	my @suffixlist = ();
	my $slashdb = getCurrentDB();
	my $story = $slashdb->getStory($cmd->{stoid});
	if ($story->{sid}) {
		my $destpath = getStoryFileDir($story->{sid});
		makeFileDir($destpath);
		my ($prefix) = $story->{sid} =~ /^\d\d\/\d\d\/\d\d\/(\d+)$/;
		
		my ($name,$path,$suffix) = fileparse($cmd->{file},@suffixlist);
	        ($suffix) = $name =~ /(\.\w+)$/;
		if (verifyFileLocation($cmd->{file})) {
			my $destfile = copyFileToLocation($cmd->{file}, $destpath, $prefix);
			my $name = fileparse($destfile);
			my $data = {
				stoid => $cmd->{stoid},
				name => $name
			};

			$slashdb->addStoryStaticFile($data);
		}

	}
	if ($cmd->{fhid}) {
		my $destpath = getFireHoseFileDir($cmd->{fhid});
		makeFileDir($destpath);
		my $numdir = sprintf("%09d",$cmd->{fhid});
		my ($prefix) = $numdir =~ /\d\d\d\d\d\d(\d\d\d)/;
		copyFileToLocation($cmd->{file}, $destpath, $prefix);
	}
}

sub copyFileToLocation {
	my ($srcfile,  $destpath, $prefix) = @_;
	slashdLog("$srcfile | $destpath | $prefix\n");
	my @suffixlist;
	my ($name,$path,$suffix) = fileparse($srcfile, @suffixlist);
	($suffix) = $name =~ /(\.\w+)$/;
	$suffix = lc($suffix);
	my $destfile;
	my $foundfile = 0;
	my $i = 1;
	my $ret_val = "";
	while(!$foundfile && $i < 20) {
		$destfile  = $destpath . "/". $prefix . "-$i" . $suffix;
		if (!-e $destfile) {
			$foundfile = 1;
		} else {
			$i++;
		}
	}
	if ($foundfile) {
		copy($srcfile, $destfile);
		$ret_val = $destfile;
	} else {
		slashdLog("Couldn't save file to dir - too many already exist");
	}
	return $ret_val;
}

1;
