#!/usr/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;
use Image::Size;
use Time::HiRes;
use LWP::UserAgent;
use URI;
use Encode 'decode_utf8';

use Apache2::RequestUtil;
use Apache2::Request;
use Apache2::Upload;
use Slash;
use Slash::Display;
use Slash::Hook;
use Slash::Utility;
use Slash::Admin::PopupTree;

sub main {
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();
	my $postflag = $user->{state}{post};
	# lc just in case
	my $op = $form->{op} || '';
	$op = lc($op);

	my $tbtitle = '';

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
		commentlog	=> {
			function	=> \&commentLog,
			seclev		=> 100,
			adminmenu	=> 'security',
			tab_selected	=> 'commentlog'
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
		moderate_recent		=> {
			function	=> \&moderate,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'recent',
		},
		siteinfo	=> {
			function 	=> \&siteInfo,
			seclev		=> 10000,
			adminmenu	=> 'info',
			tab_selected	=> 'site',
		},
		topictree	=> {
			function 	=> \&topicTree,
			seclev		=> 100,
			adminmenu	=> 'info',
			tab_selected	=> 'topictree',
		},
		templates 	=> {
			function 	=> \&templateEdit,
			seclev		=> 1000,
			adminmenu	=> 'config',
			tab_selected	=> 'templates',
		},
		topics 		=> {	# topiced,topicnew,topicsave,topicdelete
			function 	=> \&topicEdit,
			seclev		=> 10000,
			adminmenu	=> 'config',
			tab_selected	=> 'topics',
		},
		topic_extras 	=> {
			function 	=> \&topicExtrasEdit,
			seclev		=> 10000,
			adminmenu	=> 'config',
			tab_selected	=> 'topics',
		},
		update_extras 	=> {
			function 	=> \&topicExtrasEdit,
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
		acls		=> {
			function	=> \&aclEdit,
			seclev		=> 10000,
			adminmenu	=> 'config',
			tab_selected	=> 'acls',
		},
		recent		=> {
			function	=> \&displayRecent,
			seclev		=> 500,
			adminmenu	=> 'security',
			tab_selected	=> 'recent',
		},
		recent_mods		=> {
			function	=> \&displayRecentMods,
			seclev		=> 500,
			adminmenu	=> 'security',
			tab_selected	=> 'recent_mods',
		},
		spam_mods		=> {
			function	=> \&displaySpamMods,
			seclev		=> 500,
			adminmenu	=> 'security',
			tab_selected	=> 'spam_mods',
		},
		mod_bombs		=> {
			function	=> \&displayModBombs,
			seclev		=> 500,
			adminmenu	=> 'security',
			tab_selected	=> 'mod_Bombs',
		},
		recent_requests		=> {
			function	=> \&displayRecentRequests,
			seclev		=> 500,
			adminmenu	=> 'security',
			tab_selected	=> 'requests',
		},
		recent_subs		=> {
			function	=> \&displayRecentSubs,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'subs',
		},
		recent_webheads		=> {
			function	=> \&displayRecentWebheads,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'webheads',
		},
		mcd_stats		=> {
			function	=> \&displayMcdStats,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'mcdstats',
		},
		signoff_stats 		=> {
			function	=> \&displaySignoffStats,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'signoff'
		},
		peerweights 		=> {
			function	=> \&displayPeerWeights,
			seclev		=> 500,
			adminmenu	=> 'info',
			tab_selected	=> 'pw'
		},
		static_files		=> {
			function	=> \&showStaticFiles,
			seclev		=> 100,
			adminmenu	=> 'info',
		}
	};

	# admin.pl is not for regular users
	if ($user->{seclev} < 100) {
		redirect("$gSkin->{rootdir}/users.pl");
		return;
	}
	# non suadmin users can't perform suadmin ops
	unless ($ops->{$op}) {
		$op = 'default';
	}
	$op = 'list' if $user->{seclev} < $ops->{$op}{seclev};
	$op ||= 'list';

	if ($form->{op} && $form->{op} =~ /^preview|edit$/ && $form->{title}) {
		# Show submission/article title on browser's titlebar.
		$tbtitle = $form->{title};
		$tbtitle =~ s/"/'/g;
		$tbtitle = " - \"$tbtitle\"";
		# Undef the form title value if we have SID defined, since the editor
		# will have to get this information from the database anyways.
		undef $form->{title} if $form->{sid} && $form->{op} eq 'edit';
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
	header("backSlash$time_remark$tbtitle", '', $data) or return;
	# admin menu is printed from within the 'header' template

	# it'd be nice to have a legit retval
	my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants, $gSkin);

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
		}
	}
}

##################################################################
# ACLs Edit
# This is for editing the list of ACLs that are defined on your
# Slash site.  To edit which users have those ACLs, see users.pl.
sub aclEdit {
	my($form, $slashdb, $user, $constants) = @_;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $all_acls_hr;

	# If we need to create an ACL, do so.  By doing this before we
	# get the list of all ACLs in use, we make sure that when we
	# get that list, it will include the ACL we just created.
	if ($form->{aclsave}) {
		aclSave(@_, $all_acls_hr);
		# We go to the master DB for the definitive list,
		# because the ACL we created moments ago may not
		# have replicated to the reader DBs yet.
		$all_acls_hr = $slashdb->getAllACLs();
	} else {
		# Not creating any ACLs with this click, so trust
		# that the readers have the correct list.
		$all_acls_hr = $reader->getAllACLs();
	}

	slashDisplay('aclEdit', {
		title		=> getTitle('aclEdit-title'),
		acls		=> $all_acls_hr,
	});
}

##################################################################
sub aclSave {
	my($form, $slashdb, $user, $constants, $gSkin, $all_acls_hr) = @_;

	return unless $form->{thisname};

	# Set the current user (the admin) to have this acl.  Creating
	# a single acl entry makes it exist.
	$slashdb->setUser($user->{uid}, {
		acl => { $form->{thisname}, 1 }
	});

	print getData('aclSave-message');
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
sub topicTree {
	my($form, $slashdb, $user, $constants) = @_;

	slashDisplay('topicTree');
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

	my($seclev, $tpid, $page, $skin);
	my $seclev_flag = 1;

	my($title, $templateref, $template_select, $page_select,
		$skin_select, $savepage_select, $saveskin_select);

	my($templatedelete_flag, $templateedit_flag, $templateform_flag) = (0, 0, 0);
	my $pagehashref = {};
	$title = getTitle('templateEdit-title', {}, 1);
	#Just to punish those section only admins! -Brian
	# XXXSKIN jamie? -- pudge
	# $form->{section} = $user->{section} if $user->{section};

	if ($form->{templatenew} || $form->{templatepage} || $form->{templateskin} || $form->{templatepageandskin} || $form->{templatesearch}) {
		$tpid = '';
		$page = $form->{page};
		$skin = $form->{skin};

	} elsif ($form->{templatesave} || $form->{templatesavedef}) {
		$page = $form->{newP} ? $form->{newpage} : $form->{savepage};
		$skin = $form->{newS} ? $form->{newskin} : $form->{saveskin};

		my $templateref = $slashdb->getTemplate($form->{thistpid}, '', 1);
		if ($templateref->{seclev} <= $user->{seclev}) {
			templateSave($form->{thistpid}, $form->{name}, $page, $skin);
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
		$skin = $form->{skin};
	}

	$page ||= 'misc';
	$skin ||= 'default';

	$templateref = $slashdb->getTemplate($tpid, '', 1) if $tpid;

	$seclev_flag = 0 if defined($templateref->{seclev}) && $templateref->{seclev} > $user->{seclev};

	if ($form->{templatedelete}) {
		$templatedelete_flag = 1;
	} else {
		my $templates = {};

		my $getpage = $page eq 'All' ? '' : $page;
		my $getskin = $skin eq 'All' ? '' : $skin;

		unless ($form->{templateskin} || $form->{templatepage} || $form->{templatepageandskin} || $form->{templatesearch}) {
			$form->{ $form->{templatelastselect} } = 1;
		}

		if ($form->{templateskin}) {
			$getpage = '';
			$form->{templatelastselect} = 'templateskin';
		} elsif ($form->{templatepage}) {
			$getskin = '';
			$form->{templatelastselect} = 'templatepage';
		}

		if ($form->{templatesearch}) {
			$getskin = $getpage = '';
			$form->{templatelastselect} = 'templatesearch';
			$templates = $slashdb->getTemplateListByText($form->{'templatesearchtext'});
		} else {
			$templates = $slashdb->getTemplateList($getskin, $getpage);
		}

		my $pages = $slashdb->getDescriptions('pages', $page, 1);
		my $skins = $slashdb->getDescriptions('templateskins', $skin, 1);

		$pages->{All}     = 'All';
		$pages->{misc}    = 'misc';
		$skins->{All}     = 'All';
		$skins->{default} = 'default';

		# put these in alpha order by label, and add tpid to label
		my @ordered;
		for (sort { $templates->{$a} cmp $templates->{$b} } keys %$templates) {
			push @ordered, $_;
			$templates->{$_} = $templates->{$_} . " ($_)";
		}

		$template_select = createSelect('tpid',     $templates, $tpid, 1, 0, \@ordered);
		$page_select     = createSelect('page',     $pages,     $page, 1);
		$savepage_select = createSelect('savepage', $pages,     $templateref->{page} || $form->{page}, 1);
		$skin_select     = createSelect('skin',     $skins,     $skin, 1);
		$saveskin_select = createSelect('saveskin', $skins,     $templateref->{skin} || $form->{skin}, 1);
	}

	if (!$form->{templatenew} && $tpid && $templateref->{tpid}) {
		$templateedit_flag = 1;
	}

	$templateform_flag = 1 if (! $form->{templatedelete_confirm} && $tpid) || $form->{templatenew};

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
		skin_select		=> $skin_select,
		saveskin_select		=> $saveskin_select,
	});
}

##################################################################
sub templateSave {
	my($tpid, $name, $page, $skin) = @_;

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
	my $temp = $slashdb->getTemplateByName($name, {
		values		=> [ 'skin', 'page', 'name', 'tpid', 'seclev' ],
		cache_flag	=> 1,
		page		=> $page,
		skin		=> $skin,
	});

	return if $temp->{seclev} > $user->{seclev};
	my $exists = 0;
	$exists = 1 if ($name eq $temp->{name} &&
			$skin eq $temp->{skin} &&
			$page eq $temp->{page});

	# Strip non-unix newlines.
	for (qw( template title description )) {
		$form->{$_} =~ s/(\r\n|\r)/\n/g;
	}

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
				skin		=> $skin
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
			skin		=> $skin
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
# XXXSKIN - ???
#	$form->{section} = $user->{section} if $user->{section};

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

	my($blockref, $saveflag, $block_select, $retrieve_checked, $all_skins_checked,
		$portal_checked, $default_block_checked, $hidden_checked, $always_on_checked, $block_select1, $block_select2);
	my($blockedit_flag, $blockdelete_flag, $blockform_flag) = (0, 0, 0);
	$blockref = {};

	if ($bid) {
		$blockref = $slashdb->getBlock($bid, '', 1);
	}
	my $rss_templates = $slashdb->getTemplateList('','portald');
	my $rss_ref = { map { ($_, $_) } values %{$rss_templates} };

	$blockref->{rss_template} ||= $constants->{default_rss_template} || 'default';
	my $rss_select = createSelect('rss_template', $rss_ref, $blockref->{rss_template}, 1);	
	my $template_ref = $slashdb->getTemplateByName($blockref->{rss_template}, {
		values		=> [ 'template' ],
		cache_flag	=> 1,
		page		=> 'portald',
		skin		=> $blockref->{skin}
	});
	my $rss_template_code = $template_ref->{template}; 

	if ($form->{blockdelete} || $form->{blockdelete1} || $form->{blockdelete2}) {
		$blockdelete_flag = 1;
	} else {
		# get the static blocks
		my($static_blocks, $portal_blocks);
# XXXSKIN - ???
#		if ($user->{section}) {
#			$static_blocks = $slashdb->getDescriptions('static_block_section', { seclev => $user->{seclev}, section => $user->{section} }, 1);
#			$portal_blocks = $slashdb->getDescriptions('portald_block_section', { seclev => $user->{seclev}, section => $user->{section} }, 1);
#		} else {
			$static_blocks = $slashdb->getDescriptions('static_block', $user->{seclev}, 1);
			$portal_blocks = $slashdb->getDescriptions('portald_block', $user->{seclev}, 1);
#		}
		$block_select1 = createSelect('bid1', $static_blocks, $bid, 1);

		$block_select2 = createSelect('bid2', $portal_blocks, $bid, 1);

	}
	my $blocktype = $slashdb->getDescriptions('blocktype', '', 1);
	my $blocktype_select = createSelect('type', $blocktype, $blockref->{type}, 1);

	my $yes_no = $slashdb->getDescriptions('yes_no', '', 1);
	my $autosubmit_select = createSelect('autosubmit', $yes_no, $blockref->{autosubmit}, 1);
	$default_block_checked = $constants->{markup_checked_attribute} if $blockref->{default_block} == 1;
	$hidden_checked = $constants->{markup_checked_attribute} if $blockref->{hidden} == 1;
	$always_on_checked = $constants->{markup_checked_attribute} if $blockref->{always_on} == 1;
	
	# if the pulldown has been selected and submitted
	# or this is a block save and the block is a portald block
	# or this is a block edit via sections.pl
	if (! $form->{blocknew} && $bid) {
		if ($blockref->{bid}) {
			$blockedit_flag = 1;
			$blockref->{ordernum} = "NA" if $blockref->{ordernum} eq '';
			$retrieve_checked = $constants->{markup_checked_attribute} if $blockref->{retrieve} == 1;
			$all_skins_checked = $constants->{markup_checked_attribute} if $blockref->{all_skins} == 1;
			$portal_checked = $constants->{markup_checked_attribute} if $blockref->{portal} == 1;
		}
	}

	$blockform_flag = 1 if (! $form->{blockdelete_confirm} && $bid) || $form->{blocknew};

	my $title = getTitle('blockEdit-title', { bid => $bid }, 1);
	$blockref->{items} ||= $constants->{rss_max_items_incoming};

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
		default_block_checked		=> $default_block_checked,
		hidden_checked		=> $hidden_checked,
		always_on_checked		=> $always_on_checked,
		retrieve_checked	=> $retrieve_checked,
		all_skins_checked	=> $all_skins_checked,
		blocktype_select	=> $blocktype_select,
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
			join ',', @{$form}{qw[fg0 fg1 fg2 fg3 fg4 fg5 bg0 bg1 bg2 bg3 bg4 bg5]};

		# the #s will break the url
		$colorblock_clean =~ s/#//g;

	} else {
		$colorblock = $slashdb->getBlock($form->{color_block}, 'block');
	}

	@colors = split m/,/, $colorblock;

	$user->{fg} = [@colors[0..5]];
	$user->{bg} = [@colors[6..11]];

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
sub commentLog {
	my($form, $slashdb, $user, $constants) = @_;
	my $commentlog = $slashdb->getRecentCommentLog();
	slashDisplay("commentlog", { commentlog => $commentlog });
}

##################################################################
sub colorSave {
	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	my $colorblock = join ',', @{$form}{qw[fg0 fg1 fg2 fg3 fg4 fg5 bg0 bg1 bg2 bg3 bg4 bg5]};

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
	my($image, $image2, $topic, $image_select, $images_flag);

	if ($form->{topicdelete} && $form->{tid}) {
		topicDelete($form->{tid});
		print getData('topicDelete-message', { tid => $form->{tid} });

	} elsif ($form->{topicsave}) {
		topicSave(@_);
		print getData('topicSave-message');
	}

	opendir(my($dh), "$basedir/images/topics");
	# this should be a preference at some point, image
	# extensions ... -- pudge
	my $available_images = { map { ($_, $_) } grep /\.(?:gif|jpe?g|png)$/i, readdir $dh };
	closedir $dh;
	$available_images->{""} = "None";

	my %topic_desc = %{$slashdb->getDescriptions('topics', '', 1)};
	for my $tid (keys %topic_desc) {
		delete $topic_desc{$tid} if $tid && !(	# just in case someone added a bad tid
							# filter out product guide topics
			$tid < ($constants->{product_guide_tid_lower_limit} || 10_000)
				||
			$tid > ($constants->{product_guide_tid_upper_limit} || 20_000)
		);
	}

	my $topic_param = [];
	my($parents, $children);
	if (!$form->{topicnew} && $form->{nexttid}) {
		my $tree  = $slashdb->getTopicTree(undef, { no_cache => 1 });
		$topic    = $tree->{ $form->{nexttid} };
		$parents  = $topic->{parent};
		$children = $topic->{child};
		# We could get this by reading $topic->{topic_param_keys}
		# but getTopicParamsForTid() works too.  For that matter,
		# the topicEdit template could read it directly out of
		# $topic, no need to create it separately... oh well :)
		$topic_param = $slashdb->getTopicParamsForTid($form->{nexttid});
	} else {
		$topic = {};
		$parents = {};
		$children = {};
	}

	my $topic_select = Slash::Admin::PopupTree::getPopupTree(
		$parents, { type => 'ui_topiced' }, { stcid => $children }
	);

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
		topic_select		=> $topic_select,
		topic_desc		=> \%topic_desc,
		image_select		=> $image_select,
		topic_param		=> $topic_param,
	});
}

sub topicExtrasEdit {
	my($form, $slashdb, $user, $constants) = @_;
	my $extras = [];
	if ($form->{tid}) {
		if ($form->{op} eq "update_extras") {
			updateTopicNexusExtras($form->{tid});
		}
		$extras = $slashdb->getNexusExtras($form->{tid}, {content_type => "all"});
		slashDisplay("topicExtrasEdit", {
			extras => $extras
		});
	} else {
		print getData("no-tid-specified");
	}
}

sub updateTopicNexusExtras {
	my($tid) = @_;
	my $form = getCurrentForm();
	my $slashdb = getCurrentDB();
	return unless $tid;

	foreach my $key (keys %$form) {
		if ($key =~/^ex_del_(\d+)$/ && $form->{$key}) {
			$slashdb->deleteNexusExtra($1);
		} elsif ($key =~ /^ex_kw_new$/ and $form->{ex_kw_new}) {
			my $extra = {};
			$extra->{extras_keyword} = $form->{ex_kw_new};
			$extra->{extras_textname} = $form->{ex_tn_new};
			$extra->{type} = $form->{ex_ty_new};
			$extra->{content_type} = $form->{ex_ct_ty_new};
			$extra->{required} = $form->{ex_rq_new};
			$extra->{ordering} = $form->{ex_ordering_new};
			$slashdb->createNexusExtra($tid, $extra);
		} elsif ($key =~/^ex_kw_(\d+)$/) {
			my $id = $1;
			my $extra = {};
			$extra->{extras_keyword} = $form->{"ex_kw_$id"};
			$extra->{extras_textname} = $form->{"ex_tn_$id"};
			$extra->{type} = $form->{"ex_ty_$id"};
			$extra->{content_type} = $form->{"ex_ct_ty_$id"};
			$extra->{required} = $form->{"ex_rq_$id"};
			$extra->{ordering} = $form->{"ex_ordering_$id"};
			$slashdb->updateNexusExtra($id, $extra);
		}
	}
}

##################################################################
sub topicDelete {
	my($tid) = @_;

	my $slashdb = getCurrentDB();
	my $form = getCurrentForm();

	$tid ||= $form->{tid};

	my($success, $errmsg) = $slashdb->deleteTopic($tid, $form->{replacementtid});

	if (!$success) {
		# we should dump this to the screen instead
		warn $errmsg;
		slashHook('admin_topic_delete_failed',
			{ tid => $form->{tid}, replacement => $form->{replacementtid} });
		$form->{nexttid} = $form->{tid};
		$form->{tid} = '';
	} else {
		slashHook('admin_topic_delete_success',
			{ tid => $form->{tid}, replacement => $form->{replacementtid} });
		$form->{nexttid} = $form->{replacementtid};
	}
}

##################################################################
sub topicSave {
	my($form, $slashdb, $user, $constants) = @_;
	my $basedir = $constants->{basedir};

	my($chosen_hr, $chosenc_hr) = extractChosenFromForm($form);
	$form->{parent_topic} = $chosen_hr;
	$form->{child_topic} = $chosenc_hr;

	if (!$form->{width} && !$form->{height} && ! $form->{image2}) {
		@{ $form }{'width', 'height'} = imgsize("$basedir/images/topics/$form->{image}");
	}
	my $topic_param = {};
	foreach my $key (keys %$form) {
		next unless $key=~/^tp_cur_/ || $key=~/^tpname_new_/;
		my $param_name;
		my $num;
		if (($param_name) = $key =~ /^tp_cur_(.*)$/) {
			$topic_param->{$param_name} = $form->{$key};
		} elsif(($num) = $key =~/^tpname_new_(.*)/) {
			if ($form->{"tpname_new_$num"}) {
				$topic_param->{$form->{"tpname_new_$num"}} = $form->{"tpvalue_new_$num"};
			}
		}
	}

	my $options = { param => $topic_param };
	
	$form->{tid} = $slashdb->saveTopic($form, $options);
	$form->{nexttid} = $form->{tid};
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
# Story Editing
sub editStory {
	my($form, $slashdb, $user, $constants, $gSkin) = @_;
	my $admindb = getObject('Slash::Admin');

	my($stoid, $sid, $storylinks);

	# Here we validate stoid
	if ($form->{op} eq 'edit') {
		$stoid = $slashdb->getStory($form->{stoid} || $form->{sid},
			'stoid', 1);
	}


	# Basically, we upload the bodytext if we realize a name has been passed in -Brian
	if ($form->{bodytext_file}) {
                my $r = Apache2::RequestUtil->request;
                my $req = Apache2::Request->new($r);
                my $upload = $req->upload("bodytext_file");

		if ($upload) {
			my $temp_body;
			$form->{bodytext} = '';
			my $fh = $upload->fh;
			binmode $fh, ':encoding(UTF-8)';
			while (<$fh>) {
				$form->{bodytext} .= $_;
			}
		}
	}

	$slashdb->setCommonStoryWords();

	my($extracolumn_flag) = (0, 0);
	my($storyref, $story, $author, $storycontent, $locktest,
		$extracolumns, $commentstatus_select, 
		$subid, $fhid, $description);
	my $extracolref = {};
	my($fixquotes_check, $autonode_check, $fastforward_check) = ('','','');
	my $page = 'index';
	# If the user is a section only admin, we do that, if they have filled out a form we do that but 
	# if none of these apply we just do defaultsection -Brian
	# XXXSKIN - ???
	my $section = $user->{section} || $form->{section} || $constants->{defaultsection};

	for (keys %{$form}) { $storyref->{$_} = $form->{$_} }

	my $newarticle = 1 if !$stoid && !$form->{stoid} && !$form->{sid};

	my $display_check;

	# Editing a story that has yet to go into the DB...
	# basically previewing. -Brian 
	# I've never understood why we check *this* field to make
	# that determination.  Now that we have $newarticle, should
	# we be using that instead? - Jamie
	# if that tells us, then sure - pudge
	
	if ($form->{title}) {
		my $storyskin = $gSkin;
		$storyskin = $slashdb->getSkin($form->{skin}) if $form->{skin};

		$storyref->{is_dirty}      = 1;
		$storyref->{commentstatus} = $form->{commentstatus};

		$storyref->{uid} ||= $user->{uid};
		$storyref->{dept} ||= '';
		$storyref->{dept} =~ s/[-\s]+/-/g;
		$storyref->{dept} =~ s/^-//;
		$storyref->{dept} =~ s/-$//;

		my($related_sids_hr, $related_urls_hr, $related_cids_hr, $related_firehose_hr) = $admindb->extractRelatedStoriesFromForm($form, $storyref->{sid});
		$storyref->{related_sids_hr} = $related_sids_hr;
		$storyref->{related_urls_hr} = $related_urls_hr;
		$storyref->{related_cids_hr} = $related_cids_hr;
		my($chosen_hr) = extractChosenFromForm($form);
		$storyref->{topics_chosen} = $chosen_hr;

		my $rendered_hr = $slashdb->renderTopics($chosen_hr);
		$storyref->{topics_rendered} = $rendered_hr;
		$storyref->{primaryskid} = $slashdb->getPrimarySkidFromRendered($rendered_hr);
		$storyref->{topiclist} = $slashdb->getTopiclistFromChosen($chosen_hr,
			{ skid => $storyref->{primaryskid} });

		$extracolumns = $slashdb->getNexusExtrasForChosen($chosen_hr);

		for my $field (qw( introtext bodytext )) {
			local $Slash::Utility::Data::approveTag::admin = 2;
			$storyref->{$field} = $slashdb->autoUrl($form->{section}, $storyref->{$field});
			$storyref->{$field} = cleanSlashTags($storyref->{$field});
			$storyref->{$field} = strip_html($storyref->{$field});
			#$storyref->{$field} = slashizeLinks($storyref->{$field});
			$storyref->{$field} = parseSlashizedLinks($storyref->{$field});
			$storyref->{$field} = balanceTags($storyref->{$field});
			# This should be moved to balanceTags once that braindead POS is fixed -- paulej72 20150617
			$storyref->{$field} =~ s|</p>|</p>\n\n|g;
			$storyref->{$field} =~ s|</li>|</li>\n|g;
			$storyref->{$field} =~ s|</ol>|</ol>\n\n|g;
			$storyref->{$field} =~ s|</ul>|</ul>\n\n|g;
			$storyref->{$field} =~ s|</blockquote>|</blockquote>\n\n|g;
			$storyref->{$field} =~ s|</spoiler>|</spoiler>\n\n|g;			
			$storyref->{$field} =~ s|(</?h.>)\s*</p>|$1|g;
		}

		$form->{uid} ||= $user->{uid};
		$subid = $form->{subid};
		$fhid = $form->{fhid};
		$sid = $form->{sid};

		# not normally set here, so we force it to be safe
		$storyref->{tid} = $storyref->{topiclist};
			
		$storyref->{'time'} = $admindb->findTheTime();

		# Get wordcounts
		$storyref->{introtext_wordcount} = countWords($storyref->{introtext});
		$storyref->{bodytext_wordcount} = countWords($storyref->{bodytext});

		if ($form->{firstpreview}) {
			$display_check = $constants->{markup_checked_attribute};
			$storyref->{commentstatus}	= $constants->{defaultcommentstatus};
		} else {
			$display_check = $form->{display} ? $constants->{markup_checked_attribute} : '';
		}

		$stoid = $slashdb->getStory($form->{stoid} || $form->{sid}, 'stoid', 1);
		if ($stoid) {
			handleMediaFileForStory($stoid);
			$storyref->{stoid} = $stoid;
		}

	} elsif ($stoid) { # Loading an existing SID

		$user->{state}{editing} = 1;
		# Overwrite all the $storyref keys we copied in from $form.
		$storyref = $slashdb->getStory($stoid, '', 1);
		my $tmp = $user->{currentSkin} || $gSkin->{textname};
		$user->{currentSkin} = $storyref->{skin}{name};
		
		my $related = $slashdb->getRelatedStoriesForStoid($storyref->{stoid});
		my(@related_sids, @related_cids);
		
		foreach my $related (@$related) {
			if ($related->{rel_sid}) {
				push @related_sids, $related->{rel_sid} if $related->{rel_sid};
			} elsif ($related->{cid}) {
				push @related_cids, $related->{cid};
			} elsif ($related->{url}) {
				$storyref->{related_urls_hr}{$related->{url}} = $related->{title};
			}
		}

		my %related_sids = map { $_ => $slashdb->getStory($_) } @related_sids; 
		my %related_cids = map { $_ => $slashdb->getComment($_) } @related_cids;
		$storyref->{related_sids_hr} = \%related_sids;
		$storyref->{related_cids_hr} = \%related_cids;

		$sid = $storyref->{sid};
		$storyref->{is_dirty} = 1;
		$storyref->{commentstatus} = ($slashdb->getDiscussion($storyref->{discussion}, 'commentstatus') || 'disabled'); # If there is no discussion attached then just disable -Brian
		$user->{currentSkin} = $tmp;
		
		for my $field (qw( introtext bodytext )) {
			# This should be moved to balanceTags once that braindead POS is fixed -- paulej72 20150617
			$storyref->{$field} =~ s|</p>|</p>\n\n|g;
			$storyref->{$field} =~ s|</li>|</li>\n|g;
			$storyref->{$field} =~ s|</ol>|</ol>\n\n|g;
			$storyref->{$field} =~ s|</ul>|</ul>\n\n|g;
			$storyref->{$field} =~ s|</blockquote>|</blockquote>\n\n|g;
			$storyref->{$field} =~ s|</spoiler>|</spoiler>\n\n|g;
			$storyref->{$field} =~ s|(</?h.>)\s*</p>|$1|g;
		}
		
		# Get wordcounts
		$storyref->{introtext_wordcount} = countWords($storyref->{introtext});
		$storyref->{bodytext_wordcount} = countWords($storyref->{bodytext});
		$subid = $storyref->{subid};

		my $chosen_hr = $slashdb->getStoryTopicsChosen($stoid);
		$storyref->{topics_chosen} = $chosen_hr;

		my $render_info = { };
# Don't need to do this, I don't think.  Only when saving does it matter.
# We might as well leave the rendered info so we get the proper primary
# skid, just like setStory will.
#		$render_info->{neverdisplay} = 1 if $storyref->{neverdisplay};
		my $rendered_hr = $slashdb->renderTopics($chosen_hr, $render_info);

		$storyref->{topics_rendered} = $rendered_hr;
		$storyref->{primaryskid} = $slashdb->getPrimarySkidFromRendered($rendered_hr);
		$storyref->{topiclist} = $slashdb->getTopiclistFromChosen($chosen_hr,
			{ skid => $storyref->{primaryskid} });
		$extracolumns = $slashdb->getNexusExtrasForChosen($chosen_hr);

		for my $field (qw( introtext bodytext )) {
			$storyref->{$field} = parseSlashizedLinks(
				$storyref->{$field});
		}
		$display_check = $storyref->{neverdisplay} ? '' : $constants->{markup_checked_attribute};
		handleMediaFileForStory($stoid);

	} else { # New Story

		# XXXSECTIONTOPIC this kinda works now, but it should be rewritten
		$extracolumns			= $slashdb->getNexusExtras($gSkin->{nexus});
		$storyref->{commentstatus}	= $constants->{defaultcommentstatus};
		$storyref->{primaryskid}	= $gSkin->{skid};
		$storyref->{tid}		= $form->{tid} || $gSkin->{defaulttopic};

		$storyref->{'time'} = $slashdb->getTime;
		$storyref->{uid} = $user->{uid};

		$storyref->{topics_chosen} = { };
		$storyref->{topics_rendered} = { };
		$storyref->{primaryskid} = $slashdb->getPrimarySkidFromRendered({ });
		$storyref->{topiclist} = $slashdb->getTopiclistFromChosen({},
			{ skid => $storyref->{primaryskid} });

		$storyref->{is_dirty} = 1;
		$display_check = $constants->{markup_checked_attribute};

	}

	if ($storyref->{title}) {
		$storyref->{stripped_title} = strip_title($storyref->{title});
		my $oldskin = $gSkin->{skid};
		setCurrentSkin($storyref->{primaryskid});
		# Do we want to
		# Slash::Utility::Anchor::getSkinColors()
		# here?
		my %story_copy = %$storyref;

		for my $field (qw( introtext bodytext )) {
			$storyref->{$field} = cleanSlashTags($storyref->{$field});

			# do some of the processing displayStory()
			# does, as we are bypassing it by going straight to
			# dispStory() -- pudge
			$story_copy{$field} = parseSlashizedLinks($storyref->{$field});
			my $options = $field eq 'bodytext' ? { break => 1 } : undef;
			$story_copy{$field} = processSlashTags($storyref->{$field}, $options) || '';
		}

		# Get the related text.
		my $admindb = getObject('Slash::Admin');
		$storyref->{relatedtext} = $admindb->relatedLinks(
			"$story_copy{title} $story_copy{introtext} $story_copy{bodytext}",
			$storyref->{topiclist},
			$slashdb->getAuthor($storyref->{uid}, 'nickname'),
			$storyref->{uid}
		);

		my $author  = $slashdb->getAuthor($storyref->{uid});
		my $topiclist = $slashdb->getTopiclistFromChosen($storyref->{topics_chosen});
		my $topic   = $slashdb->getTopic($topiclist->[0]);
		my $preview = $form->{op} eq "preview" ? 1 : 0;
		$storycontent = dispStory(\%story_copy, $author, $topic, 'Full',
			{ topics_chosen => $storyref->{topics_chosen},
			  topiclist => $topiclist,
			  preview => $preview });
		setCurrentSkin($oldskin);
		# (and here? see comment above, Slash::Utility::Anchor::getSkinColors)
	}

	for (@{$extracolumns}) {
		my $key = $_->[1];
		$storyref->{$key} = $form->{$key} || $storyref->{$key};
	}

	my $topic_select = Slash::Admin::PopupTree::getPopupTree($storyref->{topics_chosen});

	my $authors = $slashdb->getDescriptions('authors', '', 1);
	$authors->{$storyref->{uid}} = $slashdb->getUser($storyref->{uid}, 'nickname') if $storyref->{uid} && !defined($authors->{$storyref->{uid}});
	my $author_select = createSelect('uid', $authors, $storyref->{uid}, 1);

	$storyref->{dept} =~ s/ /-/gi;

	$locktest = lockTest($storyref->{title});

	my $display_codes = $user->{section} ? 'displaycodes_sectional' : 'displaycodes';

	$description = $slashdb->getDescriptions('commentcodes_extended');
	$commentstatus_select = createSelect('commentstatus', $description, $storyref->{commentstatus}, 1);

	$fixquotes_check	= $constants->{markup_checked_attribute} if $form->{fixquotes};
	$autonode_check		= $constants->{markup_checked_attribute} if $form->{autonode};
	$fastforward_check	= $constants->{markup_checked_attribute} if $form->{fastforward};

	my $last_admin_text = $slashdb->getLastSessionText($user->{uid});
	my $lasttime = $slashdb->getTime();
	$slashdb->setUser($user->{uid}, { adminlaststorychange => $lasttime }) if $last_admin_text ne $storyref->{title};
	$slashdb->setSession($user->{uid}, {
		lasttitle	=> $storyref->{title},
		last_sid	=> $sid,
		last_action	=> 'editing',
	});

	# Run a spellcheck on introtext, bodytext, and title if they're set.
	my %introtext_spellcheck = $admindb->get_ispell_comments($storyref->{introtext}) if $storyref->{introtext};
	my %bodytext_spellcheck  = $admindb->get_ispell_comments($storyref->{bodytext})  if $storyref->{bodytext};
	my %title_spellcheck     = $admindb->get_ispell_comments($storyref->{title})     if $storyref->{title};

	# Set up our spellcheck template. Output is either a table (if errors were found) or an empty string.	
	my $ispell_comments = {
		introtext => (scalar keys %introtext_spellcheck)
			? slashDisplay("spellcheck", { words => \%introtext_spellcheck, form_element => "introtext" }, { Page => "admin", Return => 1})
			: "",
		bodytext  => (scalar keys %bodytext_spellcheck)
			? slashDisplay("spellcheck", { words => \%bodytext_spellcheck, form_element => "bodytext" }, { Page => "admin", Return => 1 })
			: "",
		title     => (scalar keys %title_spellcheck)
			? slashDisplay("spellcheck", { words => \%title_spellcheck, form_element => "title" }, { Page => "admin", Return => 1 })
			: "",
	} unless $user->{no_spell};

	my $future = $slashdb->getStoryByTimeAdmin('>', $storyref, 3);
	$future = [ reverse @$future ];
	my $past = $slashdb->getStoryByTimeAdmin('<', $storyref, 3);
	my $current = $slashdb->getStoryByTimeAdmin('=', $storyref, 20);
	unshift @$past, @$current;

	my $num_sim = $constants->{similarstorynumshow} || 5;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $similar_stories = $reader->getSimilarStories($storyref, $num_sim);
	# Truncate that data to a reasonable size for display.
	if ($similar_stories && @$similar_stories) {
		for my $sim (@$similar_stories) {
			# Display a max of five words reported per story.
			$#{$sim->{words}} = 4 if $#{$sim->{words}} > 4;
			for my $word (@{$sim->{words}}) {
				# Max of 12 chars per word.
				$word = substr($word, 0, 12);
			}
			# Max of 35 char title.
			$sim->{title} = chopEntity($sim->{title}, 35);
		}
	}

	my $authortext = $admindb->showStoryAdminBox($storyref);
	my $slashdtext = $admindb->showSlashdBox();
	
	my $signofftext = $admindb->showSignoffBox($storyref->{stoid});
	my $attached_files;
	if ($constants->{plugin}{Blob}) {
		my $blobdb = getObject("Slash::Blob");
		my $files = $blobdb->getFilesForStory($sid);
		$attached_files = slashDisplay('attached_files', { files => $files }, { Return => 1});
	}
	my $shown_in_desc = getDescForTopicsRendered($storyref->{topics_rendered},
		$storyref->{primaryskid},
		$display_check ? 1 : 0);
	# We probably should just pass the raw data instead of the formatted
	# <SELECT> into this template and let the template deal with the
	# HTML, here. Formatting these elements outside of the template
	# just defeats the purpose!	-- Cliff 2002-08-07

	my $user_signoff = 0;
	if ($stoid) {
		$user_signoff = $slashdb->sqlCount("signoff", "uid=$user->{uid} AND stoid=$stoid");
	}

	my $add_related_text;
	foreach (keys %{$storyref->{related_cids_hr}}) {
#		$add_related_text .= "cid=$_\n";
	}
	foreach (keys %{$storyref->{related_urls_hr}}) {
		$add_related_text .= "$storyref->{related_urls_hr}{$_} $_\n";
	}

	# TODO: add new tagui here

	my $pending_file_count = 0;
	my $story_static_files = [];
	if ($stoid || $form->{sid}) {
		my $story = $slashdb->getStory($form->{sid});
		$stoid ||= $story->{stoid};
		$pending_file_count = $slashdb->numPendingFilesForStory($stoid); 
		$story_static_files = $slashdb->getStaticFilesForStory($stoid);
	}
	slashDisplay('editStory', {
		stoid			=> $stoid,
		storyref 		=> $storyref,
		story			=> $story,
		storycontent		=> $storycontent,
		tagbox_html		=> '',
		sid			=> $sid,
		subid			=> $subid,
		fhid			=> $fhid,
		authortext 		=> $authortext,
		slashdtext		=> $slashdtext,
		newarticle		=> $newarticle,
		topic_select		=> $topic_select,
		author_select		=> $author_select,
		locktest		=> $locktest,
		commentstatus_select	=> $commentstatus_select,
		fixquotes_check		=> $fixquotes_check,
		autonode_check		=> $autonode_check,
		fastforward_check	=> $fastforward_check,
		display_check		=> $display_check,
		ispell_comments		=> $ispell_comments,
		extras			=> $extracolumns,
		similar_stories		=> $similar_stories,
		attached_files		=> $attached_files,
		shown_in_desc		=> $shown_in_desc,
		signofftext		=> $signofftext,
		user_signoff		=> $user_signoff,
		add_related_text	=> $add_related_text,
		pending_file_count	=> $pending_file_count,
		story_static_files	=> $story_static_files,
	});
}


##################################################################
sub extractChosenFromForm {
	my($form) = @_;
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $chosen_hr = { };
	my $chosenc_hr = { };   # c is for child, in topic editor

	if (defined $form->{topic_source} && $form->{topic_source} eq 'submission'
		&& ($form->{subid} || $form->{fhid})) {
		my @topics = ($form->{tid});
		if ($form->{primaryskid}) {
			my $nexus = $slashdb->getNexusFromSkid($form->{primaryskid});
			push @topics, $nexus if $nexus;
		}
		for my $tid (@topics) {
			$chosen_hr->{$tid} =
				$tid == $constants->{mainpage_nexus_tid}
				? 30
				: $constants->{topic_popup_defaultweight} || 10;
		}
	} else {
		my(%chosen);
		for my $x (qw(st stc)) {
			my $input = $x . '_main_select';
			next unless $form->{$input};

			my @weights = sort { $b <=> $a } keys %{$constants->{topic_popup_weights}};
			# normalize to dividing lines, so no priorities
			if (defined $form->{topic_source} && $form->{topic_source} eq 'topiced') {
				@weights = grep { $constants->{topic_popup_weights}{$_} } @weights;
			}

			my $weight = shift @weights;
			my @thismany = @{$form->{$input}};
			for my $i (0..$#thismany) {
				no strict;
				my $tid = $form->{$input}[$i];
				use strict;
				if ($tid =~ /^-(\d+)$/) {
					until ($weight < $1) {
						last unless @weights;
						$weight = shift @weights;
					}
					next;
				}
				$chosen{$x}{$tid} = $weight;
				# only dividers have values
				$weight = shift @weights if @weights
					&& !$constants->{topic_popup_weights}{$weight};
			}

			$chosen_hr = $chosen{st};
			$chosenc_hr = $chosen{stc};
		}
	}

	# save the user's topic popup settings
	if (exists $form->{st_saved_tree} || exists $form->{st_tree_pref}) {
		my $user = getCurrentUser();
		my %tmp;
		for (qw(st_saved_tree st_tree_pref)) {
			next unless exists $form->{$_};
			if ($_ eq 'st_tree_pref') {
				$form->{$_} = '' unless $form->{$_} eq 'ab';
			}
			$user->{$_} = $tmp{$_} = $form->{$_};
		}
		$slashdb->setUser($user->{uid}, \%tmp);
	}

	return($chosen_hr, $chosenc_hr);
}

##################################################################
sub getDescForTopicsRendered {
	# this should probably use templates ...
	my($topics_rendered, $primaryskid, $display) = @_;
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();
	my $tree = $slashdb->getTopicTree();
	my $mainpage_nexus_tid = getCurrentStatic("mainpage_nexus_tid");
	my $primary_nexus_tid  = $slashdb->getNexusFromSkid($primaryskid);
	my @story_nexuses        = grep { $tree->{$_}{nexus} } keys %$topics_rendered;

	my @sorted_nexuses = 	map { $_->[1] } 
	sort {
		$b->[0] <=> $a->[0] ||
		$tree->{$a->[1]}{textname} cmp $tree->{$b->[1]}{textname}
	} map { 
		my $val = 0;
		$val = 2 if $_ == $mainpage_nexus_tid;
		$val = 1 if !$val and $_ == $primary_nexus_tid;
		[$val, $_]
	} @story_nexuses;

	my $remove = qq{[<a href="#" onclick="st_main_add_really(%d,'%s',0,1); return false" class="nex_remove">x</a>]};

	my $desc;
	if (!@sorted_nexuses) {
		$desc = "This story will not appear because ";
		if (!%$topics_rendered) {
			$desc .= "no topics are selected.";
		} else {
			$desc .= "no topics in any nexuses are selected.";
		}
	} else {
		$desc = "This story ";
		if ($display) {
			$desc .= "will be ";
		} else {
			$desc .= "would be ";
		}
		my $first_nexus = shift @sorted_nexuses;
		my $x = sprintf($remove, $first_nexus, $tree->{$first_nexus}{textname});
		if ($first_nexus == $mainpage_nexus_tid) {
			$desc .= "on the $tree->{$first_nexus}{textname} $x";
		} elsif ($first_nexus == $primary_nexus_tid) {
			$desc .= "in $tree->{$first_nexus}{textname} $x";
		}
		if (@sorted_nexuses) {
			$desc .= ", and linked from ";
			if (@sorted_nexuses == 1) {
				my $x = sprintf($remove, $sorted_nexuses[0], $tree->{$sorted_nexuses[0]}{textname});
				$desc .= "$tree->{$sorted_nexuses[0]}{textname} $x";
			} else {
				my $last_nexus = pop @sorted_nexuses;
				my $next_to_last_nexus = pop @sorted_nexuses;
				my $z = sprintf($remove, $last_nexus, $tree->{$last_nexus}{textname});
				my $y = sprintf($remove, $next_to_last_nexus, $tree->{$next_to_last_nexus}{textname});
				foreach (@sorted_nexuses) {
					my $x = sprintf($remove, $_, $tree->{$_}{textname});
					$desc .= "$tree->{$_}{textname} $x, ";
				}
				$desc .= "$tree->{$next_to_last_nexus}{textname} $y and $tree->{$last_nexus}{textname} $z";
			}
		}
		if ($display) {
			$desc .= ".";
		} else {
			$desc .= "... but Display is unchecked so it won't be displayed.";
		}
	}
	return "<b>$desc</b>";
}


##################################################################
sub listStories {
	my($form, $slashdb, $user, $constants) = @_;

	my $section = $form->{section} || '';
	if ($section) {
		my $new_skid = $slashdb->getSkidFromName($section);
		if ($new_skid) {
			setCurrentSkin($new_skid);
			Slash::Utility::Anchor::getSkinColors();
		}
	}

	my($first_story, $num_stories) = ($form->{'next'} || 0, 40);
	my($count, $storylist) = $slashdb->getStoryList($first_story, $num_stories);

	my $storylistref = [];

	if ($form->{op} && $form->{op} eq 'delete') {
		rmStory($form->{stoid} || $form->{sid});
		titlebar('100%', getTitle('rmStory-title',
			{ sid => $form->{stoid} || $form->{sid} } ));
	} else {
		titlebar('100%', getTitle('listStories-title'));
	}

	my $i = $first_story || 0;

	my $stoid_list = [];
	for my $story (@$storylist) {
		my $time_plain   = $story->{'time'};
		my $time_user = timeCalc($story->{time});
		$time_user =~ s/^.*@(.*)$/($1)/;
		$story->{'time'} = timeCalc($time_plain, '%H:%M', 0).' '.$time_user;
		$story->{td}     = timeCalc($time_plain, '%A %B %d', 0);
		$story->{td2}    = timeCalc($time_plain, '%m/%d', 0);
		$story->{aid}    = $slashdb->getAuthor($story->{uid}, 'nickname');
		$story->{x}	 = ++$i;
		#$story->{title}  = chopEntity($story->{title}, 50);
		$story->{title} = strip_title($story->{title});
		$story->{tbtitle} = fixparam($story->{title});
		if ($constants->{plugin}{FireHose}) {
			my $fh = getObject("Slash::FireHose");
			my $item = $fh->getFireHoseByTypeSrcid('story',$story->{stoid});
			$story->{fhid} = $item->{id};
			$story->{fh_url} = $fh->linkFireHose($item);
		}
		push @$stoid_list, $story->{stoid};
	}

	my $usersignoffs 	= $slashdb->getUserSignoffHashForStoids($user->{uid}, $stoid_list);
	my $storysignoffcnt	= $slashdb->getSignoffCountHashForStoids($stoid_list, 1);

	# MC: The original was crack
	#my $needed_signoffs = $self->getActiveAdminCount;
	my $needed_signoffs = $constants->{'signoffs_per_article'};

	my %unique_tds = map { ($_->{td}, 1) } @$storylist;
	my $ndays_represented = scalar(keys %unique_tds);

	slashDisplay('listStories', {
		storylistref	  => $storylist,
		'x'		  => $i + $first_story,
		left		  => $count - ($i + $first_story),
		ndays_represented => $ndays_represented,
		user_signoffs 	  => $usersignoffs,
		story_signoffs	  => $storysignoffcnt,
		needed_signoffs	  => $needed_signoffs,
	});
}

##################################################################
sub rmStory {
	my($id) = @_;
	my $slashdb = getCurrentDB();
	$slashdb->deleteStory($id);
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

	$form->{dept} =~ s/ /-/g;

	my $story = $slashdb->getStory($form->{sid}, '', 1);
	$form->{aid} = $story->{aid} unless $form->{aid};

	my $admindb = getObject('Slash::Admin');

	my($chosen_hr) = extractChosenFromForm($form);
	my($related_sids_hr, $related_urls_hr, $related_cids_hr, $related_firehose_hr) = $admindb->extractRelatedStoriesFromForm($form, $story->{sid});
	my $related_sids = join ',', keys %$related_sids_hr;
	my($topic) = $slashdb->getTopiclistFromChosen($chosen_hr);
#use Data::Dumper; print STDERR "admin.pl updateStory chosen_hr: " . Dumper($chosen_hr) . "admin.pl updateStory form: " . Dumper($form);
	
	my $time = $admindb->findTheTime();

	for my $field (qw( introtext bodytext media)) {
		local $Slash::Utility::Data::approveTag::admin = 2;
		$form->{$field} = cleanSlashTags($form->{$field});
		$form->{$field} = strip_html($form->{$field});
		#$form->{$field} = slashizeLinks($form->{$field});
		$form->{$field} = balanceTags($form->{$field});
	}

	my $story_text = "$form->{title} $form->{introtext} $form->{bodytext}";
	{
		local $Slash::Utility::Data::approveTag::admin = 2;
		$story_text = parseSlashizedLinks($story_text);
		$story_text = processSlashTags($story_text);
	}

	$form->{relatedtext} = $admindb->relatedLinks(
		$story_text, $topic,
		$slashdb->getAuthor($form->{uid}, 'nickname'), $form->{uid}
	);

	$slashdb->setCommonStoryWords();

	my $data = {
		uid		=> $form->{uid},
		sid		=> $form->{sid},
		title		=> $form->{title},
		topics_chosen	=> $chosen_hr,
		dept		=> $form->{dept},
		'time'		=> $time,
		commentstatus	=> $form->{commentstatus},
		bodytext	=> $form->{bodytext},
		introtext	=> $form->{introtext},
		media		=> $form->{media},
		relatedtext	=> $form->{relatedtext},
		related_sids	=> $related_sids,
		thumb		=> $form->{thumb},
		-rendered	=> 'NULL', # freshenup.pl will write this
		is_dirty	=> 1,
		notes		=> $form->{notes}
	};

	for (qw(dept bodytext relatedtext)) {
		$data->{$_} = '' unless defined $data->{$_};  # allow to blank out
	}

#print STDERR "admin.pl before render data: " . Dumper($data);
	my $rendered_hr = $slashdb->renderTopics($chosen_hr);
	$data->{primaryskid} = $slashdb->getPrimarySkidFromRendered($rendered_hr);
	my $extracolumns = $slashdb->getNexusExtrasForChosen($chosen_hr);
#print STDERR "admin.pl extracolumns '@$extracolumns'\n";
	if ($extracolumns && @$extracolumns) {
		for my $ex_ar (@$extracolumns) {
			my $key = $ex_ar->[1];
			$data->{$key} = $form->{$key};
		}
	}

	$data->{neverdisplay} = $form->{display} ? '' : 1;
	if ($data->{neverdisplay}) {
		print STDERR "Setting sid: $form->{sid} to neverdisplay\n";
		use Data::Dumper;
		print STDERR Dumper($form);
		print STDERR Dumper($data);
	}

	if ($constants->{brief_sectional_mainpage}) {
		$data->{offmainpage} = undef;
		my $sectional_weight = $constants->{topics_sectional_weight} || 10;
		if (!$rendered_hr->{ $constants->{mainpage_nexus_tid} }) {
			my $mdn_ar = $slashdb->getMainpageDisplayableNexuses();
			my $mdn_hr = { map { ($_, 1) } @$mdn_ar };
			my $any_sectional = 0;
			for my $tid (keys %$rendered_hr) {
				$any_sectional = 1, last
					if $rendered_hr->{$tid} >= $sectional_weight
						&& $mdn_hr->{$tid};
			}
			$data->{offmainpage} = 1 if !$any_sectional;
		}
		
	}

#print STDERR "admin.pl before updateStory data: " . Dumper($data);
	if (!$slashdb->updateStory($form->{sid}, $data)) {
		titlebar('100%', getTitle('story_update_failed'));
		editStory(@_);
	} else {
		my $st = $slashdb->getStory($form->{sid});
		my %warn_skids = map {$_ => 1 } split('\|', $constants->{admin_warn_primaryskid});
		my $data = {};
		if ($warn_skids{$st->{primaryskid}}) {
			$data->{warn_skid} = $st->{primaryskid};
		}
		titlebar('100%', getTitle('updateStory-title', $data));

		$slashdb->setRelatedStoriesForStory($form->{sid}, $related_sids_hr, $related_urls_hr, $related_cids_hr, $related_firehose_hr);
		$slashdb->createSignoff($st->{stoid}, $user->{uid}, "updated");
		

		# handle any media files that were given
		handleMediaFileForStory($st->{stoid});

		# make sure you pass it the goods
		listStories(@_);
	}
}

##################################################################
sub handleMediaFileForStory {
	my($stoid) = @_;
	my $form    = getCurrentForm();
	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	my $saveblob = $constants->{admin_use_blob_for_upload};
	my $savefile = !$saveblob;

	if ($form->{media_file}) {
                my $r = Apache2::RequestUtil->request;
                my $req = Apache2::Request->new($r);
                my $upload = $req->upload("bodytext_file");
		if ($upload) {
			my $fh = $upload->fh;
			use File::Path;
			$form->{media_file} =~ s|^.*?([^/:\\]+)$|$1|;
			my $name = $form->{media_file};
			my $suffix;
			($suffix) = $name =~ /(\.\w+)$/;
			my($ofh, $tmpname, $blobdata);
			mkpath("/tmp/upload", 0, 0755) unless -e "/tmp/upload";

			if ($savefile) {
				use File::Temp qw(:mktemp);
				($ofh, $tmpname) = mkstemps("/tmp/upload/fileXXXXXX", $suffix );
			}
				
			while (<$fh>) {
				print $ofh $_ if $savefile;
				$blobdata .= $_ if $saveblob;
			}
			if ($savefile) {
				close $ofh;
			}
			my $action = "upload";
			my $file = {
				stoid	=> $stoid,
				action 	=> $action,
			};
			if ($savefile) {
				$file->{file} = "$tmpname";
			}
			if ($saveblob) {
				my $data;
				my $blob = getObject("Slash::Blob");
				$file->{blobid} = $blob->create({
						data 	=> $blobdata,
						seclev 	=> 0,
						filename => $name
				});

			}
			$slashdb->addFileToQueue($file);
		}
	}
	
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
# Handles moderation
sub moderate {
	my($form, $slashdb, $user, $constants) = @_;

	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	if (!$moddb) {
		print getData('unknown_moderation_warning');
		return ;
	}

	my $was_touched = {};
	my($sid, $cid);

	titlebar("100%", "Moderating...");
	if (!dbAvailable("write_comments")) {
		print getData("comment_db_down");
		return;
	}
	for my $key (sort keys %{$form}) {
		if ($key =~ /^reason_(\d+)_(\d+)$/) {
			($sid, $cid) = ($1, $2);
			next if $form->{$key} eq "";
			my $ret_val = $moddb->moderateComment($sid, $cid, $form->{$key});			
			# No points and not enough points shouldn't show up since the user
			# is an admin but check just in case 
			if ($ret_val < 0) {
				if ($ret_val == -1) {
					print getData('no points');
				} elsif ($ret_val == -2){
					print getData('not enough points');
				} else {
					print getData('unknown_moderation_warning');
				}
			
			} else {
				$was_touched->{$sid} += $ret_val;
			}
			
		}
	}

	foreach my $s (keys %$was_touched) {
		if ($was_touched->{$s}) {
			my $story_sid = $slashdb->getStorySidFromDiscussion($sid);
			$slashdb->setStory($story_sid, { is_dirty => 1 }) if $story_sid;
		}
	}
	my $startat = $form->{startat} || 0;
	if ($form->{returnto}) {
		print getData('moderate_recent_message_returnto', { returnto => $form->{returnto} });
	} else {
		print getData('moderate_recent_message', { startat => $startat });
	}
}


##################################################################
sub displayRecentMods {
	my($form, $slashdb, $user, $constants) = @_;
	slashDisplay('recent_mods');
}


##################################################################
sub displayRecent {
	my($form, $slashdb, $user, $constants) = @_;
	my($min, $max, $sid, $primaryskid) = (undef, undef, undef, undef);
	$min = $form->{min} if defined($form->{min});
	$max = $form->{max} if defined($form->{max});
	$sid = $form->{sid} if defined($form->{sid});
	$primaryskid = $form->{primaryskid} if defined($form->{primaryskid});
	my $startat = $form->{startat} || undef;

	my $max_cid = $slashdb->sqlSelect("MAX(cid)", "comments");
	my $recent_comments = $slashdb->getRecentComments({
		min	=> $min,
		max	=> $max,
		startat	=> $startat,
		num	=> 100,
		sid	=> $sid,
		primaryskid => $primaryskid
		
	}) || [ ];

	if (defined($form->{show_m2s})) {
		$slashdb->setUser($user->{uid},
			{ user_m2_with_mod => $form->{show_m2s} });
	}


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
		sid		=> $sid
	});
}


##################################################################
sub displaySpamMods {
	my($form, $slashdb, $user, $constants) = @_;
	my $startat = $form->{startat} || undef;

	my $recent_comments = $slashdb->getSpamMods({
		startat	=> $startat,
		num	=> 100,
	}) || [ ];

	my $subj_vislen = 1000;
	for my $comm (@$recent_comments) {
		vislenify($comm); # add $comm->{ipid_vis}
		$comm->{subject_vis} = substr($comm->{subject}, 0, $subj_vislen);
		$comm->{date} = substr($comm->{date}, 5); # strip off year
	}

	slashDisplay('spam', {
		startat		=> $startat,
		recent_comments	=> $recent_comments,
	});
}


##################################################################
sub displayModBombs {
	my($form, $slashdb, $user, $constants) = @_;
	my $note;
	
	my $moddb = getObject("Slash::$constants->{m1_pluginname}");
	
	if(!$moddb) {
		print STDERR "\nERROR: Could not get moddb.\n";
		return;
	}

	if ($form->{mb_del}) {
		$note  = _removeMod($moddb, $form->{id}, $form->{uid}, $form->{noban})
	}
	
	my $data = $moddb->dispModBombs($form->{mod_floor}, $form->{time_span});
	$data->{'note'} = $note;
	
	slashDisplay('modBomb', $data);
}


##################################################################
sub _removeMod {
	my($moddb, $id, $uid, $noban) = @_;

	return 0 unless $moddb && $id && $id =~ /^\d+$/ && $uid && $uid =~ /^\d+$/;
	my $note;
	
	my $remove = $moddb->undoSingleModerationByID($id);
	if ($remove) {
		$note = "<p class='error'>Mod id=$id removed or inactive.</p>";
	} else {
		print STDERR "\nGot a bad return value on undoSingleModerationByID: id=$id"
	}
	
	# Ban the user from moderating
	unless($noban) {
		my $banned = $moddb->modBanUID($uid);
		if ($banned) {
			$note .= "<p class='error'>User uid=$uid banned.</p>";
		} else{
			print STDERR "\nGot a bad return value on modBanUID: uid=$uid"
		}
	}
	
	return $note;
}

##################################################################
sub displayRecentRequests {
	my($form, $slashdb, $user, $constants) = @_;

	my $admindb = getObject("Slash::Admin", { db_type => 'log_slave' });

	my $logdb = getObject("Slash::DB", { db_type => 'log_slave' });

	# Note, limit the id passed in by making sure we don't try to do a
	# select on more than 500,000 rows.  This is an arbitrary number,
	# but the intent is to keep from locking up the DB too much.
	my $min_id = $form->{min_id};
	my $max_id = $admindb->getAccesslogMaxID();
	$min_id = $max_id - 10_000 > 1 ? $max_id : 1	if !$min_id;
	$min_id = $max_id + $min_id			if  $min_id < 0;
	$min_id = $max_id				if  $min_id < $max_id - 500_000;

	my $min_id_ts ||= $logdb->getAccesslog($min_id, 'ts');

	my $options = {
		logdb		=> $logdb,
		slashdb		=> $slashdb,
		min_id		=> $min_id,
	};
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
sub displayRecentSubs {
	my($form, $slashdb, $user, $constants) = @_;

	if (!$constants->{subscribe}) {
		listStories(@_);
		return;
	}

	my $admindb = getObject("Slash::Admin");
	my $startat = $form->{startat} || 0;
	my $subs = $admindb->getRecentSubs($startat);
	slashDisplay('recent_subs', {
		subs		=> $subs,
	});
}

##################################################################
sub displayRecentWebheads {
	my($form, $slashdb, $user, $constants) = @_;

	my $admindb = getObject("Slash::Admin", { db_type => 'log_slave' });

	my $data_hr = $admindb->getRecentWebheads(10, 5000);

	# We need the list of all webheads too.
	my %webheads = ( );
	for my $min (keys %$data_hr) {
		my @webheads = keys %{$data_hr->{$min}};
		for my $wh (@webheads) {
			$webheads{$wh} = 1;
		}
	}
	my $webheads_ar = [ sort keys %webheads ];

	# Format the times.
	for my $min (keys %$data_hr) {
		for my $wh (keys %{$data_hr->{$min}}) {
			$data_hr->{$min}{$wh}{dur} = sprintf("%0.3f",
				$data_hr->{$min}{$wh}{dur});
		}
	}

	slashDisplay('recent_webheads', {
		data		=> $data_hr,
		webheads	=> $webheads_ar,
	});
}

##################################################################
sub displayMcdStats {
	my($form, $slashdb, $user, $constants) = @_;

	my $stats = $slashdb->getMCDStats();
	if (!$stats) {
		print getData('no-mcd-stats');
		return;
	}
	slashDisplay('mcd_stats', { stats => $stats });
}

##################################################################
sub saveStory {
	my($form, $slashdb, $user, $constants) = @_;

	my $edituser = $slashdb->getUser($form->{uid});
	my $tid_ref;
	my $default_set = 0;

	$form->{dept} =~ s/ /-/g;

	my $admindb = getObject('Slash::Admin');

	my($chosen_hr) = extractChosenFromForm($form);
	my($tids) = $slashdb->getTopiclistFromChosen($chosen_hr);
	my($related_sids_hr, $related_urls_hr, $related_cids_hr, $related_firehose_hr) = $admindb->extractRelatedStoriesFromForm($form);

	for my $field (qw( introtext bodytext )) {
		local $Slash::Utility::Data::approveTag::admin = 2;
		$form->{$field} = cleanSlashTags($form->{$field});
		$form->{$field} = strip_html($form->{$field});
		#$form->{$field} = slashizeLinks($form->{$field});
		$form->{$field} = balanceTags($form->{$field});
	}

	my $story_text = "$form->{title} $form->{introtext} $form->{bodytext}";
	{
		local $Slash::Utility::Data::approveTag::admin = 2;
		$story_text = parseSlashizedLinks($story_text);
		$story_text = processSlashTags($story_text);
	}

	$form->{relatedtext} = $admindb->relatedLinks(
		$story_text, $tids, $edituser->{nickname}, $edituser->{uid}
	);

	my $time = $admindb->findTheTime();
	$slashdb->setCommonStoryWords();

	# used to just pass $form to createStory, which is not
	# a good idea because you end up getting form values 
	# such as op and apache_request saved into story_param
	my $data = {
		uid		=> $form->{uid},
		sid		=> $form->{sid},
		title		=> $form->{title},
		section		=> $form->{section},
		submitter	=> $form->{submitter},
		topics_chosen	=> $chosen_hr,
		dept		=> $form->{dept},
		'time'		=> $time,
		bodytext	=> $form->{bodytext},
		introtext	=> $form->{introtext},
		relatedtext	=> $form->{relatedtext},
		media		=> $form->{media},
		subid		=> $form->{subid},
		fhid		=> $form->{fhid},
		commentstatus	=> $form->{commentstatus},
		thumb		=> $form->{thumb},
		-rendered	=> 'NULL', # freshenup.pl will write this
		notes		=> $form->{notes}
	};

	for (qw(dept bodytext relatedtext)) {
		$data->{$_} = '' unless defined $data->{$_};  # allow to blank out
	}

	my $extras = $slashdb->getNexusExtrasForChosen($chosen_hr);
	for my $extra_ar (@$extras) {
		my($textname, $keyword, $type) = @$extra_ar;
		next unless $type eq 'text' || $type eq "textarea" || $type eq "list";
		$data->{$keyword} = $form->{$keyword};
	}

	$data->{neverdisplay} = 1 if !$form->{display};

	# If brief_sectional_mainpage is set, and this story has only
	# nexuses in getMainpageDisplayableNexuses(), all below
	# the sectional weight, and not the mainpage nexus itself,
	# then the current getStoriesEssentials code will pick up
	# this story (for one-liner display) even though we don't
	# want it picked up.  The kludge is to mark the story, in
	# that case, as 'offmainpage'. - Jamie 2008-01-28
	if ($constants->{brief_sectional_mainpage}) {
		my $sectional_weight = $constants->{topics_sectional_weight} || 10;
		my $rendered_hr = $slashdb->renderTopics($chosen_hr);
		if (!$rendered_hr->{ $constants->{mainpage_nexus_tid} }) {
			my $mdn_ar = $slashdb->getMainpageDisplayableNexuses();
			my $mdn_hr = { map { ($_, 1) } @$mdn_ar };
			my $any_sectional = 0;
			for my $tid (keys %$rendered_hr) {
				$any_sectional = 1, last
					if $rendered_hr->{$tid} >= $sectional_weight
						&& $mdn_hr->{$tid};
			}
			$data->{offmainpage} = 1 if !$any_sectional;
		}
		
	}

	my $sid = $slashdb->createStory($data);

	if ($sid) {
		$slashdb->setRelatedStoriesForStory($sid, $related_sids_hr, $related_urls_hr, $related_cids_hr, $related_firehose_hr);
		slashHook('admin_save_story_success', { story => $data });
		my $st = $slashdb->getStory($data->{sid});
		my $stoid = $st->{stoid};
		handleMediaFileForStory($stoid);
		my %warn_skids = map {$_ => 1 } split('\|', $constants->{admin_warn_primaryskid});
		my $data = {};
		if ($warn_skids{$st->{primaryskid}}) {
			$data->{warn_skid} = $st->{primaryskid};
		}
		titlebar('100%', getTitle('saveStory-title', $data) );
		$slashdb->createSignoff($stoid, $user->{uid}, "saved");

		listStories(@_);
	} else {
		slashHook('admin_save_story_failed', { story => $data });
		titlebar('100%', getTitle('story_creation_failed'));
		editStory(@_);
	}
}

##################################################################
sub getTitle {
	my($value, $hashref, $nocomm) = @_;
	$hashref ||= {};
	$hashref->{value} = $value;
	return slashDisplay('titles', $hashref,
		{ Return => 1, Nocomm => $nocomm });
}

sub displaySignoffStats {
	my($form, $slashdb, $user, $constants) = @_;
	my $admin = getObject('Slash::Admin');

	my %stoids_for_days;
	my $author_info;
	my $num_days = [7, 30, 90 ];
	for my $days (7, 30, 90) {
		my $signoff_info = $admin->getSignoffData($days);
		foreach (@$signoff_info) {
			$author_info->{$_->{uid}}{nickname} = $_->{nickname};
			$author_info->{$_->{uid}}{uid} = $_->{uid};
			$author_info->{$_->{uid}}{$days}{cnt}++;	
			$author_info->{$_->{uid}}{$days}{tot_time} += $_->{min_to_sign};
			$author_info->{$_->{uid}}{seclev} = $_->{seclev};
			$stoids_for_days{$days}{$_->{stoid}}++;
			push @{$author_info->{$_->{uid}}{$days}{mins}}, $_->{min_to_sign};
		}
	}

	my @author_array = values %$author_info;

	@author_array = sort { $b->{seclev} <=> $a->{seclev} } @author_array;

	slashDisplay("signoff_stats", {
		author_info	=> $author_info,
		author_array    => \@author_array,
		stoids_for_days	=> \%stoids_for_days,
		num_days	=> $num_days
	});

}

sub displayPeerWeights {
	my($form, $slashdb, $user, $constants) = @_;

	my $countA = $slashdb->sqlCount('users_param', q{name='tagpeerval' AND value != '0'});
	my $countB = $slashdb->sqlCount('users_param', q{name='tagpeerval2' AND value != '0'});

	my $weightA_hr = $slashdb->sqlSelectAllKeyValue(
		'uid, value+0 AS val',
		'users_param',
		q{name='tagpeerval'},
		'ORDER BY val DESC LIMIT 40');
	my $weightB_hr = $slashdb->sqlSelectAllKeyValue(
		'uid, value+0 AS val',
		'users_param',
		q{name='tagpeerval2'},
		'ORDER BY val DESC LIMIT 40');
	my $ordA_hr = { };
	my $ordB_hr = { };
	my @uidsA = sort
		{ $weightA_hr->{$b} <=> $weightA_hr->{$a} || $a cmp $b }
		keys %$weightA_hr;
	my @uidsB = sort
		{ $weightB_hr->{$b} <=> $weightB_hr->{$a} || $a cmp $b }
		keys %$weightB_hr;
	my $i = 1;
	for my $uid (@uidsA) {
		$weightA_hr->{$uid} = sprintf("%0.4f", $weightA_hr->{$uid});
		$ordA_hr->{$uid} = $i++;
	}
	$i = 1;
	for my $uid (@uidsB) {
		$weightB_hr->{$uid} = sprintf("%0.4f", $weightB_hr->{$uid});
		$ordB_hr->{$uid} = $i++;
	}

	if ($countA > 200) {
		$i = 40;
		my $inc = ($countA-40) / 40;
		for (1..40) {
			$i += $inc;
			my $i0 = int($i);
			my($uid, $val) = $slashdb->sqlSelect(
				'uid, value+0 AS val',
				'users_param',
				q{name='tagpeerval'},
				"ORDER BY val DESC, uid LIMIT $i0, 1");
			next unless $uid;
			$weightA_hr->{$uid} = sprintf("%0.4f", $val);
			$ordA_hr->{$uid} = $i0;
			push @uidsA, $uid;
		}
	}

	if ($countB > 200) {
		$i = 40;
		my $inc = ($countB-40) / 40;
		for (1..40) {
			$i += $inc;
			my $i0 = int($i);
			my($uid, $val) = $slashdb->sqlSelect(
				'uid, value+0 AS val',
				'users_param',
				q{name='tagpeerval2'},
				"ORDER BY val DESC, uid LIMIT $i0, 1");
			next unless $uid;
			$weightB_hr->{$uid} = sprintf("%0.4f", $val);
			$ordB_hr->{$uid} = $i0;
			push @uidsB, $uid;
		}
	}

	my $uid_str = join(',', @uidsA, @uidsB);
	my $nickname_hr = $slashdb->sqlSelectAllKeyValue(
		'uid, nickname',
		'users',
		"uid IN ($uid_str)");

#use Data::Dumper;
#print STDERR "uidsA: " . Dumper(\@uidsA);
#print STDERR "ordA: " . Dumper($ordA_hr);
#print STDERR "weightA: " . Dumper($weightA_hr);
#print STDERR "uidsB: " . Dumper(\@uidsB);
#print STDERR "ordB: " . Dumper($ordB_hr);
#print STDERR "weightB: " . Dumper($weightB_hr);
#print STDERR "nickname: " . Dumper($nickname_hr);
	slashDisplay("peer_weights", {
		uidsA		=> \@uidsA,
		ordA		=> $ordA_hr,
		weightA		=> $weightA_hr,
		uidsB		=> \@uidsB,
		ordB		=> $ordB_hr,
		weightB		=> $weightB_hr,
		nickname	=> $nickname_hr,
	});

}

sub showStaticFiles {
	my($form, $slashdb, $user, $constants) = @_;
	my $story = $slashdb->getStory($form->{sid});
	my $story_static_files = $slashdb->getStaticFilesForStory($story->{stoid});
	slashDisplay("static_files", { story_static_files => $story_static_files, sid => $form->{sid} }); 
}

createEnvironment();
main();
1;
