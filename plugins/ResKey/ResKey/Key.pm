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


=head1 DESCRIPTION

After getting an object from C<key> (see L<Slash::ResKey>), you may perform
three primary operations on the object.

Each of these performs checks as defined for that object's resource, as listed
in the C<reskey_resource_checks> table.  The rows in that table define the
classes, and the order in which those classes are to be checked.  Each class
defines the methods for executing the checks.

=over 4

=item create

To create a reskey to be used, call C<create>.  After running the checks,
a new reskey is inserted in the C<reskeys> table.

=item touch

When a reskey is tested, but not used up -- for example, in previewing, but
not yet submitting, a comment -- call C<touch>.  This performs the checks,
and marks the reskey as having been touched.

=item use

Call C<use> to finally use the reskey to unlock the resource, so it can
be used.  After the checks are run, the reskey is invalidated and may not be
used again.

(There is also a C<createuse> method, which first creates the reskey if
necesssary [it won't create one if it is already supplied], and then
immediately attempts to use it, for forms that don't need a preexisting
reskey already in the form from a previous C<create>.  Treat it as
a C<use>.)

=back


Each of the above methods returns true for success, and false for failure.
For failure, you can check C<errstr> to get the error string to present to
the user.

There are two failure conditions, C<failure> and C<death>.  By default, most
are C<death>, which means the reskey failure is fatal: you cannot try again.
However, some checks -- such as the one to make sure there's been enough
time between submission of comments -- are C<failure>.  If you wish to
continue after a C<touch> or C<use> returns false, you may do so if C<failure>
returns true:

	unless ($rkey->use) {
		if ($rkey->failure) {
			# try again
		} else {
			# you're hosed
		}
	}

You may also check the two success conditions, C<success> and C<noop>.

Assuming you're calling C<create> and later C<use>, rather than just
C<createuse>, you'll want to send the created reskey's value to the
user so that it can be submitted back later.  It is returned by the
C<reskey> method.  Either pass the entire key object to the form, or
just the reskey value itself:

	slashDisplay('myForm', { rkey => $rkey });

	<input type="hidden" name="reskey" value="[% rkey.reskey %]">

Or:

	slashDisplay('myForm', { reskey_value => $rkey->reskey });

	<input type="hidden" name="reskey" value="[% reskey_value %]">

But the easiest way is to just call the F<reskey_tag> template, which does the
right thing for you (you don't even need to pass anything to slashDisplay;
just make sure the reskey work is done in your code before calling this
in your template):

	[% PROCESS reskey_tag %]


There's also a C<get> method which returns the row from the C<reskeys>
database for that reskey.

=cut

use warnings;
use strict;

use Digest::MD5 'md5_hex';
use Time::HiRes;
use Slash;
use Slash::Constants ':reskey';
use Slash::Utility;

our($AUTOLOAD);
our($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

#========================================================================
sub new {
	my($class, $user, $resname, $reskey, $debug, $opts) = @_;
	my $rkrid;

	my $plugin = getCurrentStatic('plugin');
	return 0 unless $plugin->{'ResKey'};

	# we get the reskey automatically if it exists, can also
	# override by passing
	my $self = bless { _opts => $opts }, $class;

	$self->debug($debug);
	$self->resource($resname);

	return 0 unless $self->resname && $self->rkrid;

	# from filter_param
	if ($reskey) {
		$reskey =~ s|[^a-zA-Z0-9_]+||g;
	} elsif (!defined $reskey) {
		$reskey = getCurrentForm('reskey') unless $opts->{nostate}; # if we already have one
		if (!$reskey) {
			if ($self->static) {
				$reskey = $self->makeStaticKey;
			} else {
				$reskey = $self->createResKey;  
				$self->unsaved(1); # still needs to be inserted/checked
			}
		}
	}

	# reskey() to set the value is called only here and from dbCreate
	# this is the only place $form->{reskey} is looked at
	$self->reskey($reskey);

	$self->_init;

	return $self;
}

#========================================================================
# print out what method we're in
sub _flow {
	my($self, $name) = @_;
	# accessor calls _flow ... so don't call debug()
	return unless defined $self->{_debug} && $self->{_debug} > 1;

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
	$self->{_code} = 0;
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
		_code    => $self->{_code},
		_errstr => $self->{_errstr},
		_error  => $self->{_error},
	};
	return 1;
}

sub _restore_errors {
	my($self) = @_;
	$self->_flow;
	$self->{_code}   = $self->{_save_errors}{_code};
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

	} elsif ($name =~ /^(?:error|reskey|debug|rkrid|resname|origtype|type|code|opts|static|unsaved|max_duration)$/) {
		$sub = _createAccessor($name, \@_);

	} elsif ($name =~ /^(?:create|touch|use|createuse)$/) {
		$sub = _createActionMethod($name, \@_);

	} elsif ($name =~ /^(?:checkCreate|checkTouch|checkUse)$/) {
		$sub = _createCheckMethod($name, \@_);
	}

	# we create methods as needed, and only once
	if ($sub) {
		no strict 'refs';

#print STDERR "Creating new method $full\n";

		*{$full} = $sub;
		return $sub if $can;
		goto &$sub;

	} elsif (!$can) {
		errorLog("no method $name : [$AUTOLOAD @_]") unless
			$name =~ /^(?:DESTROY)$/;
		return;
	}
}

#========================================================================
# we have various simple accessors
sub _createAccessor {
	my($name) = @_;
	my $newname = "_$name";
	return sub {
		my($self, $value) = @_;
		$self->_flow($name);
		if (defined $value) {
			if ($name eq 'reskey' && !$self->opts->{nostate}) {
				# Setting reskey() is special, it gets
				# stored in the $user object as well.
				my $user = getCurrentUser();
				$user->{state}{reskey} = $value;
			}
			$self->{$newname} = $value;
		}
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
			$self->code($constant);
			return 1;
		}
		return 0 unless defined $self->code;
		return $self->code == $constant ? 1 : 0;
	};
}

#========================================================================
# for the main methods: create, touch, use (and createuse)
# they call private methods named same thing, but with underscore
sub _createActionMethod {
	my($name) = @_;
	return sub {
		my($self) = @_;
		$self->_flow($name);
		$self->type($name);
		$self->origtype($name);

		# first create a reskey, skipping the checks.
		# your job to make sure any check needed for
		# create is done for use, too.
		if ($self->type eq 'createuse') {
			$self->type('use');
			$self->dbCreate if $self->unsaved;
		}

		if ($self->type eq 'use' && !$self->static) {
			return 0 unless $self->fakeUse;
		}

		my $ok = $self->check;
# fake an error
#		if ($self->type eq 'use') {
#			$self->death(1);
#			$self->error(['dummy error']);
#		}

		# don't bother if type is create, and checks failed ...
		# we only continue on for touch/use to update the DB
		# to note we've been here, to clean up, etc.
		if ($self->type ne 'create' || $ok) {
			my $method_name = 'db' . ucfirst($self->type);
			$ok = $self->$method_name();
		}

		return $ok;
	};
}

#========================================================================
# this creates a method for when createCheck/touchCheck/useCheck
# is called.  it looks in the class for (in order): doCheckCreate,
# doCheckCreateExtra, doCheck, doCheckExtra.
#
# "Extra" is for future expansion, allowing a check method to return
# more than just the two main arguments: code and error hashref.  Those
# methods are used as-is, while the non-Extra versions are wrapped in
# another method.
#
# First, the specific method for the check type is tried (doCheckCreate),
# then the Extra version of it; then the generic check method
# for all check types is tried (doCheck), then finally the Extra version
# of it.
#
# If none of those is found, then a method returning NOOP is returned.

sub _createCheckMethod {
	my($name, $args) = @_;
	my($class, $self) = @$args;

	my $base  = 'doCheck';
	my $extra = 'Extra';
	my $base_name = "do\u$name";

	# doCheckCreate
	my $meth = $class->can($base_name);
	print STDERR "  Using $base_name\n" if $meth && $self->debug;

	# doCheckCreateExtra
	if (!$meth) {
		$meth = $class->can($base_name.$extra);
		if ($meth) {
			print STDERR "  Using $base_name$extra\n" if $self->debug;
			return $meth;
		}
	}

	# doCheck
	if (!$meth) {
		$meth = $class->can($base);
		print STDERR "  Using $base\n" if $meth && $self->debug;
	}

	# doCheckExtra
	if (!$meth) {
		$meth = $class->can($base.$extra);
		if ($meth) {
			print STDERR "  Using $base$extra\n" if $self->debug;
			return $meth;
		}
	}

	if (!$meth) {
		print STDERR "  Using NOOP\n" if $self->debug;
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
sub createResKey {
	return getAnonId(1, 20);
}

#========================================================================
sub dbCreate {
	my($self) = @_;
	$self->_flow;
	$self->_init;

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	my $ok = 0;

	# XXX We really should pull this repeat-insert-getAnonId
	# loop into a utility function in Environment.pm.  It's
	# repeated in createFormkey (and would be in
	# createDaypasskey except I don't think it's even worth
	# bothering).  When we do pull it out, remember to lose
	# the 'use Time::HiRes' :)
	if ($self->static) {
		$ok = 1;
	} else {
		my $reskey;
		$reskey = $self->reskey if $self->unsaved;
		my $srcid = $self->getSrcid;

		my $try_num = 1;
		my $num_tries = 10;
		while ($try_num < $num_tries) {
			$reskey ||= $self->createResKey;
			my $rows = $slashdb->sqlInsert('reskeys', {
				reskey		=> $reskey,
				rkrid		=> $self->rkrid,
				uid		=> $user->{uid},
				-srcid_ip	=> $srcid,
				-create_ts	=> 'NOW()',
			});

			if ($rows > 0) {
				$self->reskey($reskey);
				$self->unsaved(0);
				$ok = 1;
				last;
			}

			# blank for next try
			$reskey = '';
			
			# The INSERT failed because $reskey is already being
			# used.  Presumably this would be due to a collision
			# in the randomly-generated string, which indicates
			# there's a problem with the RNG (since with a true
			# RNG this would happen once every kajillion years).
			# Keep retrying, but we're going to log this once
			# we're done.
			++$try_num;
			# Pause before trying again;  in the event of a
			# problem with the RNG, lots of places in the code
			# are probably trying this all at once and this may
			# make the site fail more gracefully.
			Time::HiRes::sleep(rand($try_num));
		}
		if ($try_num > 1) {
			$try_num--;
			errorLog("Slash::ResKey::Key->create INSERT failed $try_num times: uid=$user->{uid} rkrid=$self->{rkrid} reskey=$reskey");
			# XXX: this should be more modularized, bad to keep
			# this all here, but OK to hack in for now -- pudge
			if (defined &Slash::ResKey::Checks::HumanConf::updateResKey) {
				Slash::ResKey::Checks::HumanConf::updateResKey($self);
			}
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
# dbTouch and dbUse are same, except dbUse also deals with submit_ts and is_alive
*dbTouch = \&dbUse;
sub dbUse {
	my($self) = @_;
	$self->_flow;
	my $slashdb = getCurrentDB();

	my($failed, $failure_string);
	if (!$self->success) {
		$failed = $self->error;
		$failure_string = ref($failed) ? $failed->[0] : $failed;
		$self->_save_errors;
	}
	$self->_init;
	my $ok = 0;

	if ($self->static) {
		if (!$failed) {
			$ok = $self->checkStaticKey;
		}
	} else {
		my(%update, $where, $no_is_alive_check);
		%update = (
			-touches	=> 'touches+1',
			-last_ts	=> 'NOW()',
		);

		if ($failed) {
			$update{-failures} = 'failures+1';
		}

		if ($self->type eq 'use') {
			# use(), or to be precise fakeUse() called by the
			# use() method created by _createActionMethod(),
			# already set is_alive to no, assuming success.
			$no_is_alive_check = 1;
			if ($failed) {
				# re-set these, as they were set by use(),
				# assuming success
				$update{-submit_ts} = 'NULL';
				$update{is_alive}   = 'yes';
			} else {
				# since is_alive is definitely 'no' here,
				# why not just delete it now? -Jamie
				# delete what?  the reskey?  because we (might)
				# need it for duration checks -- pudge
				# update the ts again, just to be clean
				$update{-submit_ts} = 'NOW()';
			}
		}

		$self->getUpdateClauses(\%update, \$where,
			$no_is_alive_check) or return 0;

		$ok = $slashdb->sqlUpdate('reskeys', \%update, $where);
	}

	if ($failed) {
		$self->_restore_errors;
	} elsif ($ok == 1) {
		$self->success(1);
	} else {
		$self->death(1);
		# we may want this error to be more finely detailed,
		# which may require additional SELECTs to find out
		# exactly what the problem is, or we could just
		# say the reskey is not valid
		$failure_string = 'touch-use failed';
		$self->error([$failure_string]);
	}

	if ($failure_string && !$self->static) {
		my $reskey_obj = $self->get;
		if ($reskey_obj) {
			my $rkid = $reskey_obj->{rkid};
			if ($rkid) {
				$slashdb->sqlReplace('reskey_failures', {
					rkid	=> $rkid,
					failure	=> $failure_string
				});
			}
		}
	}

	return $self->success;
}

#========================================================================
# some of these could be separate checks, but they happen for every reskey,
# and it is best for atomicity and performance to do them when we actually
# update the reskey
sub getUpdateClauses {
	my($self, $update, $where, $no_is_alive_check) = @_;
	$self->_flow;

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();
	my $user = getCurrentUser();

	my $reskey_obj = $self->get;
	return 0 unless $reskey_obj;

	my $srcid = $self->getSrcid;

	my $rkrid = $self->rkrid;

	my $where_base = "rkid=$reskey_obj->{rkid} AND rkrid=$rkrid";
	$where_base .= " AND is_alive='yes'" unless $no_is_alive_check;
	if ($$where) {
		$$where .= " AND $where_base";
	} else {
		$$where = $where_base;
	}

	# If user has logged in since getting reskey, we update the uid,
	# but still check this time by srcid. - Pudge
	# And if the user has logged OUT since getting the reskey,
	# getWhereUserClause will just treat them as anon, as,
	# presumably, the caller script will also.
	if (isAnon($reskey_obj->{uid}) && !$user->{is_anon}) {
		$update->{uid} = $user->{uid};
		$$where .= ' AND srcid_ip=' . $self->getSrcid;
	} else {  # use uid or srcid as appropriate
		$$where .= ' AND ' . $self->getWhereUserClause;
	}

	return 1;
}

#========================================================================
sub getWhereUserClause {
	my($self, $options) = @_;
	$self->_flow;

	my $user = getCurrentUser();
	my $where;

	# anonymous user without cookie, check host, not srcid
	if ($user->{is_anon} || $options->{force_srcid}) {
		$where = 'srcid_ip=' . $self->getSrcid;
	} else {
		$where = "uid=$user->{uid}";
	}

	return $where;
}

#========================================================================
# if we are going to use this reskey, set it as used
# up front, then un-use it if use fails, for the sake
# of faking atomicity
sub fakeUse {
	my($self) = @_;
	$self->_flow;
	$self->_init;

	my $where;
	my %update = (
		-submit_ts	=> 'NOW()',
		is_alive	=> 'no',
	);

	$self->getUpdateClauses(\%update, \$where) or return 0;

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
sub check {  # basically same for checkUse, maybe share same code
	my($self) = @_;
	$self->_flow;
	$self->_init;

	# checkUse
	my $meth = 'check' . ucfirst($self->type);

	# getChecks will return 0 for failure, and an empty hashref
	# if we simply have no checks to perform
	my $checks = $self->getChecks;
	if (!$checks) {
		$self->death(1);
		return 0;
	}

	for my $class (@$checks) {
		# $class implements each of
		# create, touch, and use methods
		loadClass($class);  # loadClass in Environment.pm
		errorLog("Can't load $class: $@"), next if $@;

		# any data the $check needs will be in $self
		print STDERR "Checking $class : $meth\n" if $self->debug;

		#Slash::ResKey::Checks::User->checkUse
		my $result = $class->$meth($self);

		# higher number takes precedence
		# (we start with success (code == 0), so
		# noop (code == -1) is skipped)
		if ($result->{code} > $self->code) {
			$self->code($result->{code});

			# otherwise not an error
			if ($self->code > RESKEY_SUCCESS) {
				$self->error($result->{error});
			}

			# no need to keep processing
			last if $self->code >= RESKEY_DEATH;
		}
		printf STDERR ("  Status: %d : %d\n",
			$result->{code}, $self->code) if $self->debug;
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
sub resource {
	my($self, $resname) = @_;

	if ($resname) {
		my $resource;
		if ($resname =~ /[a-zA-Z]/) {
			my $resources = $self->getResources;
			$resource = $resources->{by_name}{$resname};
		} elsif ($resname =~ /^\d+$/) {
			my $resources = $self->getResources;
			$resource = $resources->{by_id}{$resname};
		}

		if ($resource) {
			$self->{_resource} = $resource;
			$self->resname($resource->{name});
			$self->rkrid($resource->{id});
			$self->static($resource->{static});
		}
	}

	return $self->{_resource} || {};
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

	if (!$reskey_obj && !$self->unsaved) {
		$self->death(1);
		$self->error(['reskey not found']);
	}

	return $self->{_reskey_obj} = $reskey_obj;
}

#========================================================================
sub getSrcid {
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
sub getResources {
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

	my $select = $reader->sqlSelectAll('rkrid, name, static', 'reskey_resources');
	for (@$select) {
		my $resource = {
			id	=> $_->[0],
			name	=> $_->[1],
			static	=> ($_->[2] eq 'yes' ? 1 : 0)
		};
		$resources->{by_id}  {$resource->{id}}   =
		$resources->{by_name}{$resource->{name}} = $resource;
	}

	return $resources;
}

#========================================================================
sub getChecks {
	my($self) = @_;
	$self->_flow;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $name        = 'reskey_resource_checks';
	my $cache       = "_${name}_cache";
	my $cache_time  = "_${name}_cache_time";
	my $expire_time = getCurrentStatic("${name}_expire") || 86400;

	$reader->_genericCacheRefresh($name, $expire_time);
	my $checks_cache = $reader->{$cache} ||= {};

	my $checks = $checks_cache->{ $self->type }{ $self->resname };
	return $checks if defined $checks;  # could be empty array

	my $type_q = $reader->sqlQuote($self->type);
	unless ($self->rkrid && $self->resname) {
		return 0;
	}

	# this select will group by ordernum, so if there is a conflict,
	# the actual type (create, touch, use) will override the "all"
	# pseudotype

	# setting a specific ordernum to the classname "" (empty string)
	# will effectively disable that check
	my $rkrid = $self->rkrid;
	my $checks_select = $reader->sqlSelectAllHashref(
		'ordernum', 'class, ordernum', 'reskey_resource_checks',
		"rkrid=$rkrid AND (type=$type_q OR type='all')",
		"ORDER BY ordernum, type DESC, rkrcid"
	);

	$checks = [];
	for my $ordernum (sort { $a <=> $b } keys %$checks_select) {
		push @$checks, $checks_select->{$ordernum}{class}
			if $checks_select->{$ordernum}{class};
	}
	$checks_cache->{ $self->type }{ $self->resname } = $checks;

	unless (@$checks) {
		my($type, $resname) = ($self->type, $self->resname);
		errorLog("No checks for $type / $resname");
	}

	return $checks;
}

#========================================================================
sub getAllCheckVars {
	my($self) = @_;

	my $vars = $self->{_check_vars} ||= {};
	return $vars if keys %$vars;

	my $reader = getObject('Slash::DB', { db_type => 'reader' });

	my $all = $reader->sqlSelectAll('rkrid, name, value', 'reskey_vars');
	for my $row (@$all) {
		$vars->{ $row->[0] }{ $row->[1] } = $row->[2];
	}

	return $vars;
}

#========================================================================
sub getCheckVars {
	my($self) = @_;

	if ($self->rkrid) {
		my $vars = $self->getAllCheckVars;
		return $vars->{ $self->rkrid };
	}

	return;
}

#========================================================================
sub makeStaticKey {
	my($self, $id, $salt) = @_;

	my $constants = getCurrentStatic();
	my $user = getCurrentUser();
	$salt ||= $self->getCurrentSalt;
	$id   ||= $self->{id} || '';

	return md5_hex(
		join($;,
			$user->{uid},
			$user->{srcids}{ $constants->{reskey_srcid_masksize} || 24 },
			# these change so often, i don't think there's a real point
			# to fixing it to a specific resource (resname) or id,
			# and making it more general makes it a little simpler to use
			# -- pudge
			#$self->resname,
			#$id,
			$constants->{reskey_static_salt},
			$salt
		)
	);
}

#========================================================================
sub checkStaticKey {
	my($self) = @_;

	my $salts = $self->getCurrentSalts;
	for my $salt (@$salts) {
		my $test = $self->makeStaticKey($self->{id}, $salt);
		if ($test && $self->reskey eq $test) {
			return 1;
		}
	}

	return 0;
}

#========================================================================
sub getCurrentSalt {
	my($self) = @_;
	my($salts) = $self->getCurrentSalts(1);
	return $salts->[0];
}


#========================================================================
# XXX This needs to be optimized to (a) use the reader DB instead
# of the writer and (b) cache the current values in memcached.
# Preferably, all possibly-valid hourly salts (all with ts <= NOW)
# should be in one memcached object;  when set, that object should
# be set to expire at xx:59:59.
sub getCurrentSalts {
	my($self, $num) = @_;

	my $constants = getCurrentStatic();
	my $slashdb = getCurrentDB();

	$num ||= int( ($constants->{reskey_timeframe} || 14400) / 3600 );

	my($salts) = $slashdb->sqlSelectColArrayref('salt', 'reskey_hourlysalt', 'ts <= NOW()', "ORDER BY ts DESC LIMIT $num");
	return $salts;
}

sub ERROR {
	my($self, $extra, $user) = @_;
	$extra ||= '';
	$user ||= getCurrentUser();
	printf STDERR "AJAXE %d: UID:%d, extra:%s: %s (%s) (%s:%s:%s:%s:%s:%s:%s)\n",
		$$, $user->{uid}, $extra, $self->errstr, $self->error->[0], $self->reskey,
		$self->type, $self->resname, $self->rkrid, $self->code, $self->static,
		$user->{srcids}{ 24 };
}

1;

__END__


=head1 SEE ALSO

Slash(3).

=head1 VERSION

$Id$
