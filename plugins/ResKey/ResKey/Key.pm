# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::ResKey::Key;

=head1 NAME

Slash::ResKey::Key - Resource management for Slash


=head1 SYNOPSIS

	my $reskey = getObject('Slash::ResKey');
	my $key = $reskey->key('zoo');
	if ($key->create) { ... }
	if ($key->touch)  { ... }
	if ($key->use) { ... }
	else { print $key->errstr }

=cut

use warnings;
use strict;

use Slash;
use Slash::Constants ':reskey';
use Slash::Utility;

our($AUTOLOAD);
our($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

#========================================================================
sub new {
	my($class, $user, $resname, $reskey, $debug) = @_;
	my $rkrid;

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'ResKey'};

	# we get the reskey automatically if it exists, can also
	# override by passing
	my $self = bless {
		debug	=> $debug,
		_reskey	=> $reskey || getCurrentForm('reskey')
	}, $class;

	if ($resname =~ /[a-zA-Z]/) {
		my $resources = $self->_getResources;
		$rkrid = $resources->{name}{$resname};
	} elsif ($resname =~ /^\d+$/) {
		my $resources = $self->_getResources;
		$rkrid = $resname;
		$resname = $resources->{id}{$rkrid};
	}

	return unless $resname && $rkrid;

	$self->{resname} = $resname;
	$self->{rkrid}   = $rkrid;

	$self->_init;

	return $self;
}

#========================================================================
# print out what method we're in
sub _flow {
	my($self, $name) = @_;
	return unless $self->{debug};

	my @caller1 = caller(1);
	my $name1 = $caller1[3];

	if ($name) {
		$name1 =~ s/::[^:]+$/::$name/;
	}

	printf STDERR "ResKey flow: calling %-40s\n", $name1;
}

#========================================================================
# call to reset values before doing anything requiring a return value
sub _init {
	my($self) = @_;
	$self->_flow;
	$self->{code} = 0;
	delete $self->{_errstr};
	delete $self->{_error};
	delete $self->{_reskey_obj};
	return 1;
}

#========================================================================
# sometimes we may wish to save/restore errors and codes
sub _save_errors {
	my($self) = @_;
	$self->_flow;
	$self->{_save_errors} = {
		code    => $self->{code},
		_errstr => $self->{_errstr},
		_error  => $self->{_error},
	};
	return 1;
}

sub _restore_errors {
	my($self) = @_;
	$self->_flow;
	$self->{code}    = $self->{_save_errors}{code};
	$self->{_errstr} = $self->{_save_errors}{_errstr};
	$self->{_error}  = $self->{_save_errors}{_error};
	delete $self->{_save_errors};
	return 1;
}

#========================================================================
sub can {
	my($self, $meth) = @_;
	return unless @_ == 2;
	my $can = UNIVERSAL::can($self, $meth);
	unless ($can) {
		$AUTOLOAD = ref($self) . '::' . $meth;
		$can = AUTOLOAD('AUTOLOAD::can', $self);
	}
	return $can;
}

#========================================================================
# a lot of methods around these parts just copy each other, so
# we use AUTOLOAD to make things a bit simpler to modify
sub AUTOLOAD {
	my $can   = $_[0] eq 'AUTOLOAD::can' ? shift : 0;
	(my $name = $AUTOLOAD) =~ s/^.*://;
	my $sub;

	# when called as a package class, package
	# may not be in the name ...
	my $full = $AUTOLOAD;
	$full = "$_[0]$full" if $full =~ /^::\w+$/;

	if ($name =~ /^(?:noop|success|failure|death)$/) {
		$sub = _createStatusAccessor($name, \@_);

	} elsif ($name =~ /^(?:error|reskey)$/) {
		$sub = _createAccessor($name, \@_);

	} elsif ($name =~ /^(?:create|touch|use)$/) {
		$sub = _createActionMethod($name, \@_);
	
	} elsif ($name =~ /^(?:createCheck|touchCheck|useCheck)$/) {
		$sub = _createCheckMethod($name, \@_);
	}

	# we create methods as needed, and only once
	if ($sub) {
		no strict 'refs';

#print "Creating new method $full\n";

		*{$full} = $sub;
		return $sub if $can;
		goto &$sub;

	} elsif (!$can) {
		errorLog("no method $name") unless
			$name =~ /^(?:DESTROY)$/;
		return;
	}
}

#========================================================================
# we may have various simple accessors
sub _createAccessor {
	my($name) = @_;
	my $newname = "_$name";
	return sub {
		my($self, $value) = @_;
		$self->_flow($name);
		return $self->{$newname} = $value if $value;
		return $self->{$newname};
	};
}

#========================================================================
# each key can have one of three status results: success, failure, death
# checks can also return noop
sub _createStatusAccessor {
	my($name) = @_;
	my $constant = $Slash::Constants::CONSTANTS{reskey}{"RESKEY_\U$name"};
	return sub {
		my($self, $set) = @_;
		$self->_flow($name);
		if ($set) {
			$self->{code} = $constant;
			return 1;
		}
		return 0 unless defined $self->{code};
		return $self->{code} == $constant ? 1 : 0;
	};
}

#========================================================================
# for the main methods: create, touch, use
# they call private methods named same thing, but with underscore
sub _createActionMethod {
	my($name) = @_;
	my $method_name = "_$name";
	return sub {
		my($self) = @_;
		$self->_flow($name);
		$self->{type} = $name;

		my $ok = 1;
		$ok = $self->_fakeUse if $self->{type} eq 'use';
		$ok = $self->_check if $ok;

		# don't bother if type is create, and checks failed ...
		# we only continue on for touch/use to update the DB
		# to note we've been here, to clean up, etc.
		if ($self->{type} ne 'create' || $ok) {
			$ok = $self->$method_name();
		}

		return $ok;
	};
}

#========================================================================
# the check methods are named similar to the main ones, but with
# capital letters.  we could change this is someone hates it.
#
# if it is public (no underscore), then it is expected to
# return a proper hashref, with code and error defined.
# otherwise, we call the private method (with underscore), which
# is expected to return two scalar values, a status code and
# optional error string, which are then put into the hashref.
#
# this allows us to simultaneously have complex possibilities
# for the future, and let simple methods still be simple.
# we *could* handle this in the _check method itself, but
# this is a bit cleaner, and we don't know if something other
# than _check might be calling these methods in the future.
sub _createCheckMethod {
	my($name, $args) = @_;
	my $method_name = "_\u$name";

	my $meth = $args->[0]->can($method_name);
	if (!$meth) {
		$meth = $args->[0]->can('Check');
		return $meth if $meth;
	}
	$meth ||= $args->[0]->can('_Check');

	if (!$meth) {
		return sub { return { code => RESKEY_NOOP } }
	}

	return sub {
		my($pkg, $self) = @_;
		$self->_flow($name);
		my($code, $error) = $meth->($self);
		return {
			code	=> $code,
			error	=> $error,
		};
	};
}

#========================================================================
sub _create {
	my($self) = @_;
	$self->_flow;
	$self->_init;

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	my $ok = 0;
	my $num_tries = 10;

	while (1) {
		my $reskey = getAnonId(1);
		my $rows = $slashdb->sqlInsert('reskeys', {
			reskey		=> $reskey,
			rkrid		=> $self->{rkrid},
			uid		=> $user->{uid},
			-srcid_ip	=> $self->_getSrcid,
			-create_ts	=> 'NOW()',
		});

		if ($rows > 0) {
			$self->reskey($reskey);
			$ok = 1;
			last;
		}

		# The INSERT failed because $formkey is already being
		# used.  Keep retrying as long as is reasonably possible.
		if (--$num_tries <= 0) {
			# Give up!
			errorLog("Slash::ResKey::Key->_create failed: $reskey\n");
			last;
		}
	}

	if ($ok) {
		$self->success(1);
	} else {
		$self->death(1);
		$self->error(['create failed']);
	}

	return $self->success;
}

#========================================================================
# _touch and _use are same, except _use also deals with submit_ts and is_alive
*_touch = \&_use;
sub _use {
	my($self) = @_;
	$self->_flow;
	my $failed = !$self->success;
	$self->_save_errors if $failed;
	$self->_init;

	my(%update, $where, $no_is_alive_check);
	%update = (
		-touches	=> 'touches+1',
		-last_ts	=> 'NOW()',
	);

	if ($failed) {
		%update = (%update,
			-failures	=> 'failures+1',
		);
	}

	if ($self->{type} eq 'use') {
		# use() already set it to no, assuming success
		$no_is_alive_check = 1;
		if ($failed) {
			# re-set these, as they were set by use(),
			# assuming success
			%update = (%update,
				-submit_ts	=> 'NULL',
				is_alive	=> 'yes',
			);
		} else {
			# update the ts again, just to be clean
			%update = (%update,
				-submit_ts	=> 'NOW()',
			);
		}
	}

	$self->_update(\%update, \$where, $no_is_alive_check) or return 0;

	my $slashdb = getCurrentDB();
	my $rows = $slashdb->sqlUpdate('reskeys', \%update, $where);

	if ($failed) {
		$self->_restore_errors;
	} elsif ($rows == 1) {
		$self->success(1);
	} else {
		$self->death(1);
		# we may want this error to be more finely detailed,
		# which may require additional SELECTs to find out
		# exactly what the problem is, or we could just
		# say the reskey is not valid
		$self->error(['touch-use failed']);
	}

	return $self->success;
}

#========================================================================
# some of these could be separate checks, but they happen for every reskey,
# and it is best for atomicity and performance to do them when we actually
# update the reskey
sub _update {
	my($self, $update, $where, $no_is_alive_check) = @_;
	$self->_flow;

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	my $reskey_obj = $self->get;
	return 0 unless $reskey_obj;

	my $srcid = $self->_getSrcid;

	my $where_base = "rkid=$reskey_obj->{rkid}";
	$where_base .= " AND is_alive='yes'" unless $no_is_alive_check;
	if ($$where) {
		$$where .= " AND $where_base";
	} else {
		$$where = $where_base;
	}

	# if user has logged in since getting reskey, we update the uid,
	# but still check this time by srcid
	if (isAnon($reskey_obj->{uid}) && !$user->{is_anon}) {
		$update->{uid} = $user->{uid};
		$$where .= ' AND srcid_ip=' . $self->_getSrcid;
	} else {  # use uid or srcid as appropriate
		$$where .= ' AND ' . $self->_whereUser;
	}

	return 1;
}

#========================================================================
# if we are going to use this reskey, set it as used
# up front, then un-use it if use fails, for the sake
# of faking atomicity
sub _fakeUse {
	my($self) = @_;
	$self->_flow;
	$self->_init;

	my $where;
	my %update = (
		-submit_ts	=> 'NOW()',
		is_alive	=> 'no',
	);

	$self->_update(\%update, \$where) or return 0;

	my $slashdb = getCurrentDB();
	my $rows = $slashdb->sqlUpdate('reskeys', \%update, $where);

	if ($rows == 1) {
		$self->success(1);
	} else {
		# we don't know what happened here ... bail
		$self->death(1);
		$self->error(['touch-use failed']);
	}

	return $self->success;
}

#========================================================================
sub _check {  # basically same for _checkUse, maybe share same code
	my($self) = @_;
	$self->_flow;
	$self->_init;

	my $meth = $self->{type} . 'Check';

	# getChecks will return 0 for failure, and an empty hashref
	# if we simply have no checks to perform
	my $checks = $self->_getChecks;
	if (!$checks) {
		$self->death(1);
		return 0;
	}

	for my $class (@$checks) {
		# $class implements each of
		# create, touch, and use methods
		local $@ = loadClass($class);  # loadClass in Environment.pm
		errorLog("Can't load $class: $@"), next if $@;

		# any data the $check needs will be in $self
#print "Checking $class : $meth\n";
		#Slash::ResKey::Checks::User->createCheck
		my $result = $class->$meth($self);

		# higher number takes precedence
		if ($result->{code} > $self->{code}) {
			$self->{code} = $result->{code};

			# otherwise not an error
			if ($self->{code} > RESKEY_SUCCESS) {
				$self->error($result->{error});
			}

			# no need to keep processing
			last if $self->{code} >= RESKEY_DEATH;
		}
#print "Status: $result->{code} : $self->{code}\n";
	}

	return $self->success;
}

#========================================================================
sub errstr {
	my($self) = @_;
	$self->_flow;
	return $self->{_errstr} if $self->{_errstr};

	my $errstr;
	my $error = $self->error;

	if ($error) {
		if (ref($error) eq 'ARRAY') {
			$error->[2] ||= 'reskey';
			$error->[1]{rkey} = $self;
			$errstr = getData(@$error);
		} else {
			$errstr = $error;
		}
	}

	return $self->{_errstr} = $errstr;
}

#========================================================================
sub get {
	my($self, $refresh) = @_;
	$self->_flow;
	return $self->{_reskey_obj} if !$refresh && $self->{_reskey_obj};

	my $slashdb = getCurrentDB();
	my $reskey_obj;

	if ($self->reskey) {
		my $reskey_q = $slashdb->sqlQuote($self->reskey);
		$reskey_obj = $slashdb->sqlSelectHashref('*', 'reskeys', "reskey=$reskey_q");
	}

	if (!$reskey_obj) {
		$self->death(1);
		$self->error(['reskey not found']);
	}

	return $self->{_reskey_obj} = $reskey_obj;
}

#========================================================================
sub _getSrcid {
	my($self) = @_;
	$self->_flow;
	return $self->{_srcid_ip} if $self->{_srcid_ip};
	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	return $self->{_srcid_ip} = get_srcid_sql_in(
		$user->{srcids}{ $constants->{reskey_srcid_masksize} || 24 }
	);
}

#========================================================================
sub _whereUser {
	my($self, $options) = @_;
	$self->_flow;

	my $user = getCurrentUser();
	my $where;

	# anonymous user without cookie, check host, not srcid
	if ($user->{is_anon} || $options->{force_srcid}) {
		$where = 'srcid_ip=' . $self->_getSrcid;
	} else {
		$where = "uid=$user->{uid}";
	}

	return $where;
}

#========================================================================
sub _getResources {
	my($self) = @_;
	$self->_flow;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $name        = 'reskey_resources';
	my $cache       = "_${name}_cache";
	my $cache_time  = "_${name}_cache_time";
	my $expire_time = getCurrentStatic("${name}_expire") || 86400;

	$reader->_genericCacheRefresh($name, $expire_time);
	my $resources = $reader->{$cache} ||= {};

	return $resources if scalar keys %$resources;

	my $select = $reader->sqlSelectAll('rkrid, name', 'reskey_resources');
	for (@$select) {
		$resources->{id}  {$_->[0]} = $_->[1];
		$resources->{name}{$_->[1]} = $_->[0];
	}

	return $resources;
}

#========================================================================
sub _getChecks {
	my($self) = @_;
	$self->_flow;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $name        = 'reskey_resource_checks';
	my $cache       = "_${name}_cache";
	my $cache_time  = "_${name}_cache_time";
	my $expire_time = getCurrentStatic("${name}_expire") || 86400;

	$reader->_genericCacheRefresh($name, $expire_time);
	my $checks_cache = $reader->{$cache} ||= {};

	my $checks = $checks_cache->{ $self->{type} }{ $self->{resname} };
	return $checks if defined $checks;  # could be empty array

	my $type_q = $reader->sqlQuote($self->{type});
	unless ($self->{rkrid} && $self->{resname}) {
		return 0;
	}

	# this select will group by ordernum, so if there is a conflict,
	# the actual type (create, touch, use) will override the "all"
	# pseudotype

	# setting a specific ordernum to the classname "" (empty string)
	# will effectively disable that check
	my $checks_select = $reader->sqlSelectAllHashref(
		'ordernum', 'class, ordernum', 'reskey_resource_checks',
		"rkrid=$self->{rkrid} AND (type=$type_q OR type='all')",
		"ORDER BY ordernum, type DESC, rkrcid"
	);

	$checks = [];
	for my $ordernum (sort { $a <=> $b } keys %$checks_select) {
		push @$checks, $checks_select->{$ordernum}{class}
			if $checks_select->{$ordernum}{class};
	}
	$checks_cache->{ $self->{type} }{ $self->{resname} } = $checks;

	unless (@$checks) {
		errorLog("No checks for $self->{type} / $self->{resname}");
	}

	return $checks;
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
