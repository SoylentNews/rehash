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

use vars qw(%nvdescriptions);

$| = 1;

##################################################################
sub listMiners {
	my ($slashdb, $form, $user, $udbt) = @_;

	$udbt->timing_clear();

        my ($miner_ar, $miner_arrayref, %rel_week_count, %nuggets_day_count);

        $miner_arrayref = $slashdb->sqlSelectAll(
                "miner.miner_id, count(rel.rel_id)",
                "miner, rel",
                "rel.type = miner.name
                AND rel.parse_code = 'miner'
                AND rel.first_verified > DATE_SUB(NOW(), INTERVAL 7 DAY)",
                "GROUP BY miner.miner_id
                ORDER BY name"
        );
        $rel_week_count{$_->[0]} = $_->[1] for @{$miner_arrayref};

	for (1, 3, 7) {
		$miner_arrayref = $slashdb->sqlSelectAll(
			'miner.miner_id, AVG(url_analysis.nuggets)',

			'miner, url_info, url_analysis',
			
			"url_info.miner_id = miner.miner_id AND
			 url_info.url_id = url_analysis.url_id AND
			 url_analysis.ts > DATE_SUB(NOW(), INTERVAL $_ DAY)",

			'GROUP BY miner.miner_id ORDER BY miner.name'
		);

		for $miner_ar (@$miner_arrayref) {
			my ($miner_id, $nuggets_day_count) = @{$miner_ar};
			$nuggets_day_count{$miner_id}{$_} =
				int($nuggets_day_count + 0.5);
		}
	}

        $miner_arrayref = $slashdb->sqlSelectAllHashrefArray(
                "miner.miner_id, name, last_edit, last_edit_aid, owner_aid,
                progress, comment, count(url_info.url_id) as url_count", 
                "miner, url_info",
                "url_info.miner_id = miner.miner_id",
                "GROUP BY miner.miner_id ORDER BY name"
        );

	my $i = 0;
	for my $href (@{$miner_arrayref}) {
		my $mi = $href->{miner_id};

		$href->{url_number_highlite} = 
			$rel_week_count{$mi} > $href->{url_count} * 60;
		
		$href->{nugget_numbers} = join(",",
			map { $_ || 0 } @{$nuggets_day_count{$mi}}{1,3,7},
		);

        	$href->{last_edit} =~ 
			/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;
        	my ($yyyy, $mon, $dd, $hh, $min, $ss) = 
			($1, $2, $3, $4, $5, $6);
		$href->{last_edit_formatted} = "$yyyy-$mon-$dd $hh:$min";

		$href->{week_count} = $rel_week_count{$mi} || 0;

                $href->{comment} = substr($href->{comment}, 0, 25) . "..."
			if length($href->{comment}) > 30;
		$href->{comment} = HTML::Entities::encode($href->{comment});

		$href->{newrow} = 1 if $i % 5 == 4 and 
				       $i++ < $#{$miner_arrayref} - 2;
        }

	slashDisplay('listMiners', { 
		miners 			=> $miner_arrayref,
		nugget_day_count	=> \%nuggets_day_count,
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
       	my $miner = $slashdb->sqlSelectHashref(
		'*', 'miner', 'miner_id=' . $slashdb->sqlQuote($miner_id)
        );

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
		$slashdb->getDescriptions(
			'progresscodes', '', 1, \%nvdescriptions
		),
		$miner->{progress}, 
		1
	);   

	my $authors = $slashdb->getDescriptions(
		'authornames', '', 1, \%nvdescriptions
	);
	my $owner_aid_menu = createSelect(
		'owner_aid', $authors, $miner->{owner_aid}, 1, 0, 1
	);   

        my $url_ar = $slashdb->sqlSelectAll(
		'url_id, url',
		'url_info',
		"miner_id='$miner_id'", 
		'ORDER BY url'
        );

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

	show_miner_url_info($slashdb, $form, $user, $udbt, $miner_id, $force);
}

##################################################################
sub updateMiner {
	my ($slashdb, $form, $user, $udbt) = @_;
	my $miner_id = $form->{miner_id} || 0;

        if ($form->{op} eq 'newminer') {
		# Get miner name from the form, or set an appropriate default.
        	my $name = $form->{newname} ||
			   'miner' . time . int(rand(900)+100);
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

       		# Prepend the "(?i)" unless this field is marked case_sensitive.
        	for my $field (grep /_(text|regex)$/, keys %{$form}) {
        		$form->{$field} = "(?i)$form->{$field}"
				if $form->{$field} and !$form->{"${field}_cs"};
        	}
        	$form->{last_edit_aid} = $user->{nickname};
		warn getData('miner_update_warning', {
			id => $miner_id, name => $name
		}) if $udbt->{debug} > 0;
        	for (@field_names) { 
			$update_fields{$_} = $form->{$_} if exists $form->{$_};
		}
		$slashdb->sqlUpdate(
			'miner', 
			\%update_fields, 
			"miner_id=$miner_id"
		);

		slashDisplay('updateMiner', { name => $name });

		warn "editMiner '$miner_id' forceupdate '$form->{forceupdate}'";
                editMiner(@_, $miner_id, $form->{forceupdate});

        } elsif ($form->{deleteminer}) {
        	my $miner_id = $miner_id;
        	my $name = $udbt->id_to_minername($miner_id);
	        my $url_ar = $slashdb->sqlSelectAll(
			"url_id, url",
	        	"url_info",
	        	"miner_id = '$miner_id'",
	        	"ORDER BY url"
	        );

	        if (@$url_ar) {
	        	# This should probably just say "Are you sure?" and then the
	        	# "delete2" action should zero out all the URLs that use it.
	        	# But for now, just forbid this.
			slashDisplay('updateMiner', { name => $name, num => scalar(@$url_ar), url_ar => $url_ar });

	        	editMiner(@_,$miner_id);
	        } else {
	        	$slashdb->sqlDo("DELETE FROM miner WHERE miner_id = '$miner_id'");

			slashDisplay('updateMiner', { name => $name, miner_id => $miner_id });

	                listMiners();
	        }
        }
}

##################################################################
sub listUrls {
	my ($slashdb, $form, $user, $udbt) = @_;

	my ($n_urls_total, $n_urls_with_miners) = (
		$slashdb->sqlCount('url_info'),
		$slashdb->sqlCount('url_info', 'miner_id=0')
	);

	my @where = ('miner.miner_id = url_info.miner_id');
	push @where, 'url_info.url LIKE ' .
		     $slashdb->sqlQuote("%$form->{like}%")
	if $form->{like};
	push @where, "miner.owner_aid = '$1'"
		if $form->{owner} and $form->{owner} =~ /(\w{1,20})/;
	my $where = join ' AND ', @where;
	
	my $limit = 500;
	$limit = $1 if $form->{limit} and $form->{limit} =~ /(\d+)/;
	$limit = 1 if $limit < 1; $limit = 9999 if $limit > 9999;
	my $start = 0;
	$start = $1 if $form->{start} and $form->{start} =~ /(\d+)/;
	$limit = "$start,$limit" if $start;

        my $url_arrayref = $slashdb->sqlSelectAllHashrefArray(
	        'url_info.url_id, url_info.url, url_info.is_success,
		url_info.last_success, miner.miner_id, miner.name,
	        length(url_message_body.message_body)',
		
		'url_info, miner LEFT JOIN url_message_body
	        ON url_info.url_id = url_message_body.url_id',

	        $where,

	        "ORDER BY url_info.url LIMIT $limit"
        );

        for (@{$url_arrayref}) {
		$_->{is_success} = $_->{is_success} == 0;
		$_->{last_success_formatted} = timeCalc($_->{last_success})
			if $_->{last_success};

                my $ref_cnt = $slashdb->sqlCount(
                	'rel',
			"from_url_id=$_->{url_id} AND
			 parse_code='miner'",
			'GROUP BY to_url_id'
                );
                $_->{referencing} = $ref_cnt,
	}
	
	slashDisplay('listUrls', { 
		urls_total		=> $n_urls_total,
		urls_with_miners	=> $n_urls_with_miners,
		urls			=> $url_arrayref,
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

	my $urls_ar = $slashdb->sqlSelectColArrayref(
		'url_id',
		'url_info',
		'miner_id=' . $slashdb->sqlQuote($miner_id)
	);

	my $start_time = Time::HiRes::time();
	my %conditions;
	if ($force) {
		%conditions = (
			force_request		=> 1,
			force_analyze_miner	=> 1,
		);
	} else {
		%conditions = (
			use_current_time	=> time()-3600,
			force_analyze_miner	=> 1,
			timeout			=> 5,
		);
	}

	print getData('processing_urls', { url_ids => $urls_ar });
	$udbt->process_url_ids(\%conditions, @{$urls_ar});
	my $duration = int((Time::HiRes::time() - $start_time)*1000+0.5)/1000;
	print getData('processed_urls', { 
		url_ids => $urls_ar, 
		dur => $duration,
	});

	my $miner_ref = $slashdb->sqlSelectHashref(
		'pre_stories_text, pre_stories_regex,
		 post_stories_text, post_stories_regex',
		'miner', 'miner_id=' . $slashdb->sqlQuote($miner_id)
	);

	for (@{$urls_ar}) {
		# Previously this was a sqlSelectAll(). We only use one record 
		# anyways, so why not give the dB a break.
		my $ar = $slashdb->sqlSelectArrayRef(
			'url, message_body',
			'url_info, url_message_body',
			"url_info.url_id=$_ and url_message_body.url_id=$_"
		);
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
		$orig_length = substr("	    $orig_length", -6, 6);
		$orig_length =~ s/ /\&nbsp;/g;
		
		$pre_trimmed_chars = substr("	  $pre_trimmed_chars", -6, 6);
		$pre_trimmed_chars =~ s/ /\&nbsp;/g;
		
		$post_trimmed_chars = substr("	   $post_trimmed_chars", -6, 6); 
		$post_trimmed_chars =~ s/ /\&nbsp;/g;
		
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
			tags => \@tags, 
			duration => $duration,
			url => $url,  
			orig_length => $orig_length,
			orig_start => $orig_start,
			orig_end => $orig_end,
			pre_trimmed_chars => $pre_trimmed_chars,
			trim_pre_start => $trim_pre_start,
			trim_pre_end => $trim_pre_end,
			post_trimmed_chars => $post_trimmed_chars,
			trim_post_start	=> $trim_post_start,
			trim_post_end	=> $trim_post_end,
		});

		show_miner_rel_info(
			$slashdb, $form, $user, $udbt, $_
		);
	}
}

#################################################
sub show_miner_rel_info {
	# 1.x code never passes more than one url_id. Why the array?
	my ($slashdb, $form, $user, $udbt, @url_ids) = @_;

	return if !@url_ids;
	my $max_results = 100;

	my $where_clause = sprintf "(%s) AND
		 	 	    rel.to_url_id = url_info.url_id AND
				    parse_code = 'miner'",

				    join ' OR ', map { "rel.from_url_id=$_" } 
				    		 @url_ids;

	my $ar = $slashdb->sqlSelectAllHashrefArray(
		"url_info.url_id, url_info.url, url_info.title,
		 url_info.last_attempt, url_info.last_success",
		 
		'url_info, rel',

		$where_clause,

		"ORDER BY rel.from_url_id, url_info.url_id LIMIT $max_results"
	);

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
		max_results	=> $max_results,
	});
}

##################################################################
sub editUrl {
	my ($slashdb, $form, $user, $udbt, $urlid) = @_;
	my($new_url, $titlebar_type);
        $urlid ||= $form->{url_id};

        if ($urlid eq "new") {
        	$new_url = $form->{newurl};
        	$new_url = $udbt->canonical($new_url);
		$urlid = $udbt->url_to_id($new_url);

		$titlebar_type = 'added';
		if (!$urlid) {
			$udbt->add_url($new_url);
			$urlid = $udbt->url_to_id($new_url);
			$udbt->correlate_miner_to_urls('none', $new_url)
				if $urlid;
			$titlebar_type = 'existing';
	        } 
	} else {
		$titlebar_type = 'editing';
	}

	my ($url_id, $url, $title, $miner_id, $last_attempt, $last_success,
	$status_code, $reason_phrase, $message_body_length ) =
		$slashdb->sqlSelect(
        		'url_info.url_id, url_info.url, url_info.title,
			 url_info.miner_id, url_info.last_attempt, 
			 url_info.last_success, url_info.status_code, 
			 url_info.reason_phrase,
			 length(url_message_body.message_body)',

        		'url_info
        		LEFT JOIN url_message_body ON
			url_info.url_id = url_message_body.url_id',

        		'url_info.url_id = ' . $slashdb->sqlQuote($urlid)
		);

	my $miner_name;
	$miner_name = $udbt->id_to_minername($miner_id) if $miner_id;

	my $ar = $slashdb->sqlSelectColArrayref(
		'count(*)', 'rel', 
		'from_url_id=' . $slashdb->sqlQuote($url_id) . " AND
		 parse_code = 'miner'",
		'GROUP BY to_url_id'
	);

	my $referencing = ($ar ? scalar(@$ar) : 0);

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
		referencing		=> $referencing,
		titlebar_type		=> $titlebar_type,
	});
			
	show_miner_rel_info(@_, $url_id);
}

##################################################################
sub updateUrl {
	my ($slashdb, $form, $user, $udbt) = @_;

        if ($form->{deleteurl}) {

		my $url_id = $form->{url_id};
		my $url = $udbt->id_to_url($url_id);
        	$udbt->delete_url_ids($url_id) if $url_id;
		
		slashDisplay('updateUrl', { url_id => $url_id, url => $url });	

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
			url_id => $url_id, 
			duration => $duration
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
			url_id => $url_id, 
			miner_name => $miner_name
		});	

		editUrl(@_,$url_id);
	}
}

##################################################################
sub listSpiders {
	my ($slashdb, $form, $user, $udbt) = @_;

	my $where;
	$where = "name LIKE " . $slashdb->sqlQuote("%$form->{like}%")
		if $form->{like};

        my $spider_arrayref = $slashdb->sqlSelectAllHashrefArray(
	        'spider_id, name, last_edit, last_edit_aid, conditions, 
		 group_0_selects, commands',
	        'spider',
	        $where,
	        'LIMIT 50'
        );

        for (@$spider_arrayref) {
        	my $a = $_->{last_edit} =~
			/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/;

                $_->{last_edit_formatted} = timeCalc("$1-$2-$3 $4:$5:$6")
			if $a
        }
	slashDisplay('listSpiders', { arrayref => $spider_arrayref });
}

##################################################################
sub editSpider {
	my ($slashdb, $form, $user, $udbt, $spider_id) = @_;

        $spider_id ||= $form->{spider_id};

        my $spider_arrayref = $slashdb->sqlSelectAll(
        	"name, last_edit, last_edit_aid,
            	conditions, group_0_selects, commands",
        	"spider",
        	"spider_id = '$spider_id'"
        );

        my $spider_ar = $spider_arrayref->[0];

       	my ($name, $last_edit, $last_edit_aid,
       		$conditions, $group_0_selects, $commands) = @$spider_ar;

	$conditions =~ s{^\s+}{}gm;		$conditions =~ s{\s+$}{}gm;
	$group_0_selects =~ s{^\s+}{}gm;	$group_0_selects =~ s{\s+$}{}gm;
	$commands =~ s{^\s+}{}gm;		$commands =~ s{\s+$}{}gm;

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
	});
				
}

##################################################################
sub updateSpider {
	my ($slashdb, $form, $user, $udbt) = @_;

        if ($form->{updatespider}) {
        	my $spider_id = $form->{spider_id};
        	my %set_clause;

        	$form->{last_edit_aid} = $user->{nickname};
		$set_clause{$_} = $form->{$_} for qw(
			name 
			last_edit_aid 
			conditions 
			group_0_selects 
			commands
		);

        	$slashdb->sqlUpdate('spider',
			\%set_clause, "spider_id = '$spider_id'"
        	);

		slashDisplay('updateSpider');
                editSpider(@_, $spider_id);
        } elsif ($form->{runspider}) {
        	my $spider_id = $form->{spider_id};
        	my ($spider_name) = $slashdb->sqlSelect(
			'name', 
			'spider', 
			"spider_id=$spider_id"
		);

        	if ($spider_name) {
        		$udbt->{debug} = 1;
	        	$udbt->spider_by_name($spider_name);
        		$udbt->{debug} = 0;
	        }
		slashDisplay('updateSpider', { spider_name => $spider_name });
                editSpider(@_,$spider_id);
        }
}

##################################################################
# Not part of NewsVac, should be pulled into it's own plugin.
#
#  Archive Editor
sub archEdit {
	my ($slashdb, $form, $user, $udbt, $name) = @_;

	my ($archItem);
	$form->{name} = '' if $form->{newarchive};
	$name ||= $form->{name};

	my $names = $slashdb->sqlSelectMany('name, name','archives');
	my $archive_select = createSelect('name', $names, $name, 1);

	# Determine next operation based on current one.
	my $nextop = 'savearchive';
	$nextop = 'editarchive' if !$name && !$form->{newarchive};

	$archItem = $slashdb->sqlSelectHashref('*', 'archives', 'name=' . $slashdb->sqlQuote($name)) if $name;

	$archItem = {} if $form->{newarchive};

	slashDisplay('archEdit', {
			archItem	=> $archItem,
			nextop		=> $nextop,
	});
}

##################################################################
# Not part of NewsVac, should be pulled into it's own plugin.
#
# Save Archive data.
sub archSave {
	my ($slashdb, $form, $user, $udbt) = @_;

	$form->{thisname} = '' if $form->{newarchive};
	if ($form->{editarchive}) {
		$form->{savearchive} = '';
		$form->{thisname} = $form->{name};
	}

	if ($form->{newarchive} || $form->{editarchive}) {
		return;
	} elsif ($form->{thisname}) {
		my ($exists) = $slashdb->sqlSelect(
			'1', 'archives',
			'name=' . $slashdb->sqlQuote($form->{thisname})
		);

		if (!$exists && !$form->{delarch_confirm}) {
			$slashdb->sqlInsert('archives', { 
				name => $form->{thisname},
			});
		}

		if ($form->{delarch_confirm}) {
			$slashdb->sqlDo(
				'DELETE from archives WHERE name=' . 
				$slashdb->sqlQuote($form->{thisname})
			);
		} else {
			$slashdb->sqlUpdate('archives', {
				title 		=> $form->{title},
				image_regexp 	=> $form->{image_regexp},
				location	=> $form->{location},
				url_location	=> $form->{url_location},
				year		=> $form->{year_backref},
				month		=> $form->{month_backref},
				'date'		=> $form->{day_backref},
				template	=> $form->{template}
			}, 'name=' . $slashdb->sqlQuote($form->{thisname}));
			$form->{editarchive} = 1;
		}
	}
	archEdit(@_, $form->{thisname});
}


##################################################################
sub main {
	my $udbt	= getObject('Slash::NewsVac');
	my $slashdb	= getCurrentDB();
	my $user	= getCurrentUser();
	my $form	= getCurrentForm();

	# We use custom descriptions with derivative names since we are using
	# variants based on the 1.x scheme, for now.
	%nvdescriptions = (
		'authornames' => sub {
			$_[0]->sqlSelectMany(
				'nickname,nickname', 
				'authors_cache'
			) 
		},

		'progresscodes' => sub {
			$_[0]->sqlSelectMany(
				'name,name', 'code_param', "type='nvprogress'"
			)
		},
	);

	$slashdb->getSection('newsvacadmin');

	header("vacSlash $user->{tzcode} $user->{offset}");

	my $op = $form->{op};

	my $ops = {
		listminers => {
			function => \&listMiners,
			seclev	=> 10000,
		},
		editminer => {
			function => \&editMiner,
			seclev	=> 10000,
		},
		updateminer => {
			function => \&updateMiner,
			seclev	=> 10000,
		},
		listurls => {
			function => \&listUrls,
			seclev	=> 10000,
		},
		processurls => {
			function => \&processUrls,
			seclev	=> 10000,
		},
		newurl => {
			function => \&editUrl,
			seclev	=> 10000,
		},
		editurl => {
			function => \&editUrl,
			seclev	=> 10000,
		},
		updateurl => {
			function => \&updateUrl,
			seclev	=> 10000,
		},
		listspiders => {
			function => \&listSpiders,
			seclev	=> 10000,
		},
		editspider => {
			function => \&editSpider,
			seclev	=> 10000,
		},
		updatespider => {
			function => \&updateSpider,
			seclev	=> 10000,
		},

		# this doesn't seem to exist
		listnuggets => {
			#function => \&listNuggets,
			function => \&notDoneYet,
			seclev	=> 10000,
		},
		
		# this doesn't seem to exist
		editnugget => {
			#function => \&editNugget,
			function => \&notDoneYet,
			seclev	=> 10000,
		},
		
		# this doesn't seem to exist
		updatenugget => {
			#function => \&updateNugget,
			function => \&notDoneYet,
			seclev	=> 10000,
		},

		timingdump => {
			function => \$udbt->timing_dump,
			seclev	=> 10000,
		},
	};

	$op ||= 'listminers';
	if ($op) {
		$op = '' unless $user->{seclev} >= $ops->{$op}{seclev};
		$ops->{$op}{function}->($slashdb, $form, $user, $udbt) if $op;
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

