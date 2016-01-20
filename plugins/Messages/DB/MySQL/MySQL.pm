# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

package Slash::Messages::DB::MySQL;

=head1 NAME

Slash::Messages - Send messages for Slash


=head1 SYNOPSIS

	my $messages = getObject("Slash::Messages");

=head1 DESCRIPTION

LONG DESCRIPTION.

=cut

use strict;
use Slash::DB;
use Slash::Constants qw(:messages);
use Slash::Utility;
use Storable qw(nfreeze thaw);
use Encode qw(decode_utf8 is_utf8);

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub isInstalled {
	my $constants = getCurrentStatic();
	return undef if !$constants->{plugin}{Messages};
	1;
}

sub init {
	my($self, @args) = @_;

	$self->SUPER::init(@args) if $self->can('SUPER::init');

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	my $constants = getCurrentStatic();
#use Data::Dumper; warn "Messages/DB/MySQL.pm init() self=$self slashdb=$slashdb args='@args' cpm='$constants->{plugin}{Messages}' plugins: " . Dumper($plugins);
	return unless $plugins->{Messages};

	$self->{_drop_table}	= 'message_drop';
	$self->{_drop_cols}	= 'id,user,code,message,fuser,altto,date';
	$self->{_drop_prime}	= 'id';
	$self->{_drop_store}	= 'message';

	$self->{_web_table}	= 'message_web, message_web_text';
	$self->{_web_table1}	= 'message_web';
	$self->{_web_table2}	= 'message_web_text';
	$self->{_web_cols}	= 'message_web.id,user,code,message,fuser,readed,date,subject';
	$self->{_web_prime}	= 'message_web.id=message_web_text.id AND message_web.id';
	$self->{_web_prime1}	= 'id';
	$self->{_web_prime2}	= 'id';

	$self->{_prefs_table}	= 'users_messages';
	$self->{_prefs_cols}	= 'users_messages.code,users_messages.mode';
	$self->{_prefs_prime1}	= 'uid';
	$self->{_prefs_prime2}	= 'code';

	$self->{_log_table}	= 'message_log';

	1;
}

sub getDescriptions {
	my($self, $codetype, $optional, $flag) =  @_;
	my %descriptions = (
		'deliverymodes'
			=> sub { $_[0]->sqlSelectMany('code,name', 'code_param', "type='deliverymodes'") },
		'messagecodes'
			=> sub { $_[0]->sqlSelectMany('code,type', 'message_codes', "code >= 0") },
		'messagecodes_sub'
			=> sub { $_[0]->sqlSelectMany('code,type', 'message_codes', "code >= 0 AND type LIKE 'Subscription%'") },	
		'bvdeliverymodes'
			=> sub { $_[0]->sqlSelectAllHashref('code', 'code,name,bitvalue', 'message_deliverymodes') },
		'bvmessagecodes'
			=> sub { $_[0]->sqlSelectAllHashref('type', 'code,type,delivery_bvalue', 'message_codes', "code >= 0") },
		'bvmessagecodes_slev'
			=> sub { $_[0]->sqlSelectAllHashref('type', 'code,type,seclev,delivery_bvalue', 'message_codes', "code >= 0") },
	);
	# handle in Slash::DB::MySQL (or whatever)
	return $self->SUPER::getDescriptions($codetype, $optional, $flag, \%descriptions);
}

sub getMessageCode {
	my($self, $code, $flag) = @_;
	return unless $code =~ /^-?\d+$/;

	my $codeBank = {};
	my $cache = '_getMessageCodes_' . $code;

	if ($flag) {
		undef $self->{$cache};
	} elsif ($self->{$cache}) {
		# don't go back to SQL if $code is undefined but $cache exists
		return $self->{$cache}{$code};
	}

	my $row = $self->sqlSelectHashref('code,type,seclev,modes,send,subscribe,acl',
		'message_codes', "code=$code");
	$codeBank->{$code} = $row if $row;

	$self->{$cache} = $codeBank if getCurrentStatic('cache_enabled');

	return $codeBank->{$code};
}

sub getPrefs {
	my($self, $uid, $code) = @_;
	my $table = $self->{_prefs_table};
	my $cols  = $self->{_prefs_cols};
	my $prime = $self->{_prefs_prime1};
	my $where = $prime . '=' . $self->sqlQuote($uid);

	if ($code) {
		$prime .= $self->{_prefs_prime2} . '=' . $self->sqlQuote($code);
	}

	my $data = {};
	for (@{ $self->sqlSelectAll($cols, $table, $where) }) {
		$data->{$_->[0]} = $_->[1];
	}
	return $data;
}

sub setPrefs {
	my($self, $uid, $prefs) = @_;
	my $table = $self->{_prefs_table};
	my $cols  = $self->{_prefs_cols};
	my $prime = $self->{_prefs_prime1};
	my $where = $prime . '=' . $self->sqlQuote($uid);

	# First we delete, then we insert, this allows us to remove MSG_MODE_NONE type entries
	# Basically it keeps defaults out of the DB, and makes it smaller :)
	$self->sqlDelete($table, "uid = $uid");
	for my $code (keys %$prefs) {
		next if $prefs->{$code} == MSG_MODE_NONE;
		$self->sqlInsert($table, {
			uid	=> $uid,
			code	=> $code,
			mode	=> $prefs->{$code},
		});
	}
}

sub setPrefsSub {
	my($self, $uid, $prefs) = @_;
	my $table = $self->{_prefs_table};
	my $cols  = $self->{_prefs_cols};
	my $prime = $self->{_prefs_prime1};
	my $where = $prime . '=' . $self->sqlQuote($uid);
	my $messagecodes_sub = getDescriptions('messagecodes_sub');

	# First we delete, then we insert, this allows us to remove MSG_MODE_NONE type entries
	# Basically it keeps defaults out of the DB, and makes it smaller :)
	for my $scode (keys %$messagecodes_sub) {
		$self->sqlDelete($table, "uid = $uid AND code=$scode");
	}	
	for my $code (keys %$prefs) {
		next if $prefs->{$code} == MSG_MODE_NONE;
		$self->sqlInsert($table, {
			uid	=> $uid,
			code	=> $code,
			mode	=> $prefs->{$code},
		});
	}
}

sub log {
	my($self, $msg, $mode, $count) = @_;
	$count = 1 if !$count || $count < 1;
	my $table = $self->{_log_table};
	$msg->{user} ||= {};

	my %data = (
		id	=> $msg->{id},
		user	=> (ref($msg->{user})
				? ($msg->{user}{uid} || 0)
				: ($msg->{user} || 0)
			   ),
		fuser	=> (ref($msg->{fuser})
				? ($msg->{fuser}{uid} || 0)
				: ($msg->{fuser} || 0)
			   ),
		code	=> $msg->{code},
		mode	=> $mode,
	);

	$self->sqlInsert($table, \%data, { delayed => 1 })
		for 1 .. $count;
}

sub _create_web {
	my($self, $user, $code, $message, $fuser, $id, $subject, $date) = @_;
	my $table1 = $self->{_web_table1};
	my $table2 = $self->{_web_table2};

	# fix scalar to be a ref for freezing
	$self->sqlInsert($table1, {
		id	=> $id,
		user	=> $user,
		fuser	=> $fuser,
		code	=> $code,
		date	=> $date,
	});

	$self->sqlInsert($table2, {
		id	=> $id,
		subject	=> $subject,
		message	=> $message,
	});

	return $id;
}

sub _create {
	my($self, $user, $code, $message, $fuser, $altto, $send) = @_;
	my $table = $self->{_drop_table};
	my $prime = $self->{_drop_prime};

	# fix scalar to be a ref for freezing
	my $frozen = nfreeze(ref $message ? $message : \$message);

	my %insert_data = (
		user	=> $user,
		fuser	=> $fuser,
		altto	=> $altto || '',
		code	=> $code,
		message	=> $frozen,
		'send'	=> $send || 'now',
	);

	$insert_data{'-message'} = "0x" . unpack("H*", delete $insert_data{message})
		if getCurrentStatic('utf8');

	$self->sqlInsert($table, \%insert_data);

	my($msg_id) = $self->getLastInsertId({ table => $table, prime => $prime });
	return $msg_id;
}

sub _get_web {
	my($self, $msg_id) = @_;
	my $table = $self->{_web_table};
	my $cols  = $self->{_web_cols};
	my $prime = $self->{_web_prime};

	my $id_db = $self->sqlQuote($msg_id);
	my $data  = $self->sqlSelectHashref($cols, $table, "$prime=$id_db");

	$table    = $self->{_web_table1};
	$prime    = $self->{_web_prime1};
	$self->sqlUpdate($table, { readed => 1 }, "$prime=$id_db");

	# force to set UTF8 flag because these fields are 'blob'.
	#if (getCurrentStatic('utf8')) {
	#	$data->{'subject'} = decode_utf8($data->{'subject'}) unless (is_utf8($data->{'subject'}));
	#	$data->{'message'} = decode_utf8($data->{'message'}) unless (is_utf8($data->{'message'}));
	#}

	return $data;
}

sub _set_readed {
	my($self, $msg_id) = @_;
	my $id_db = $self->sqlQuote($msg_id);
	my $table    = $self->{_web_table1};
	my $prime    = $self->{_web_prime1};
	$self->sqlUpdate($table, { readed => 1 }, "$prime=$id_db");
}

sub _get_web_by_uid {
	my($self, $uid) = @_;
	my $table = $self->{_web_table};
	my $cols  = $self->{_web_cols};
	my $prime = "message_web.id=message_web_text.id AND user";
	my $other = "ORDER BY date ASC";

	my $id_db = $self->sqlQuote($uid || getCurrentUser('uid'));
	my $data = $self->sqlSelectAllHashrefArray(
		$cols, $table, "$prime=$id_db", $other
	);

	# force to set UTF8 flag because these fields are 'blob'.
	if (getCurrentStatic('utf8')) {
		for (@$data) {
			use Encode qw(_is_utf8);
			_is_utf8($_->{subject};
			_is_utf8($_->{message};
			#$_->{'subject'} = decode_utf8($_->{'subject'}) unless (is_utf8($_->{'subject'}));
			#$_->{'message'} = decode_utf8($_->{'message'}) unless (is_utf8($_->{'message'}));
		}
	}

	return $data;
}

sub _get_web_count_by_uid {
	my($self, $uid) = @_;
	my $table = $self->{_web_table};
	my $cols  = "readed";

	my $uid_db = $self->sqlQuote($uid || getCurrentUser('uid'));
	my $data = $self->sqlSelectAll(
		$cols, $table, "user=$uid_db AND " .
		"$self->{_web_table1}.$self->{_web_prime1} = $self->{_web_table2}.$self->{_web_prime2}",
	);

	my $read = grep { $_->[0] } @$data;
	return {
		'read'	=> $read,
		unread	=> scalar(@$data) - $read,
		total	=> scalar(@$data)
	};
}

sub _get {
	my($self, $msg_id) = @_;
	my $table = $self->{_drop_table};
	my $cols  = $self->{_drop_cols};
	my $prime = $self->{_drop_prime};

	my $id_db = $self->sqlQuote($msg_id);

	my $data = $self->sqlSelectHashref($cols, $table, "$prime=$id_db");

	$self->_thaw($data);
	return $data;
}

sub _gets {
	my($self, $count, $extra) = @_;
	my $table = $self->{_drop_table};
	my $cols  = $self->{_drop_cols};

	$count = 1 if $count && $count =~ /\D/;
	my $other = "ORDER BY date ASC";
	$other .= " LIMIT $count" if $count;

	my $where = '';
	if ($extra) {
		$where = join(' AND ', map {
			$_ . "=" . $self->sqlQuote($extra->{$_})
		} keys %$extra);
	}

	my $all = $self->sqlSelectAllHashrefArray(
		$cols, $table, $where, $other
	);

	for my $data (@$all) {
		$self->_thaw($data);
	}

	return $all;
}

sub _thaw {
	my($self, $data) = @_;
	my $store = $self->{_drop_store};
	$data->{$store} = thaw($data->{$store});
	# return scalar as scalar, not ref
	$data->{$store} = ${$data->{$store}} if ref($data->{$store}) eq 'SCALAR';
}

# For dailystuff
sub getDailyLog {
	my($self) = @_;

	my @time1 = localtime( time() - 86400 );
	my $date1 = sprintf "%4d%02d%02d000000", $time1[5] + 1900, $time1[4] + 1, $time1[3];

	my @time2 = localtime();
	my $date2 = sprintf "%4d%02d%02d000000", $time2[5] + 1900, $time2[4] + 1, $time2[3];

	my $table = $self->{_log_table};
	my $data = $self->sqlSelectAll(
		'code, mode, count(*) as count',
		$table,
		"date >= '$date1' AND date < '$date2'",
		"GROUP BY code, mode"
	);
}

# For dailystuff
sub deleteMessages {
	my($self) = @_;
	my $table = $self->{_web_table1};
	my $prime = $self->{_web_prime1};

	# set defaults
	my $constants = getCurrentStatic();
	my $sendx = $constants->{message_send_expire}  || 7;
	my $webx  = $constants->{message_web_expire}   || 14;
	my $webmx = $constants->{message_web_maxtotal} || 25;
	my $logx  = $constants->{archive_delay}        || 14;

	# delete message log entries
	$self->sqlDo("DELETE FROM $self->{_log_table} " .
		"WHERE TO_DAYS(NOW()) - TO_DAYS(date) > $logx");

	# delete web messages over certain date
	my $ids = $self->sqlSelectColArrayref($prime, $table,
		"TO_DAYS(NOW()) - TO_DAYS(date) > $webx"
	);
	$self->_delete_web($_, 0, 1) for @$ids;

	# delete user's web messages over certain total #
	$ids = $self->sqlSelectAll("user,count(*)", $table,
		"", "group by user"
	);
	for (@$ids) {
		if ($_->[1] > $webmx) {
			my $c = $_->[1] - $webmx;
			my $delids = $self->sqlSelectColArrayref(
				$prime, $table, "user=$_->[0]",
				"ORDER BY date ASC LIMIT $c"
			);
			$self->_delete_web($_, 0, 1) for @$delids;
		}
	}

	# delete unsent messages in queue over certain date
	$self->_delete(0, "TO_DAYS(NOW()) - TO_DAYS(date) > $sendx");
}

sub _delete_web {
	my($self, $id, $uid, $override) = @_;
	my $table1 = $self->{_web_table1};
	my $prime1 = $self->{_web_prime1};
	my $table2 = $self->{_web_table2};
	my $prime2 = $self->{_web_prime2};

	my $id_db = $self->sqlQuote($id);
	my $where1 = "$prime1=$id_db";
	my $where2 = "$prime1=$id_db";

	unless ($override) {
		$uid ||= getCurrentUser('uid');
		return 0 unless $uid;
		my $uid_db = $self->sqlQuote($uid);
		my $where  = $where1 . " AND user=$uid_db";
		my($check) = $self->sqlSelect('user', $table1, $where);
		return 0 unless defined($check) && $check eq $uid;
	}

	$self->sqlDo("DELETE FROM $table1 WHERE $where1");
	$self->sqlDo("DELETE FROM $table2 WHERE $where2");

	my $dynamic_blocks = getObject("Slash::DynamicBlocks");
	$dynamic_blocks->setUserBlock('messages', $uid) if $dynamic_blocks;

	return 1;
}

sub _defer {
	my($self, $id) = @_;
	my $table = $self->{_drop_table};
	my $prime = $self->{_drop_prime};

	my $id_db = $self->sqlQuote($id);
	my $where = "$prime=$id_db";

	$self->sqlUpdate($table, {
		'send'	=> 'defer'
	}, $where);
}

sub _delete {
	my($self, $id, $where) = @_;
	my $table = $self->{_drop_table};
	my $prime = $self->{_drop_prime};
	if (!$where) {
		my $id_db = $self->sqlQuote($id);
		$where = "$prime=$id_db";
	}

	$self->sqlDo("DELETE FROM $table WHERE $where");
}

sub _delete_all {
	my($self) = @_;
	my $table = $self->{_drop_table};

	# this will preserve auto_increment count
	$self->sqlDo("DELETE FROM $table WHERE 1=1");
}

sub _getMailingUsersRaw {
	my($self, $code) = @_;
	return unless $code =~ /^-?\d+$/;

	my $mode  = MSG_MODE_EMAIL;
	my $cols  = "users.uid";
	my $table = "users,users_messages";
	my $where = <<SQL;
users.uid=users_messages.uid AND
users_messages.code=$code AND users_messages.mode=$mode AND users.realemail != ''
SQL

	my $users  = $self->sqlSelectColArrayref($cols, $table, $where);
	return $users;
}

sub _getMailingUsers {
	my($self, $code) = @_;
	return unless $code =~ /^-?\d+$/;
	
	my $users  = $self->_getMailingUsersRaw($code);
	my $fields = [qw(
		realemail
		story_never_topic	story_never_author	story_never_nexus
		story_always_topic	story_always_author	story_always_nexus
		sectioncollapse
		daily_mail_special seclev
	)];
	# XXX While normally I'm all in favor of using object-specific
	# get and set methods, here getUser() may be the wrong approach.
	# We may have tens of thousands of users in @$users and it will
	# be a significant optimization of resources both for slashd and
	# for the database to grab just the above fields all at once.
	# -Jamie 2007-08-08
	$users     = { map { $_ => $self->getUser($_, $fields) } @$users };
	return $users;
}

sub _getMessageUsers {
	my($self, $code, $seclev, $subscribe, $acl) = @_;
	return unless $code =~ /^-?\d+$/;
	my $cols  = "users_messages.uid";
	my $table = "users_messages";
	my $where = "users_messages.code=$code AND users_messages.mode >= 0";

	my @users;
	if ($seclev && $seclev =~ /^-?\d+$/) {
		my $seclevt = "$table,users";
		my $seclevw = "$where AND users.uid = users_messages.uid AND seclev >= $seclev";
		my $seclevu = $self->sqlSelectColArrayref($cols, $seclevt, $seclevw) || [];
		push @users, @$seclevu;
	}

	if ($acl) {
		my $acl_q = $self->sqlQuote($acl);
		my $aclt = "$table,users_acl";
		my $aclw = "$where AND users_acl.uid = users_messages.uid AND users_acl.acl=$acl_q";
		my $aclu = $self->sqlSelectColArrayref($cols, $aclt, $aclw) || [];
		push @users, @$aclu;
	}


	my %seen;
	@users = grep { !$seen{$_}++     } @users;
	@users = grep { isSubscriber($_) } @users if $subscribe;
	return \@users;
}

1;

__END__
