#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2003 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Slash 2.003;	# require Slash 2.3.x
use Slash::Constants qw(:web);
use Slash::Display;
use Slash::Utility;

use Image::Size;
use Schedule::Cron;

use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

##################################################################
sub main {
	my $newsvac	= getObject('Slash::NewsVac');
	my $slashdb	= getCurrentDB();
	my $constants	= getCurrentStatic();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();

	$slashdb->getSection('newsvacadmin');

	my $seclev  = $constants->{newsvac_admin_seclev} || 10_000;
	my $allowed = $user->{seclev} >= $seclev;

	my %ops = (
		listminers	=> [ $allowed,	\&listMiners	],
		newminer	=> [ $allowed,	\&updateMiner	],
		editminer	=> [ $allowed,	\&editMiner	],
		updateminer	=> [ $allowed,	\&updateMiner	],

		listurls	=> [ $allowed,	\&listUrls	],
		processurls	=> [ $allowed,	\&processUrls	],
		newurl		=> [ $allowed,	\&newUrl	],
		editurl		=> [ $allowed,	\&editUrl	],
		updateurl	=> [ $allowed,	\&updateUrl	],

		listspiders	=> [ $allowed,	\&listSpiders	],
		editspider	=> [ $allowed,	\&editSpider	],
		updatespider	=> [ $allowed,	\&updateSpider	],

		timingdump	=> [ $allowed,	\&timingDump	],

		listkeywords	=> [ $allowed,	\&listKeywords	],
		editkeyword	=> [ $allowed,	\&editKeyword	],
		updatekeyword	=> [ $allowed,	\&updateKeyword	],
		deletekeyword	=> [ $allowed,	\&deleteKeyword	],
		addkeyword	=> [ $allowed,	\&addKeyword	],

		default		=> [ $allowed,	\&listMiners	],
	);

	my $op = $form->{op};
	if (!$op || !exists $ops{$op} || !$ops{$op}[ALLOWED]) {
		$form->{op} = $op = 'default';
	}

	header("vacSlash $user->{tzcode} $user->{offset}");

	if ($allowed) {
		$ops{$op}[FUNCTION]->($slashdb, $constants, $user, $form, $newsvac);
	} else {
		print getData('invalid_seclev');
	}

	footer();
}

##################################################################
sub listMiners {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	my $rel_week_count			= $newsvac->getWeekCounts();
	my $nuggets_day_count			= $newsvac->getDayCounts();
	my($miner_arrayref, $miners_nourl)	= $newsvac->getMinerList();

	my $i = 0;
	for my $miner (@{$miner_arrayref}) {
		my $mi = $miner->{miner_id};

		$miner->{url_number_highlite} =
			$rel_week_count->{$mi} > $miner->{url_count} * 60;

		$miner->{nugget_numbers} = join(",",
			map { $_ || 0 } @{$nuggets_day_count->{$mi}}{1, 3, 7},
		);

		$miner->{last_edit_formatted} = timeCalc($miner->{last_edit});

		$miner->{week_count} = $rel_week_count->{$mi} || 0;

		$miner->{comment} = substr($miner->{comment}, 0, 25) . "..."
			if length($miner->{comment}) > 30;
		$miner->{comment} = HTML::Entities::encode($miner->{comment});

		$miner->{newrow} = 1 if (
			($i % 5) == 4
				&&
			$i++ < ($#{$miner_arrayref} - 2)
		);
	}

	# Remember, we now list miners with no URLs, otherwise, user-created
	# miners would remain UNDISPLAYED. 1.x code had this problem, no need
	# to propagate it here.
	slashDisplay('listMiners', {
		miners 			=> $miner_arrayref,
		miners_nourl		=> $miners_nourl,
		nugget_day_count	=> $nuggets_day_count,
	});
}

##################################################################
sub editMiner {
	my($slashdb, $constants, $user, $form, $newsvac, $miner_id, $force) = @_;

	$miner_id ||= $form->{miner_id};
	my $name = $newsvac->id_to_minername($miner_id);

	# This is a mess. Convert it to use a hashref.
	my $miner = $newsvac->getMiner($miner_id);

	$miner->{last_edit} = timeCalc($miner->{last_edit});

	my @fields = qw(extract_regex
		pre_stories_text post_stories_text pre_stories_regex post_stories_regex
		pre_story_text post_story_text pre_story_regex post_story_regex
	);

	# Remove the (?i) and instead set the checkbox appropriately.
	# This begs to be made into a loop.
	my(%checkboxes, %errs);
	for my $field (@fields) {
		# set checkbox if field has (?i) at beginning
		warn $field;
		$checkboxes{$field} = ' CHECKED' if
			$miner->{$field} &&
			$miner->{$field} !~ s{^\(\?i\)}{};
	}

	for my $field (grep /_regex$/, @fields) {
		$errs{$field} = $newsvac->check_regex(
			$miner->{$field}, 'x'
		) if $miner->{$field};
	}

	my $urls = $newsvac->getMinerURLs($miner_id);

	slashDisplay('editMiner', {
		errs			=> \%errs,
		checkboxes		=> \%checkboxes,
		miner			=> $miner,
		progresscodes		=> $newsvac->getNVDescriptions('progresscodes'),
		authors			=> $newsvac->getNVDescriptions('authornames'),
		url_ar			=> $urls,
	});

	show_miner_url_info(@_, $miner_id, $force) if @$urls;
}

##################################################################
# This little routine is pulling way too much duty, it probably should
# be split up into different handlers in the long run.
sub updateMiner {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	my $miner_id = $form->{miner_id} || 0;

	if ($form->{op} eq 'newminer') {
		# Get miner name from the form, or set an appropriate default.
		my $name = $form->{newname} ||
			'miner' . time . int(rand(900)+100);
		$name = substr($name, 0, 20);
		$name =~ s/\W+//g;

		$miner_id = $newsvac->minername_to_id($name);
		if ($miner_id) {
			print getData('miner_already_exists', {
				name => $name
			});
		} else {
			$newsvac->add_miner_and_urls(
				$name, $user->{nickname},
				'', '', '', '', '', '', '', '', '', '', ''
			);
			$miner_id = $newsvac->minername_to_id($name);
			slashDisplay('updateMiner');
		}
		editMiner(@_, $miner_id);

	} elsif ($form->{updateminer}) {
		my $name = $newsvac->id_to_minername($miner_id);

		my(%update_fields);
		my(@field_names) = qw(
			name last_edit_aid
			owner_aid
			pre_stories_text
			post_stories_text
			pre_stories_regex
			post_stories_regex
			pre_story_text
			post_story_text
			pre_story_regex
			post_story_regex
			extract_vars
			extract_regex
			tweak_code
			progress
			comment
		);

		warn getData('miner_update_warning', {
			id => $miner_id, name => $name
		}) if $newsvac->{debug} > 0;

		# Prepend the "(?i)" unless this field is marked as
		# case sensitive. Remember to grab the "^" anchor
		# if it appears at the beginning of the pre-regex field.
		for my $field (grep /_(text|regex)$/, @field_names) {
			$form->{$field} = '(?i)' . $form->{$field}
				if	$form->{$field} and
					!$form->{$field . '_cs'};
		}

		$form->{last_edit_aid} = $user->{nickname};
		for (@field_names) {
			$update_fields{$_} = $form->{$_} if exists $form->{$_};
		}
		$newsvac->setMiner($miner_id, \%update_fields);

		slashDisplay('updateMiner', { name => $name });

		editMiner(@_, $miner_id, $form->{forceupdate});

	} elsif ($form->{deleteminer}) {
		# Deletion has been aborted by the user if this
		# form element is set
		if ($form->{nonconfirm}) {
			listMiners(@_);
			return;
		}

		my $name = $newsvac->id_to_minername($miner_id);
		if ($name eq 'none') {
			print getData('update_miner_nonedelete');

			editMiner(@_, $miner_id);
			return;
		}

		# Check for any URLs that use this miner
		my $urls = $newsvac->getMinerURLs($miner_id);

		if (@$urls) {
			# If URLs are present, miner can not be deleted; say so
			slashDisplay('updateMiner', {
				name	=> $name,
				urls	=> $urls,
			});

			editMiner(@_, $miner_id);

		} else {
			# Otherwise confirm the deletion before performing it
			if (! $form->{confirm}) {
				slashDisplay('updateMiner', {
					name		=> $name,
					miner_id	=> $miner_id,
					need_confirm	=> 1,
				});

				editMiner(@_, $miner_id);

			} else {
				$newsvac->deleteMiner($miner_id);

				slashDisplay('updateMiner', {
					name		=> $name,
					miner_id	=> $miner_id,
				});

				listMiners(@_);
			}
		}
	}
}

##################################################################
sub listUrls {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	my($n_urls_total, $n_urls_no_miners) = $newsvac->getURLCounts;

	my $url_arrayref = $newsvac->getUrlList(
		$form->{like},
		$form->{owner},
		$form->{start},
		$form->{limit}
	);

	slashDisplay('listUrls', {
		urls_total	=> $n_urls_total,
		urls_no_miners	=> $n_urls_no_miners,
		urls		=> $url_arrayref,
	});
}

##################################################################
sub processUrls {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	my @url_ids = split /\D/, $form->{ids};
	use Data::Dumper; print STDERR Dumper \@url_ids;
	my $start_time = Time::HiRes::time();
	$newsvac->process_url_ids({}, @url_ids);
	my $duration = int((Time::HiRes::time() - $start_time)*1000+0.5)/1000;

	my $ids = join ',', @url_ids;

	slashDisplay('processUrls', { ids => $ids, duration => $duration });
	listUrls(@_);
}

#################################################
sub show_miner_url_info {
	my($slashdb, $constants, $user, $form, $newsvac, $miner_id, $force) = @_;

	my $url_ids	= $newsvac->getMinerURLIds($miner_id);
	my $miner	= $newsvac->getMinerRegexps($miner_id);

	my $start_time = Time::HiRes::time();
	my %conditions;
	if ($force) {
		%conditions = (
			force_request		=> 1,
			force_analyze_miner	=> 1,
		);
	} else {
		%conditions = (
			use_current_time	=> time() - 3600,
			force_analyze_miner	=> 1,
			timeout			=> 5,
		);
	}

	print getData('processing_urls', {
		url_ids	=> $url_ids
	});

	$newsvac->process_url_ids(\%conditions, @$url_ids);
	my $duration = int((Time::HiRes::time() - $start_time)*1000+0.5)/1000;

	print getData('processed_urls', {
		url_ids => $url_ids,
		dur	=> $duration,
	});

	for my $url_id (@$url_ids) {
		my $ar = $newsvac->getURLBody($url_id);

		# We should report when we don't retrieve a URL, eventually
		next unless $ar && @$ar;

		my($url, $message_body) = @$ar;
		my $orig_length = length($message_body);

		(my $mb_squeezed = $message_body) =~ s/\s+/ /g;
		my($orig_start, $orig_end) = (
			strip_literal(substr $mb_squeezed, 0, 30),
			strip_literal(substr $mb_squeezed, -30, 30)
		);
		$newsvac->trim_body($miner_id, \$message_body,
			$miner->{pre_stories_text},
			$miner->{pre_stories_regex},
			'', ''
		);

		my $trim_pre_length = length($message_body);
		($mb_squeezed = $message_body) =~ s/\s+/ /g;
		my $pre_trimmed_chars = $orig_length - $trim_pre_length;
		my($trim_pre_start, $trim_pre_end) = (
			strip_literal(substr $mb_squeezed, 0, 30),
			strip_literal(substr $mb_squeezed, -30, 30)
		);
		$newsvac->trim_body($miner_id, \$message_body,
			'', '',
			$miner->{post_stories_text},
			$miner->{post_stories_regex},
		);

		my $trim_post_length = length($message_body);
		($mb_squeezed = $message_body) =~ s/\s+/ /g;
		my $post_trimmed_chars = $trim_pre_length - $trim_post_length;
		my($trim_post_start, $trim_post_end) = (
			strip_literal(substr $mb_squeezed, 0, 30),
			strip_literal(substr $mb_squeezed, -30, 30)
		);

		my $count = 0;
		my $regex = qr{
			(.{0,10}<a\s+[^>]*href="?)
			([^">]+)
			("?[^>]*>.{0,10})
		}xi;
		my @tags;

		while ($mb_squeezed =~ /$regex/g) {
			$count++;
			my $tag_node = [$count, $1, $2, $3];
			$_ = strip_literal($_) for @{$tag_node}[1..3];
			push @tags, $tag_node;
		}

		slashDisplay('showMinerUrlInf', {
			tags			=> \@tags,
			duration		=> $duration,
			url			=> $url,
			orig_length		=> $orig_length,
			orig_start		=> $orig_start,
			orig_end		=> $orig_end,
			pre_trimmed_chars 	=> $pre_trimmed_chars,
			trim_pre_start		=> $trim_pre_start,
			trim_pre_end		=> $trim_pre_end,
			post_trimmed_chars	=> $post_trimmed_chars,
			trim_post_start		=> $trim_post_start,
			trim_post_end		=> $trim_post_end,
		});

		show_miner_rel_info(
			$slashdb, $constants, $user,
			$form, $newsvac, $url_id
		) if $url_id;
	}
}

#################################################
sub show_miner_rel_info {
	my($slashdb, $constants, $user, $form, $newsvac, @url_ids) = @_;

	return if !@url_ids;
	my $url_rel = $newsvac->getURLRelationships(\@url_ids, 100) or return;

	for my $rel (@$url_rel) {
		if ($rel->{url} =~ /^nugget:/) {
			$rel->{url_nugget}	= 1;
			my $info		= $newsvac->nugget_url_to_info($rel->{url});
			$rel->{slug}		= $info->{slug};
			$rel->{source}		= $info->{source};
			$rel->{url}		= $info->{url};
			$rel->{title}		||= $info->{title};

		} else {
			warn getData('show_miner_rel_info', {
				url_id		=> $rel->{url_id},
				url_id_list	=> \@url_ids
			});
		}
	}

	slashDisplay('showMinerRelInf', {
		arrayref 	=> $url_rel,
	});
}

##################################################################
sub editUrl {
	my($slashdb, $constants, $user, $form, $newsvac, $url_id) = @_;
	my($new_url, $titlebar_type);
	$url_id ||= $form->{url_id};

	if ($url_id eq 'new' || $url_id eq 'newurl') {
		$new_url = $form->{newurl};
		$new_url = $newsvac->canonical($new_url);
		$url_id = $newsvac->url_to_id($new_url);

		$titlebar_type = 'added';
		if (!$url_id) {
			$newsvac->add_url($new_url);
			$url_id = $newsvac->url_to_id($new_url);
			$newsvac->correlate_miner_to_urls('none', $new_url)
				if $url_id;
		} else {
			$titlebar_type = 'existing';
		}
	} else {
		$titlebar_type = 'editing';
	}

	($url_id, my($url, $title, $miner_id, $last_attempt, $last_success,
		$status_code, $reason_phrase, $message_body_length)) =
		$newsvac->getURLData($url_id);

	my $miner_name;
	$miner_name = $newsvac->id_to_minername($miner_id) if $miner_id;

	my $rel = $newsvac->getURLRelationCount($url_id);

	slashDisplay('editUrl', {
		new_url 		=> $new_url,
		url_id 			=> $url_id,
		url			=> $url,
		title			=> $title,
		miner_id		=> $miner_id,
		miner_name		=> $miner_name,
		last_attempt		=> $last_attempt,
		last_success		=> $last_success,
		status_code		=> $status_code,
		reason_phrase		=> $reason_phrase,
		message_body_length	=> $message_body_length,
		referencing		=> $rel ? scalar @$rel : 0,
		titlebar_type		=> $titlebar_type,
	});

	show_miner_rel_info(
		$slashdb, $constants, $user,
		$form, $newsvac, $url_id
	) if $url_id;
}

##################################################################
sub newUrl {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	editUrl(@_, 'newurl');
}

##################################################################
sub updateUrl {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	if ($form->{deleteurl}) {
		(my $url_id = $form->{url_id}) =~ s/\D//g;
		if ($url_id) {
			my $url = $newsvac->id_to_url($url_id);
			$newsvac->deleteURL($url_id) if $url_id;

			slashDisplay('updateUrl', {
				url_id => $url_id, url => $url
			});
		}
		listUrls(@_);

	} elsif ($form->{requesturl}) {
		my $url_id = $form->{url_id};
		my $url = $newsvac->id_to_url($url_id);
		my $start_time = Time::HiRes::time();
		my $duration =
			int((Time::HiRes::time() - $start_time)*1000+0.5)/1000;

		# Makes HTTP request.
		$newsvac->request(
			$url_id,
			$url,
			{},
			{},
			{},
			{ force_request => 1 }
		);

		slashDisplay('updateUrl', {
			url_id		=> $url_id,
			duration	=> $duration
		});

		editUrl(@_[0..4], $url_id);

	} else {
		my $miner_name = $form->{miner_name};
		my $miner_id = $newsvac->minername_to_id($form->{miner_name});
		my $url_id = $form->{url_id};
		my $url = $newsvac->id_to_url($url_id);

		if ($miner_id) {
			$newsvac->correlate_miner_to_urls($miner_name, $url);
		} else {
			$newsvac->add_miner_and_urls(
				$miner_name, $user->{aid},
				'', '', '', '', '', '', '', '', '',
				'put your regex here', '', $url
			);
		}

		slashDisplay('updateUrl', {
			url_id		=> $url_id,
			miner_name	=> $miner_name
		});

		editUrl(@_[0..4], $url_id);
	}
}

##################################################################
sub listSpiders {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	# We may need to work on the classing here, some punctuation may be
	# allowed in minor names.
	$form->{like} =~ s/\W//g;

	slashDisplay('listSpiders', {
		arrayref	=> $newsvac->getSpiderList($form->{like})
	});
}

##################################################################
sub editSpider {
	my($slashdb, $constants, $user, $form, $newsvac, $spider_id) = @_;
	$spider_id ||= $form->{spider_id};

	my($name, $last_edit, $last_edit_aid, $conditions, $group_0_selects,
		$commands) = $newsvac->getSpider($spider_id);

	my $timespecs = $newsvac->getSpiderTimespecs($spider_id);

	for ($conditions, $group_0_selects, $commands) {
		s/^\s+//gm;
		s/\s+$//gm;
	}

	$last_edit = timeCalc($last_edit);

	slashDisplay('editSpider', {
		spider_id	=> $spider_id,
		name		=> $name,
		last_edit	=> $last_edit,
		last_edit_aid	=> $last_edit_aid,
		conditions	=> $conditions,
		group_0_selects	=> $group_0_selects,
		commands	=> $commands,
		timespecs	=> $timespecs,
	});
}

##################################################################
sub updateSpider {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	# This form processing should be redone in the VERY near future
	# for flexibility. It should be working now, but adding on
	# to this list will be painful. Maybe $op separate handlers,
	# but maybe helper functions might be a better solution?
	my $spider_id = $form->{spider_id};
	if ($form->{runspider}) {
		# THIS block is for force-executing a spider.
		my $spider_name = $newsvac->getSpiderName($spider_id);

		if ($spider_name) {
			local $newsvac->{debug} = 1;
			$newsvac->spider_by_name($spider_name);
		}
		print getData('update_spider_runspider', {
			spider_name => $spider_name
		});

		editSpider(@_, $spider_id);

	} elsif ($form->{newspider}) {
		# THIS block is for creating a new spider.
		if (!$form->{newname}) {
			print getData('update_spider_noname');
		} else {
			# If successful, $rc contains the id of the newly
			# created spider.
			my $rc = $newsvac->add_spider($form->{newname});

			print getData('update_spider_add_results', {
				success => $rc,
			});

			if ($rc) {
				editSpider(@_, $rc);
			} else {
				listSpiders(@_);
			}
		}
	} elsif ($form->{deletespider}) {
		my $spider_name = $newsvac->getSpiderName($spider_id);

		if ($form->{noconfirm}) {
			print getData('update_spider_nodelete');

			editSpider(@_, $spider_id);
			return;
		}

		if ($form->{confirm} eq 'Yes') {
			$newsvac->deleteSpider($form->{spider_id});

			print getData('update_spider_deletedspider', {
				spider_name	=> $spider_name
			});

			listSpiders(@_);
		} else {
			print getData('update_spider_confirmdelete', {
				spider_name 	=> $spider_name,
				spider_id	=> $spider_id,
			});

			editSpider(@_, $spider_id);
		}
	} else {
		# THIS block is where spider data is saved.
		my %set_clause;

		$form->{last_edit_aid} = $user->{nickname};
		$set_clause{$_} = $form->{$_} for qw(
			name
			last_edit_aid
			conditions
			group_0_selects
			commands
		);
		$newsvac->setSpider($spider_id, \%set_clause);

		# Handle the timespecs.
		my %timespecs;
		for (grep { /^timespec_(\d+)_timespec$/ } keys %{$form}) {
			/^timespec_(\d+)_timespec$/;
			next if !defined $1;
			my $id = $1;

			# Test the given timespec only if we aren't deleting it.
			eval {
				sub dispatch { };

				my $cron = new Schedule::Cron(\&dispatch);
				$cron->get_next_execution_time(
					$form->{"timespec_${id}_timespec"}
				);
			} unless $form->{"timespec_${id}_del"};

			if ($@) {
				my $err = <<EOT;
Error in '$form->{"timespec_${id}_timespec"}': $@
EOT

				# Remove unimportant kruft. I don't know
				# why this regexp doesn't work HERE and works
				# fine when I test it outside of Slash.
				#
				# $(#%^&* thing!	-- Cliff
				$err =~ s{ at .+? line \d+\.$}{};
				$form->{"timespec_${id}_err"} = $err;
				next;
			}

			$timespecs{$id} = {
				timespec	=> $form->{"timespec_${id}_timespec"},
				name		=> $form->{name},
				del		=> $form->{"timespec_${id}_del"},
			};
		}
		$newsvac->setSpiderTimespecs($spider_id, \%timespecs);

		print getData('update_spider_savedspider', {
			spider_name => $form->{name},
		});

		editSpider(@_, $spider_id);
	}
}

##################################################################
sub listKeywords {
	my($slashdb, $constants, $user, $form, $newsvac, $tag) = @_;
	$tag ||= $form->{keyword_tag};

	my $valid_tags	= $newsvac->getKeywordTags;
	my $keywords	= $newsvac->getTagKeywords($tag) if $tag;

	slashDisplay('listKeywords', {
		valid_tags	=> $valid_tags,
		keywords	=> $keywords,
	});
}

##################################################################
sub editKeyword {
	my($slashdb, $constants, $user, $form, $newsvac, $keyword_id) = @_;
	$keyword_id = $form->{keyword_id} if !defined $keyword_id;

	my $keyword_data;
	if ($keyword_id) {
		$keyword_data = $newsvac->getKeyword($keyword_id) if $keyword_id;
	} else {
		$keyword_data = {
			tag	=> $form->{keyword_tag},
		};
	}

	slashDisplay('editKeyword', {
		keyword_id	=> $keyword_id,
		data		=> $keyword_data,
	});
}

##################################################################
sub updateKeyword {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	my $keyword_id = $form->{keyword_id};

	if (!(	$form->{keyword_weight} &&
		$form->{keyword_tag} &&
		$form->{keyword_regex} ))
	{
		print getData('updateKeyword_emptyfields');

		editKeyword(@_, $keyword_id);
	}

	# Pass off to proper op handler if certain form targets are set.
	if ($form->{deletekeyword} || $form->{addkeyword}) {
		deleteKeyword(@_) if $form->{deletekeyword};
		addKeyword(@_)	  if $form->{addkeyword};

		return;
	}

	# Basic update logic.
	my $new_id = $newsvac->setKeyword($keyword_id, {
		regex	=> $form->{keyword_regex},
		tag	=> $form->{keyword_tag},
		weight	=> $form->{keyword_weight},
	});

	print getData('updateKeyword_kwsaved', { new_id => $new_id });
	editKeyword(@_, $new_id || $keyword_id);
}

##################################################################
sub addKeyword {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;

	# Must have a tag for keyword adding.
	if (!$form->{keyword_tag}) {
		print getData('addKeyword_notag');

		listKeywords(@_);
		return;
	}

	editKeyword(@_, 0);
}

##################################################################
sub deleteKeyword {
	my($slashdb, $constants, $user, $form, $newsvac) = @_;
	my $keyword_id = $form->{keyword_id};

	if ($form->{noconfirm}) {
		print getData('deleteKeyword_noconfirm');

		editKeyword(@_, $keyword_id);
		return;
	}

	if (!$form->{confirm}) {
		print getData('deleteKeyword_confirm');

		editKeyword(@_, $keyword_id);
		return;
	}

	if ($form->{confirm} eq 'Yes') {
		$newsvac->deleteKeyword($keyword_id);

		print getData('deleteKeyword_deleted');
	}
	listKeywords(@_, $form->{keyword_tag});
}


createEnvironment();
main();

1;
