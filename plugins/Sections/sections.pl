#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;

#################################################################
sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my $op = $form->{op};
	my $seclev = $user->{seclev};

	if ($seclev < 100) {
		my $rootdir = getCurrentStatic('rootdir');
		redirect("$rootdir/users.pl");
		return;
	}

	$form->{section_extras} = [];
	for (grep { /^extraname_\d+/ } keys %{$form}) {
		next unless /^extraname_(\d+)$/;
		next if !($1 && !$form->{"extradel_$1"});
		$form->{"extraname_$1"} =~ s/\s//g;
		next if !$form->{"extraname_$1"};

		push @{$form->{section_extras}}, [
			# Field label
			$form->{"extraval_$1"} || $form->{"extraname_$1"},
			# Field name
			$form->{"extraname_$1"}
		];
	}

	header(getData('head'), 'admin');

	if ($op eq 'rmsub' && $seclev >= 100) {  # huh?

	} elsif ($form->{addsection}) {
		titlebar('100%', getData('addhead'));
		editSection();

	} elsif ($form->{deletesection} || $form->{deletesection_cancel} || $form->{deletesection_confirm}) {
		delSection($form->{section});
		listSections($user);

	} elsif ($op eq 'editsection' || $form->{editsection} ||
		 $form->{addextra})
	{
		saveSection($form->{section}) 
			if $form->{addextra} && @{$form->{section_extras}};
		titlebar('100%', getData('edithead'));
		editSection($form->{section});

	} elsif ($form->{savesection}) {
		titlebar('100%', getData('savehead'));
		saveSection($form->{section});
		listSections($user);

	} elsif ((! defined $op || $op eq 'list') && $seclev >= 500) {
		titlebar('100%', getData('listhead'));
		listSections($user);
	}

	footer();
}

#################################################################
sub listSections {
	my($user) = @_;
	my $slashdb = getCurrentDB();

	if ($user->{section}) {
		editSection($user->{section});
		return;
	}
	my $section_titles = $slashdb->getDescriptions('sections-all');
	my @values;
	for (keys %$section_titles) {
		push @values, [$_ , $section_titles->{$_}] ;
	}

	slashDisplay('listSections', {
		sections => \@values,
	});
}

#################################################################
sub delSection {
	my($section) = @_;
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	if ($form->{deletesection}) {
		slashDisplay('delSection', {
			section	=> $section
		});
	} elsif ($form->{deletesection_cancel}) {
		slashDisplay('delSectCancel', {
			section	=> $section
		});
	} elsif ($form->{deletesection_confirm}) {
		slashDisplay('delSectConfirm', {
			section	=> $section,
			title	=> "Deleted $section Section",
			width	=> '100%'
		});
		$slashdb->deleteSection($section);
	}
}

#################################################################
sub editSection {
	my($section) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my(@blocks, $this_section);
	if ($form->{addsection}) {
		$this_section = {};
	} else {
		$this_section = $slashdb->getSection($section,'', 1);
		my $blocks = $slashdb->getSectionBlock($section);

		for (@$blocks) {
			my $block = $blocks[@blocks] = {};
			@{$block}{qw(section bid ordernum title portal url)} =
				@$_;
			$block->{title} =~ s/<(.*?)>//g;
		}
	}

	my $qid = createSelect('qid', $slashdb->getPollQuestions(),
		$this_section->{qid}, 1);
	my $isolate = createSelect(
		'isolate', 
		$slashdb->getDescriptions('isolatemodes'),
		$this_section->{isolate}, 
		1
	);
	my $issue = createSelect(
		'issue', 
		$slashdb->getDescriptions('issuemodes'),
		$this_section->{issue}, 
		1
	);

	my $extras = $form->{section_extras};
	$extras = $slashdb->getSectionExtras($form->{section})
		unless @{$extras};

	slashDisplay('editSection', {
		section		=> $section,
		this_section	=> $this_section,
		qid		=> $qid,
		isolate		=> $isolate,
		issue		=> $issue,
		blocks		=> \@blocks,
		topics		=> $slashdb->getDescriptions(
			'topics_section', $section
		),
		extras		=> $extras,
	});
}

#################################################################
sub saveSection {
	my($section) = @_;
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	# Non alphanumerics are not allowed in the section key.
	# And I don't see a reason for underscores either, but
	# dashes should be allowed.
	($section  = $form->{section}) =~ s/[^A-Za-z0-9\-]//g;

	# Before we insert, give some reasonable defaults.
	$form->{url} 	  ||= '';
	$form->{hostname} ||= '';
	$form->{artcount} ||= 0;

	my $found = $slashdb->getSection($section, 'section', 1);
	if ($found) {
		$slashdb->setSection($section, {
			qid		=> $form->{qid},
			title		=> $form->{title},
			issue		=> $form->{issue},
			isolate		=> $form->{isolate},
			artcount	=> $form->{artcount},
			url		=> $form->{url},
			hostname	=> $form->{hostname},
		});

		print getData('update', { section => $section });
	} else {
		my $return = $slashdb->createSection({
			section		=> $section,
			qid		=> $form->{qid},
			title		=> $form->{title},
			issue		=> $form->{issue},
			isolate		=> $form->{isolate},
			artcount	=> $form->{artcount},
			url		=> $form->{url},
			hostname	=> $form->{hostname},
		});
		print getData($return ? 'insert' : 'failed', { 
			section => $section
		});
	} 
	$slashdb->setSectionExtras($section, $form->{section_extras}) 
		if @{$form->{section_extras}};
	
}

#################################################################
createEnvironment();
main();

1;
