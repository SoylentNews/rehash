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

	# Loop thru %$form once, at this time, and pull out all the necessary
	# elements, rather than pulling from it multiple times, later.
	#
	# These keys are local to the script. No forms for the Groups plugin
	# should EVER name a form element from the following list:
	#
	#	SUBSECTIONS
	#	SECTION_EXTRAS
	#	NEW_subsection
	#	DEL_subsection
	#
	# so it should be fairly safe, if not completely kosher.
	$form->{'SUBSECTIONS'} = {};
	$form->{'SECTION_EXTRAS'} = [];
	for (keys %{$form}) {
		# Poor Man's Switch syntax. It's better than if-else's. :p

		/^extraname_(\d+)/ && do {
			next if !($1 && !$form->{"extradel_$1"});
			$form->{"extraname_$1"} =~ s/\s//g;
			next if !$form->{"extraname_$1"};

			push @{$form->{'SECTION_EXTRAS'}}, [
				# Field label
				$form->{"extraval_$1"} ||
				$form->{"extraname_$1"},

				# Field name
				$form->{"extraname_$1"}
			];
			
			next;
		};

		($_ eq 'new_subsection') && !$form->{savesection} && do {
			$op = 'editsection';
			next if !$form->{new_subsection};

			# Set up parameters for call to 
			# Slash::DB::createSubSection
			$form->{'NEW_subsection'} = [
				$form->{section},
				$form->{new_subsection},
				0
			];

			next;
		};

		# Handles fields like:
		# 	del_subsection_*
		/^del_subsection_(\d+)/ && do {
			$form->{'DEL_subsection'} = $1;
			$op = 'editsection';
			
			next;
		};

		# This handles form fields like:
		# 	subsection_title_*, subsection_artcount_*
		/^subsection_title_(\d+)/ && do {
			$form->{'SUBSECTIONS'}{$1} = {
				title	=> $form->{"subsection_title_$1"},
				artcount=> $form->{"subsection_artcount_$1"},
			};

			next;
		}
	}


	header(getData('head'), '', { admin => 1 } );

	# Next up for dispatch hash conversion!
	#
	if ($op eq 'rmsub' && $seclev >= 100) {  # huh?

	} elsif ($form->{addsection}) {
		titlebar('100%', getData('addhead'));
		editSection();

	} elsif ($form->{deletesection} || $form->{deletesection_cancel} || $form->{deletesection_confirm}) {
		delSection($form->{section});
		listSections($user);

	} elsif ($op eq 'editsection' ||
		 $form->{editsection} || 
		 $form->{addextra}) {

		saveSection($form->{section}) 
			if $form->{addextra} && @{$form->{'SECTION_EXTRAS'}};
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

	# Create a new subsection if we've been told to.
	if ($form->{'NEW_subsection'}) {
		$slashdb->createSubSection(@{$form->{'NEW_subsection'}});
		print getData('subsection_added');
	}

	# Delete a subsection if the proper conditions are met.
	if ($form->{'confirm'} && $form->{'DEL_subsection'}) {
		$slashdb->removeSubSection($section, $form->{'DEL_subsection'});
		print getData('subsection_removed');
	}

	my $qid = $this_section->{qid} ? 
		createSelect('qid', 
			$slashdb->getPollQuestions(),
			$this_section->{qid},
			1
		) : '';
	my $isolate = createSelect('isolate', 
		$slashdb->getDescriptions('isolatemodes'),
		$this_section->{isolate}, 
		1
	);
	my $issue = createSelect('issue', 
		$slashdb->getDescriptions('issuemodes'),
		$this_section->{issue}, 
		1
	);

	my $extras = $form->{'SECTION_EXTRAS'};
	$extras = $slashdb->getSectionExtras($form->{section})
		unless @{$extras};
	my $extra_types = $slashdb->getDescriptions('section_extra_types');

	# Get list of subsections.
	my $subsections = $slashdb->getSubSectionsBySection($section);
	
	my $topics = $slashdb->getDescriptions('topics_section', $section);
	slashDisplay('editSection', {
		section		=> $section,
		this_section	=> $this_section,
		qid		=> $qid,
		isolate		=> $isolate,
		issue		=> $issue,
		blocks		=> \@blocks,
		topics		=> $topics,
		extras		=> $extras,
		extra_types	=> $extra_types,
		subsections	=> $subsections,
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
	($section = $form->{section}) =~ s/[^A-Za-z0-9\-]//g;

	# Before we insert, give some reasonable defaults.
	$form->{url}		||= '';
	$form->{cookiedomain}	||= '';
	$form->{hostname}	||= '';
	$form->{artcount}	||= 0;

	my $found = $slashdb->getSection($section, 'section', 1);
	if ($found) {
		$slashdb->setSection($section, {
			qid		=> $form->{qid},
			title		=> $form->{title},
			issue		=> $form->{issue},
			isolate		=> $form->{isolate},
			artcount	=> $form->{artcount},
			url		=> $form->{url},
			writestatus	=> 'dirty',
			cookiedomain	=> $form->{cookiedomain},
			hostname	=> $form->{hostname},
			index_handler	=> $form->{index_handler},
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
			writestatus	=> 'dirty',
			cookiedomain	=> $form->{cookiedomain},
			hostname	=> $form->{hostname},
			index_handler	=> $form->{index_handler},
		});
		print getData($return ? 'insert' : 'failed', { 
			section => $section
		});
	} 

	# Set section extras.
	$slashdb->setSectionExtras($section, $form->{'SECTION_EXTRAS'}) 
		if @{$form->{'SECTION_EXTRAS'}};

	# Set subsections.
	for (keys %{$form->{'SUBSECTIONS'}}) {
		$slashdb->setSubSection($_, $form->{'SUBSECTIONS'}{$_})
	};
}

#################################################################
createEnvironment();
main();

1;
