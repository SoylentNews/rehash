#!/usr/bin/perl -w

###############################################################################
# newsvacadmin.pl - this code runs the site's newsvac admin page
#
# Copyright (C) 2000 Andover.Net
# jamie@mccarthy.org
# based on code Copyright (C) 1997 Rob "CmdrTaco" Malda
# malda@slashdot.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
#  $Id$
###############################################################################
use strict;

use Slash;
use Slash::Display;
use Slash::Utility;

use Image::Size;
use Schedule::Cron;

use vars qw(%nvdescriptions);

$| = 1;

##################################################################
sub listMiners {
	my ($slashdb, $form, $user, $udbt) = @_;
        my ($miners_nourl, $miner_arrayref, $rel_week_count, $nuggets_day_count);

	$udbt->timing_clear();
        $rel_week_count = $udbt->getWeekCounts();
	$nuggets_day_count = $udbt->getDayCounts();
        ($miner_arrayref, $miners_nourl) = $udbt->getMinerList();

	my $i = 0;
	for (@{$miner_arrayref}) {
		my $mi = $_->{miner_id};

		$_->{url_number_highlite} = 
			$rel_week_count->{$mi} > $_->{url_count} * 60;
		
		$_->{nugget_numbers} = join(",",
			map { $_ || 0 } @{$nuggets_day_count->{$mi}}{1,3,7},
		);

        	$_->{last_edit} =~ 
			/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;
        	my($yyyy, $mon, $dd, $hh, $min, $ss) =
			($1, $2, $3, $4, $5, $6);
		$_->{last_edit_formatted} = "$yyyy-$mon-$dd $hh:$min";

		$_->{week_count} = $rel_week_count->{$mi} || 0;

                $_->{comment} = substr($_->{comment}, 0, 25) . "..."
			if length($_->{comment}) > 30;
		$_->{comment} = HTML::Entities::encode($_->{comment});

		$_->{newrow} = 1 if $i % 5 == 4 and 
				    $i++ < $#{$miner_arrayref} - 2;
        }

	# Remember, we now list miners with no URLs, otherwise, user-created
	# miners would remain UNDISPLAYED. 1.x code had this problem, no need
	# to propagate it here.
	slashDisplay('listMiners', { 
		miners 			=> $miner_arrayref,
		miners_nourl		=> $miners_nourl,
		nugget_day_count	=> $nuggets_day_count,
	});

	warn "doing timing_dump after listMiners";
	$udbt->timing_dump();
}

##################################################################
sub editMiner {
	my ($slashdb, $form, $user, $udbt, $miner_id, $force) = @_;

	$miner_id ||= $form->{miner_id};
	my $name = $udbt->id_to_minername($miner_id);

	# This is a mess. Convert it to use a hashref.
	my $miner = $udbt->getMiner($miner_id);

	$miner->{last_edit} =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;
	$miner->{last_edit} = timeCalc("$1-$2-$3 $4:$5:$6");
        
        # Remove the (?i) and instead set the checkbox appropriately.
	# This begs to be made into a loop.
	my(%checkboxes);
        $checkboxes{pre_stories_text} =
		$miner->{pre_stories_text} &&
		$miner->{pre_stories_text} !~ s{^\(\?i\)}{};

        $checkboxes{post_stories_text} =
		$miner->{post_stories_text} && 
		$miner->{post_stories_text} !~ s{^\(\?i\)}{};

        $checkboxes{pre_stories_regex} = 
		$miner->{pre_stories_regex} && 
		$miner->{pre_stories_regex} !~ s{^\(\?i\)}{};

        $checkboxes{post_stories_regex} =
		$miner->{post_stories_regex} &&
		$miner->{post_stories_regex} !~ s{^\(\?i\)}{};
		
        $checkboxes{extract_regex} =		
		$miner->{extract_regex} && 
		$miner->{extract_regex} !~ s{^\(\?i\)}{};

        my %errs;
        $errs{pre_regex} = $udbt->check_regex(
		$miner->{pre_stories_regex}, 'x'
	) if $miner->{pre_stories_regex};
	
        $errs{post_regex} = $udbt->check_regex(
		$miner->{post_stories_regex}, 'x'
	) if $miner->{post_stories_regex};
	
	$errs{extract_regex} = $udbt->check_regex(
		$miner->{extract_regex}, 'x'
	) if $miner->{extract_regex};

    	$miner->{$_} = HTML::Entities::encode($miner->{$_}) for qw(
		pre_stories_text
		post_stories_text
		pre_stories_regex
		post_stories_regex
		extract_vars
		extract_regex
		tweak_code
		progress
		comment
	);
        
	my $progress_select = createSelect(
		'progress', 
		$udbt->getNVDescriptions('progresscodes'),
		$miner->{progress}, 
		1
	);   

	my $authors = $udbt->getNVDescriptions('authornames');
	my $owner_aid_menu = createSelect(
		'owner_aid',
		$authors, 
		$miner->{owner_aid}, 
		1, 0, 1
	);   

        my $url_ar = $udbt->getMinerURLs($miner_id);

	if ($udbt->{debug} > 0) {
		warn "doing timing_dump after editMiner";
		$udbt->timing_dump();
	}

	slashDisplay('editMiner', { 
		errs			=> \%errs,
		progress_select		=> $progress_select,
		owner_aid_menu		=> $owner_aid_menu,
		miner			=> $miner,
		url_ar			=> $url_ar,
	});

	show_miner_url_info($slashdb, $form, $user, $udbt, $miner_id, $force)
		if @{$url_ar};
}

##################################################################
# This little routine is pulling way too much duty, it probably should
# be split up into different handlers in the long run.
sub updateMiner {
	my ($slashdb, $form, $user, $udbt) = @_;
	my $miner_id = $form->{miner_id} || 0;
	
	if ($form->{op} eq 'newminer') {
		 # Get miner name from the form, or set an appropriate default.
		my $name = $form->{newname} || 'miner' . time .
			int(rand(900)+100);
		$name = substr($name, 0, 20);
		$name =~ s/\W+//g;
		$miner_id = $udbt->minername_to_id($name);
		if ($miner_id) {
			print getData('miner_already_exists', {
				name => $name 
			});
		} else {
			$udbt->add_miner_and_urls(
				$name, $user->{nickname},
				'', '', '', '',
				'', '',
				''
			);
			$miner_id = $udbt->minername_to_id($name);
			slashDisplay('updateMiner');
		}
		editMiner(@_, $miner_id);
	} elsif ($form->{updateminer}) {
		my $name = $udbt->id_to_minername($miner_id);

		my(%update_fields);
		my(@field_names) = qw(
			name last_edit_aid
			owner_aid
       			pre_stories_text 
			post_stories_text
       			pre_stories_regex 
			post_stories_regex
       			extract_vars 
			extract_regex
       			tweak_code 
			progress
			comment
		);

		warn getData('miner_update_warning', {
			id => $miner_id, name => $name
		}) if $udbt->{debug} > 0;

       		# Prepend the "(?i)" unless this field is marked as 
		# case sensitive. Remember to grab the "^" anchor
		# if it appears at the beginning of the pre-regex field.
		for my $field (grep /_(text|regex)$/, keys %{$form}) {
			$form->{$field} =~ s/^(^)?/$1(?i)/
				if	$form->{$field} and 
					!$form->{"${field}_cs"} and
					/^pre_regex/;

			$form->{$field} = "(?i)$form->{$field}"
				if	$form->{$field} and
					!$form->{"${field}_cs"} and
					/_text$/;
		}
		$form->{last_edit_aid} = $user->{nickname};
		for (@field_names) { 
			$update_fields{$_} = $form->{$_} if exists $form->{$_};
		}
		$udbt->setMiner($miner_id, \%update_fields);

		slashDisplay('updateMiner', { name => $name });

                editMiner(@_, $miner_id, $form->{forceupdate});
	} elsif ($form->{deleteminer}) {
		# Deletion has been aborted by the user if this form element is
		# set.
		if ($form->{nonconfirm}) {
			listMiners(@_);
			return;
		}

		my $name = $udbt->id_to_minername($miner_id);
		if ($name eq 'none') {
			print getData('update_miner_nonedelete');

			editMiner(@_, $miner_id);
			return;
		}

		# Check for any URLs that use this miner.
		my $urls_ar = $udbt->getMinerURLs($miner_id);

		if (@{$urls_ar}) {
			# If URLs are present, miner can not be deleted. Say so.
			slashDisplay('updateMiner', {
				name	=> $name, 
				urls	=> $urls_ar,
			});

			editMiner(@_, $miner_id);
		} else {
			# Otherwise confirm the deletion before performing it.
			if (! $form->{confirm}) { 
				slashDisplay('updateMiner', {
					name		=> $name, 
					miner_id	=> $miner_id,
					need_confirm	=> 1,
				});

				editMiner(@_, $miner_id);
			} else {
				$udbt->deleteMiner($miner_id);

				slashDisplay('updateMiner', {
					name	=> $name,
					miner_id=> $miner_id,
				});

				listMiners(@_);
			}
		}
	}
}

##################################################################
sub listUrls {
	my ($slashdb, $form, $user, $udbt) = @_;

	my ($n_urls_total, $n_urls_no_miners) = $udbt->getURLCounts();

	my $url_arrayref = $udbt->getUrlList(
		$form->{match}, 
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
	my ($slashdb, $form, $user, $udbt, $url_ids) = @_;

	my @url_ids = split / /, $url_ids;
	my $start_time = Time::HiRes::time();
	$udbt->process_url_ids({}, @url_ids);
	my $ids = @url_ids;
	my $duration = int((Time::HiRes::time() - $start_time)*1000+0.5)/1000;

	slashDisplay('processUrls', { ids => $ids, duration => $duration });
	listUrls(@_);
}

#################################################
sub show_miner_url_info {
	my ($slashdb, $form, $user, $udbt, $miner_id, $force) = @_;

	my $urls_ar   = $udbt->getMinerURLIds($miner_id);
	my $miner_ref = $udbt->getMinerRegexps($miner_id);

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

	print getData('processing_urls', { url_ids => $urls_ar });
	$udbt->process_url_ids(\%conditions, @{$urls_ar});
	my $duration = int((Time::HiRes::time() - $start_time)*1000+0.5)/1000;
	print getData('processed_urls', { 
		url_ids => $urls_ar, 
		dur	=> $duration,
	});

	for (@{$urls_ar}) {
		my $ar = $udbt->getURLBody($_);
		
		# We should report when we don't retrieve a URL, eventually.
		next unless $ar && @{$ar};
		my($url, $message_body) = @{$ar};
		my $orig_length = length($message_body);
		my $mb_squeezed = $message_body; $mb_squeezed =~ s/\s+/ /g;
		my($orig_start, $orig_end) = (
			strip_literal(substr $mb_squeezed, 0, 30),
			strip_literal(substr $mb_squeezed, -30, 30)
		);
		$udbt->trim_body($miner_id, \$message_body,
			$miner_ref->{pre_stories_text},
			$miner_ref->{pre_stories_regex},
			'', ''
		);
		my $trim_pre_length = length($message_body);
		$mb_squeezed = $message_body; $mb_squeezed =~ s/\s+/ /g;
		my $pre_trimmed_chars = $orig_length - $trim_pre_length;
		my($trim_pre_start, $trim_pre_end) = (
			strip_literal(substr $mb_squeezed, 0, 30),
			strip_literal(substr $mb_squeezed, -30, 30)
		);
		$udbt->trim_body($miner_id, \$message_body,
			'', '',
			$miner_ref->{post_stories_text},
			$miner_ref->{post_stories_regex},
		);
		my $trim_post_length = length($message_body);
		$mb_squeezed = $message_body; $mb_squeezed =~ s/\s+/ /g;
		my $post_trimmed_chars = $trim_pre_length - $trim_post_length;
		my($trim_post_start, $trim_post_end) = (
			strip_literal(substr $mb_squeezed, 0, 30),
			strip_literal(substr $mb_squeezed, -30, 30)
		);
		
		# Vague attempt to line up the numerics here. Straighten out
		# in templates.
		#$orig_length = substr("	    $orig_length", -6, 6);
		#$orig_length =~ s/ /\&nbsp;/g;
		
		#$pre_trimmed_chars = substr("	  $pre_trimmed_chars", -6, 6);
		#$pre_trimmed_chars =~ s/ /\&nbsp;/g;
		
		#$post_trimmed_chars = substr("	   $post_trimmed_chars", -6, 6); 
		#$post_trimmed_chars =~ s/ /\&nbsp;/g;
		
		my $count = 0;
		my $regexp = 
			'(.{0,10}<a\s+[^>]*href="?)([^">]+)("?[^>]*>.{0,10})';
		my @tags;
		while ($mb_squeezed =~ m/$regexp/gi) {
			$count++;
			my $tag_node = [$count, $1, $2, $3]; 
			$_ = HTML::Entities::encode($_) for @{$tag_node}[1..3];
			push @tags, $tag_node;
		}

		slashDisplay('show_miner_url_info', { 
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
			$slashdb, $form, $user, $udbt, $_
		) if $_;
	}
}

#################################################
sub show_miner_rel_info {
	my ($slashdb, $form, $user, $udbt, @url_ids) = @_;

	return if !@url_ids;
	my $ar = $udbt->getURLRelationships(\@url_ids, 100);

	for (@{$ar}) {
		if ($_->{url} =~ /^nugget:/) {
			$_->{url_nugget} = 1;
			my $info_ref = $udbt->nugget_url_to_info($_->{url});
			$_->{slug} = $info_ref->{slug};
			$_->{source} = $info_ref->{source};
			$_->{url} = $info_ref->{url};
			$_->{title} ||= $info_ref->{title};

		} else {
			warn getData('show_miner_rel_info', {
				url_id 		=> $_->{url_id},
				url_id_list 	=> \@url_ids 
			});
		}
	}

	slashDisplay('show_miner_rel_info', { 
		arrayref 	=> $ar,
	});
}

##################################################################
sub editUrl {
	my ($slashdb, $form, $user, $udbt, $urlid) = @_;
	my($new_url, $titlebar_type);
        $urlid ||= $form->{url_id};

	if ($urlid eq 'new' || $urlid eq 'newurl') {
		$new_url = $form->{newurl};
		$new_url = $udbt->canonical($new_url);
		$urlid = $udbt->url_to_id($new_url);

		$titlebar_type = 'added';
		if (!$urlid) {
			$udbt->add_url($new_url);
			$urlid = $udbt->url_to_id($new_url);
			$udbt->correlate_miner_to_urls('none', $new_url)
				if $urlid;
		} else {
			$titlebar_type = 'existing';
		} 
	} else {
		$titlebar_type = 'editing';
	}

	my ($url_id, $url, $title, $miner_id, $last_attempt, $last_success,
	    $status_code, $reason_phrase, $message_body_length) =
		$udbt->getURLData($urlid);

	my $miner_name;
	$miner_name = $udbt->id_to_minername($miner_id) if $miner_id;

	my $ar = $udbt->getURLRelationCount($url_id);

	slashDisplay('editUrl',{ 
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
		referencing		=> $ar ? scalar @{$ar} : 0,
		titlebar_type		=> $titlebar_type,
	});
			
	show_miner_rel_info(@_, $url_id);
}

##################################################################
sub newUrl {
	my ($slashdb, $form, $user, $udbt) = @_;

	editUrl(@_, 'newurl');
}

##################################################################
sub updateUrl {
	my ($slashdb, $form, $user, $udbt) = @_;

	if ($form->{deleteurl}) {

		(my $url_id = $form->{url_id}) =~ s/\D//g;
		if ($url_id) {
			my $url = $udbt->id_to_url($url_id);
	        	$udbt->deleteURL($url_id) if $url_id;
	
			slashDisplay('updateUrl', { 
				url_id => $url_id, url => $url 
			});	
		}
		listUrls(@_);
		
	} elsif ($form->{requesturl}) {

		my $url_id = $form->{url_id};
		my $url = $udbt->id_to_url($url_id);
		my $start_time = Time::HiRes::time();
		my $duration = 
			int((Time::HiRes::time() - $start_time)*1000+0.5)/1000;

		# Makes HTTP request.
		$udbt->request(
			$url_id, 
			$url, 
			{}, 
			{}, 
			{},
			{ force_request => 1 }
		);

		slashDisplay('updateUrl', {
			url_id	=> $url_id, 
			duration=> $duration
		});	

		editUrl(@_,$url_id);

	} else { 
		my $miner_name = $form->{miner_name};
		my $miner_id = $udbt->minername_to_id($form->{miner_name});
		my $url_id = $form->{url_id};
		my $url = $udbt->id_to_url($url_id);

		if ($miner_id) {
			$udbt->correlate_miner_to_urls($miner_name, $url);
		} else {
			$udbt->add_miner_and_urls(
				$miner_name, $user->{aid},
				'', '', '', '', '', 'put your regex here', '',
				$url);
		}

		slashDisplay('updateUrl', {
			url_id		=> $url_id, 
			miner_name	=> $miner_name
		});	

		editUrl(@_, $url_id);
	}
}

##################################################################
sub listSpiders {
	my ($slashdb, $form, $user, $udbt) = @_;

	# We may need to work on the classing here, some punctuation may be
	# allowed in minor names.
	$form->{like} =~ s/\W//g;

	slashDisplay('listSpiders', {
		arrayref => $udbt->getSpiderList($form->{like})
	});
}

##################################################################
sub editSpider {
	my ($slashdb, $form, $user, $udbt, $spider_id) = @_;
        ($spider_id ||= $form->{spider_id}) =~ s/\D//g;

	my($name, $last_edit, $last_edit_aid, $conditions, $group_0_selects,
	   $commands) = $udbt->getSpider($spider_id);

	my $timespecs = $udbt->getSpiderTimespecs($spider_id);

	$conditions	=~ s{^\s+}{}gm;	$conditions 	=~ s{\s+$}{}gm;
	$group_0_selects=~ s{^\s+}{}gm;	$group_0_selects=~ s{\s+$}{}gm;
	$commands 	=~ s{^\s+}{}gm;	$commands 	=~ s{\s+$}{}gm;

	my ($yyyy, $mon, $dd, $hh, $min, $ss) = 
		$last_edit =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;

	$last_edit = timeCalc("$yyyy-$mon-$dd $hh:$min:$ss");
        
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
	my ($slashdb, $form, $user, $udbt) = @_;

	# This form processing should be redone in the VERY near future 
	# for flexibility. It should be working now, but adding on
	# to this list will be painful. Maybe $op separate handlers, 
	# but maybe helper functions might be a better solution?
	(my $spider_id = $form->{spider_id}) =~ s/\D//g;
	if ($form->{runspider}) {
		# THIS block is for force-executing a spider.
		my $spider_name = $udbt->getSpiderName($spider_id);

		if ($spider_name) {
			$udbt->{debug} = 1;
			$udbt->spider_by_name($spider_name);
			$udbt->{debug} = 0;
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
			my $rc = $udbt->add_spider($form->{newname});

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
		my $spider_name = $udbt->getSpiderName($spider_id);

		if ($form->{noconfirm}) {
			print getData('update_spider_nodelete');

			editSpider(@_, $spider_id);
			return;
		}

		if ($form->{confirm} eq 'Yes') {
			$udbt->deleteSpider($form->{spider_id});

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
		$udbt->setSpider($spider_id, \%set_clause);

		# Handle the timespecs.
		my %timespecs;
		for (grep { /^timespec_(\d+)_timespec$/ } keys %{$form}) {
			/^timespec_(\d+)_timespec$/;
			next if !defined $1;
			my $id = $1;

			# Test the given timespec.
			eval {
				sub dispatch { };
				
				my $cron = new Schedule::Cron(\&dispatch);
				$cron->get_next_execution_time(
					$form->{"timespec_${id}_timespec"}
				);
			};
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
				timespec=> $form->{"timespec_${id}_timespec"},
				name 	=> $form->{name},
				del	=> $form->{"timespec_${id}_del"},
			};
		}
		$udbt->setSpiderTimespecs($spider_id, \%timespecs);

		print getData('update_spider_savedspider', {
			spider_name => $form->{name},
		});

		editSpider(@_, $spider_id);
	}
}

##################################################################
sub timingDump {
	my ($slashdb, $form, $user, $udbt) = @_;

	$udbt->timing_dump();
}

##################################################################
sub listKeywords {
	my($slashdb, $form, $user, $udbt, $tag) = @_;
	my($keywords);
	$tag ||= $form->{keyword_tag};
	
	my $valid_tags	= $udbt->getKeywordTags();
	$keywords = $udbt->getTagKeywords($tag) if $tag;

	slashDisplay('listKeywords', {
		valid_tags	=> $valid_tags,
		keywords	=> $keywords,
	});
}

##################################################################
sub editKeyword {
	my($slash, $form, $user, $udbt, $kw_id) = @_;
	my($keyword_data);
	$kw_id = $form->{keyword_id} if !defined $kw_id;

	if ($kw_id) {
		$keyword_data = $udbt->getKeyword($kw_id) if $kw_id;
	} else {
		$keyword_data = {
			tag	=> $form->{keyword_tag},
		};
	}
	
	slashDisplay('editKeyword', {
		kw_id	=> $kw_id,
		data	=> $keyword_data,
	});
}

##################################################################
sub updateKeyword {
	my($slash, $form, $user, $udbt) = @_;

	my $kw_id = $form->{keyword_id};

	if (!(	$form->{keyword_weight} && 
		$form->{keyword_tag} &&
		$form->{keyword_regex} ))
	{
		print getData('updateKeyword_emptyfields');

		editKeyword(@_, $kw_id);
	}

	# Pass off to proper op handler if certain form targets are set.
	if ($form->{deletekeyword} or $form->{addkeyword}) {
		deleteKeyword(@_) if $form->{deletekeyword};
		addKeyword(@_)	  if $form->{addkeyword};

		return;
	}

	# Basic update logic.
	my $new_id = $udbt->setKeyword($kw_id, {
		regex	=> $form->{keyword_regex},
		tag	=> $form->{keyword_tag},
		weight	=> $form->{keyword_weight},
	});

	print getData('updateKeyword_kwsaved', { new_id => $new_id });
	editKeyword(@_, $new_id || $kw_id);
}

##################################################################
sub addKeyword {
	my($slash, $form, $user, $udbt) = @_;

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
	my($slash, $form, $user, $udbt) = @_;
	(my $kw_id = $form->{keyword_id}) =~ s/\D//g;

	if ($form->{noconfirm}) {
		print getData('deleteKeyword_noconfirm');

		editKeyword(@_, $kw_id);
		return;
	}

	if (!$form->{confirm}) {
		print getData('deleteKeyword_confirm');

		editKeyword(@_, $kw_id);
		return;
	}

	if ($form->{confirm} eq 'Yes') {
		$udbt->deleteKeyword($kw_id);

		print getData('deleteKeyword_deleted');
	}
	listKeywords(@_, $form->{keyword_tag});
}

##################################################################
sub main {
	my $udbt	= getObject('Slash::NewsVac');
	my $slashdb	= getCurrentDB();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();

	$slashdb->getSection('newsvacadmin');

	header("vacSlash $user->{tzcode} $user->{offset}");

	my $op = $form->{op};
	my $required_seclev = getCurrentStatic('newsvac_admin_seclev');

	my $ops = {

		listminers => {
			function=> \&listMiners,
			seclev	=> $required_seclev,
		},
		newminer  => {
			function=> \&updateMiner,
			seclev	=> $required_seclev,
		},
		editminer => {
			function=> \&editMiner,
			seclev	=> $required_seclev,
		},
		updateminer => {
			function=> \&updateMiner,
			seclev	=> $required_seclev,
		},

		listurls => {
			function=> \&listUrls,
			seclev	=> $required_seclev,
		},
		processurls => {
			function=> \&processUrls,
			seclev	=> $required_seclev,
		},
		newurl => {
			function=> \&newUrl,
			seclev	=> $required_seclev,
		},
		editurl => {
			function=> \&editUrl,
			seclev	=> $required_seclev,
		},
		updateurl => {
			function=> \&updateUrl,
			seclev	=> $required_seclev,
		},

		listspiders => {
			function=> \&listSpiders,
			seclev	=> $required_seclev,
		},
		editspider => {
			function=> \&editSpider,
			seclev	=> $required_seclev,
		},
		updatespider => {
			function=> \&updateSpider,
			seclev	=> $required_seclev,
		},

		timingdump => {
			function=> \&timingDump,
			seclev	=> $required_seclev,
		},

		listkeywords => {
			function=> \&listKeywords,
			sevlev 	=> $required_seclev,
		},
		editkeyword	=> {
			function=> \&editKeyword,
			seclev	=> $required_seclev,
		},
		updatekeyword	=> {
			function=> \&updateKeyword,
			seclev	=> $required_seclev,
		},
		deletekeyword	=> {
			function=> \&deleteKeyword,
			seclev	=> $required_seclev,
		},
		addkeyword	=> {
			function=> \&addKeyword,
			seclev	=> $required_seclev,
		},

		default => {
			function=> \&listMiners,
			seclev  => $required_seclev,
		}
	};

	$op ||= '';
	$op = 'default' if !($op && exists $ops->{$op});
	if ($op) {
		my @args = ($slashdb, $form, $user, $udbt);
		if (exists $ops->{$op}) {
			# Currently $slashdb isn't used in any of our
			# dispatchers, but this may not always be the case.
			if ($user->{seclev} >= $ops->{$op}{seclev}) {
				$ops->{$op}{function}->(@args);
			} else {
				print getData('invalid_seclev');
			}
		} else {
			print getData('invalid_op');
			$ops->{default}{function}->(@args);
		}
	}
	print getData('noop') if ! $op;

	# Display who is logged in right now.
	footer();
}

sub notDoneYet {
	my($slashdb, $form, $user, $udbt) = @_;

	titlebar('100%', <<EOT);
Op '$form->{op}' -- This functionality hasn't been written yet!
EOT

	listMiners(@_);
}


main();
1;

