#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2001 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use Image::Size;
use Date::Manip;
use Slash;
use Slash::Display;
use Slash::Utility;

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();

	if ($user->{seclev} < 100) {
		my $rootdir = getCurrentStatic('rootdir');
		redirect("$rootdir/users.pl");
		return;
	}

	my($tbtitle);
	if (($form->{op} =~ /^preview|edit$/) && $form->{title}) {
		# Show submission/article title on browser's titlebar.
		$tbtitle = $form->{title};
		$tbtitle =~ s/"/'/g;
		$tbtitle = " - \"$tbtitle\"";
		# Undef the form title value if we have SID defined, since the editor
		# will have to get this information from the database anyways.
		undef $form->{title} if ($form->{sid} && $form->{op} eq 'edit');
	}

	# "backSlash" needs to be in a template or something -- pudge
	my $gmt_now_secs = UnixDate(ParseDate($slashdb->getTime()), "%s");
	my $gmt_ts = UnixDate("epoch $gmt_now_secs", "%T");
	my $local_ts = UnixDate("epoch ".($gmt_now_secs + $user->{off_set}), "%T");
	my $time_remark = (length $tbtitle > 10)
		? " $gmt_ts"
		: " $local_ts $user->{tzcode} = $gmt_ts GMT";
	header("backSlash$time_remark$tbtitle", 'admin');

	
	# Admin Menu
	print "<P>&nbsp;</P>" unless $user->{seclev};

	my $op = $form->{op};

	if ($form->{topicdelete}) {
		topicDelete();
		topicEdit();

	} elsif ($form->{topicsave}) {
		topicSave();
		topicEdit();

	} elsif ($form->{topiced} || $form->{topicnew}) {
		topicEdit();

	} elsif ($op eq 'save') {
		saveStory();

	} elsif ($op eq 'update') {
		updateStory();

	} elsif ($op eq 'list') {
		titlebar('100%', getTitle('listStories-title'));
		listStories();

	} elsif ($op eq 'delete') {
		rmStory($form->{sid});
		listStories();

	} elsif ($op eq 'preview') {
		editStory();

	} elsif ($op eq 'edit') {
		editStory($form->{sid});

	} elsif ($op eq 'listtopics') {
		listTopics($user->{seclev});

	} elsif ($op eq 'colored' || $form->{colored} || $form->{colorrevert} || $form->{colorpreview}) {
		colorEdit($user->{seclev});
		$op = 'colored';

	} elsif ($form->{colorsave} || $form->{colorsavedef} || $form->{colororig}) {
		colorSave();
		colorEdit($user->{seclev});

	} elsif ($form->{blockdelete_cancel} || $op eq 'blocked') {
		blockEdit($user->{seclev},$form->{bid});

	} elsif ($form->{blocknew}) {
		blockEdit($user->{seclev});

	} elsif ($form->{blocked1}) {
		blockEdit($user->{seclev}, $form->{bid1});

	} elsif ($form->{blocked2}) {
		blockEdit($user->{seclev}, $form->{bid2});

	} elsif ($form->{blocksave} || $form->{blocksavedef}) {
		blockSave($form->{thisbid});
		blockEdit($user->{seclev}, $form->{thisbid});

	} elsif ($form->{blockrevert}) {
		$slashdb->revertBlock($form->{thisbid}) if $user->{seclev} < 500;
		blockEdit($user->{seclev}, $form->{thisbid});

	} elsif ($form->{blockdelete}) {
		blockEdit($user->{seclev}, $form->{thisbid});

	} elsif ($form->{blockdelete1}) {
		blockEdit($user->{seclev}, $form->{bid1});

	} elsif ($form->{blockdelete2}) {
		blockEdit($user->{seclev}, $form->{bid2});

	} elsif ($form->{blockdelete_confirm}) {
		blockDelete($form->{deletebid});
		blockEdit($user->{seclev});

	} elsif ($form->{templatedelete_cancel}) {
		templateEdit($user->{seclev}, $form->{tpid}, $form->{page}, $form->{section});

	} elsif ($form->{templatenew}) {
		templateEdit($user->{seclev});
	
	} elsif ($form->{templatepage} || $form->{templatesection}) {
		templateEdit($user->{seclev}, '', $form->{page}, $form->{section});

	} elsif ($form->{templateed}) {
		templateEdit($user->{seclev}, $form->{tpid}, $form->{page}, $form->{section});

	} elsif ($form->{templatesave} || $form->{templatesavedef}) {
		my ($page,$section);
		if ($form->{save_new}) {
			$section = $form->{newS} ? $form->{newsection} : $form->{section};
			$page = $form->{newP} ? $form->{newpage} : $form->{page};
		} else { 
			$section = $form->{newS} ? $form->{newsection} : $form->{savesection};
			$page = $form->{newP} ? $form->{newpage} : $form->{savepage};
		}

		templateSave($form->{thistpid}, $form->{name},  $page, $section);
		templateEdit($user->{seclev}, $form->{thistpid}, $page, $section);

	} elsif ($form->{templaterevert}) {
		$slashdb->revertBlock($form->{thistpid}) if $user->{seclev} < 500;
		templateEdit($user->{seclev}, $form->{tpid}, $form->{page}, $form->{section});

	} elsif ($form->{templatedelete}) {
		templateEdit($user->{seclev}, $form->{tpid}, $form->{page}, $form->{section});

	} elsif ($form->{templatedelete_confirm}) {
		templateDelete($form->{deletename}, $form->{deletetpid});
		templateEdit($user->{seclev});

	} elsif ($op eq 'authors') {
		authorEdit($form->{thisaid});

	} elsif ($form->{authoredit}) {
		authorEdit($form->{myuid});

	} elsif ($form->{authornew}) {
		authorEdit();

	} elsif ($form->{authordelete}) {
		authorDelete($form->{myuid});

	} elsif ($form->{authordelete_confirm} || $form->{authordelete_cancel}) {
		authorDelete($form->{thisaid});
		authorEdit();

	} elsif ($form->{authorsave}) {
		authorSave();
		authorEdit($form->{myuid});

	} elsif ($op eq 'vars') {
		varEdit($form->{name});	

	} elsif ($op eq 'varsave') {
		varSave();
		varEdit($form->{name});

	} elsif ($op eq 'listfilters') {
		listFilters();

	} elsif ($form->{editfilter}) {
		titlebar("100%", getTitle('editFilter-title'));
		editFilter($form->{filter_id});

	} elsif ($form->{newfilter}) {
		updateFilter(1);

	} elsif ($form->{updatefilter}) {
		updateFilter(2);

	} elsif ($form->{deletefilter}) {
		updateFilter(3);

	} elsif ($form->{siteinfo}) {
		siteInfo();
		
	} else {
		titlebar('100%', getTitle('listStories-title'));
		listStories();
	}


	# Display who is logged in right now.
	footer();
	writeLog('admin', $user->{uid}, $op, $form->{sid});
}


##################################################################
#  Variables Editor
sub varEdit {
	my($name) = @_;

	my $slashdb = getCurrentDB();
	my $varsref;

	my $vars = $slashdb->getDescriptions('vars', '', 1);
	my $vars_select = createSelect('name', $vars, $name, 1);

	if($name) {
		$varsref = $slashdb->getVar($name);
	}

	slashDisplay('varEdit', { 
		vars_select 	=> $vars_select,
		varsref		=> $varsref,
	});
}

##################################################################
sub varSave {

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	if ($form->{thisname}) {
		my $value = $slashdb->getVar($form->{thisname});
		if ($value) {
			$slashdb->setVar($form->{thisname}, {
				value		=> $form->{value},
				description	=> $form->{desc}
			});
		} else {
			$slashdb->createVar($form->{thisname}, $form->{value}, $form->{desc});
		}

		if ($form->{desc}) {
			print getMessage('varSave-message');
		} else {
# please don't delete this by just removing comment,
# since we don't even warn the admin this will happen.
#			$slashdb->deleteVar($form->{thisname});
#			print getMessage('varDelete-message');
		}
	}
}

##################################################################
# Author Editor
sub authorEdit {
	my($aid) = @_;

	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $authornew = getCurrentForm('authornew');

	return if $user->{seclev} < 500;

	my($section_select, $author_select);
	my $deletebutton_flag = 0;

	$aid ||= $user->{uid};
	$aid = '' if $authornew;

	my $authors = $slashdb->getDescriptions('authors');
	my $author = $slashdb->getAuthor($aid) if $aid;

	$author_select = createSelect('myuid', $authors, $aid, 1);
	$section_select = selectSection('section', $author->{section}, {}, 1, 1);
	$deletebutton_flag = 1 if !$authornew && $aid ne $user->{uid};

	for ($author->{email}, $author->{copy}) {
		$_ = strip_literal($_);
	}

	slashDisplay('authorEdit', {
		author 			=> $author,
		author_select		=> $author_select,
		section_select		=> $section_select,
		deletebutton_flag 	=> $deletebutton_flag,
		aid			=> $aid,
	});	
}

##################################################################
sub siteInfo {
	return if getCurrentUser('seclev') < 100; 

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	my $site_info = $slashdb->getDescriptions('site_info');

	slashDisplay('siteInfo', {
		plugins 	=> $plugins,
		site_info	=> $site_info,
	});	

}

##################################################################
sub authorSave {

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	return if getCurrentUser('seclev') < 500;
	if ($form->{thisaid}) {
		# And just why do we take two calls to do
		# a new user? 
		if ($slashdb->createAuthor($form->{thisaid})) {
			print getMessage('authorInsert-message');
		}
		if ($form->{thisaid}) {
			print getMessage('authorSave-message');
			my %author = (
				name	=> $form->{name},
				pwd	=> $form->{pwd},
				email	=> $form->{email},
				url	=> $form->{url},
				seclev	=> $form->{seclev},
				copy	=> $form->{copy},
				quote	=> $form->{quote},
				section => $form->{section}
			);
			$slashdb->setAuthor($form->{thisaid}, \%author);
		} else {
			print getMessage('authorDelete-message');
			$slashdb->deleteAuthor($form->{thisaid});
		}
	}
}

##################################################################
sub authorDelete {
	my $aid = shift;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	return if getCurrentUser('seclev') < 500;

	print qq|<FORM ACTION="$ENV{SCRIPT_NAME}" METHOD="POST">|;
	print getMessage('authorDelete-confirm-msg', { aid => $aid }) if $form->{authordelete};

	if ($form->{authordelete_confirm}) {
		$slashdb->deleteAuthor($aid);
		print getMessage('authorDelete-deleted-msg', { aid => $aid }) if ! DBI::errstr;
	} elsif ($form->{authordelete_cancel}) {
		print getMessage('authorDelete-canceled-msg', { aid => $aid});
	}
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
	my($seclev, $tpid, $page, $section) = @_;
	my($slashdb, $form, $pagehashref, $title, $templateref,
		$template_select, $page_select, $section_select,
		$savepage_select, $savesection_select,
		$templatedelete_flag, $templateedit_flag, $templateform_flag);

	return if $seclev < 100;	
	$page ||= 'misc';
	$section ||= 'default';

	$slashdb = getCurrentDB();
	$form = getCurrentForm();
	$pagehashref = {};
	$templatedelete_flag = $templateedit_flag = $templateform_flag = 0;

	$templateref = $slashdb->getTemplate($tpid, '', 1) if $tpid;
	$title = getTitle('templateEdit-title', {}, 1);

	if ($form->{templatedelete}) {
		$templatedelete_flag = 1;
	} else {
		my $templates = {};

		if ($form->{templatesection}) {
			if ($section eq 'All') {
				$templates = $slashdb->getDescriptions('templates', $page, 1);
			} else {
				$templates = $slashdb->getDescriptions('templatesbysection', $section, 1);
			}
		} else {
			if ($page eq 'All') {
				$templates = $slashdb->getDescriptions('templates', $page, 1);
			} else {
				$templates = $slashdb->getDescriptions('templatesbypage', $page, 1);
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
		$savepage_select = createSelect('savepage', $pages, $templateref->{page}, 1) if $templateref->{tpid};
		$template_select = createSelect('tpid', $templates, $tpid, 1, 0, \@ordered);
		$section_select = createSelect('section', $sections, $section, 1);
		$savesection_select = createSelect('savesection', $sections, $templateref->{section}, 1) if $templateref->{tpid};
	}

	if (!$form->{templatenew} && $tpid && $templateref->{tpid}) {
		$templateedit_flag = 1;
	}

	$templateform_flag = 1 if ( (! $form->{templatedelete_confirm} && $tpid) || $form->{templatenew});

	slashDisplay('templateEdit', {
		tpid 			=> $tpid,
		title 			=> $title,
		templateref		=> $templateref,
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

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	return if getCurrentUser('seclev') < 500;

	$form->{seclev} ||= 500;

	my $id = $slashdb->getTemplate($tpid, '', 1);
	my $temp = $slashdb->getTemplateByName($name, [ 'section','page','name','tpid' ], 1 ,$page,$section);

	my $exists = 0;
	$exists = 1 if ($name eq $temp->{name} && 
			$section eq $temp->{section} && 
			$page eq $temp->{page});

	if ($form->{save_new}) {
		if ($id->{tpid} || $exists) {
			print getMessage('templateSave-exists-message', { tpid => $tpid, name => $name } );
			return;
		} else {
			print "trying to insert $name<br>\n";
			$tpid = $form->{thistpid} = $slashdb->createTemplate({
               			name		=> $name,
				template        => $form->{template},
				title		=> $form->{title},
				description	=> $form->{description},
				seclev          => $form->{seclev},
				page		=> $page,
				section		=> $section
			});

			print getMessage('templateSave-inserted-message', { tpid => $tpid , name => $name});
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
		print getMessage('templateSave-saved-message', { tpid => $tpid, name => $name });
	}	

}
##################################################################
sub templateDelete {
	my($name, $tpid) = @_;

	my $slashdb = getCurrentDB();

	return if getCurrentUser('seclev') < 500;
	$slashdb->deleteTemplate($tpid);
	print getMessage('templateDelete-message', { name => $name, tpid => $tpid });
}

##################################################################
# Block Editing and Saving 
# 020300 PMG modified the heck out of this code to allow editing
# of sectionblock values retrieve, title, url, rdf, section 
# to display a different form according to the type of block we're dealing with
# based on value of new column in blocks "type". Added description field to use 
# as information on the block to help the site editor get a feel for what the block 
# is for, etc... 
# Why bother passing seclev? Just pull it from the user object.
sub blockEdit {
	my($seclev, $bid) = @_;

	return if $seclev < 500;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	my($blockref, $saveflag, $block_select, $retrieve_checked,
		$portal_checked, $block_select1, $block_select2);
	my($blockedit_flag, $blockdelete_flag, $blockform_flag) = (0, 0, 0);

	if ($bid) {
		$blockref = $slashdb->getBlock($bid, '', 1);
	}
	my $sectionbid = $blockref->{section}; 

	my $title = getTitle('blockEdit-title',{}, 1);

	if ($form->{blockdelete} || $form->{blockdelete1} || $form->{blockdelete2}) {
		$blockdelete_flag = 1;
	} else { 
		# get the static blocks
		my $blocks = $slashdb->getDescriptions('static_block', $seclev, 1);
		$block_select1 = createSelect('bid1', $blocks, $bid, 1);

		$blocks = $slashdb->getDescriptions('portald_block', $seclev, 1);
		$block_select2 = createSelect('bid2', $blocks, $bid, 1);

	}

	# if the pulldown has been selected and submitted 
	# or this is a block save and the block is a portald block
	# or this is a block edit via sections.pl
	if (! $form->{blocknew} && $bid ) {
		if ($blockref->{bid}) {
			$blockedit_flag = 1;
			$blockref->{ordernum} = "NA" if $blockref->{ordernum} eq '';
			$retrieve_checked = "CHECKED" if $blockref->{retrieve} == 1; 
			$portal_checked = "CHECKED" if $blockref->{portal} == 1; 
		}	
	}	

	$blockform_flag = 1 if ( (! $form->{blockdelete_confirm} && $bid) || $form->{blocknew}) ;

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
		sectionbid		=> $sectionbid,
	});	
			
}

##################################################################
sub blockSave {
	my($bid) = @_;

	my $slashdb = getCurrentDB();

	return if getCurrentUser('seclev') < 500;
	return unless $bid;
	my $saved = $slashdb->saveBlock($bid);

	if (getCurrentForm('save_new') && $saved > 0) {
		print getMessage('blockSave-exists-message', { bid => $bid } );
		return;
	}	

	if ($saved == 0) {
		print getMessage('blockSave-inserted-message', { bid => $bid });
	}
	print getMessage('blockSave-saved-message', { bid => $bid });
}

##################################################################
sub blockDelete {
	my($bid) = @_;

	my $slashdb = getCurrentDB();

	return if getCurrentUser('seclev') < 500;
	$slashdb->deleteBlock($bid);
	print getMessage('blockDelete-message', { bid => $bid });
}

##################################################################
sub colorEdit {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();

	my($color_select, $block, $colorblock_clean, $title, @colors);
	return if $user->{'seclev'} < 500;

	my $colorblock;
	$form->{color_block} ||= 'colors';

	if ($form->{colorpreview}) {
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

	return if getCurrentUser('seclev') < 500;
	my $colorblock = join ',', @{$form}{qw[fg0 fg1 fg2 fg3 fg4 bg0 bg1 bg2 bg3 bg4]};

	$slashdb->saveColorBlock($colorblock);
}

##################################################################
# Topic Editor
sub topicEdit {

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $basedir = getCurrentStatic('basedir');

	return if getCurrentUser('seclev') < 500;
	my($topic, $topics_menu, $topics_select);
	my $available_images = {};
	my $image_select = "";

	my ($imageseen_flag,$images_flag) = (0,0);

	local *DIR;
	opendir(DIR, "$basedir/images/topics");
	# @$available_images = grep(/.*\.gif|jpg/i, readdir(DIR)); 

	$available_images = { map { ($_, $_) } grep /\.(?:gif|jpg)$/, readdir DIR };

	closedir(DIR);

	$topics_menu = $slashdb->getDescriptions('topics', '', 1);
	$topics_select = createSelect('nexttid', $topics_menu, $form->{nexttid},1);

	if (!$form->{topicdelete}) {

		$imageseen_flag = 1 if ($form->{nexttid} && ! $form->{topicnew} && ! $form->{topicdelete});

		if (!$form->{topicnew}) {
			$topic = $slashdb->getTopic($form->{nexttid});
		} else {
			$topic = {};
			$topic->{tid} = getTitle('topicEd-new-title',{},1);
		}

		if ($available_images) {
			$images_flag = 1;
			my $default = $topic->{image};
			$image_select = createSelect('image', $available_images, $default,1);
		} 
	}

	slashDisplay('topicEdit', {
		imageseen_flag		=> $imageseen_flag,
		images_flag		=> $images_flag,
		topic			=> $topic,
		topics_select		=> $topics_select,
		image_select		=> $image_select
	});		
}

##################################################################
sub topicDelete {

	my $slashdb = getCurrentDB();
	my $form_tid = getCurrentForm('tid');

	my $tid = $_[0] || $form_tid;

	print getMessage('topicDelete-message', { tid => $tid });
	$slashdb->deleteTopic($form_tid);
	$form_tid = '';
}

##################################################################
sub topicSave {

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	my $basedir = getCurrentStatic('basedir');

	if ($form->{tid}) {
		$slashdb->saveTopic();
		if (!$form->{width} && !$form->{height}) {
		    @{ $form }{'width', 'height'} = imgsize("$basedir/images/topics/$form->{image}");
		}
	}
	
	$form->{nexttid} = $form->{tid};

	print getMessage('topicSave-message');
}

##################################################################
sub listTopics {
	my($seclev) = @_;

	my $slashdb = getCurrentDB();
	my $imagedir = getCurrentStatic('imagedir');

	my $topics = $slashdb->getTopics();
	my $title = getTitle('listTopics-title');

	my $x = 0;
	my $topicref = {};

	for my $topic (values %$topics) {

		$topicref->{$topic->{tid}} = { 
			alttext  	=> $topic->{altext},
			image 		=> $topic->{image},
			height 		=> $topic->{height},
			width 		=> $topic->{width},
		};

		if ($x++ % 6) {
			$topicref->{$topic->{tid}}{trflag} = 1;
		}

		if ($seclev >= 500) {
			$topicref->{$topic->{tid}}{topicedflag} = 1;		
		}
	}

	slashDisplay('listTopics', {
			topicref 	=> $topicref,
			title		=> $title
		}
	);
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
	my ($story_content) = @_;

	my $constants = getCurrentStatic();
	my $related_links = "";

	my %relatedLinks = (
		intel		=> "Intel;http://www.intel.com",
		linux		=> "Linux;http://www.linux.com",
		lycos		=> "Lycos;http://www.lycos.com",
		redhat		=> "Red Hat;http://www.redhat.com",
		'red hat'	=> "Red Hat;http://www.redhat.com",
		wired		=> "Wired;http://www.wired.com",
		netscape	=> "Netscape;http://www.netscape.com",
		lc $constants->{sitename}	=> "$constants->{sitename};$constants->{rootdir}",
		malda		=> "Rob Malda;http://CmdrTaco.net",
		cmdrtaco	=> "Rob Malda;http://CmdrTaco.net",
		apple		=> "Apple;http://www.apple.com",
		debian		=> "Debian;http://www.debian.org",
		zdnet		=> "ZDNet;http://www.zdnet.com",
		'news.com'	=> "News.com;http://www.news.com",
		cnn		=> "CNN;http://www.cnn.com"
	);

	foreach my $key (keys %relatedLinks) {
		if (exists $relatedLinks{$key} && /\W$key\W/i) {
			my($label,$url) = split m/;/, $relatedLinks{$key};
			$label =~ s/(\S{20})/$1 /g;
			$related_links .= qq[<LI><A HREF="$url">$label</A></LI>\n];
		}
	}

	# And slurp in all the URLs just for good measure
	while ($story_content =~ m|<A(.*?)>(.*?)</A>|sgi) {
		my($url, $label) = ($1, $2);
		$label =~ s/(\S{30})/$1 /g;
		$related_links .= "<LI><A$url>$label</A></LI>\n" unless $label eq "[?]";
	}
	return $related_links;
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
# Story Editing
sub editStory {
	my($sid) = @_;

	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $constants = getCurrentStatic();

	my($authoredit_flag, $extracolumn_flag) = (0, 0);
	my($storyref, $story, $author, $topic, $storycontent, $storybox, $locktest,
		$editbuttons, $sections, $topic_select, $section_select, $author_select,
		$extracolumns, $displaystatus_select, $commentstatus_select, $description);
	my $extracolref = {};
	my($fixquotes_check,$autonode_check,$fastforward_check) = ('off','off','off');

	foreach (keys %{$form}) { $storyref->{$_} = $form->{$_} }

	my $newarticle = 1 if (!$sid && !$form->{sid});
	
	$extracolumns = $slashdb->getKeys($storyref->{section}) || [ ];
	if ($form->{title}) { 
		$storyref->{writestatus} = $slashdb->getVar('defaultwritestatus', 'value');
		$storyref->{displaystatus} = $slashdb->getVar('defaultdisplaystatus', 'value');
		$storyref->{commentstatus} = $slashdb->getVar('defaultcommentstatus', 'value');

		$storyref->{uid} ||= $user->{uid};
		$storyref->{section} = $form->{section};

		foreach (@{$extracolumns}) {
			$storyref->{$_} = $form->{$_} || $storyref->{$_};
		}

		$storyref->{writestatus} = $form->{writestatus} if exists $form->{writestatus};
		$storyref->{displaystatus} = $form->{displaystatus} if exists $form->{displaystatus};
		$storyref->{commentstatus} = $form->{commentstatus} if exists $form->{commentstatus};
		$storyref->{dept} =~ s/[-\s]+/-/g;
		$storyref->{dept} =~ s/^-//;
		$storyref->{dept} =~ s/-$//;

		$storyref->{introtext} = $slashdb->autoUrl($form->{section}, $storyref->{introtext});
		$storyref->{bodytext} = $slashdb->autoUrl($form->{section}, $storyref->{bodytext});

		$topic = $slashdb->getTopic($storyref->{tid});
		$form->{uid} ||= $user->{uid};
		$author = $slashdb->getAuthor($form->{uid});
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
		$storyref->{relatedtext} = getRelated("$storyref->{title} $storyref->{bodytext} $storyref->{introtext}")
			. otherLinks($slashdb->getAuthor($storyref->{uid}, 'nickname'), $storyref->{tid}, $storyref->{uid});

		$storybox = fancybox($constants->{fancyboxwidth}, 'Related Links', $storyref->{relatedtext},0,1);

	} elsif (defined $sid) { # Loading an existing SID
		my $tmp = $user->{currentSection};
		$user->{currentSection} = $slashdb->getStory($sid, 'section');
		($story, $storyref, $author, $topic) = displayStory($sid, 'Full');
		$user->{currentSection} = $tmp;
		$storybox = fancybox($constants->{fancyboxwidth},'Related Links', $storyref->{relatedtext},0,1);

	} else { # New Story
		$storyref->{writestatus} = $slashdb->getVar('defaultwritestatus', 'value');
		$storyref->{displaystatus} = $slashdb->getVar('defaultdisplaystatus', 'value');
		$storyref->{commentstatus} = $slashdb->getVar('defaultcommentstatus', 'value');

		$storyref->{'time'} = $slashdb->getTime();
		# hmmm. I don't like hardcoding these PMG 10/19/00
		# I would agree. How about setting defaults in vars
		# that can be override? -Brian
		$storyref->{tid} ||= 'news';
		$storyref->{section} ||= 'articles';

		$storyref->{uid} = $user->{uid};
	}

	$sections = $slashdb->getDescriptions('sections');

	$editbuttons = editbuttons($newarticle);

	$topic_select = selectTopic('tid', $storyref->{tid}, 1);

	$section_select = selectSection('section', $storyref->{section}, $sections, 1) unless $user->{section};

	if ($user->{seclev} >= 100) {
		$authoredit_flag = 1;
		my $authors = $slashdb->getDescriptions('authors');
		$author_select = createSelect('uid', $authors, $storyref->{uid}, 1);
	} 

	$storyref->{dept} =~ s/ /-/gi;

	$locktest = lockTest($storyref->{title});

	unless ($user->{section}) {
		$description = $slashdb->getDescriptions('displaycodes');
		$displaystatus_select = createSelect('displaystatus', $description, $storyref->{displaystatus},1);
	}
	$description = $slashdb->getDescriptions('commentcodes');
	$commentstatus_select = createSelect('commentstatus', $description, $storyref->{commentstatus},1);

	$fixquotes_check = "on" if $form->{fixquotes};
	$autonode_check = "on" if $form->{autonode};
	$fastforward_check = "on" if $form->{fastforward};

	if (@{$extracolumns}) {
		$extracolumn_flag = 1;

		foreach (@{$extracolumns}) {
			next if $_ eq 'sid';
			my($sect, $col) = split m/_/;
			$storyref->{$_} = $form->{$_} || $storyref->{$_};

			$extracolref->{$_}{sect} = $sect;
			$extracolref->{$_}{col} = $col;
		}
	}

# hmmmm
#Import Image (don't even both trying this yet :)<BR>
#	<INPUT TYPE="file" NAME="importme"><BR>

	$slashdb->setSession($user->{uid}, { lasttitle => $storyref->{title} });

	slashDisplay('editStory', {
		storyref 		=> $storyref,
		story			=> $story,
		storycontent		=> $storycontent,
		storybox		=> $storybox,
		sid			=> $sid,
		editbuttons		=> $editbuttons,
		topic_select		=> $topic_select,
		section_select		=> $section_select,
		author_select		=> $author_select,
		locktest		=> $locktest,
		displaystatus_select	=> $displaystatus_select,
		commentstatus_select	=> $commentstatus_select,
		fixquotes_check		=> $fixquotes_check,
		autonode_check		=> $autonode_check,
		fastforward_check	=> $fastforward_check,
		extracolumn_flag	=> $extracolumn_flag,
		extracolref		=> $extracolref,
		user			=> $user,
		authoredit_flag		=> $authoredit_flag,
	});
}

##################################################################
sub listStories {

	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $form = getCurrentForm();

	my($x, $first) = (0, $form->{'next'});
	my $storylist = $slashdb->getStoryList();

	my $storylistref = [];

	my($hits, $comments, $sid, $title, $aid, $time, $tid, $section, 
	$displaystatus, $writestatus, $td, $td2, $yesterday, $tbtitle,
	$count, $left, $substrtid,$substrsection, $sectionflag);

	my($i, $canedit) = (0, 0);

	for (@$storylist) {
		($hits, $comments, $sid, $title, $aid, $time, $tid, $section,
			$displaystatus, $writestatus, $td, $td2) = @$_;

		$substrtid = substr($tid, 0, 5);
		
		$title = substr($title, 0, 50) . '...' if (length $title > 55);

		if ($user->{uid} eq $aid || $user->{seclev} >= 100) {
			$canedit = 1;
			$tbtitle = fixparam($title);
		} 

		$x++;
		next if $x < $first;
		last if $x > $first + 40;

		unless ($user->{section} || $form->{section}) {
			$sectionflag = 1;
			$substrsection = substr($section, 0, 5);
		}

		$storylistref->[$i] = {
			'x'		=> $x,
			hits		=> $hits,
			comments	=> $comments,
			sid		=> $sid,
			title		=> $title,
			aid		=> $slashdb->getAuthor($aid, 'nickname'),
			'time'		=> $time,
			canedit		=> $canedit,
			substrtid	=> $substrtid,
			section		=> $section,
			sectionflag	=> $sectionflag,
			substrsection	=> $substrsection,
			td		=> $td,
			td2		=> $td2,
			writestatus	=> $writestatus,
			displaystatus	=> $displaystatus,
		};
		
		$i++;
	}

	$count = @$storylist;
	$left = $count - $x;

	slashDisplay('listStories', {
		storylistref	=> $storylistref,
		'x'		=> $x,
		left		=> $left
	});	
}

##################################################################
sub rmStory {
	my($sid) = @_;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	$slashdb->deleteStory($sid);

	titlebar('100%', getTitle('rmStory-title', {sid => $sid}));
}

##################################################################
sub listFilters {
	my($header, $footer);

	my $slashdb = getCurrentDB();

	my $title = getTitle('listFilters-title');
	my $filter_ref = $slashdb->getContentFilters();

	slashDisplay('listFilters', { 
		title		=> $title, 
		filter_ref	=> $filter_ref 
	});
}

##################################################################
sub editFilter {
	my($filter_id) = @_;

	my $slashdb = getCurrentDB();

	$filter_id ||= getCurrentForm('filter_id');

	my @values = qw(regex modifier field ratio minimum_match
		minimum_length maximum_length err_message);
	my $filter = $slashdb->getContentFilter($filter_id, \@values, 1);

	# this has to be here - it really screws up the block editor
	$filter->{err_message} = strip_literal($filter->{'err_message'});

	slashDisplay('editFilter', { 
		filter		=> $filter, 
		filter_id	=> $filter_id 
	});
}

##################################################################
# updateFilter - 3 possible actions
# 1 - create new filter
# 2 - update existing
# 3 - delete existing
sub updateFilter {
	my($filter_action) = @_;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	
	if ($filter_action == 1) {
		my $filter_id = $slashdb->createContentFilter();
		titlebar("100%", getTitle('updateFilter-new-title', { filter_id => $filter_id }));
		editFilter($filter_id);

	} elsif ($filter_action == 2) {
		if (!$form->{regex} || !$form->{regex}) {
			print getMessage('updateFilter-message');
			editFilter($form->{filter_id});

		} else {
			$slashdb->setContentFilter();
		}

		titlebar("100%", getTitle('updateFilter-update-title'));
		editFilter($form->{filter_id});

	} elsif ($filter_action == 3) {
		$slashdb->deleteContentFilter($form->{filter_id});
		titlebar("100%", getTitle('updateFilter-delete-title'));
		listFilters();
	}
}

##################################################################
sub editbuttons {
	my($newarticle) = @_;
	my $editbuttons = slashDisplay('editbuttons',
		{ newarticle => $newarticle }, 1);
	return $editbuttons
}

##################################################################
sub updateStory {

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	# Some users can only post to a fixed section
	if (my $section = getCurrentUser('section')) {
		$form->{section} = $section;
		$form->{displaystatus} = 1;
	}

	$form->{writestatus} = 1;

	$form->{dept} =~ s/ /-/g;

	$form->{aid} = $slashdb->getStory($form->{sid}, 'aid')
		unless $form->{aid};
	$form->{relatedtext} = getRelated("$form->{title} $form->{bodytext} $form->{introtext}")
		. otherLinks($slashdb->getAuthor($form->{uid}, 'nickname'), $form->{tid}, $form->{uid});

	$slashdb->updateStory();
	titlebar('100%', getTitle('updateStory-title'));
	listStories();
}

##################################################################
sub saveStory {

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();
	# my $user = getCurrentUser();
	my $user = $slashdb->getUser($form->{uid});
	my $rootdir = getCurrentStatic('rootdir');

	$form->{displaystatus} ||= 1 if $user->{section};
	$form->{section} = $user->{section} if $user->{section};
	$form->{dept} =~ s/ /-/g;
	$form->{relatedtext} = getRelated(
		"$form->{title} $form->{bodytext} $form->{introtext}"
	) . otherLinks($user->{nickname}, $form->{tid}, $user->{uid});
	$form->{writestatus} = 1 unless $form->{writestatus} == 10;

	my $sid = $slashdb->createStory($form);
	$slashdb->createDiscussion($sid, $form->{title}, 
		$form->{'time'}, 
		"$rootdir/article.pl?sid=$sid"
	);

	titlebar('100%', getTitle('saveStory-title'));
	listStories();
}

#################################################################
sub getMessage {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	return slashDisplay('messages', $hashref,
		{ Return => 1, Nocomm => $nocomm });
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
}


createEnvironment();
main();
1;
