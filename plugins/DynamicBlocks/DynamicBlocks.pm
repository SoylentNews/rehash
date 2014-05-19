# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2009 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::DynamicBlocks;

use strict;
use Slash;
use Slash::Display;
use Slash::Utility;
use Time::Local;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

# Update an existing block
sub setBlock {
	my ($self, $block) = @_;

	return 0 if (!$block->{name});

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	return 0 if ($block->{uid} == $constants->{anonymous_coward_uid});

	my $data = {};
	my $block_name = $slashdb->sqlQuote($block->{'name'});

	# Check if this block exists. Then create or update.
	my $bid = $slashdb->sqlSelect('bid', 'dynamic_user_blocks', "name = $block_name");
	if (!$bid) {
		return 0 if (!$block->{type_id});
		$data = {
			"type_id"	=> $block->{type_id},
			"uid" => $block->{uid},
			"title"	=> $block->{title},
			"url"	=> $block->{url},
			"-name"	=> $block_name,
			"description" => $block->{description},
			"block"	=> $block->{block},
			"seclev" => $block->{seclev},
			"-created" => 'NOW()',
			"-last_update" => 'NOW()',
		};
		$slashdb->sqlInsert('dynamic_user_blocks', $data);
	} else {
		$data->{'title'} = $block->{title};
		$data->{'url'} = $block->{url};
		$data->{'block'} = $block->{block};
		$data->{'-last_update'} = 'NOW()';
		$slashdb->sqlUpdate('dynamic_user_blocks', $data, "bid = $bid and name = $block_name");
	}
}

sub setUserBlock {
	my ($self, $name, $uid, $options) = @_;

	return 0 if (!$name or !$uid);

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();
	return 0 if ($uid == $constants->{anonymous_coward_uid});

	my $user = $slashdb->getUser($uid);
	my ($block, $data, $id);

	$block = $self->setUserCommentBlock($user) if ($name eq 'comments');
	$block = $self->setUserJournalBlock($user) if ($name eq 'journal');
	$block = $self->setUserBookmarksBlock($user) if ($name eq 'bookmarks');
	$block = $self->setUserFriendsBlock($user) if ($name eq 'friends');
	$block = $self->setUserSubmissionsBlock($user) if ($name eq 'submissions');
	$block = $self->setUserMessagesBlock($user) if ($name eq 'messages');

	$id = $slashdb->sqlSelect('bid', 'dynamic_user_blocks', "name = '$name-$uid' and $uid = $uid");
	if ($block) {
		if (!$id) {
			my $block_definition;
			if ($options->{private}) {
				$block_definition = $self->getBlockDefinition('', { type => 'user', private => $options->{private} });
			} else {
				$block_definition = $self->getBlockDefinition('', { type => 'user', private => 'no'});
			}

			$data = {
				type_id => $block_definition->{type_id},
				uid => $uid,
				title => $block->{title},
				url => $block->{url},
				name => "$name-$uid",
				description => $block->{description},
				block => $block->{block},
				seclev => 0,
				"-created" => 'NOW()',
				"-last_update" => 'NOW()',
			};
			$slashdb->sqlInsert('dynamic_user_blocks', $data);
		} else {
			$data = {
				"title" => $block->{title},
				"url" => $block->{url},
				"block" => $block->{block},
				"-last_update" => 'NOW()',
			};
			$slashdb->sqlUpdate('dynamic_user_blocks', $data, "bid = $id");
		}
	} else {
		# No data was returned for this box type, but id is set. Delete the box since it's stale.
		$slashdb->sqlDelete('dynamic_user_blocks', "bid = $id and name = '$name-$uid' and $uid = $uid") if $id;
	}
}

sub setUserCommentBlock {
	my ($self, $user) = @_;

	return 0 if !$user->{uid};

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	my $comments =
		$slashdb->sqlSelectAllHashrefArray(
			'sid, cid, subject, date, points, reason',
			'comments',
			"uid = " . $user->{uid} . " order by date desc limit 5"
		);

	my $block;
	if (scalar @$comments) {
		my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });

		my $comments_block =
			slashDisplay('createcomments', {
				reasons => $mod_reader->getReasons(),
				comments => $comments,
			}, { Page => 'dynamicblocks', Return => 1 });

		$block->{block} = $comments_block;
		$block->{url} = '~' . strip_paramattr($user->{nickname}) . '/comments';
		$block->{title} = strip_literal($user->{nickname}) . "'s Comments";
		$block->{description} = 'Comments';
	}

	return (keys %$block) ? $block : 0;
}

sub setUserJournalBlock {
	my ($self, $user) = @_;

	return 0 if !$user->{uid};

	my $slashdb = getCurrentDB();

	my $journals =
	$slashdb->sqlSelectAllHashrefArray(
		'id, description, date',
		'journals',
		"uid = " . $user->{uid} . " and promotetype = 'publish' order by date desc limit 5"
	);

	my $block;
	if (scalar @$journals) {
		my $journals_block =
			slashDisplay('createjournals', {
				nick => $user->{nickname},
				journals => $journals,
			}, { Page => 'dynamicblocks', Return => 1 });

		$block->{block} = $journals_block;
		$block->{url} = '~' . strip_paramattr($user->{nickname}) . '/journal';
		$block->{title} = strip_literal($user->{nickname}) . "'s Journal";
		$block->{description} = 'Journal';
	}

	return (keys %$block) ? $block : 0;
}


sub setUserBookmarksBlock {
	my ($self, $user) = @_;

	return 0 if !$user->{uid};

	my $slashdb = getCurrentDB();

	my $bookmarks_reader = getObject('Slash::Bookmark');
	return 0 if !$bookmarks_reader;

	my $bookmarks = $bookmarks_reader->getRecentBookmarksByUid($user->{uid}, 5);

	my $block;
	if (scalar @$bookmarks) {
		my $bookmarks_block =
			slashDisplay('createbookmarks', {
				bookmarks => $bookmarks,
			}, { Page => 'dynamicblocks', Return => 1 });

		$block->{block} = $bookmarks_block;
		$block->{url} = '~' . strip_paramattr($user->{nickname}) . '/bookmarks';
		$block->{title} = strip_literal($user->{nickname}) . "'s Bookmarks";
		$block->{description} = 'Bookmarks';
	}

	return (keys %$block) ? $block : 0;
}


sub setUserFriendsBlock {
	my ($self, $user) = @_;

	return 0 if !$user->{uid};

	my $slashdb = getCurrentDB();

	my $friends =
		$slashdb->sqlSelectAllHashrefArray(
			'id, person',
			'people',
			"uid = " . $user->{uid} .
			" and type = 'friend'" .
			" order by id desc limit 5"
		);

	foreach my $friend (@$friends) {
		$friend->{nick} = $slashdb->sqlSelect('nickname', 'users', "uid = " . $friend->{person});
		$friend->{displaynick} = $friend->{nick};
		$friend->{nick} = strip_paramattr($friend->{nick});
		$friend->{bio} = $slashdb->sqlSelect('bio', 'users_info', "uid = " . $friend->{person}) if $user->{u2_friends_bios};
	}

	my $block;
	if (scalar @$friends) {
		my $friends_block =
			slashDisplay('createfriends', {
				friends => $friends,
			}, { Page => 'dynamicblocks', Return => 1 });

		$block->{block} = $friends_block;
		$block->{url} = '~' . strip_paramattr($user->{nickname}) . '/friends';
		$block->{title} = strip_literal($user->{nickname}) . "'s Friends";
		$block->{description} = 'Friends';
	}

	return (keys %$block) ? $block : 0;
}

sub setUserSubmissionsBlock {
	my ($self, $user) = @_;

	return 0 if !$user->{uid};

	my $slashdb = getCurrentDB();

	my $submissions =
	$slashdb->sqlSelectAllHashrefArray(
		'id',
		'firehose',
		"uid = " . $user->{uid} .
		" and (type = 'submission' or type = 'feed')",
		' order by createtime desc limit 5'
	);

	foreach my $subid (@$submissions) {
		$subid->{title} = $slashdb->sqlSelect('title', 'firehose_text', "id = " . $subid->{id});
	}

	my $block;
	if (scalar @$submissions) {
		my $submissions_block =
			slashDisplay('createsubmissions',
				{	submissions => $submissions,},
				{ Page => 'dynamicblocks', Return => 1 });

		$block->{block} = $submissions_block;
		$block->{url} = '~' . strip_paramattr($user->{nickname}) . '/submissions';
		$block->{title} = strip_literal($user->{nickname}) . "'s Submissions";
		$block->{description} = 'Submissions';
	}

	return (keys %$block) ? $block : 0;
}

sub setUserMessagesBlock {
	my ($self, $user) = @_;

	return 0 if !$user->{uid};

	my $slashdb = getCurrentDB();

	my $limit = 5;
	my $messages =
		$slashdb->sqlSelectAllHashrefArray(
		'id',
		'message_web',
		"user = " . $user->{uid} .
		" order by date desc limit $limit"
		);

	foreach my $message (@$messages) {
		$message->{subject} = $slashdb->sqlSelect('subject', 'message_web_text', 'id = ' . $message->{id});
	}

	my $block;
	if (scalar @$messages) {
		my $count = $slashdb->sqlSelect('count(id)', 'message_web', "user = " . $user->{uid});
		$count -= $limit;
		$count = 0 if (scalar @$messages < 5);
		my $messages_block =
			slashDisplay('createmessages',
				{ messages => $messages, messagecount => $count,},
				{ Page => 'dynamicblocks', Return => 1 });
			
		$block->{block} = $messages_block;
		$block->{url} = 'my/messages';
		$block->{title} = 'Messages';
		$block->{description} = 'Messages';
	}

	return (keys %$block) ? $block : 0;
}



sub setRemarkAsMessage {
	my ($self) = @_;

	my $slashdb = getCurrentDB();
	my $messages = getObject('Slash::Messages');
	my $remarks_message_code = $slashdb->sqlSelect('code', 'message_codes', "type = 'Remarks'");
	my $remarks_reader = getObject("Slash::Remarks");
	return 0 if (!$messages or !$remarks_message_code or !$remarks_reader);

	my $remarks = $remarks_reader->getRemarks( { max => 1 } );
	foreach my $admin (@{$slashdb->currentAdmin()}) {
		my $users = $messages->checkMessageCodes($remarks_message_code, [$admin->[5]]);
		if (scalar @$users) {
			my $data = {
				template_name => 'remarks_msg',
				template_page => 'dynamicblocks',
				subject => { template_name => 'remarks_msg_subj', template_page => 'dynamicblocks'},
				remark => $remarks->[0],
			};
			$messages->create($admin->[5], $remarks_message_code, $data);
		}
	}
}

# Returns a named block
sub getDynamicBlock { 
	my ($self, $name, $options) = @_;

	my $slashdb = getCurrentDB();

	my $block;
	($block->{block}, $block->{title}, $block->{url}, $block->{portal_id}) =
		$slashdb->sqlSelect('block, title, url, portal_id', 'dynamic_user_blocks', "name = '$name'");
	$block->{name} = $name;

	if ($block->{portal_id}) {
		($block->{block}, $block->{title}, $block->{url}) = $self->getPortalBlockContent($block->{portal_id});
	}

	if ($options->{strip_list} && $block->{block}) {
		$block->{block} =~ s/<\/?ul>//g;
		$block->{block} =~ s/<li>//g;
		$block->{block} =~ s/<\/li>/<br\/>/g;
	}

	if ($options->{user_bio_messages} && $block->{block}) {
		$block->{block} =~ s/\(('(\d+,?)+')\)/\($1, 'user_bio_messages'\)/g;
	}

	return $block->{block} ? $block : 0;
}

# Returns all portal blocks.
sub getPortalBlocks {
	my ($self, $keyed_on, $options) = @_;

	return 0 if !$keyed_on;

	my $slashdb = getCurrentDB();

	my $block_definition = $self->getBlockDefinition('', { type => 'portal', private => 'no'});
	my $where_clause = "type_id = '" . $block_definition->{type_id} . "'";
	if ($options->{uid}) {
		$where_clause .= " and uid = '" . $options->{uid} . "'";
	} else {
		$where_clause .= " and uid = '0'";
	}

	my @filter = ('^.+_more$', '^rand$', '^userlogin$', '^emailsponsor$', '^vendor_intel$', '^vendor_amd$');

	my $blocks = $slashdb->sqlSelectAllHashref($keyed_on, '*', 'dynamic_user_blocks', $where_clause);
	BLOCKS: foreach my $block (keys %$blocks) {
		if ($options->{filter} eq 'basic') {
			foreach my $filter_regex (@filter) {
				if ($blocks->{$block}{name} =~ /$filter_regex/) {
					delete $blocks->{$block};
					next BLOCKS;
				}
			}
		}

		$blocks->{$block}{type} = $block_definition->{type};
		$blocks->{$block}{private} = $block_definition->{private};
	
		($blocks->{$block}{block}, $blocks->{$block}{title}, $blocks->{$block}{url}) =
			$self->getPortalBlockContent($blocks->{$block}{portal_id});
	}

	return (keys %$blocks) ? $blocks : 0;
}

# Returns a hash of a particular user's friends' blocks.
# Does not return any admin blocks.
sub getFriendBlocks {
	my ($self, $keyed_on, $uid, $options) = @_;

	return 0 if (!$keyed_on || !$uid);

	my $zoo = getObject("Slash::Zoo", { db_type => 'reader' });
	return 0 if !$zoo;

	my $friends = $zoo->getRelationships($uid, 1);
	my $blocks;
	foreach my $friend (@$friends) {
		my $friend_blocks = $self->getUserBlocks($keyed_on, $friend->[0], { friend => 1 });
		if ($friend_blocks) {
			foreach my $friend_block (keys %$friend_blocks) {
				$blocks->{$friend_block} = $friend_blocks->{$friend_block};
			}
		}
	}

	return (keys %$blocks) ? $blocks : 0;
}

# Returns a hash of a particular user's blocks.
# Includes their public and private admin blocks if they are an admin.
sub getUserBlocks {
	my ($self, $keyed_on, $uid, $options) = @_;

	return 0 if (!$keyed_on || !$uid);

	my $slashdb = getCurrentDB();
	my $blocks;

	my $where_clause = "uid = '$uid'";
	# Only include public user and portal boxes if it's a friend lookup.
	if ($options->{friend}) {
		my $user_def = $self->getBlockDefinition('', { type => 'user', private => 'no'});
		my $portal_def = $self->getBlockDefinition('', { type => 'portal', private => 'no'});
		$where_clause .= ' and type_id IN(';
		$where_clause .= $user_def->{type_id} . ',' . $portal_def->{type_id};
		$where_clause .= ')';
	}

	my $user_blocks = $slashdb->sqlSelectAllHashref($keyed_on, '*', 'dynamic_user_blocks', $where_clause);

	my $user = $slashdb->getUser($uid);
	my $admin_blocks;
	if ($user->{seclev} >= 1000 and !$options->{friend}) {
		my $block_definition = $self->getBlockDefinition('', { type => 'admin', private => 'no'});
		my $where_clause = "type_id = '" . $block_definition->{type_id} . "'";
		$admin_blocks = $slashdb->sqlSelectAllHashref($keyed_on, '*', 'dynamic_user_blocks', $where_clause);
	}

	foreach my $admin_block (keys %$admin_blocks) {
		$admin_blocks->{$admin_block}{type} = 'admin';
		$blocks->{$admin_block} = $admin_blocks->{$admin_block};
	}

	foreach my $user_block (keys %$user_blocks) {
		if (($options->{filter} eq 'basic') and ($user_blocks->{$user_block}{name} =~ /^messages-$uid/)) {
			delete $user_blocks->{$user_block};
			next;
		}

		my $block_definition = $self->getBlockDefinition($user_blocks->{$user_block}{type_id});
		$user_blocks->{$user_block}{type} = $block_definition->{type};
		$user_blocks->{$user_block}{private} = $block_definition->{private};

		if ($block_definition->{type} eq 'portal') {
			($user_blocks->{$user_block}{block}, $user_blocks->{$user_block}{title}, $user_blocks->{$user_block}{url}) =
				$self->getPortalBlockContent($user_blocks->{$user_block}{portal_id});
		}

		$blocks->{$user_block} = $user_blocks->{$user_block};
	}

	return (keys %$blocks) ? $blocks : 0;
}

# Returns the 3 main fields not normally mirrored in 'dynamic_user_blocks'
sub getPortalBlockContent {
	my ($self, $id) = @_;

	my $slashdb = getCurrentDB();

	my @block_data = $slashdb->sqlSelect('block, title, url', 'blocks', "id = $id");
	return @block_data;
}

# Returns a hash describing a block type
# e.g. private/user, public/admin, public/portal
# 
# getBlockDefinition($type_id)
# getBlockDefinition("", { type => "admin", private => "no" })
# getBlockDefinition("", { type => "user", private => "yes" })
sub getBlockDefinition {
	my ($self, $id, $options) = @_;

	return 0 if !$id and !$options;

	my $slashdb = getCurrentDB();

	my $block_definition;
	my $where;
	if ($id) {
		$where .= "type_id = $id";
	} else {
		$where .= "private = '" . $options->{private} . "'";
		$where .= " and type = '" . $options->{type} . "'" if ($options->{type});
		$where .= " and type_id = " . $options->{type_id} if ($options->{type_id});
	}

	($block_definition->{type_id}, $block_definition->{type}, $block_definition->{private}) =
		$slashdb->sqlSelect('type_id, type, private', 'dynamic_blocks', $where);

	return ($block_definition->{type_id}) ? $block_definition : 0;
}

# This is called periodically by certain tasks.
# It syncs 'blocks' and 'dynamic_user_blocks, but does
# not mirror certain fields (block, url, title).
sub syncPortalBlocks {
	my ($self, $name, $options) = @_;

	return if (!$name && !$options);

	my $slashdb = getCurrentDB();

	my $portal_block_definition = $self->getBlockDefinition('', { type => "portal", private => "no" } );

	my $names;
	if (!$name && $options->{all}) {
		$names = $slashdb->sqlSelectColArrayref('bid', 'blocks');
	} else {
		$names = [$name];
	}

	foreach my $name (@$names) {
		my $block_data;
		($block_data->{id}, $block_data->{last_update},
		  $block_data->{shill_uid}, $block_data->{seclev}) =
				$slashdb->sqlSelect('id, last_update, shill_uid, seclev', 'blocks', "bid = '$name'");

		# Check if this block already exists in dynamic_user_blocks
		my $dynb_id = $slashdb->sqlSelect('bid', 'dynamic_user_blocks', "portal_id = " . $block_data->{id});

		my $data;
		if (!$dynb_id) {
			$data = {
				"portal_id" => $block_data->{id},
				"type_id" => $portal_block_definition->{type_id},
				"uid" => $block_data->{shill_uid},
				"name" => $name,
				"seclev" => $block_data->{seclev},
				#"created" => $block_data->{last_update},
				"last_update" => $block_data->{last_update},
			};
			$slashdb->sqlInsert('dynamic_user_blocks', $data);
		} else {
			$data = {
				"last_update" => $block_data->{last_update}
			};
			$slashdb->sqlUpdate('dynamic_user_blocks', $data, "bid = " . $dynb_id);
		}
	}
}

# Returns: a hash of blocks which have been updated between $options->{min_time} and now().
# Will return 0 on error or if no blocks will be updated.
# This will normally be used with an Ajax call. 
#
# $list: a comma delimited list of blocks to check.
# $options->{min_time}: yyyy-mm-dd hh:mm:ss format. The base time for which you'd like
# to check for updates.
#
# getBlocksEligibleForUpdate("foo,bar", { min_time => 'yyyy-mm-dd hh:mm:ss' });
sub getBlocksEligibleForUpdate {
	my ($self, $list, $options) = @_;

	my $constants = getCurrentStatic();
	return 0 if (!$constants->{dynamic_blocks} || !$options->{min_time});

	my $slashdb = getCurrentDB();
	my $min_time = $options->{min_time};
	my $dynamic_blocks;
	foreach my $block (split(/,/, $list)) {
		# Need better use of an exclusion list here.
		next if ($block eq 'poll');

		if (($options->{uid}) && ($options->{uid} != $constants->{anonymous_coward_uid}) && ($block eq 'userbio_self')) {
			$block = 'messages-' . $options->{uid};
		}

		my ($bid, $portal_id, $type_id) =
			$slashdb->sqlSelect(
				'bid, portal_id, type_id',
				'dynamic_user_blocks',
				"name = '$block' and last_update BETWEEN '$min_time' and NOW()"
			);
		if ($bid) {
			if (($options->{uid}) && ($block eq 'messages-' . $options->{uid})) {
				my $user = $slashdb->getUser($options->{uid});
				$dynamic_blocks->{'userbio_self'}{block} = $self->getUserBioBlock($user, { only_inner_html => 1 } );
			} else {
				my $block_definition = $self->getBlockDefinition($type_id);

				my ($block_data, $block_title, $block_url);
				if ($block_definition->{type} eq "portal") {
					($block_data, $block_title, $block_url) =
						$self->getPortalBlockContent($portal_id);
				} else {
					($block_data, $block_title, $block_url) =
						$slashdb->sqlSelect('block, title, url', 'dynamic_user_blocks', "bid = $bid");
				}

				if ($block_data) {
					$dynamic_blocks->{$block}{block} = $block_data;
					$dynamic_blocks->{$block}{title} = $block_title;
					$dynamic_blocks->{$block}{url} = $block_url;
				}
			}
		}
	}

	return (keys %$dynamic_blocks) ? $dynamic_blocks : 0;
}

sub getUserBioBlock {
	my ($self, $user, $options) = @_;

	my $slashdb = getCurrentDB();
	my $constants = getCurrentStatic();

	return if ($user->{uid} == $constants->{anonymous_coward_uid});

	my $messages = $self->getDynamicBlock('messages-' . $user->{uid}, { user_bio_messages => 1, strip_list => 1 });
	my $block = $messages->{block} if $messages;

	my $expiry_date;
	if ($user->{lastgranted} and ($user->{lastgranted} ne '0000-00-00 00:00:00')) {
		my ($gyear, $gmonth, $gday, $ghour, $gmin, $gsec) =
			$user->{lastgranted} =~ /^(\d+)\-(\d+)\-(\d+)\s(\d+)\:(\d+)\:(\d+)$/;

		my $granted_secs = timelocal($gsec, $gmin, $ghour, $gday, $gmonth - 1 , $gyear);
		my $expiry_secs = $granted_secs + (60 * 60 * $constants->{mod_stir_hours});
		my ($sec, $min, $hour, $mday, $mon, $year) = localtime($expiry_secs);
		$expiry_date = sprintf("%4d-%02d-%02d", $year+1900,$mon + 1,$mday, undef, undef, undef);
	}

	my $only_inner = $options->{only_inner_html} || 0;

	my $biobox = slashDisplay('userbio', {
		user => $user,
		expirydate => $expiry_date,
		messages => $block,
		only_inner_html => $only_inner,
		},
		{ Page => 'dynamicblocks', Skin => 'default', Return => 1 });

	return $biobox;
}

sub displayBlock {
	my ($self, $name, $options, $supplemental_pages) = @_;

	my $slashdb = getCurrentDB();

	my $block = $self->getDynamicBlock($name);
		($block->{title}) = $block->{title} =~ /^.+\s(\w+)$/ if ($options->{user_self} and $block and $block->{block});

	my $supplement = '';
	foreach my $sp (@$supplemental_pages) {
		my ($page, $data) = each %$sp;
		$supplement .= slashDisplay($page, {
			supplement_data => $data
		}, { Page => 'dynamicblocks', Return => 1 });
	}

	return
		slashDisplay('displayblock',
			{ block => $block, supplement => $supplement },
			{ Page => 'dynamicblocks', Return => 1 });
}

sub ajaxDeleteMessage {
	my ($self, $constants, $user, $form, $options) = @_;

	my $messages = getObject('Slash::Messages');
	my $dynamic_blocks = getObject('Slash::DynamicBlocks');
	return 0 if (!$messages ||
		!$dynamic_blocks ||
		!$user->{uid} ||
		!$form->{val} ||
		($user->{uid} == $constants->{anonymous_coward_uid})
	);

	my $ids = [];
	@$ids = split(/,/, $form->{val});
	foreach my $id (@$ids) {
		my $message = $messages->getWeb($id);
		next if ($user->{uid} != $message->{user}{uid});
		$messages->_delete_web($id, $user->{uid});
	}

	my $gb_options = {};
	$gb_options->{strip_list} = 1 if ($form->{strip_list} == 1);
	$gb_options->{user_bio_messages} = 1 if ($form->{user_bio_messages} == 1);
	my $block = $dynamic_blocks->getDynamicBlock('messages-' . $user->{uid}, $gb_options);

	if ($block && $block->{block}) {
		$block->{user_bio_messages} = 1 if ($form->{user_bio_messages} == 1);
		$block->{strip_list} = 1 if ($form->{strip_list} == 1);
	}

	return Data::JavaScript::Anon->anon_dump($block);
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if $self->{_dbh} && !$ENV{GATEWAY_INTERFACE};
}

1;

=head1 NAME

Slash::DynamicBlocks - Slash dynamic slashbox module

=head1 SYNOPSIS

use Slash::DynamicBlocks;

=head1 DESCRIPTION

This contains all of the routines currently used by DynamicBlocks.

=head1 SEE ALSO

Slash(3).

=cut
