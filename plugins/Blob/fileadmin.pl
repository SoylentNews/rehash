#!/usr/bin/perl -w

use strict;
use Slash;
use Slash::Display;
use Slash::Blob;
use Slash::Utility;

sub main {
	my $slashdb   = getCurrentDB();
	my $constants = getCurrentStatic();
	my $user      = getCurrentUser();
	my $form      = getCurrentForm();
	my $blobdb    = getObject('Slash::Blob');

	my $ops = {
		listFilesForStories	=> {
			function => \&listFilesForStories,
		},
		editBySid   		=> {
			function => \&editBySid,
		},
		listAll			=> {
			function => \&listAll,
		},
		editFile		=> {
			function => \&editFile,
		},
		addFileForStory		=> {
			function => \&addFileForStory,
		},
		deleteFilesForStory	=> {
			function => \&deleteFilesForStory,
		},
	};


	my $op = $form->{op};
	$op = exists $ops->{$op} 
		? $op 
		: $form->{sid}
			? 'editBySid'
			: 'listFilesForStories';

# admin.pl is not for regular users
	unless ($user->{is_admin}) {
		redirect("/");
		return;
	}

	header();

	$ops->{$op}{function}->($slashdb, $constants, $user, $form, $blobdb);

	footer();
}

##################################################################
sub listFilesForStories { 
	my($slashdb, $constants, $user, $form ,$blobdb) = @_;

	my $files = $blobdb->getFilesForStories();

	slashDisplay('liststories', {
		files	=> $files,
	});


}

##################################################################
sub editBySid { 
	my($slashdb, $constants, $user, $form, $blobdb) = @_;
	return unless $form->{sid};

	my $files = $blobdb->getFilesForStory($form->{sid});

	slashDisplay('listsid', {
		files	=> $files,
		sid	=> $form->{sid},
	});


}

##################################################################
sub addFileForStory {
	my($slashdb, $constants, $user, $form, $blobdb) = @_;

	if ($form->{file_content}) {
		my $data;
		if ($form->{file_content}) {
			my $upload = $form->{query_apache}->upload;
			if ($upload) {
				my $temp_body;
				my $fh = $upload->fh;
				local $/;
				$data = $fh;
			}
		}

		my $content = {
			seclev		=> $form->{seclev},
			filename	=> $form->{file_content},
			content_type	=> $form->{content_type},
			data		=> $data,
			sid		=> $form->{sid},
			description	=> $form->{description},
		};

		$blobdb->createFileForStory($content);
	}

	if ($form->{delete}) {
		if (ref($form->{_multi}{delete}) eq 'ARRAY') {
			for (@{$form->{_multi}{delete}}) {
				$blobdb->deleteStoryFile($_);
			}
		} else {
			$blobdb->deleteStoryFile($form->{delete});
		}
	}

	editBySid(@_);
}

##################################################################
# Stubbed Out
sub listAll { 
}

##################################################################
# Stubbed Out
sub editFile { 
}

##################################################################

createEnvironment();
main();
1;
