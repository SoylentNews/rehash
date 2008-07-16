#!/usr/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use File::Path;
use File::Temp;
use File::Copy;
use Image::Size;
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

	if (!$constants->{imagemagick_convert}) {
		slashdLog("no imagemagick convert location specified, exiting");
	}
	
	my $file_queue_cmds = [];
	my $cmd;
	while (!$task_exit_flag) {
		if(!@$file_queue_cmds) {
			$file_queue_cmds = $slashdb->getNextFileQueueCmds();
		}
		$cmd = shift @$file_queue_cmds;
		if ($cmd) {
			if ($cmd->{blobid}) {
				$cmd->{file} = blobToFile($cmd->{blobid});
			}
			if ($cmd->{action} eq 'upload' && $cmd->{file} =~ /\.(jpg|gif|png)/i) {
				$cmd->{action} = "thumbnails";
			}
			handleFileCmd($cmd);
		}
		last if $task_exit_flag;
		sleep(10);
	}
};

sub handleFileCmd {
	my($cmd) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $convert = $constants->{imagemagick_convert};

	if ($cmd->{action} eq "thumbnails") {
		slashdLog("Creating Thumbnails");
		my $files = uploadFile($cmd);
		$files ||= [];
		slashdLog("after upload file");
		foreach (@$files) {
			slashdLog("thumbing $_");
			my ($name, $path) = fileparse($_);
			my ($namebase, $suffix) = $name =~ /^(\w+\-\d+)\.(\w+)$/;
			my $thumb = $namebase . "-thumb." . $suffix;
			my $thumbsm = $namebase . "-thumbsm." . $suffix;
			my $thumblg = $namebase . "-thumblg." . $suffix;

			slashdLog("About to create thumb $path$thumb");
			system("$convert -size 260x194  $path$name  -resize '130x97>'  -bordercolor transparent  -border 48 -gravity center -crop 130x97+0+0 -page +0+0 -colors 256 -depth 8 -compress BZip $path$thumb");
			my $data = {
				stoid => $cmd->{stoid} || 0,
				fhid  => $cmd->{fhid} || 0 ,
				name => "$path$thumb"
			};
			my $sfid = addFile($data);

			if ($cmd->{fhid}) {
				my $firehose = getObject("Slash::FireHose");
				if ($firehose) {
					$firehose->setFireHose($cmd->{fhid}, { thumb => $sfid });
				}
			}

			slashdLog("About to create thumbsms $path$thumbsm");
			system("$convert -size 100x74 $path$name  -resize '50x37>'  -bordercolor transparent -border 18 -gravity center -crop 50x37+0+0 -page +0+0 -colors 256 -depth 8 -compress BZip $path$thumbsm");
			$data = {
				stoid => $cmd->{stoid} || 0,
				fhid  => $cmd->{fhid} || 0,
				name => "$path$thumbsm"
			};
			addFile($data);

			slashdLog("About to create thumblg $path$thumblg");
			system("$convert $path$name  -resize '425x344>' -colors 256 -depth 8 -compress BZip $path$thumblg");
			$data = {
				stoid => $cmd->{stoid} || 0,
				fhid  => $cmd->{fhid} || 0,
				name => "$path$thumblg"
			};
			addFile($data);
		}
	}
	if ($cmd->{action} eq "upload") {
		slashdLog("handling upload\n");
		uploadFile($cmd);
	}
	$slashdb->deleteFileQueueCmd($cmd->{fqid});
	if (verifyFileLocation($cmd->{file})) {
		# unlink $cmd->{file};
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

sub blobToFile {
	my($blobid) = @_;
	my $blob = getObject("Slash::Blob");
	my $blob_ref = $blob->get($blobid);
	my($suffix) = $blob_ref->{filename} =~ /(\.\w+$)/;
	$suffix = lc($suffix);
	my ($ofh, $tmpname) = mkstemps("/tmp/upload/fileXXXXXX", $suffix );
	slashdLog("Writing file data to $tmpname\n");
	print $ofh $blob_ref->{data};
	close $ofh;
	$blob->delete($blobid);
	return $tmpname;
}

sub uploadFile {
	my($cmd) = @_;
	my @suffixlist = ();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $convert = $constants->{imagemagick_convert};

	my $story = $slashdb->getStory($cmd->{stoid});
	my @files;

	my $file = $cmd->{file};
	if ($file =~ /\.(gif|jpg)$/i) {
		my $filepng = $file;
		$filepng =~s /\.(gif|jpg)$/\.png/;
		if ($convert) {
			system("$convert $file $filepng");
		}
		$file = $filepng;
	}

	if ($story->{sid}) {
		my $destpath = getStoryFileDir($story->{sid});
		makeFileDir($destpath);
		my ($prefix) = $story->{sid} =~ /^\d\d\/\d\d\/\d\d\/(\d+)$/;
		
		my ($name,$path,$suffix) = fileparse($file,@suffixlist);
	        ($suffix) = $name =~ /(\.\w+)$/;
		if (verifyFileLocation($file)) {
			my $destfile = copyFileToLocation($file, $destpath, $prefix);
			push @files, $destfile if $destfile;
			my $name = fileparse($destfile);
			my $data = {
				stoid => $cmd->{stoid} || 0,
				fhid => $cmd->{fhid} || 0,
				name => "$destpath/$name"
			};

			addFile($data);
		}


	}
	if ($cmd->{fhid}) {
		my $destpath = getFireHoseFileDir($cmd->{fhid});
		makeFileDir($destpath);
		my $numdir = sprintf("%09d",$cmd->{fhid});
		my ($prefix) = $numdir =~ /\d\d\d\d\d\d(\d\d\d)/;
		if (verifyFileLocation($file)) {
			my $destfile = copyFileToLocation($file, $destpath, $prefix);
			my $name = fileparse($destfile);
			push @files, $destfile if $destfile;
			my $data = {
				stoid => $cmd->{stoid} || 0,
				fhid => $cmd->{fhid} || 0,
				name => "$destpath/$name"
			};
			slashdLog("Add firehose item: $data->{name}");
			addFile($data);
		}
	}
	return \@files;
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

sub addFile {
	my($data) = @_;
	print "Add story file\n";
	my $slashdb = getCurrentDB();
	slashdLog("addFile $data->{name}");
	if ($data->{name} =~ /\.(png|gif|jpg)$/i) {
		($data->{width}, $data->{height}) = imgsize("$data->{name}");
		slashdLog("addFile $data->{width} $data->{height}");
	}
	return $slashdb->addStaticFile($data);
}

1;
