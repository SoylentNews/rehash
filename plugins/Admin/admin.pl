#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2002 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Time::HiRes;
use Image::Size;
use POSIX qw(O_RDWR O_CREAT O_EXCL tmpnam);

use Slash;
use Slash::Display;
use Slash::Hook;
use Slash::Utility;

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $postflag = $user->{state}{post};
	# lc just in case
	my $op = lc($form->{op});

	my($tbtitle);

	my $ops = {
		slashd		=> {
			function	=> \&displaySlashd,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'slashd',
		},
		edit_keyword	=> {
			function	=> \&editKeyword,
			seclev		=> 10000,
		},
		save		=> {
			function	=> \&saveStory,
			seclev		=> 100,
			tab_selected	=> 'stories',
		},
		update		=> {
			function	=> \&updateStory,
			seclev		=> 100,
			tab_selected	=> 'stories',
		},
		list		=> {
			function	=> \&listStories,
			seclev		=> 100,
			tab_selected	=> 'stories',
		},
		default		=> {
			function	=> \&listStories,
			seclev		=> 100,
			tab_selected	=> 'stories',
		},
		'delete'		=> {
			function 	=> \&listStories,
			seclev		=> 10000,
			tab_selected	=> 'stories',
		},
		preview		=> {
			function 	=> \&editStory,
			seclev		=> 100,
		},
		edit		=> {
			function 	=> \&editStory,
			seclev		=> 100,
			tab_selected	=> 'new',
		},
		blocks 		=> {	# blockdelete_cancel,blockdelete_confirm,
					# blockdelete1,blockdelete2,blocksave,
					# blockrevert,blocksavedef,blockdelete,blocknew,
			function 	=> \&blockEdit,
			seclev		=> 500,
			adminmenu	=> 'config',
			tab_selected	=> 'blocks',
		},
		colors 		=> {	# colored,colorpreview,colorsave,colorrevert,
					# colororig,colorsavedef,

			function 	=> \&colorEdit,
			seclev		=> 10000,
			adminmenu	=> 'config',
			tab_selected	=> 'colors',
		},
		listfilters 	=> {
			function 	=> \&listFilters, # listfilters
			seclev		=> 100,
			adminmenu	=> 'config',
			tab_selected	=> 'filters',
		},
		editfilter	=> {
			function 	=> \&editFilter, # newfilter,updatefilter,deletefilter,
			seclev		=> 100,
			adminmenu	=> 'config',
			tab_selected	=> 'filters',
		},
		siteinfo	=> {
			function 	=> \&siteInfo,
			seclev		=> 10000,
			adminmenu	=> 'info',
			tab_selected	=> 'site',
		},

		templates 	=> { 	# templatedelete_confirm,templatesection,
					# templatedelete_cancel,
					# templatepage,templateed,templatedelete,
					# templatenew,templatesave,

			function 	=> \&templateEdit,
			seclev		=> 500,
			adminmenu	=> 'config',
			tab_selected	=> 'templates',
		},

		topics 		=> {	# topiced,topicnew,topicsave,topicdelete

			function 	=>  \&topicEdit,
			seclev		=> 10000,
			adminmenu	=> 'config',
			tab_selected	=> 'topics',
		},
		vars 		=> {	# varsave, varedit

			function 	=> \&varEdit,
			seclev		=> 10000,
			adminmenu	=> 'config',
			tab_selected	=> 'vars',
		},
		recent		=> {
			function	=> \&displayRecent,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'recent',
		},
		recent_requests		=> {
			function	=> \&displayRecentRequests,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'requests',
		},
	};

	# admin.pl is not for regular users
	if ($user->{seclev} < 100) {
		my $rootdir = getCurrentStatic('rootdir');
		redirect("$rootdir/users.pl");
		return;
	}
	# non suadmin users can't perform suadmin ops
	unless ($ops->{$op}) {
		$op = 'default';
	}
	$op = 'list' if $user->{seclev} < $ops->{$op}{seclev};
	$op ||= 'list';

	if (($form->{op} =~ /^preview|edit$/) && $form->{title}) {
		# Show submission/article title on browser's titlebar.
		$tbtitle = $form->{title};
		$tbtitle =~ s/"/'/g;
		$tbtitle = " - \"$tbtitle\"";
		# Undef the form title value if we have SID defined, since the editor
		# will have to get this information from the database anyways.
		undef $form->{title} if ($form->{sid} && $form->{op} eq 'edit');
	}

	my $db_time = $slashdb->getTime();
	my $gmt_ts = timeCalc($db_time, "%T", 0);
	my $local_ts = timeCalc($db_time, "%T");

	my $time_remark = (length $tbtitle > 10)
		? " $gmt_ts"
		: " $local_ts $user->{tzcode} = $gmt_ts GMT";
	# "backSlash" needs to be in a template or something -- pudge
	my $data = {
		admin => 1,
		adminmenu => $ops->{$op}{adminmenu} || 'admin',
		tab_selected => $ops->{$op}{tab_selected},
	};
	header("backSlash$time_remark$tbtitle", '', $data);
	# admin menu is printed from within the 'header' template

	# it'd be nice to have a legit retval
	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants);

	# Display who is logged in right now.
	footer();
	writeLog($user->{uid}, $op, $form->{sid});
}


##################################################################
#  Variables Editor
sub varEdit {
	my($form, $slashdb, $user, $constants) = @_;

	if ($form->{varsave}) {
		varSave(@_);
	}

	my $name = $form->{name};
	my $varsref;

	my $vars = $slashdb->getDescriptions('vars', '', 1);
	$vars->{""} = "";
	my $vars_select = createSelect('name', $vars, $name, 1);

	if ($name) {
		$varsref = $slashdb->getVar($name, '', 1);
	}

	slashDisplay('varEdit', {
		title		=> getTitle('varEdit-title', { name => $name }),
		vars_select 	=> $vars_select,
		varsref		=> $varsref,
	});
}

##################################################################
sub varSave {
	my($form, $slashdb, $user, $constants) = @_;

	if ($form->{thisname}) {
		my $value = $slashdb->getVar($form->{thisname}, '', 1);
		if ($value && $value->{name}) {
			$slashdb->setVar($form->{thisname}, {
				value		=> $form->{value},
				description	=> $form->{desc}
			});
		} else {
			$slashdb->createVar($form->{thisname}, $form->{value}, $form->{desc});
		}

		if ($form->{desc}) {
			print getData('varSave-message');
		} else {
# please don't delete this by just removing comment,
# since we don't even warn the admin this will happen.
#			$slashdb->deleteVar($form->{thisname});
#			print getData('varDelete-message');
		}
	}
}

##################################################################
sub siteInfo {
	my($form, $slashdb, $user, $constants) = @_;

	my $plugins = $slashdb->getDescriptions('plugins');
	my $site_info = $slashdb->getDescriptions('site_info');

	slashDisplay('siteInfo', {
		plugins 	=> $plugins,
		site_info	=> $site_info,
	});

}

##################################################################
sub pageEdit {
	my($seclev, $page) = @_;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	my $pages = $slashdb->getPages();
	my $pageselect = createSelect('page', $pages, $page, 1);

	slashDisplay('pageEdit', { page => $page });
}

##################################################################
# OK, here's the template editor
# @my_names = grep /^$foo-/, @all_names;
sub templateEdit {
	my($form, $slashdb, $user, $constants) = @_;

	my($seclev, $tpid, $page, $section);
	my $seclev_flag = 1;

	my($title, $templateref, $template_select, $page_select,
		$section_select, $savepage_select, $savesection_select);

	my($templatedelete_flag, $templateedit_flag, $templateform_flag) = 0;
	my $pagehashref = {};
	$title = getTitle('templateEdit-title', {}, 1);
	#Just to punish those section only admins! -Brian
	$form->{section} = $user->{section} if $user->{section};

	if ($form->{templatenew} || $form->{templatepage} || $form->{templatesection}) {
		$tpid = '';
		$page = $form->{page};
		$section = $form->{section};

	} elsif ($form->{templatesave} || $form->{templatesavedef}) {
		if ($form->{save_new}) {
			$section = $form->{newS} ? $form->{newsection} : $form->{section};
			$page = $form->{newP} ? $form->{newpage} : $form->{page};
		} else {
			$section = $form->{newS} ? $form->{newsection} : $form->{savesection};
			$page = $form->{newP} ? $form->{newpage} : $form->{savepage};
		}

	
		my $templateref = $slashdb->getTemplate($form->{thistpid}, '', 1);
		if ( $templateref->{seclev} <= $user->{seclev}) {
			templateSave($form->{thistpid}, $form->{name},  $page, $section);
		} else {
			print getData('seclev-message', { name => $form->{name}, tpid => $form->{thistpid} });
		}

		$tpid = $form->{thistpid};

	} elsif ($form->{templatedelete_confirm}) {
		my $templateref = $slashdb->getTemplate($form->{deletetpid}, '', 1);
		if ($templateref->{seclev} <= $user->{seclev}) {
			templateDelete($form->{deletename}, $form->{deletetpid});
			print getData('templateDelete-message', { name => $form->{deletename}, tpid => $form->{deletepid} });
		} else {
			print getData('seclev-message', { name => $form->{deletename}, tpid => $form->{deletepid} });
		}

	} else {
		$tpid = $form->{tpid};
		$page = $form->{page};
		$section = $form->{section};
	}

	$page ||= 'misc';
	$section ||= 'default';

	$templateref = $slashdb->getTemplate($tpid, '', 1) if $tpid;
	$seclev_flag = 0 if $templateref->{seclev} > $user->{seclev};

	if ($form->{templatedelete}) {
		$templatedelete_flag = 1;
	} else {
		my $templates = {};

		if ($form->{templatesection}) {
			if ($section eq 'All') {
				$templates = $slashdb->getTemplateList('', $page);
			} else {
				$templates = $slashdb->getTemplateList($section);
			}
		} else {
			if ($page eq 'All') {
				$templates = $slashdb->getTemplateList();
			} else {
				$templates = $slashdb->getTemplateList('', $page);
			}
		}

		my $pages = $slashdb->getDescriptions('pages', $page, 1);
		my $sections = $slashdb->getDescriptions('templatesections', $section, 1);

		$pages->{All} = 'All';
		$pages->{misc} = 'misc';
		$sections->{default} = 'default';
		$sections->{All} = 'All';

		# put these in alpha order by label, and add tpid to label
		my @ordered;
		for (sort { $templates->{$a} cmp $templates->{$b} } keys %$templates) {
			push @ordered, $_;
			$templates->{$_} = $templates->{$_} . " ($_)";
		}

		$page_select = createSelect('page', $pages, $page, 1);
		$savepage_select = createSelect('savepage', $pages, $templateref->{page}, 1)
			if $templateref->{tpid};
		$template_select = createSelect('tpid', $templates, $tpid, 1, 0, \@ordered);
		$section_select = createSelect('section', $sections, $section, 1);
		$savesection_select = createSelect('savesection', $sections, $templateref->{section}, 1)
			if $templateref->{tpid};
	}

	if (!$form->{templatenew} && $tpid && $templateref->{tpid}) {
		$templateedit_flag = 1;
	}

	$templateform_flag = 1 if ((! $form->{templatedelete_confirm} && $tpid) || $form->{templatenew});

	slashDisplay('templateEdit', {
		tpid 			=> $tpid,
		title 			=> $title,
		templateref		=> $templateref,
		seclev_flag		=> $seclev_flag,
		templateedit_flag	=> $templateedit_flag,
		templatedelete_flag	=> $templatedelete_flag,
		template_select		=> $template_select,
		templateform_flag	=> $templateform_flag,
		page_select		=> $page_select,
		savepage_select		=> $savepage_select,
		section_select		=> $section_select,
		savesection_select	=> $savesection_select,
	});
}

##################################################################
sub templateSave {
	my($tpid, $name, $page, $section) = @_;

	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	if (!$form->{seclev}) {
		$form->{seclev} = 500;
	} elsif ($form->{seclev} > $user->{seclev}) {
		$form->{seclev} = $user->{seclev};
	}

	my $id = $slashdb->getTemplate($tpid, '', 1);
	my $temp = $slashdb->getTemplateByName($name, [ 'section', 'page', 'name', 'tpid', 'seclev' ], 1 , $page, $section);

	return if $temp->{seclev} > $user->{seclev};
	my $exists = 0;
	$exists = 1 if ($name eq $temp->{name} &&
			$section eq $temp->{section} &&
			$page eq $temp->{page});

	if ($form->{save_new}) {
		if ($id->{tpid} || $exists) {
			print getData('templateSave-exists-message', { tpid => $tpid, name => $name });
			return;
		} else {
			print "trying to insert $name<br>\n";
			($tpid) = ($form->{thistpid}) = $slashdb->createTemplate({
				name		=> $name,
				template        => $form->{template},
				title		=> $form->{title},
				description	=> $form->{description},
				seclev          => $form->{seclev},
				page		=> $page,
				section		=> $section
			});

			print getData('templateSave-inserted-message', { tpid => $tpid , name => $name});
		}
	} else {

		$slashdb->setTemplate($tpid, {
			name		=> $name,
			template 	=> $form->{template},
			description	=> $form->{description},
			title		=> $form->{title},
			seclev		=> $form->{seclev},
			page		=> $page,
			section		=> $section
		});
		print getData('templateSave-saved-message', { tpid => $tpid, name => $name });
	}
}

##################################################################
sub templateDelete {
	my($name, $tpid) = @_;

	my $slashdb = getCurrentDB();

	return if getCurrentUser('seclev') < 500;
	$slashdb->deleteTemplate($tpid);
}

##################################################################
sub blockEdit {
	my($form, $slashdb, $user, $constants) = @_;

	my($bid);
	# Control for section editors when editing blocks -Brian
	$form->{section} = $user->{section} if $user->{section};

	if ($form->{blocksave} || $form->{blocksavedef}) {
		blockSave($form->{thisbid});
		$bid = $form->{thisbid};
		print getData('blockSave-saved-message', { bid => $bid });

	} elsif ($form->{blockrevert}) {
		$slashdb->revertBlock($form->{thisbid});
		$bid = $form->{thisbid};

	} elsif ($form->{blockdelete}) {
		$bid = $form->{thisbid};

	} elsif ($form->{blockdelete1} || $form->{blocked1}) {
		$bid = $form->{bid1};

	} elsif ($form->{blockdelete2} || $form->{blocked2}) {
		$bid = $form->{bid2};

	} elsif ($form->{blockdelete_confirm}) {
		blockDelete($form->{deletebid});
		print getData('blockDelete-message', { bid => $form->{deletebid} });
	}

	my($blockref, $saveflag, $block_select, $retrieve_checked, $all_sections_checked,
		$portal_checked, $block_select1, $block_select2);
	my($blockedit_flag, $blockdelete_flag, $blockform_flag) = (0, 0, 0);
	$blockref = {};

	if ($bid) {
		$blockref = $slashdb->getBlock($bid, '', 1);
	}
	my $sectionbid = $blockref->{section};
	my $rss_templates = $slashdb->getTemplateList('','portald');
	my $rss_ref = { map { ($_, $_) } values %{$rss_templates} };

	$blockref->{rss_template} ||= $constants->{default_rss_template};
	my $rss_select = createSelect('rss_template', $rss_ref, $blockref->{rss_template}, 1);	
	my $template_ref = $slashdb->getTemplateByName($blockref->{rss_template}, [ 'template' ], 1 , 'portald', $blockref->{section});
	my $rss_template_code = $template_ref->{template}; 

	if ($form->{blockdelete} || $form->{blockdelete1} || $form->{blockdelete2}) {
		$blockdelete_flag = 1;
	} else {
		# get the static blocks
		my($static_blocks, $portal_blocks);
		if ($user->{section}) {
			$static_blocks = $slashdb->getDescriptions('static_block_section', { seclev => $user->{seclev}, section => $user->{section} }, 1);
			$portal_blocks = $slashdb->getDescriptions('portald_block_section', { seclev => $user->{seclev}, section => $user->{section} }, 1);
		} else {
			$static_blocks = $slashdb->getDescriptions('static_block', $user->{seclev}, 1);
			$portal_blocks = $slashdb->getDescriptions('portald_block', $user->{seclev}, 1);
		}
		$block_select1 = createSelect('bid1', $static_blocks, $bid, 1);

		$block_select2 = createSelect('bid2', $portal_blocks, $bid, 1);

	}
	my $blocktype = $slashdb->getDescriptions('blocktype', '', 1);
	my $blocktype_select = createSelect('type', $blocktype, $blockref->{type}, 1);

	my $yes_no = $slashdb->getDescriptions('yes_no', '', 1);
	my $autosubmit_select = createSelect('autosubmit', $yes_no, $blockref->{autosubmit}, 1);

	# if the pulldown has been selected and submitted
	# or this is a block save and the block is a portald block
	# or this is a block edit via sections.pl
	if (! $form->{blocknew} && $bid) {
		if ($blockref->{bid}) {
			$blockedit_flag = 1;
			$blockref->{ordernum} = "NA" if $blockref->{ordernum} eq '';
			$retrieve_checked = "CHECKED" if $blockref->{retrieve} == 1;
			$all_sections_checked = "CHECKED" if $blockref->{all_sections} == 1;
			$portal_checked = "CHECKED" if $blockref->{portal} == 1;
		}
	}

	$blockform_flag = 1 if ((! $form->{blockdelete_confirm} && $bid) || $form->{blocknew});

	my $title = getTitle('blockEdit-title', { bid => $bid }, 1);
	$blockref->{items} ||= $constants->{max_items};

	slashDisplay('blockEdit', {
		bid 			=> $bid,
		title 			=> $title,
		blockref		=> $blockref,
		blockedit_flag		=> $blockedit_flag,
		blockdelete_flag	=> $blockdelete_flag,
		block_select1		=> $block_select1,
		block_select2		=> $block_select2,
		blockform_flag		=> $blockform_flag,
		portal_checked		=> $portal_checked,
		retrieve_checked	=> $retrieve_checked,
		all_sections_checked	=> $all_sections_checked,
		blocktype_select	=> $blocktype_select,
		sectionbid		=> $sectionbid,
		autosubmit_select	=> $autosubmit_select,
		rss_select		=> $rss_select,
		rss_template_code	=> $rss_template_code,
	});
}

##################################################################
sub blockSave {
	my($bid) = @_;

	my $slashdb = getCurrentDB();
	return unless $bid;

	my $saved = $slashdb->saveBlock($bid);

	if (getCurrentForm('save_new') && $saved > 0) {
		print getData('blockSave-exists-message', { bid => $bid });
		return;
	}

	if ($saved == 0) {
		print getData('blockSave-inserted-message', { bid => $bid });
	}
}

##################################################################
sub blockDelete {
	my($bid) = @_;

	my $slashdb = getCurrentDB();
	$slashdb->deleteBlock($bid);
}

##################################################################
sub colorEdit {
	my($form, $slashdb, $user, $constants) = @_;

	my($color_select, $block, $colorblock_clean, $title, @colors);

	# return if $user->{'seclev'} < 500;
	if ($form->{colorsave} || $form->{colorsavedef} || $form->{colororig}) {
		colorSave();
	}

	my $colorblock;
	$form->{color_block} ||= 'colors';

	if ($form->{colorpreview} || $form->{colorsave}) {
		$colorblock_clean = $colorblock =
			join ',', @{$form}{qw[fg0 fg1 fg2 fg3 fg4 bg0 bg1 bg2 bg3 bg4]};

		# the #s will break the url
		$colorblock_clean =~ s/#//g;

	} else {
		$colorblock = $slashdb->getBlock($form->{color_block}, 'block');
	}

	@colors = split m/,/, $colorblock;

	$user->{fg} = [@colors[0..4]];
	$user->{bg} = [@colors[5..9]];

	$title = getTitle('colorEdit-title');

	$block = $slashdb->getDescriptions('color_block', '', 1);
	$color_select = createSelect('color_block', $block, $form->{color_block}, 1);

	slashDisplay('colorEdit', {
		title 			=> $title,
		colorblock_clean	=> $colorblock_clean,
		colors			=> \@colors,
		color_select		=> $color_select,
	});
}

##################################################################
sub colorSave {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	my $colorblock = join ',', @{$form}{qw[fg0 fg1 fg2 fg3 fg4 bg0 bg1 bg2 bg3 bg4]};

	$slashdb->saveColorBlock($colorblock);
}

##################################################################
# Keyword Editor
sub editKeyword {
	my($form, $slashdb, $user, $constants) = @_;

	if ($form->{keywordnew}) {
		$form->{id} = '';
		saveKeyword(@_);
	}
	deleteKeyword(@_) if $form->{keyworddelete};
	saveKeyword(@_) if $form->{keywordsave};

	my($keywords_menu, $keywords_select);

	$keywords_menu = $slashdb->getDescriptions('keywords', '', 1);
	$keywords_select = createSelect('id', $keywords_menu, $form->{id}, 1, '', 1);

	my $keyword = $slashdb->getRelatedLink($form->{id}) 
		if $form->{id};

	slashDisplay('keywordEdit', {
		keywords_select		=> $keywords_select,
		keyword			=> $keyword,
	});
}

##################################################################
sub deleteKeyword {
	my($form, $slashdb, $user, $constants) = @_;

	print getData('keywordDelete-message');
	$slashdb->deleteRelatedLink($form->{id});
	$form->{id} = '';
}

##################################################################
sub saveKeyword {
	my($form, $slashdb, $user, $constants) = @_;
	my $basedir = $constants->{'basedir'};

	return if getCurrentUser('seclev') < 500;

	if ($form->{id}) {
		$slashdb->setRelatedLink($form->{id}, {
			keyword	=> $form->{keyword},
			name	=> $form->{name},
			'link'	=> $form->{'link'}
		});
	} else {
		$form->{id} = $slashdb->createRelatedLink({
			keyword	=> $form->{keyword},
			name	=> $form->{name},
			'link'	=> $form->{'link'}
		});
	}

	print getData('keywordSave-message');
}

##################################################################
# Topic Editor
sub topicEdit {
	my($form, $slashdb, $user, $constants) = @_;
	my $basedir = $constants->{basedir};
	my($image, $image2);

	my($topic, $topics_menu, $topics_select);
	my $available_images = {};
	my $image_select = "";

	if ($form->{topicdelete} && $form->{tid}) {
		topicDelete($form->{tid});
		print getData('topicDelete-message', { tid => $form->{tid} });

	} elsif ($form->{topicsave}) {
		topicSave(@_);
		print getData('topicSave-message');
	}

	my($imageseen_flag, $images_flag) = (0, 0);

	local *DIR;
	opendir(DIR, "$basedir/images/topics");

	# this should be a preference at some point, image
	# extensions ... -- pudge
	# and case insensitive :)  -Brian
	$available_images = { map { ($_, $_) } grep /\.(?:gif|jpe?g|png)$/, readdir DIR };

	closedir(DIR);

	my $tdesc = 'topics_all';
	#What is this for? -Brian
	if ($user->{section} && $user->{seclev} <= 9000) {
		$tdesc = 'topics_section';
	}
	$topics_select = createSelect('nexttid', 
		$slashdb->getDescriptions($tdesc, $user->{section}, 1),
		$form->{nexttid} ? $form->{nexttid} : $constants->{defaulttopic}, 1);
	my $sections = {};
	if ($user->{section} && $user->{seclev} <= 9000) {
		$sections->{$user->{section}} = $slashdb->getSection($user->{section}, 'title', '', 1);
	} else {
		$sections = $slashdb->getDescriptions('sections-contained', '', 1);
	}

	my $section_topics_arref = $slashdb->getSectionTopicType($form->{nexttid});
	my $section_topics_hashref = {};

	for (@$section_topics_arref) {
		$section_topics_hashref->{$_->[0]}{$_->[1]} = 1;
	}
	my $types = $slashdb->getDescriptions('genericstring', 'section_topic_type');
	my $sectionref;

	while (my($section, $title) = each %$sections) {
		$sectionref->{$section}{checked} = ($section_topics_hashref->{$section}) ? ' CHECKED' : '';
		$sectionref->{$section}{title} = $title;
		for my $type (keys %$types) {
			$sectionref->{$section}{$type}{checked} = ($section_topics_hashref->{$section}{$type}) ? ' CHECKED' : '';
		} 
	}

	if (!$form->{topicdelete}) {
		if (!$form->{topicnew} && $form->{nexttid}) {
			$topic = $slashdb->getTopic($form->{nexttid}, 0, 1);
		} else {
			$topic = {};
		}
	}

	if ($available_images) {
		$images_flag = 1;
		$image_select = createSelect('image', $available_images, $topic->{image}, 1);
	}

	# we can change topic->{image} because it's cached and it'll hose it sitewide
	# non non-alphanumerics in the name?  this is sorta ill-conceived.  there
	# should be a flag, or something ...
	$image = $topic->{image};
	if ($image =~ /^\w+\.\w+$/) {
		$image = "$constants->{imagedir}/topics/$image";
	} else {
		$image2 = $image;
	}

	my $topicname = $topic->{name} || '';
	slashDisplay('topicEdit', {
		title			=> getTitle('editTopic-title', { tname => $topicname }),
		images_flag		=> $images_flag,
		image			=> $image2 ? $image2 : $image,
		image2			=> $image2,
		topic			=> $topic,
		topics_select		=> $topics_select,
		image_select		=> $image_select,
		sectionref		=> $sectionref
	});
}

##################################################################
sub topicDelete {
	my($tid) = @_;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	$tid ||= $form->{tid};

	$slashdb->deleteTopic($tid);
	$slashdb->deleteSectionTopicsByTopic($form->{tid}, $form->{type});
	$form->{tid} = '';
}

##################################################################
sub topicSave {
	my($form, $slashdb, $user, $constants) = @_;
	my $basedir = $constants->{basedir};

	if (!$form->{width} && !$form->{height} && ! $form->{image2}) {
		@{ $form }{'width', 'height'} = imgsize("$basedir/images/topics/$form->{image}");
	}

	$form->{tid} = $slashdb->saveTopic($form);

	# The next few lines need to be wrapped in a transaction -Brian
	$slashdb->deleteSectionTopicsByTopic($form->{tid}, $form->{type});
	for my $element1 (keys %$form) {
		if ($element1 =~ /^exsect/) {
			# I picked | because sections, types can have _ in them -Brian
			my ($junk, $sect, $type) = split(/\|/, $element1);
			$slashdb->createSectionTopic($sect, $form->{tid}, $type);
		}

	}

	$form->{nexttid} = $form->{tid};
}

##################################################################
# hmmm, what do we want to do with this sub ? PMG 10/18/00
sub importImage {
	# Check for a file upload
	my $section = $_[0];

	my $rootdir = getCurrentStatic('rootdir');

	my $filename = getCurrentForm('importme');
	my $tf = getsiddir() . $filename;
	$tf =~ s|/|~|g;
	$tf = "$section~$tf";

	if ($filename) {
		local *IMAGE;
		system("mkdir /tmp/slash");
		open(IMAGE, ">>/tmp/slash/$tf");
		my $buffer;
		while (read $filename, $buffer, 1024) {
			print IMAGE $buffer;
		}
		close IMAGE;
	} else {
		return "<image:not found>";
	}

	my($w, $h) = imgsize("/tmp/slash/$tf");
	return qq[<IMG SRC="$rootdir/$section/] .  getsiddir() . $filename
		. qq[" WIDTH="$w" HEIGHT="$h" ALT="$section">];
}

##################################################################
sub importFile {
	# Check for a file upload
	my $section = $_[0];

	my $rootdir = getCurrentStatic('rootdir');

	my $filename = getCurrentForm('importme');
	my $tf = getsiddir() . $filename;
	$tf =~ s|/|~|g;
	$tf = "$section~$tf";

	if ($filename) {
		system("mkdir /tmp/slash");
		open(IMAGE, ">>/tmp/slash/$tf");
		my $buffer;
		while (read $filename, $buffer, 1024) {
			print IMAGE $buffer;
		}
		close IMAGE;
	} else {
		return "<attach:not found>";
	}
	return qq[<A HREF="$rootdir/$section/] . getsiddir() . $filename
		. qq[">Attachment</A>];
}

########################################################
# Returns the directory (eg YY/MM/DD/) that stories are being written in today
sub getsiddir {
	my($mday, $mon, $year) = (localtime)[3, 4, 5];
	$year = $year % 100;
	my $sid = sprintf('%02d/%02d/%02d/', $year, $mon+1, $mday);
	return $sid;
}

##################################################################
sub importText {
	# Check for a file upload
	my $filename = getCurrentForm('importme');
	my($r, $buffer);
	if ($filename) {
		while (read $filename, $buffer, 1024) {
			$r .= $buffer;
		}
	}
	return $r;
}

##################################################################
# Generated the 'Related Links' for Stories
sub getRelated {
	my($story_content, $tid) = @_;

	my $slashdb = getCurrentDB();
	my $rl = $slashdb->getRelatedLinks();
	my $related_text = "";
	my @rl_keys = sort keys %$rl;

	if ($rl) {
		my @matchkeys =
			sort grep {
				$rl->{$_}{keyword} =~ /^_topic_id_$tid(?!\d)/
				||
				$rl->{$_}{keyword} !~ /^_topic_id_/
					&& $story_content =~ /\b$rl->{$_}{keyword}\b/i
			} @rl_keys;
		for my $key (@matchkeys) {
			my $str = qq[&middot; <A HREF="$rl->{$key}{link}">$rl->{$key}{name}</A><BR>\n];
			$related_text .= $str unless $related_text =~ /\Q$str\E/;
		}
	}

	# And slurp in all of the anchor links (<A>) from the story just for
	# good measure.  If TITLE attribute is present, use that for the link
	# label; otherwise just use the A content.
	while ($story_content =~ m|<A\s+(.*?)>(.*?)</A>|sgi) {
		my($a_attr, $label) = ($1, $2);
		if ($a_attr =~ m/(\bTITLE\s*=\s*(["'])(.*?)\2)/si) {
			$label = $3;
			$a_attr =~ s/$1//;
		}

		$label = strip_notags($label);
		$label =~ s/(\S{30})/$1 /g;
		my $str = qq[&middot; <A $a_attr>$label</A><BR>\n];
		$related_text .= $str unless $related_text =~ /\Q$str\E/
			|| $label eq "?" || $label eq "[?]";
	}

	return $related_text;
}

##################################################################
sub otherLinks {
	my($aid, $tid, $uid) = @_;

	my $slashdb = getCurrentDB();

	my $topic = $slashdb->getTopic($tid);

	return slashDisplay('otherLinks', {
		uid		=> $uid,
		aid		=> $aid,
		tid		=> $tid,
		topic		=> $topic,
	}, { Return => 1, Nocomm => 1 });
}

##################################################################
sub get_slashd_box {
	my $slashdb = getCurrentDB();
	my $sldst = $slashdb->getSlashdStatuses();
	for my $task (keys %$sldst) {
		$sldst->{$task}{last_completed_hhmm} =
			substr($sldst->{$task}{last_completed}, 11, 5)
			if defined($sldst->{$task}{last_completed});
		$sldst->{$task}{next_begin_hhmm} =
			substr($sldst->{$task}{next_begin}, 11, 5)
			if defined($sldst->{$task}{next_begin});
		$sldst->{$task}{summary_trunc} =
			substr($sldst->{$task}{summary}, 0, 30)
			if $sldst->{$task}{summary};
	}
	# Yes, this really is the easiest way to do this.
	# Yes, it is quite complicated.
	# Sorry.  - Jamie
	my @tasks_next = reverse (
		map {				# Build an array of
			$sldst->{$_}
		} grep {			# the defined elements of
			defined($_)
		} ( (				# the first 3 elements of
			sort {			# a sort of
				$sldst->{$a}{next_begin} cmp $sldst->{$b}{next_begin}
			} grep {		# the defined elements of
				defined($sldst->{$_}{next_begin})
				&& !$sldst->{$_}{in_progress}
			} keys %$sldst		# the hash keys.
		)[0..2] )
	);
	my @tasks_inprogress = (
		map {				# Build an array of
			$sldst->{$_}
		} sort {			# a sort of
			$sldst->{$a}{task} cmp $sldst->{$b}{task}
		} grep {			# the in-progress elements of
			$sldst->{$_}{in_progress}
		} keys %$sldst			# the hash keys.
	);
	my @tasks_last = reverse (
		map {				# Build an array of
			$sldst->{$_}
		} grep {			# the defined elements of
			defined($_)
		} ( (				# the last 3 elements of
			sort {			# a sort of
				$sldst->{$a}{last_completed} cmp $sldst->{$b}{last_completed}
			} grep {		# the defined elements of
				defined($sldst->{$_}{last_completed})
				&& !$sldst->{$_}{in_progress}
			} keys %$sldst		# the hash keys.
		)[-3..-1] )
	);
	my $text = slashDisplay('slashd_box', {
		tasks_next              => \@tasks_next,
		tasks_inprogress        => \@tasks_inprogress,
		tasks_last              => \@tasks_last,
	}, , { Return => 1 });
	return $text;
}

##################################################################
# Story Editing
sub editStory {
	my($form, $slashdb, $user, $constants) = @_;

	my($sid, $storylinks);
	# Added validation of sid -Brian
	if ($form->{op} eq 'edit') {
		$sid = $slashdb->getStory($form->{sid}, 'sid')
			if ($form->{sid});
	}
	# Basically, we upload the bodytext if we realize a name has been passed in -Brian
	if ($form->{bodytext_file}) {
		my $upload = $form->{query_apache}->upload;
		if ($upload) {
			my $temp_body;
			$form->{bodytext} = '';
			my $fh = $upload->fh;
			while (<$fh>) {
				$form->{bodytext} .= $_;
			}
		}
	}

	my($extracolumn_flag) = (0, 0);
	my($storyref, $story, $author, $topic, $storycontent, $locktest,
		$sections, $topic_select, $section_select, $author_select,
		$extracolumns, $displaystatus_select, $commentstatus_select, 
		$subid, $description);
	my $extracolref = {};
	my($fixquotes_check, $autonode_check, 
		$fastforward_check, $shortcuts_check) =
		('','','','');
	my($multi_topics, $story_topics);
	my $page = 'index';
	my $section = $user->{section} ? $user->{section} : $form->{section};

	for (keys %{$form}) { $storyref->{$_} = $form->{$_} }

	my $newarticle = 1 if (!$sid && !$form->{sid});

	# Editting a story that has yet to go into the DB, basically previewing. -Brian 
	if ($form->{title}) {
		# Section authors get forced into their section, if not we see what section has been set to. 
		# This fails we grab the defaultsection for a new story.  -Brian
		$form->{section} = $user->{section} if $user->{section};
		$form->{section} ||= $constants->{defaultsection};
		my $SECT = $slashdb->getSection($form->{section});
		$extracolumns = $slashdb->getSectionExtras($storyref->{section}) || [ ];
		# Did you know we actually have  var that should set this? -Brian
		$storyref->{writestatus}   = "dirty";
		$storyref->{displaystatus} = $form->{displaystatus} || $SECT->{defaultdisplaystatus};
		$storyref->{commentstatus} = $form->{commentstatus} || $SECT->{defaultcommentstatus};
		$storyref->{subsection}	   = $form->{subsection} || $SECT->{defaultsubsection};
		$storyref->{section}	   = $form->{section} || $SECT->{defaultsection};

		$storyref->{uid} ||= $user->{uid};
		#$storyref->{section} = $form->{section};

#		$storyref->{writestatus} = $form->{writestatus}
#			if exists $form->{writestatus};
#		$storyref->{displaystatus} = $form->{displaystatus}
#			if exists $form->{displaystatus};
#		$storyref->{commentstatus} = $form->{commentstatus}
#			if exists $form->{commentstatus};
		$storyref->{dept} =~ s/[-\s]+/-/g;
		$storyref->{dept} =~ s/^-//;
		$storyref->{dept} =~ s/-$//;

		for my $field (qw( introtext bodytext )) {
			$storyref->{$field} = $slashdb->autoUrl(
				$form->{section}, $storyref->{$field});
			$storyref->{$field} = slashizeLinks(
				$storyref->{$field});
			$storyref->{$field} = parseSlashizedLinks(
				$storyref->{$field});
			$storyref->{$field} = balanceTags(
				$storyref->{$field});
		}

		$topic = $slashdb->getTopic($storyref->{tid});
		$form->{uid} ||= $user->{uid};
		$author = $slashdb->getAuthor($form->{uid});
		$subid = $form->{subid};
		$sid = $form->{sid};

		if (!$form->{'time'} || $form->{fastforward}) {
			$storyref->{'time'} = $slashdb->getTime();
		} else {
			$storyref->{'time'} = $form->{'time'};
		}

		my $tmp = $user->{currentSection};
		$user->{currentSection} = $storyref->{section};

		$storycontent = dispStory($storyref, $author, $topic, 'Full');

		$user->{currentSection} = $tmp;
		$storyref->{relatedtext} =
			getRelated(
				"$storyref->{title} $storyref->{bodytext} $storyref->{introtext}",
				$storyref->{tid}
			) . otherLinks(
				$slashdb->getAuthor($storyref->{uid}, 'nickname'),
				$storyref->{tid}, 
				$storyref->{uid}
			);

		# Get wordcounts
		$storyref->{introtext_wordcount} = countWords($storyref->{introtext});
		$storyref->{bodytext_wordcount} = countWords($storyref->{bodytext});

	} elsif (defined $sid) { # Loading an existing SID
		my $tmp = $user->{currentSection};
		$user->{currentSection} = $slashdb->getStory($sid, 'section', 1);
		($story, $storyref, $author, $topic) = displayStory($sid, 'Full');
		$storyref->{writestatus} = 'dirty';
		$storyref->{commentstatus}  = ($slashdb->getDiscussion($storyref->{discussion}, 'commentstatus') || 'disabled'); # If there is no discussion attached then just disable -Brian
		$extracolumns = $slashdb->getSectionExtras($user->{currentSection}) || [ ];
		$user->{currentSection} = $tmp;
		# Get wordcounts
		$storyref->{introtext_wordcount} = countWords($storyref->{introtext});
		$storyref->{bodytext_wordcount} = countWords($storyref->{bodytext});
		$subid = $storyref->{subid};

	} else { # New Story
		my $section = $user->{section} || $form->{section};
		my $SECT = $slashdb->getSection($section || $constants->{defaultsection});
		$extracolumns		    = $slashdb->getSectionExtras($SECT->{section}) || [ ];
		$storyref->{displaystatus}  = $SECT->{defaultdisplaystatus};
		$storyref->{commentstatus}  = $SECT->{defaultcommentstatus};
		$storyref->{tid}            = $form->{tid} || $SECT->{defaulttopic};
		$storyref->{section}	    = $SECT->{section};
		$storyref->{subsection}	    = $SECT->{defaultsubsection};

		$storyref->{'time'} = $slashdb->getTime();
		$storyref->{uid} = $user->{uid};
		$storyref->{writestatus} = "dirty";
		$subid = $form->{subid};
	}

	for (@{$extracolumns}) {
		my $key = $_->[1];
		$storyref->{$key} = $form->{$key} || $storyref->{$key};
	}

	$sections = $slashdb->getDescriptions('sections');


	if ($constants->{multitopics_enabled}) {
		$multi_topics = $slashdb->getDescriptions(
	    		'topics_section', 
			$storyref->{section}
		);
		$story_topics = $slashdb->getStoryTopics($storyref->{sid});
		$story_topics->{$storyref->{tid}} ||= 1 ; 
	}

	# Topic list is sorted alpha, by VALUE. These calls to createSelect
	# should really be moved to the templates at some point.
	# - Cliff
	if ($constants->{use_alt_topic}) {
		$topic_select = createSelect('tid',
			$slashdb->getDescriptions(
				'topics_section_type', 
				$section, 
				$constants->{use_alt_topic}
			),
			$storyref->{tid}, 1, 0, 1
		);
	} else {
		if ($section) {
	    		$topic_select = createSelect('tid',
	    			$slashdb->getDescriptions(
					'topics_section', 
					$section
				),
	    			$storyref->{tid}, 1, 0, 1
	    		);
		} else {
	    		$topic_select = createSelect('tid',
	    			$slashdb->getDescriptions('topics'),
	    			$storyref->{tid}, 1, 0, 1
	    		);
		}
	}

	$section_select = selectSection('section', $storyref->{section}, $sections, 1) unless $user->{section};

	my $authors = $slashdb->getDescriptions('authors', '', 1);
	$author_select = createSelect('uid', $authors, $storyref->{uid}, 1);

	my $subsections = $slashdb->getDescriptions('section_subsection', $storyref->{section}, 1);
	my $subsection_select = createSelect('subsection', $subsections, $storyref->{subsection}, 1)
		if $subsections;

	$storyref->{dept} =~ s/ /-/gi;

	$locktest = lockTest($storyref->{title});

	my $display_codes = $user->{section} ? 'displaycodes_sectional' : 'displaycodes';

	unless ($user->{section}) {
		$description = $slashdb->getDescriptions($display_codes);
		$displaystatus_select = createSelect('displaystatus', $description, $storyref->{displaystatus}, 1);
	}
	$description = $slashdb->getDescriptions('commentcodes');
	$commentstatus_select = createSelect('commentstatus', $description, $storyref->{commentstatus}, 1);

	$fixquotes_check	= 'CHECKED' if $form->{fixquotes};
	$autonode_check		= 'CHECKED' if $form->{autonode};
	$fastforward_check	= 'CHECKED' if $form->{fastforward};
	$shortcuts_check	= 'CHECKED' if $form->{shortcuts};

	$slashdb->setSession($user->{uid}, {
		lasttitle	=> $storyref->{title},
		last_sid	=> $sid,
		last_subid	=> '',
	});

	my $ispell_comments = {
		introtext =>    get_ispell_comments($storyref->{introtext}),
		bodytext =>     get_ispell_comments($storyref->{bodytext}),
	} unless $user->{no_spell};

	my $future = $slashdb->getStoryByTimeAdmin('>', $storyref, "3");
	$future = [ reverse(@$future) ];
	my $past = $slashdb->getStoryByTimeAdmin('<', $storyref, "3");

	my $num_sim = $constants->{similarstorynumshow} || 5;
	my $similar_stories = $slashdb->getSimilarStories($storyref, $num_sim);
	# Truncate that data to a reasonable size for display.
	if ($similar_stories && @$similar_stories) {
		for my $sim (@$similar_stories) {
			# Display a max of five words reported per story.
			$#{$sim->{words}} = 4 if $#{$sim->{words}} > 4;
			for my $word (@{$sim->{words}}) {
				# Max of 12 chars per word.
				$word = substr($word, 0, 12);
			}
			if (length($sim->{title}) > 35) {
				# Max of 35 char title.
				$sim->{title} = substr($sim->{title}, 0, 30);
				$sim->{title} =~ s/\s+\S+$//;
				$sim->{title} .= "...";
			}
		}
	}

	my $authortext = slashDisplay('futurestorybox', {
		past => $past,
		present => $storyref,
		future => $future,
	}, { Return => 1 });

	my $slashdtext = get_slashd_box();

	# We probably should just pass the raw data instead of the formatted
	# <SELECT> into this template and let the template deal with the
	# HTML, here. Formatting these elements outside of the template
	# just defeats the purpose!	-- Cliff 2002-08-07
	slashDisplay('editStory', {
		storyref 		=> $storyref,
		story			=> $story,
		storycontent		=> $storycontent,
		sid			=> $sid,
		subid			=> $subid,
		authortext 		=> $authortext,
		slashdtext		=> $slashdtext,
		newarticle		=> $newarticle,
		topic_select		=> $topic_select,
		section_select		=> $section_select,
		author_select		=> $author_select,
		locktest		=> $locktest,
		displaystatus_select	=> $displaystatus_select,
		commentstatus_select	=> $commentstatus_select,
		fixquotes_check		=> $fixquotes_check,
		autonode_check		=> $autonode_check,
		fastforward_check	=> $fastforward_check,
		shortcuts_check		=> $shortcuts_check,
		subsection_select	=> $subsection_select,
		ispell_comments		=> $ispell_comments,
		extras			=> $extracolumns,
		multi_topics		=> $multi_topics,
		story_topics		=> $story_topics,
		similar_stories		=> $similar_stories,
	});
}

##################################################################
sub write_to_temp_file {
	my($data) = @_;
	local *TMP;
	my $tmp;
	do {
		# Note: don't mount /tmp over NFS, it's a security risk
		# See Camel3, p. 574
		$tmp = tmpnam();
	} until sysopen(TMP, $tmp, O_RDWR|O_CREAT|O_EXCL, 0600);
	print TMP $data;
	close TMP;
	$tmp;
}

##################################################################
sub get_ispell_comments {
	my($text) = @_;
	$text = strip_nohtml($text);
	# don't split to scalar context, it clobbers @_
	my $n_text_words = scalar(my @junk = split /\W+/, $text);
	my $slashdb = getCurrentDB();

	my $ispell = $slashdb->getVar("ispell", "value");
	return "" if !$ispell;
	return "bad ispell var '$ispell'"
		unless $ispell eq 'ispell' or $ispell =~ /^\//;
	return "insecure ispell var '$ispell'" if $ispell =~ /\s/;
	if ($ispell ne 'ispell') {
		return "no file, not readable, or not executable '$ispell'"
			if !-e $ispell or !-f _ or !-r _ or !-x _;
	}

	# That last "1" means to ignore errors
	my $ok = $slashdb->getTemplateByName('ispellok', '', 1, '', '', 1);
	$ok = $ok ? ($ok->{template} || "") : "";
	$ok =~ s/\s+/\n/g;

	local *ISPELL;
	my $tmptext = write_to_temp_file($text);
	my $tmpok = "";
	$tmpok = write_to_temp_file($ok) if $ok;
	my $tmpok_flag = "";
	$tmpok_flag = " -p $tmpok" if $tmpok;
	if (!open(ISPELL, "$ispell -a -B -S -W 3$tmpok_flag < $tmptext 2> /dev/null |")) {
		errorLog("could not pipe to $ispell from $tmptext, $!");
		return "could not pipe to $ispell from $tmptext, $!";
	}
	my %w;
	while (defined(my $line = <ISPELL>)) {
		# Grab all ispell's flagged words and put them in the hash
		$w{$1}++ if $line =~ /^[#?&]\s+(\S+)/;
	}
	close ISPELL;
	unlink $tmptext, $tmpok;

	my $comm = '';
	for my $word (sort {lc($a) cmp lc($b) or $a cmp $b} keys %w) {
		# if it's a repeated error, ignore it
		next if $w{$word} >= 2 and $w{$word} > $n_text_words*0.002;
		# a misspelling; report it
		$comm = "ispell doesn't recognize:" if !$comm;
		$comm .= " $word";
	}
	return $comm;
}

##################################################################
sub listStories {
	my($form, $slashdb, $user, $constants) = @_;

	my($first_story, $num_stories) = ($form->{'next'} || 0, 40);
	my($count, $storylist) = $slashdb->getStoryList($first_story, $num_stories);

	my $storylistref = [];
	my($i, $canedit) = (0, 0);

	if ($form->{op} eq 'delete') {
		rmStory($form->{sid});
		titlebar('100%', getTitle('rmStory-title', {sid => $form->{sid}}));
	} else {
		titlebar('100%', getTitle('listStories-title'));
	}

	for (@$storylist) {
		my($hits, $comments, $sid, $title, $aid, $time_plain, $topic,
			$subsection, $section,
			$displaystatus, $writestatus) = @$_;
		my $time = timeCalc($time_plain, '%H:%M', 0);
		my $td   = timeCalc($time_plain, '%A %B %d', 0);
		my $td2  = timeCalc($time_plain, '%m/%d', 0);

		$title = substr($title, 0, 50) . '...' if (length $title > 55);
		my $tbtitle = fixparam($title);
		if ($user->{uid} eq $aid || $user->{seclev} >= 100) {
			$canedit = 1;
		}

		$storylistref->[$i] = {
			'x'		=> $i + $first_story + 1,
			hits		=> $hits,
			comments	=> $comments,
			sid		=> $sid,
			title		=> $title,
			aid		=> $slashdb->getAuthor($aid, 'nickname'),
			'time'		=> $time,
			canedit		=> $canedit,
			topic		=> $topic,
			section		=> $section,
			subsection	=> $subsection,
			td		=> $td,
			td2		=> $td2,
			writestatus	=> $writestatus,
			displaystatus	=> $displaystatus,
			tbtitle		=> $tbtitle,
		};
		$i++;
	}

	slashDisplay('listStories', {
		storylistref	=> $storylistref,
		'x'		=> $i + $first_story,
		left		=> $count - ($i + $first_story),
	});
}

##################################################################
sub rmStory {
	my($sid) = @_;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	$slashdb->deleteStory($sid);
}

##################################################################
sub listFilters {
	my($form, $slashdb, $user, $constants) = @_;

	my $formname = $form->{formname};

	my $title = getTitle('listFilters-title');
	my $filter_ref = $slashdb->getContentFilters($formname);

	my $form_list = $slashdb->getDescriptions('forms');
	my $form_select = createSelect('formname', $form_list, $formname, 1);

	slashDisplay('listFilters', {
		title		=> $title,
		form_select	=> $form_select,
		filter_ref	=> $filter_ref
	});
}

##################################################################
sub editFilter {
	my($form, $slashdb, $user, $constants) = @_;

	my($filter_id);

	my $formname = $form->{formname};

	if ($form->{newfilter}) {
		$filter_id = $slashdb->createContentFilter($formname);
		titlebar("100%", getTitle('updateFilter-new-title', { filter_id => $filter_id }));

	} elsif ($form->{updatefilter}) {
		if (!$form->{regex}) {
			print getData('updateFilter-message');

		} else {
			$slashdb->setContentFilter();
		}

		$filter_id = $form->{filter_id};
		titlebar("100%", getTitle('updateFilter-update-title'));

	} elsif ($form->{deletefilter}) {
		$slashdb->deleteContentFilter($form->{filter_id});
		titlebar("100%", getTitle('updateFilter-delete-title'));
		listFilters($formname);
		return();
	}

	$filter_id ||= $form->{filter_id};

	my @values = qw(regex form modifier field ratio minimum_match
		minimum_length err_message);
	my $filter = $slashdb->getContentFilter($filter_id, \@values, 1);

	my $form_list = $slashdb->getDescriptions('forms');
	my $form_select = createSelect('formname', $form_list, $filter->{form}, 1);

	# this has to be here - it really screws up the block editor
	$filter->{err_message} = strip_literal($filter->{'err_message'});

	slashDisplay('editFilter', {
		form_select 	=> $form_select,
		filter		=> $filter,
		filter_id	=> $filter_id
	});
}

##################################################################
sub updateStory {
	my($form, $slashdb, $user, $constants) = @_;

	my $tid_ref;
	my $default_set = 0;
	my $topic = $form->{tid};

	$form->{dept} =~ s/ /-/g;

	$form->{aid} = $slashdb->getStory($form->{sid}, 'aid', 1)
		unless $form->{aid};

	$form->{relatedtext} = getRelated("$form->{title} $form->{bodytext} $form->{introtext}", $topic)
		. otherLinks($slashdb->getAuthor($form->{uid}, 'nickname'), $topic, $form->{uid});

	my $time = ($form->{fastforward})
		? $slashdb->getTime()
		: $form->{'time'};

	if ($constants->{use_alt_topic} && $constants->{enable_index_topic} && $constants->{organise_stories}) {
		$topic = $form->{$constants->{organise_stories}};
	}

	if ($constants->{multitopics_enabled}) {
		for my $k (keys %$form) {
			if ($k =~ /^tid_(.*)$/) {
				push @$tid_ref, $1;
			}
		}
		for (@{$tid_ref}) {
			$default_set++ if $topic && $_ eq $topic;
		}
		push @$tid_ref, $topic if !$default_set;

		$slashdb->setStoryTopics($form->{sid}, $tid_ref);
	}
	$form->{introtext} = slashizeLinks($form->{introtext});
	$form->{bodytext} =  slashizeLinks($form->{bodytext});
	$form->{introtext} = balanceTags($form->{introtext});
	$form->{bodytext} =  balanceTags($form->{bodytext});

	my $data = {
		uid		=> $form->{uid},
		sid		=> $form->{sid},
		title		=> $form->{title},
		section		=> $form->{section},
		tid		=> $topic,
		dept		=> $form->{dept},
		'time'		=> $time,
		displaystatus	=> $form->{displaystatus},
		writestatus	=> $form->{writestatus},
		bodytext	=> $form->{bodytext},
		introtext	=> $form->{introtext},
		relatedtext	=> $form->{relatedtext},
		subsection	=> $form->{subsection},
	};
	my $extras = $slashdb->getSectionExtras($data->{section});
	if ($extras && @$extras) {
		for (@$extras) {
			my $key = $_->[1];
			$data->{$key} = $form->{$key} if $form->{$key};
		}
	}

	$slashdb->setStory($form->{sid}, $data);
	my $dis_data = {
		sid	=> $data->{sid},
		title	=> $data->{title},
		section	=> $data->{section},
		url	=> "$constants->{rootdir}/article.pl?sid=$data->{sid}",
		ts	=> $data->{'time'},
		topic	=> $data->{tid},
		commentstatus	=> $form->{commentstatus}
	};


	$slashdb->setDiscussionBySid($data->{sid}, $dis_data);
	if ($data->{displaystatus} < 1) {
		$slashdb->setVar('writestatus', 'dirty');
		$slashdb->setSection($data->{section}, { writestatus => 'dirty' });
	}

	titlebar('100%', getTitle('updateStory-title'));
	# make sure you pass it the goods
	listStories(@_);
}

##################################################################
sub displaySlashd {
	my($form, $slashdb, $user, $constants) = @_;
	my $answer = $slashdb->getSlashdStatuses();
	for my $task (keys %$answer) {
		$answer->{$task}{last_completed_hhmm} =
			substr($answer->{$task}{last_completed}, 11, 5)
			if defined($answer->{$task}{last_completed});
		$answer->{$task}{next_begin_hhmm} =
			substr($answer->{$task}{next_begin}, 11, 5)
			if defined($answer->{$task}{next_begin});
		$answer->{$task}{summary_trunc} =
			substr($answer->{$task}{summary}, 0, 30)
			if $answer->{$task}{summary};
	}
	slashDisplay('slashd_status', {
		tasks => $answer,
	});
}

##################################################################
sub displayRecent {
	my($form, $slashdb, $user, $constants) = @_;
	my($min, $max) = (undef, undef);
	$min = $form->{min} if defined($form->{min});
	$max = $form->{max} if defined($form->{max});
	my $startat = $form->{startat} || undef;

	my $max_cid = $slashdb->sqlSelect("MAX(cid)", "comments");
	my $recent_comments = $slashdb->getRecentComments({
		min	=> $min,
		max	=> $max,
		startat	=> $startat,
		num	=> 30,
	}) || [ ];

	my $subj_vislen = 30;
	for my $comm (@$recent_comments) {
		vislenify($comm); # add $comm->{ipid_vis}
		$comm->{subject_vis} = substr($comm->{subject}, 0, $subj_vislen);
		$comm->{date} = substr($comm->{date}, 5); # strip off year
	}

	slashDisplay('recent', {
		startat		=> $startat,
		max_cid		=> $max_cid,
		recent_comments	=> $recent_comments,
		min		=> $min,
		max		=> $max,
	});
}

##################################################################
sub displayRecentRequests {
	my($form, $slashdb, $user, $constants) = @_;

	my $admindb = getObject("Slash::Admin",
		$constants->{backup_db_user} || $constants->{log_db_user});

	my $backupdb = getObject("Slash::DB",
		$constants->{backup_db_user} || $constants->{log_db_user});

	# Note, limit the id passed in by making sure we don't try to do a
	# select on more than 500,000 rows.  This is an arbitrary number,
	# but the intent is to keep from locking up the DB too much.
	my $min_id = $form->{min_id};
	my $max_id = $admindb->getAccesslogMaxID();
	$min_id = $max_id - 10_000 > 1 ? $max_id : 1	if !$min_id;
	$min_id = $max_id + $min_id			if  $min_id < 0;
	$min_id = $max_id				if  $min_id < $max_id - 500_000;

	my $min_id_ts ||= $backupdb->getAccesslog($min_id, 'ts');

	my $options = { min_id => $min_id };
	$options->{thresh_count} = defined($form->{thresh_count}) ? $form->{thresh_count} : 100;
	$options->{thresh_hps}   = defined($form->{thresh_hps}  ) ? $form->{thresh_hps}   : 0.1;

	my $start_time = Time::HiRes::time;
	my $data = $admindb->getAccesslogAbusersByID($options);
	my $duration = Time::HiRes::time - $start_time;
	vislenify($data); # add {ipid_vis} to each row
	for my $row (@$data) {
		# Get constant roundoff decimals.
		$row->{hps} = sprintf("%0.2f", $row->{hps});
	}

	slashDisplay('recent_requests', {
		min_id		=> $min_id,
		min_id_ts	=> $min_id_ts,
		max_id		=> $max_id,
		thresh_count	=> $options->{thresh_count},
		thresh_hps	=> $options->{thresh_hps},
		data		=> $data,
		select_secs	=> sprintf("%0.3f", $duration),
	});
}

##################################################################
sub saveStory {
	my($form, $slashdb, $user, $constants) = @_;

	my $edituser = $slashdb->getUser($form->{uid});
	my $tid_ref;
	my $topic = $form->{tid};
	my $default_set = 0;

	# In the previous form of this, a section only
	# editor could assign a story to a different user
	# and bypass their own restrictions for what section
	# they could post to. -Brian
	$form->{displaystatus} ||= 1 if ($user->{section} || $edituser->{section});
	if ($user->{section} || $edituser->{section}) {
		$form->{section} = $user->{section} ? $user->{section} : $edituser->{section};
	}
	$form->{dept} =~ s/ /-/g;
	my $story_text = "$form->{title} $form->{bodytext} $form->{introtext}";
	$form->{relatedtext} = getRelated($story_text, $form->{tid})
		. otherLinks($edituser->{nickname}, $form->{tid}, $edituser->{uid});
	$form->{introtext} = slashizeLinks($form->{introtext});
	$form->{bodytext} =  slashizeLinks($form->{bodytext});
	$form->{introtext} = balanceTags($form->{introtext});
	$form->{bodytext} =  balanceTags($form->{bodytext});

	my $time = ($form->{fastforward})
		? $slashdb->getTime()
		: $form->{'time'};

	if ($constants->{use_alt_topic} && $constants->{enable_index_topic} && $constants->{organise_stories}) {
		$topic = $form->{$constants->{organise_stories}};
	}

	# used to just pass $form to createStory, which is not
	# a good idea because you end up getting form values 
	# such as op and apache_request saved into story_param
	my $data = {
		uid		=> $form->{uid},
		sid		=> $form->{sid},
		title		=> $form->{title},
		section		=> $form->{section},
		submitter	=> $form->{submitter},
		tid		=> $topic,
		dept		=> $form->{dept},
		'time'		=> $time,
		displaystatus	=> $form->{displaystatus},
		writestatus	=> $form->{writestatus},
		bodytext	=> $form->{bodytext},
		introtext	=> $form->{introtext},
		relatedtext	=> $form->{relatedtext},
		subid		=> $form->{subid},
		subsection	=> $form->{subsection},
	};
	my $extras = $slashdb->getSectionExtras($data->{section});
	if ($extras && @$extras) {
		for (@$extras) {
			my $key = $_->[1];
			$data->{$key} = $form->{$key} if $form->{$key};
		}
	}
	my $sid = $slashdb->createStory($data);

	# we can use multiple values in forms now, we don't
	# need to keep using this idiom -- pudge
	if ($constants->{multitopics_enabled}) {
		for my $k (keys %$form) {
		    if ($k =~ /tid_(.*)/) {
			push @$tid_ref, $1;
		    }
		}
		for (@{$tid_ref}) {
			$default_set++ if $_ eq $topic;
		}
		push @$tid_ref, $topic if !$default_set;
	
		$slashdb->setStoryTopics($sid, $tid_ref);
	}

	if ($sid) {
		my $section = $slashdb->getSection($form->{section});
		my $rootdir = $section->{rootdir} || $constants->{rootdir};

		my $id = $slashdb->createDiscussion( {
			title	=> $form->{title},
			section	=> $form->{section},
			topic	=> $topic,
			url	=> "$rootdir/article.pl?sid=$sid&tid=$topic",
			sid	=> $sid,
			commentstatus	=> $form->{commentstatus},
			ts	=> $form->{'time'}
		});
		if ($id) {
			$slashdb->setStory($sid, { discussion => $id });
		} else {
			# Probably should be a warning sent to the browser
			# for this error, though it should be rare.
			errorLog("could not create discussion for story '$sid'");
		}
		$data->{discussion} = $id;
		slashHook('admin_save_story_success', { story => $data });
	} else {
		slashHook('admin_save_story_failed', { story => $data });
		titlebar('100%', getData('story_creation_failed'));
		listStories(@_);
		return;
	}

	titlebar('100%', getTitle('saveStory-title'));
	listStories(@_);
}

##################################################################
sub getTitle {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	return slashDisplay('titles', $hashref,
		{ Return => 1, Nocomm => $nocomm });
}

##################################################################
sub getLinks {
# huh? who did this?
# "getLinks" appears nowhere else in the codebase - Jamie 2002/01/09
}

createEnvironment();
main();
1;
