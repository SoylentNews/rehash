package Slash::Custom::Bulkmail;

#Copyright (c) 1999, 2000 James A Thomason III (thomasoniii@yahoo.com). All rights reserved.
#This program is free software; you can redistribute it and/or
#modify it under the same terms as Perl itself.

$VERSION = "2.051";

use Socket;
use Carp 'cluck';
use 5.004;

use strict;

{

	#Let's make up some defaults
	my $def_From				= 'Postmaster';
	my $def_To					= 'postmaster@your.smtp.com';
	my $def_Smtp				= 'your.smtp.com';		#<--Set this variable.  Important!
	my $def_Domain				= "";	# smtp.com
	my $def_Port 				= '25';
	my $def_Tries				= '5';
	my $def_Subject				= "(no subject)";
	my $def_Precedence 			= "list";				#list, bulk, or junk
	my $def_Trusting			= 0;
	my $def_log_full_line		= 0;
	my $def_envelope_limit		= 0;
	my $def_allow_duplicates	= 0;
	
	my $def_use_envelope		= 0;
	my $def_HTML				= 0;
	my $def_safe_banned			= 1;
	
	my $def_BMD 		= "::";
	my $def_DHD			= ",";
	my $def_DMD			= ",";
	my $def_DMDE		= "=";
	my $def_DHDE		= "=";
	
	my $def_lineterm	= "\n";
	
	my $def_HFM			= 0;
	
	#defaults are done.  Mess with _nothing_ else.  I mean it.  You've been warned.


	{
		my $counter;
		
		sub add_attr {
			my $self = shift || undef;
			if (@_){
				my $low = $counter;
				$counter += shift;
				return ($low .. $counter);
			}
			else {return $counter++};
		};
		
	};
	
	my $From 			= Slash::Custom::Bulkmail->add_attr();
	my $To				= Slash::Custom::Bulkmail->add_attr();
	my $Message 		= Slash::Custom::Bulkmail->add_attr();
	my $cached_message 	= Slash::Custom::Bulkmail->add_attr();
	my $Subject 		= Slash::Custom::Bulkmail->add_attr();
	my $merge 			= Slash::Custom::Bulkmail->add_attr();
	my $dynamic			= Slash::Custom::Bulkmail->add_attr();
	my $dynamic_headers	= Slash::Custom::Bulkmail->add_attr();
	
	my $BULK 			= Slash::Custom::Bulkmail->add_attr();
	my $LIST 			= Slash::Custom::Bulkmail->add_attr();
	my $BAD 			= Slash::Custom::Bulkmail->add_attr();
	my $GOOD 			= Slash::Custom::Bulkmail->add_attr();
	my $ERRFILE			= Slash::Custom::Bulkmail->add_attr();
	my $banned 			= Slash::Custom::Bulkmail->add_attr();
	
	my $safe_banned		= Slash::Custom::Bulkmail->add_attr();
	
	my $Smtp 			= Slash::Custom::Bulkmail->add_attr();
	my $Domain 			= Slash::Custom::Bulkmail->add_attr();
	my $Port 			= Slash::Custom::Bulkmail->add_attr();
	my $Tries 			= Slash::Custom::Bulkmail->add_attr();
	my $Precedence 		= Slash::Custom::Bulkmail->add_attr();
	my $HTML			= Slash::Custom::Bulkmail->add_attr();
	my $allow_duplicates= Slash::Custom::Bulkmail->add_attr();
	my $sort_list		= Slash::Custom::Bulkmail->add_attr();
	
	my $cached_domain	= Slash::Custom::Bulkmail->add_attr();
	my $waiting_message	= Slash::Custom::Bulkmail->add_attr();
	
	my $connected 		= Slash::Custom::Bulkmail->add_attr();
	
	my $Trusting	 	= Slash::Custom::Bulkmail->add_attr();
	my $log_full_line	= Slash::Custom::Bulkmail->add_attr();
	my $envelope_limit	= Slash::Custom::Bulkmail->add_attr();
	my $error 			= Slash::Custom::Bulkmail->add_attr();
	my $duplicates 		= Slash::Custom::Bulkmail->add_attr();
	my $headers 		= Slash::Custom::Bulkmail->add_attr();
	my $BMD 			= Slash::Custom::Bulkmail->add_attr();		#filemap delimiter
	my $DMD				= Slash::Custom::Bulkmail->add_attr();		#dynamic message delimiter
	my $DMDE			= Slash::Custom::Bulkmail->add_attr();		#dynamic message assignment delimiter
	my $DHD				= Slash::Custom::Bulkmail->add_attr();		#dynamic header delimiter
	my $DHDE			= Slash::Custom::Bulkmail->add_attr();		#dynamic header assignment delimiter
	my $HFM 			= Slash::Custom::Bulkmail->add_attr();		#headers from message
	my $lineterm		= Slash::Custom::Bulkmail->add_attr();		#line terminator
	
	
	my $use_envelope	= Slash::Custom::Bulkmail->add_attr();
	
	#email accessors
	sub email_accessor {
		my $self = shift || undef;
		my $prop = shift || undef;
		
		if (@_){
			my $email = shift || undef;
			if ($self->valid_email($email)){
				$self->[$prop] = $email;
			}
			else {
				return $self->error("Invalid address: $email");
			};
		}
		
		return $self->[$prop];
		
	};
	
	sub From 		{shift->email_accessor($From, @_)};
	sub To 			{shift->email_accessor($To, @_)};
	
	sub AUTOLOAD {
		my $self = shift || undef;
		my $method = $Slash::Custom::Bulkmail::AUTOLOAD;
		
		$method =~ s/^.*:://;

		return $self->error("Method \"$method()\" doesn't exist.  Did you mean to call header?");

	};
					
	sub header {
	
		my $self = shift || undef;
		my $header = shift or return $self->[$headers];
		
		if ($header =~ /^(?:From|Subject|Precedence|HTML|To)$/){
			return $self->$header(@_);
		};
	
		$self->[$headers]->{$header} = shift || undef if @_;
	
		return $self->[$headers]->{$header};
	
	};
	
	
	#/email accessors
	
	#validating accessors
	
	sub valid_precedence {
		my $self = shift;
		my $value = shift || undef;
		
		return 1 if $self->Trusting || $value =~ /list|bulk|junk/i;
	};
	
	sub Precedence 	{
		my $self = shift || undef;
		
		if (@_){
			my $value = shift || undef;
			if ($self->valid_precedence($value)){
				$self->[$Precedence] = lc $value;
			}
			else {
				return $self->error("Invalid precedence.  'list', 'bulk', or 'junk' only, please.");
			};
		};
		
		return $self->[$Precedence];
	};
	
	sub Domain		{
		my $self = shift || undef;
		
		if (@_){
			my $value = shift || undef;
			$value =~ s/^.*@//; #make sure it is a domain, not an email address
			my $fake_email = "j\@$value";								#hee hee.  Let's make a fake email address that will pass the validator
			if ($self->valid_email($fake_email)){	#if the domain is correct. Spares another validation routine
				$self->[$Domain] = $value;
			}
			else {
				return $self->error("Invalid domain.  ($value)");
			};
		};
		
		return $self->[$Domain];
		
	};
		
	#/validating accessors
	
	#file accessors
	sub file_accessor {
		my $self 		= shift || undef;
		my $file_place 	= shift || undef;
		my $IO 			= shift || undef;
		my $file 		= @_ > 1 ? [@_] : shift || undef;
		if ($file){
			unless (ref $file){
				my $handle = $self->gen_handle();
				return $self->error("Invalid IO value ($IO), '>', '>>', '<', or '' only.\n  Why are you using the file accessor directly anyway?") unless $IO =~ /^<<?$|^>>?$/;
				open ($handle, $IO . $file);
				$self->[$file_place] = $handle;
			}
			elsif (ref($file) =~ /^(GLOB|ARRAY|CODE)$/){
				$self->[$file_place] = $file;
			}
			else {
				return $self->error("File error.  I don't understand what a " . ref ($file) . " is. ($file)");
			};
		};
		
		return $self->[$file_place];
	
	};
	
	sub BULK	{shift->file_accessor($BULK, "NO IO", @_)};
	sub LIST	{shift->file_accessor($LIST, "<", @_)};
	sub BAD		{shift->file_accessor($BAD,  ">>", @_)};
	sub GOOD	{shift->file_accessor($GOOD, ">>", @_)};
	sub ERRFILE	{shift->file_accessor($ERRFILE,">>", @_)};
	#/file accessors

	#hash accessors
	sub hash_accessor {
		my $self = shift || undef;
		my $prop = shift || undef;
		my $file = @_ > 1 ? [@_] : shift || undef;
		if ($file) {
			unless (ref $file){
				my $handle = $self->gen_handle();
				open ($handle, $file) or return $self->error("Cannot open file: $file");
				$file = $handle;
			};
			
			if (ref($file) =~ /^GLOB|ARRAY|CODE$/){
				my %hash = ();
				my $key = undef;
				my $value = undef;
				while (defined($key = $self->getnextLine($file))){
					chomp $key;
					if ($prop != $banned){
						$value = $self->getnextLine($file) || return $self->error("Cannot get value for hash: odd length");
					}
					else {
						$value = $self->lc_domain($key);
						$key = lc $key;
					};
					$hash{$key} = $value;
				};
				$self->[$prop] = \%hash;
			}			
			elsif (ref $file eq "HASH"){
				$self->[$prop] = $file;
			}
			else {
				return $self->error("I can't build that hash.  I don't know what a " . ref ($file) . " is. ($file)");
			};
		};
		
		return $self->[$prop];
	};
	
	sub banned			{shift->hash_accessor($banned, @_)};
	sub merge 			{shift->hash_accessor($merge, @_) or return undef};
	sub dynamic 		{shift->hash_accessor($dynamic, @_)};
	sub dynamic_headers {shift->hash_accessor($dynamic_headers, @_)};
	sub duplicates		{shift->hash_accessor($duplicates, @_)};
	
	sub setDuplicate {
		my $self = shift || undef;
		my $email = shift or return $self->error("Cannot set duplicate: No email address");
		
		return 1 if $self->allow_duplicates();
		
		if ($self->safe_banned){
			$self->duplicates->{lc $email} = 1;
		}
		else {
			$self->duplicates->{$self->lc_domain($email)} = 1;
		};
		
		return 1;
	};
	
	sub isDuplicate {
		my $self = shift || undef;
		my $email = shift or return $self->error("Cannot determine duplicate: No email address");
		return 0 if $self->allow_duplicates();
		
		if ($self->safe_banned){
			return $self->duplicates->{lc $email};
		}
		else {
			return $self->duplicates->{$self->lc_domain($email)};
		};
		
	};
	
	sub isBanned {
		my $self = shift || undef;
		my $email = shift or return $self->error("Cannot determine banned-ness: No email address");
		my ($local, $domain) = split(/@/,$email);
		
		#first see if the domain is banned
		return 2 if $self->banned->{lc $domain};
		
		#then see if the email address is banned
		if ($self->safe_banned){
			return 1 if defined $self->banned->{lc $email};
		}
		else {
			return 1 if $self->banned->{lc $email} eq $self->lc_domain($email);
		};
		
		return 0;
	};
	#/hash accessors

	#boring ole' normal accessors
	sub accessor {
		my $self = shift || undef;
		my $prop = shift or return $self->error("Accessor called incorrectly: Bad programmer!");
		$self->[$prop] = shift || undef if @_;
		return $self->[$prop];
	};
	
	sub lineterm 		{shift->accessor($lineterm, @_)};
	sub Trusting 		{shift->accessor($Trusting, @_)};
	sub log_full_line 	{shift->accessor($log_full_line, @_)};

	sub connected 		{shift->accessor($connected, @_)};
	sub Subject 		{shift->accessor($Subject, @_)};
	sub Message 		{shift->accessor($Message, @_)};
	sub cached_message	{shift->accessor($cached_message, @_)};
	sub HTML	 		{shift->accessor($HTML, @_)};
	sub allow_duplicates{shift->accessor($allow_duplicates, @_)};
	sub sort_list		{shift->accessor($sort_list, @_)};

	sub Smtp 			{shift->accessor($Smtp, @_)};
	sub Port 			{shift->accessor($Port, @_)};
	sub Tries 			{shift->accessor($Tries, @_)};
	
	sub cached_domain	{shift->accessor($cached_domain, @_)};
	sub waiting_message	{shift->accessor($waiting_message, @_)};
	
	sub BMD				{shift->accessor($BMD, @_)};
	sub DMD				{shift->accessor($DMD, @_)};
	sub DMDE			{shift->accessor($DMDE, @_)};
	sub DHD				{shift->accessor($DHD, @_)};
	sub DHDE			{shift->accessor($DHDE, @_)};
	sub HFM				{shift->accessor($HFM, @_)};
	
	sub use_envelope	{shift->accessor($use_envelope, @_)}; #also, envelope_limit, below
	
	sub safe_banned		{shift->accessor($safe_banned, @_)};
	
	#/boring ole' normal accessors

	sub envelope_limit {
		my $self = shift;
		my $limit = shift || 0;
		return 0 unless defined $limit or $self->[$envelope_limit]->[0];	
				#we can't reach the limit if there isn't one
	
		if (defined $limit){
			$self->[$envelope_limit] = [$limit, 0];
			return $limit;
		}
		else {
			my ($limit, $times) = @{$self->[$envelope_limit]};
			if ($times >= $limit){
				$self->[$envelope_limit] = [$limit, 0];
				return 1;	#yes, we have reached the limit
			}
			else {
				$times++;
				$self->[$envelope_limit] = [$limit, $times];
				return 0;	#no, we have not reached the limit
			};
		};
		
	};

	{	#wrap up class and object error handling
		#Bulkmail 2.03 objects and higher store their error strings first.
		#But you don't care, since you've never _ever_ directly accessed the
		#underlying object, right?
		
		BEGIN {
			my $error = Slash::Custom::Bulkmail->add_attr();
		};
		
		my $global_error = undef;
		sub error {
			my $self = shift || undef;
			
			if (ref $self){
				if (@_){
					$self->[$error] = shift || undef;
					
					$self->log_it($self->[$error], $self->ERRFILE()) if $self->ERRFILE;
				   	
				   	if (@_){
						my $what = shift || undef;
						my $where = shift || undef;

						$self->log_it($what, $where);
					}; 
			
					return undef;
				}
				else {return $self->[$error]};
			}
			else {
				if (@_){
					$global_error = shift;
					return undef;
				}
				else {return $global_error};
			};
		};	  #end error
			
	};	  #end error wrap up

	sub log_it {
		
		my $self = shift || undef;
		my $value = shift || undef;
		my $handle = shift || undef;
		
		if (ref $handle eq 'ARRAY'){
			push @$handle, $value;
		}
		elsif (ref $handle eq 'CODE'){
			&$handle($value);
		}
		elsif (ref $handle eq 'GLOB'){
			select((select($handle), $| = 1)[0]); 		#Make sure the file is piping hot!
			
			local $\ = undef;
			
			if (ref $value eq 'ARRAY'){
				$value = join($self->BMD, @{$value});
			}
			elsif (ref $value eq 'HASH'){
				my $keys   = $self->build_merge_line($self->merge->{"BULK_MAILMERGE"}, $self->BMD); 
				$value = join($self->BMD, map {$value->{$_}} sort keys %{$value});
			}
			elsif (ref $value){
				$self->error("Don't know how to properly log a " . ref ($value) . " ($value) to a file.");
			};
			
			#get rid of those sendmail-ified carriage returns
			$value =~ s/\015\012$//g;
			print $handle $value, $self->lineterm() or cluck("Tried to print: '$value'");
		}
		else {return $self->error("Logging error: Nothing to log to")};
		
		return 1;
		
	};

	#make sure that we're disconnected
	sub DESTROY {
		my $self = shift || undef;
		$self->disconnect;
		$self = undef;
	};

	sub new {

		my $class = shift || undef;	
		my $self = [];			#why not a hash?  An array is a smidgen bit faster and no one is gonna see the underlying structure anyway
		bless $self, $class;	#Hey!  What are you doing looking in here anyway?  Use the nice OO interface I wrote you!

		$self->init(
			"From"						=> $def_From,
			"To"						=> $def_To,
			"Smtp"						=> $def_Smtp,
			"Domain"					=> $def_Domain,
			"Port"						=> $def_Port,
			"Tries"						=> $def_Tries,
			"Subject"					=> $def_Subject,
			"Precedence"				=> $def_Precedence,
			"Trusting"					=> $def_Trusting,
			"log_full_line"				=> $def_log_full_line,
			"envelope_limit"			=> $def_envelope_limit,
			"duplicates" 				=> {},
			"merge"						=> {},
			"dynamic"					=> {},
			"banned" 					=> {},
			"lineterm"					=> $def_lineterm,
			"BMD"						=> $def_BMD,
			"DMD"						=> $def_DMD,
			"DHD"						=> $def_DHD,
			"DMDE"						=> $def_DMDE,
			"DHDE"						=> $def_DHDE,
			"HFM"						=> $def_HFM,
			"safe_banned"				=> $def_safe_banned,
			"use_envelope"				=> $def_use_envelope,
			"HTML"						=> $def_HTML,
			"allow_duplicates"			=> $def_allow_duplicates,
			"sort_list"					=> 0,
			@_
		) or return Slash::Custom::Bulkmail->error("Cannot create object, initialization error: " . $self->error());
		return $self;
		
	};

#Didn't I tell you not to mess with anything else?  Oh well, it's your funeral.	
	
	sub init {
	
		my ($self, %init) = @_;
		
		$self->ERRFILE		($init{"ERRFILE"}) 	if $init{"ERRFILE"};	#Be sure we can log errors ASAP
		$self->Trusting		($init{"Trusting"});
		$self->log_full_line($init{"log_full_line"});
		
		$self->envelope_limit($init{"envelope_limit"});
		
		$self->From			($init{"From"}) 	or return undef;
		$self->To			($init{"To"}) 		or return undef;
		$self->Subject		($init{"Subject"}) 	or return undef;
		$self->Message		($init{"Message"})	if $init{"Message"};
		$self->merge		($init{"merge"});
		
		$self->dynamic			($init{"dynamic"});
		$self->dynamic_headers	($init{"dynamic_headers"});
			
		#smtp related
		$self->Smtp			($init{"Smtp"}) 		or return undef;
		$self->Port			($init{"Port"}) 		or return undef;
		$self->Tries		($init{"Tries"}) 		or return undef;
		$self->Precedence	($init{"Precedence"}) 	or return undef;
		$self->Domain		($init{"Domain"} or $init{"From"});
		
		$self->BMD($init{"BMD"});
		$self->DMD($init{"DMD"});
		$self->DMDE($init{"DMDE"});
		$self->DHD($init{"DHD"});
		$self->DHDE($init{"DHDE"});
		$self->HFM($init{"HFM"});
		
		#file related
		$self->LIST			($init{"LIST"})	 	if $init{"LIST"};
		$self->BAD			($init{"BAD"}) 		if $init{"BAD"};
		$self->GOOD			($init{"GOOD"}) 	if $init{"GOOD"};
		
		$self->lineterm		($init{"lineterm"});
		$self->safe_banned	($init{"safe_banned"});
		$self->allow_duplicates	($init{"allow_duplicates"});
		
		$self->use_envelope	($init{"use_envelope"});
	
		#initialize our duplicates hash.
		$self->duplicates({});
		
		#initialize our banned hash.
		$self->banned($init{"banned"} || {});
	
		#Initialize the additional headers hash.
		$self->[$headers] = {};
		
		#no cached domain
		$self->cached_domain("");
		
		#and remove those defaults
		delete @init{qw(ERRFILE Trusting log_full_line envelope_limit From To 
			Subject Message merge dynamic dynamic_headers Smtp Port Tries 
			Precedence Domain BMD DMD DMDE DHD DHDE HFM LIST BAD GOOD banned lineterm 
			safe_banned allow_duplicates use_envelope duplicates banned sort_list)
		};
		
		#is there anything left?  We're gonna assume that they're headers for simplicity's sake.
		#These things will get bounced down to header, in the accessor method section.

		foreach my $BULK_header (keys %init){
			$self->header($BULK_header,$init{$BULK_header});
		};	
	
		return 1;
	};



	{
		my $handle = 0;
		
		sub gen_handle {
			no strict 'refs';
			my $self = shift || undef;
			return \*{"Mail::BulkMail::Handle::HANDLE" . $handle++};	#You'll note that I don't want my 
																		#namespace polluted either
		};
	
	};
	
	
	sub getnextLine {
		my $self = shift || undef;
		my $file = shift or return $self->error("No file to getnextLine");
		if (ref $file eq "GLOB"){
			local $/ = $self->lineterm() || "\n";
			my $line = scalar <$file>;
			return undef unless $line;
			chomp $line;
			return $line;
		}
		elsif (ref $file eq "ARRAY"){
			return shift @$file;
		}
		elsif (ref $file eq "CODE"){
			return &$file;
		}
		else {
			return $self->error("I can't get the next line.  I don't know what a " .  ref $file . " is. ($file)");
		};
	};
	
	sub connect {
	
		my ($self) = shift || undef;	
		
		my $bulk = $self->gen_handle();
	
		my ($s_tries, $c_tries) = ($self->Tries, $self->Tries);
	
		1 while ($s_tries-- && ! socket($bulk, PF_INET, SOCK_STREAM, getprotobyname('tcp')));
		return $self->error("Socket error $!") if $s_tries < 0;
		
		my $paddr = sockaddr_in($self->Port, inet_aton($self->Smtp));
		
		1 while ! connect($bulk, $paddr) && $c_tries--;
		
		return $self->error("Connect error $!") if $c_tries < 0;
		
		#keep our bulk pipes piping hot.
		select((select($bulk), $| = 1)[0]);
		
		local $\ = "\015\012";
		local $/ = "\015\012";
		
		my $response = <$bulk> || "";
		return $self->error("No response from server: $response") if  ! $response || $response =~ /^[45]/;
		
		#We're either given a domain, or we'll build it based on who the message is from
		my $domain = $self->Domain;
		
		print $bulk "HELO $domain";
		
		$response = <$bulk> || "";
		return $self->error("Server won't say HELO: $response") if ! $response || $response =~ /^[45]/;
	
		$self->[$connected] = 1;
		#print "BULK : ($bulk)";
		$self->BULK($bulk);
		
		return 1;
	};
	
	sub disconnect {
		
		my $self = shift || undef;
		
		local $\ = "\015\012";
		local $/ = "\015\012";
		
		if ($self->BULK){
			my $handle = $self->BULK();
		
			print $handle "quit" or return $self->error("Cannot tell server I want to quit");
	
			close $handle or return $self->error("Cannot close connection to server: $!");
		};
		
		$self->[$connected] = 0;
		
		return 1;
		
	};
	

};

sub Tz {

	my $self = shift || undef;
	
	my ($min, $hour, $isdst) = (localtime(time))[1,2,-1];
	my ($gmin, $ghour, $gsdst) = (gmtime(time))[1,2, -1];
	
	my $diffhour = $hour - $ghour;
	$diffhour = 12 - $diffhour if $diffhour > 12;
	$diffhour = 12 + $diffhour if $diffhour < -12;
	
	($diffhour = sprintf("%03d", $hour - $ghour)) =~ s/^0/\+/;

	return $diffhour . sprintf("%02d", $min - $gmin);

};

sub Date {

	my $self 	= shift || undef;
	
	my @months 	= qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	my @days 	= qw(Sun Mon Tue Wed Thu Fri Sat);
	
	my ($sec, $min, $hour, $mday, $mon, $year, $wday) = localtime(time);
		
	return sprintf("%s, %02d %s %04d %02d:%02d:%02d %05s",
		$days[$wday], $mday, $months[$mon], $year + 1900, $hour, $min, $sec, $self->Tz);
	
	
};

sub lc_domain {

	#lowercase the domain part, but _not_ the local part.  Why not?
	#Read the specs, you can't make assumptions about the local part, it is case sensitive
	#even though 99.999% of the net treats it as insensitive.

	my $self = shift || undef;

	my $email = shift || undef;
	
	if ($email =~ /@/){
		my ($local, $domain) = split(/@/, $email);
		$email = "$local@" . lc $domain;
	};
	
	return $email;
	
};


# Why not use Email::Valid here? - Jamie
# Because I don't have the time or inclination to test it, as long as
# it is working.  if it barfs again, i will.  or someone else can.  -- pudge
sub valid_email {
	
	my $self = shift || undef;
	my $email = shift || undef;
	
	return $email if $email =~ /^Postmaster$/i;
	
	my $atom = q<[!#$%&'*+\-/=?^`{|}~\w]>;
	my $qstring = q/"(?:[^"\\\\\015]|\\\.)+"/;
	my $word = "($atom+|$qstring)";

	$email = $self->comment_killer($email);				#No one else handles comments, to my knowledge. Cool, huh?  :)

	$email =~ m/^$word\s*\<\s*(.+)\s*\>\s*$/;			#match beginning phrases
	
	$email = $2 if $2;									#if we've got a phrase, we've extracted the e-mail address
														#and stuck it in $2, so set $email to it.
														#if we didn't have a phrase, the whole thing is the e-mail address
	return $email if $self->Trusting;
	
	return $1 if $email =~ m<
							^\s*($word					#any word (see above)
							(?:\.$word)*				#optionally followed by a dot, and more words, as many times as we'd like
							@							#and an at symbol
							$atom+						#followed by as many atoms as we want
							(?:\.$atom+)*				#optionally followed by a dot, and more atoms, as many times as we'd like
							\.[a-zA-Z]{2,})\s*$		#followed by at least 2 letters
							>xo;						
};

sub comment_killer {
	
	my $self  = shift || undef;
	my $email = shift || undef;
	
	while ($email =~ /\((?:[^()\\\015]|\\.)*\)/){$email =~ s/\((?:[^()\\\015]|\\.)*\)//};

	return $email;
};
#/validation

sub build_merge_line {
	my $self = shift || undef;
	my $line = shift || undef;
	my $delim = shift || undef;
	
	my @line = ();
	
	unless (ref $line){
		return [split(/$delim/, $line)];
	}
	elsif (ref $line eq "CODE"){
		my $array_ref = &$line;
		return $array_ref if (ref $array_ref) =~ /ARRAY|HASH/ ;
		return $self->error("Code reference returned non-array ref value (" . ref($array_ref) . ")");
	}
	elsif (ref $line eq "ARRAY" || ref $line eq "HASH"){
		return $line;
	}
	else {
		return $self->error("Cannot build merge array.  I don't know what a " . ref($line) .  " is. ($line)");
	};

};

sub build_merge_hash {
	my $self = shift || undef;
	my $line = shift || undef;
	my $local_merge = shift || undef;
	
	my $merge = undef;
	
	if (defined $self->merge->{"BULK_MAILMERGE"}){
		{
			my %temp_hash = %{$self->merge};	#deref the global hash, and the store a reference to it.  Why?  So we don't
			$merge = \%temp_hash;				#manipulate the global hash by mistake.
		};

		#print FILE "BUILDING MERGE REFS: $merge, ", $self->merge(), "\n";
		return $self->error("Cannot use BULK_MAILMERGE with envelope sending") if $self->use_envelope && !$self->Trusting;
	
		my $keys   = $self->build_merge_line($self->merge->{"BULK_MAILMERGE"}, $self->BMD) or return undef;
		my $values = $self->build_merge_line($line, $self->BMD) or return undef;
		#print "****VALUES:(@$values)\n";
		
		return $self->error("BULK_MAILMERGE must be same type as line (" . ref($keys) .  " is not " . ref($values) .  ")") unless ref $keys eq ref $values;
		
		unless (ref $values eq "HASH" || ref $keys eq "HASH"){
			@{%$merge}{@$keys} = @$values;
		}
		else {@$merge->{keys %$values} = @$merge->{keys %$values}};
		
		if (defined $merge->{"DYNAMIC_MESSAGE"}){
			my $values = $self->build_merge_line($merge->{"DYNAMIC_MESSAGE"}, $self->DMD) or return undef;
			
			if (ref $values eq "HASH"){
				$merge->{"DYNAMIC_MESSAGE"} = $values;
			}
			else {
				my %temp_hash = ();
				my $delim = $self->DMDE;
				foreach my $dynamic (@$values){
					my ($key, $value) = split(/$delim/, $dynamic);
					$temp_hash{$key} = $self->dynamic->{$key}->{$value} or return $self->error("Dynamic key ($key, $value) not defined");
				};
				$merge->{"DYNAMIC_MESSAGE"} = \%temp_hash;
			};
		};
		
		if (defined $merge->{"DYNAMIC_HEADERS"}){
			my $values = $self->build_merge_line($merge->{"DYNAMIC_HEADERS"}, $self->DHD) or return undef;
			if (ref $values eq "HASH"){
				$merge->{"DYNAMIC_HEADERS"} = $values;
			}
			else {
				my %temp_hash = ();
				my $delim = $self->DHDE;
				foreach my $dynamic (@$values){
					my ($key, $value) = split(/$delim/, $dynamic);
					$temp_hash{$key} = $self->dynamic_headers->{$key}->{$value} or return $self->error("Dynamic header key ($key, $value) not defined");
				};
				$merge->{"DYNAMIC_HEADERS"} = \%temp_hash;
			};
		};	
	}
	else {$merge->{"BULK_EMAIL"} = $line};
	
	
	if (defined $local_merge){
		my $merge ||= \%{$self->merge};	#See comment above

		my $local_hash_ref = undef;
		if (ref $local_merge eq "CODE"){
			$local_hash_ref = &$local_merge;
			return $self->error("Code reference returned non-hash ref value") unless ref $local_hash_ref eq "HASH";
		}
		elsif (ref $local_merge eq "HASH"){
			$local_hash_ref = $local_merge;
		}
		else {
			return $self->error("Local merges must be either hash refs or code refs.  I don't understand what a " . ref($local_merge) .  " is.");
		};
		
		@$merge{keys %{$local_hash_ref}} = values %{$local_hash_ref};
	};
	
	if (defined $merge){
		$merge->{"BULK_LINE"} = $line;
		return $merge;
	}
	else {return $self->merge};
	
};

sub validate_address {
	my $self = shift || undef;
	my $merge = shift;
	
	my $email = ref $merge eq 'HASH' ? $merge->{"BULK_EMAIL"} : $merge;
	#print "REF MERGE: $merge\n";
	#print "LINE     : ", $merge->{"BULK_LINE"}, "\n";
	#print "ALLOWED  : ", $self->log_full_line, "\n"; 
	my $line = $self->log_full_line ?
					ref $merge eq 'HASH' 
						? $merge->{"BULK_LINE"} 
						: $email 
					: $email;
	
	#no point in continuing if the email is invalid, a duplicate, or banned
	unless ($self->valid_email($email)){
		$self->log_it($line, $self->BAD) if $self->BAD;
		return $self->error("Invalid address: $email");
	};
	
	if ($self->isDuplicate($email)){
		return $self->error("Duplicate address: $email");
	};

	if ($self->isBanned($email)){
		$self->log_it($line, $self->BAD) if $self->BAD;
		return $self->error("Banned address: $email") if $self->isBanned($email);
	};	
	
	return 1;
};


sub mail {
	my $self = shift || undef;
	my $line = shift || undef;
	my $local_merge = shift || undef;
	
	my $merge = $self->build_merge_hash($line, $local_merge) or return undef;
	
	return undef unless $self->validate_address($merge or $line);

	$self->build_envelope($merge)			|| return $self->error("Cannot build envelope: " 			. $self->error);
	$self->send_to_envelope($merge) 		|| return $self->error("Cannot build 'to' in envelope: " 	. $self->error);
	$self->send_message_data($merge)		|| return $self->error("Cannot transmit data: "  			. $self->error);
	return 1;
};


sub bulkmail {

	my $self = shift || undef;
	my $local_merge = shift || undef;
	
	my $last_merge = undef;

	while (defined (my $line = $self->getnextLine($self->LIST))){
		chomp $line unless ref $line;
		#print "LINE: $line\n";

		$line =~ s/(?:^\s+|\s+$)//g unless ref $line;	#trash trailing and leading white space
		#print "LINE: $line(", ref $line, ")\n";
		
		my $merge = $self->build_merge_hash($line, $local_merge) or return undef;

		#no point in continuing if the email is invalid, a duplicate, or banned
		next unless $self->validate_address($merge or $line);

		my $email = $merge->{"BULK_EMAIL"} || $line;
					
		#open FILE, ">>file.txt";
		if ($self->use_envelope){
			
			my $domain = lc $email;
			$domain =~ s/^.*@//;
			#print "USING THE ENVELOPE\n";
			if ($domain ne $self->cached_domain || $self->envelope_limit) {
			#print "NOT A CACHED DOMAIN\n ($domain)::(", $self->cached_domain, ")\n";
				$self->cached_domain($domain) 				or return undef; 
			
				if ($self->waiting_message){
					#print "	MESSAGE WAITING...SENDING DATA\n";
					$self->send_message_data($merge); 		#or return undef;
					$self->waiting_message(0);
					#print "	MESSAGE WAITING...SENT DATA\n";
				};
				#print "	BUILDING ENVELOPE\n";
				$self->build_envelope($merge) or next;
				#print "	BUILT ENVELOPE\n";
				#print "	SENDING ENVELOPE\n";
				#$self->waiting_message(1);
				if ($self->send_to_envelope($merge) || $self->waiting_message){
					#print "I shall make a WAITING: message\n";
					$self->waiting_message(1);
					$self->log_it($self->log_full_line 
						? $merge->{"BULK_LINE"} 
						: $merge->{"BULK_EMAIL"}, $self->GOOD
					);
				}
				else {
					#print "I shall unmake a WAITING: message\n";
					$self->waiting_message(0);
				}; 			#or return undef;
				#print "WAITING: ", $self->waiting_message(), "\n";
				#print "	SENT ENVELOPE\n";

			}
			else {
				#print "IT'S A CACHED DOMAIN\n";
				unless ($self->waiting_message){
					#print "	BUILDING THE ENVELOPE\n";
					$self->build_envelope($merge) or next;
					#print "	BUILT THE ENVELOPE\n";
				};
				#print "	SENDING THE 'TO' ENVELOPE\n";
				#$self->waiting_message(1);
				if ($self->send_to_envelope($merge) || $self->waiting_message){
					#print "I shall make a WAITING: message\n";
					$self->waiting_message(1);
					
					$self->log_it($self->log_full_line 
						? $merge->{"BULK_LINE"} 
						: $merge->{"BULK_EMAIL"}, $self->GOOD
					);
				}
				else {
					#print "I shall unmake a WAITING: message\n";
					$self->waiting_message(0)
				}; 			#or return undef;
				#print "WAITING: ", $self->waiting_message(), "\n";
				#print "	SENT THE 'TO' ENVELOPE THAT's CACHED\n";
			};
		}
		else {
			#print "NO ENVELOPE...MAILING ($line)\n";
			$self->mail($line, $merge); 						#or return undef;
			#print "NO ENVELOPE...MAILED ($line)\n";
		};
		
		$last_merge = $merge;
	};
	if ($self->waiting_message){
		#print "A MESSAGE IS WAITING\n";
		#print "LAST MERGE: $last_merge\n";
		#print "\n\n======================================================\n\n";
		$self->send_message_data($last_merge); 			#or return undef;
		$self->waiting_message(0);
	};

	return 1;

};

sub buildMessage {
	
	#Dynamically generate the message and headers, mail merge, double periods, etc.
	
	my $self = shift || undef;
	my $merge = shift || undef;

	return $self->cached_message if $self->cached_message;

	my $message = $self->Message;
	#print "BUILDING MESSAGE\n";
	#return \$message if $self->cached_message;
	#print "NON CACHED MESSAGE\n";
	
	#not sure if I want to alter the pre-set headers...
	my %he = %{$self->header};
	my $headers = \%he;
	
	$message =~ s/(?:\r\n?|\r?\n)/\015\012/g;
	
	if ($self->HFM){
		my $header_string = undef;
		($header_string, $message) = split(/\015\012\015\012/, $message, 2);

		my $last_header = undef;
		foreach (split/\015\012/, $header_string){
			if (/:/){
				my ($header, $value) = split(/\s*:\s*/);
				$headers->{$header} = $value;
				$last_header = $header;
			}
			elsif (/^\s+/){
				$headers->{$last_header} .= "\015\012$_";
			}
			else {
				return $self->error("Invalid Headers from Message: line ($_)\n\n-->($header_string)");
			};
		};
				
		#$header_string =~ s/\015\012\s+([^:]+?)\015\012/$1\015\012/g;
		#$headers = {split(/\s*:\s*|\015\012/, $header_string)};
	};
	
	$headers->{"From"} 			||= $self->From;
	$headers->{"To"}   			||= $self->use_envelope ? $self->To : $merge->{"BULK_EMAIL"};
	$headers->{"Subject"} 		||= $self->Subject;
	$headers->{"Precedence"} 	||= $self->Precedence;

	@$headers{keys %{$merge->{"DYNAMIC_HEADERS"}}} = values %{$merge->{"DYNAMIC_HEADERS"}};

	return $self->error("Cannot send with undefined 'to' address:  (" 	. $headers->{"To"} . ")") 			if $self->use_envelope && ! defined $headers->{"To"};

	#build the headers
	my $message_header = "Date: " . $self->Date . "\015\012";
	foreach my $header (qw(From Subject To Precedence)){
		unless (defined $headers->{$header}){
			delete $headers->{$header};
			next;
		};
		#print "HEADER: $header\n";
		$message_header .= "$header: " . $self->scalar_or_code($headers->{$header}) . "\015\012";
		delete $headers->{$header} if defined $headers->{$header};
	};
	
	foreach my $header (sort keys %{$headers}){
		#print "HEADER: $header\n";
		$message_header .= "$header: " . $self->scalar_or_code($headers->{$header}) . "\015\012";
	};
	
	delete $merge->{"DYNAMIC_HEADERS"} if defined $merge->{"DYNAMIC_HEADERS"};
	
	#set the content-type to html, if appropriate.
	$message_header .= "Content-type: text/html\015\012" if $self->HTML;
	
	$message_header .= "X-Bulkmail: $Slash::Custom::Bulkmail::VERSION\015\012";
	
	$message_header .= "\015\012";
	#/build the headers
	
	unless ($self->use_envelope){
		foreach (keys %{$merge->{"DYNAMIC_MESSAGE"}}){
			my $dynamic_value = $self->merge->{"DYNAMIC_MESSAGE"}->{$_};
			$message =~ s/$_/$self->scalar_or_code($dynamic_value)/ge;
		};
		delete $merge->{"DYNAMIC_MESSAGE"} if defined $merge->{"DYNAMIC_MESSAGE"};
	};
	
	$message =~ s/^\./../gm;

	$message_header .= $message;
	#print map {"MERGE KEY: $_, ". $merge->{$_}. "\n"} keys %$merge;
	
	foreach my $item (keys %$merge){
		next if $self->use_envelope && $item eq "BULK_EMAIL";
		#next unless defined $merge->{$item};
		my $val = defined $merge->{$item} ? $merge->{$item} :  "";
		$message_header =~ s/$item/$self->scalar_or_code($val)/ge;
	};
	#print FILE "MERGE REFS: $merge, ", $self->merge, "\n";
	#print "\n-----\nHEADER: $message_header\n-----\n";
	$self->cached_message(\$message_header) if $self->use_envelope || $merge eq $self->merge; 
													#no point re-building the message each time if we're using the envelope
													#or if the merge hash we're building from is the global one



	return \$message_header;	#actually, message_header + message
};

sub scalar_or_code {
	my $self = shift || undef;
	my $thing = shift || "";
	my $temp = ref $thing eq "CODE" ? $thing->() : $thing;
	$temp =~ s/(?:\r\n?|\r?\n)/\015\012/g;
	return $temp;
};

sub build_envelope {
	my $self  = shift || undef;
	my $email = shift || undef;
#print map {"EMAIL HASH KEYS: ($_): " . $email->{$_} . "\n"} keys %$email;
	$email = ref $email eq "HASH" ? $email->{"BULK_EMAIL"} : $email;
#print "CONNECTING\n";

	$self->connect unless $self->connected;
	return undef unless $self->connected;
	#print "CONNECTED\n";

	local $\ = "\015\012";
	local $/ = "\015\012";

	my $bulk = $self->BULK();
	#First thing we're gonna do is reset it in case there's any garbage sitting there.

	print $bulk "RSET";
	#print "-->RSET";

	my $response = <$bulk> || "";

	return $self->error("Cannot reset connection: $response") if ! $response || $response =~ /^[45]/;
	if ($response =~ /^221/){
		$self->disconnect();
		return $self->error("Server disconnected: $response");
	};
	
	#Who's the message from?
	print $bulk "MAIL FROM:<", $self->From, ">";
	$response = <$bulk> || "";
	return $self->error("Invalid Sender: $response <" . $self->From() . ">") if ! $response || $response =~ /^[45]/;
	if ($response =~ /^221/){
		$self->disconnect(); 
		return $self->error("Server disconnected: $response");
	};
	
	return 1;		 
	
};

sub send_to_envelope {
	my $self = shift || undef;
	my $email = shift || undef;
	
	return $self->error("Not connected!  Cannot send 'to' envelope part") unless $self->connected;
	
	$email = ref $email eq "HASH" ? $self->valid_email($email->{"BULK_EMAIL"}) : $self->valid_email($email);
		
	$self->setDuplicate($email);
	#print "\n----\nTO:$email\n----\n";
	local $\ = "\015\012";
	local $/ = "\015\012";
	
	my $bulk = $self->BULK();
	
	#Who's the message to?
	#print "SENDING THE TO ENVELOPE TO: (($email))\n";
	print $bulk "RCPT TO:<", $email, ">";
	my $response = <$bulk> || "";
	return $self->error("Invalid Recipient: $response <$email>") if ! $response || $response =~ /^[45]/;
	if ($response =~ /^221/){
		$self->disconnect();
		return $self->error("Server disconnected: $response");
	};
	
	return 1;
};

sub send_message_data {
	my $self = shift || undef;
	my $merge = shift || undef;
	
	return $self->error("Not connected!  Cannot send 'to' envelope part") unless $self->connected;
	#print "HERE IS MY MERGE FOR SENDING MESSAGE DATA: $merge\n";
	#print map {":::::MERGE MAP: $_, ". $merge->{$_} . "\n"} keys %$merge;
	#print "MESSAGE: ", $self->Message, "\n";
	my $message = $self->buildMessage($merge);
	#print "MESSAGE: $message\n";
	#print "CACHED: " , $self->cached_message, "\n";
	local $\ = "\015\012";
	local $/ = "\015\012";
	
	my $bulk = $self->BULK;
	
	#Let the server know we're gonna start sending data
	print $bulk "DATA";
	my $response = <$bulk> || "";
	return $self->error("Not ready to accept data: $response") if ! $response || $response =~ /^[45]/;
	if ($response =~ /^221/){
		$self->disconnect(); 
		return $self->error("Server disconnected: $response");
	};		
#print "MESSAGE:::((($$message)))\n";
	print $bulk $$message;
	
	print $bulk ".";
	
	$response = <$bulk> || "";
	return $self->error("Message not accepted for delivery: $response") if ! $response || $response =~ /^[45]/;
	if ($response =~ /^221/){
		$self->disconnect();
		return $self->error("Server disconnected: $response");
	};
#print "MESSAGE::::SENT DATA\n";
	$self->log_it($self->log_full_line ? $merge->{"BULK_LINE"} : $merge->{"BULK_EMAIL"}, $self->GOOD) if $self->GOOD && ! $self->use_envelope;

	$message = undef;
	$merge = undef;

	return 1;

};

1;

__END__

=pod

=head1 NAME

Slash::Custom::Bulkmail 2.051 - Platform independent mailing list module

=head1 AUTHOR

Jim Thomason thomasoniii@yahoo.com

=head1 SYNOPSIS

 $bulk = Slash::Custom::Bulkmail->new(
           "LIST" => "/home/jim3.list",
           "From" => 'thomasoniii@yahoo.com',
        "Subject" => 'This is a test message!',
        "Message" => "Here is the text of my message!"
 );

 $bulk->bulkmail;

Be sure to set your default variables in the module, or set them
in each bulk mail object.  Otherwise, you'll be using the defaults.

=head1 DESCRIPTION

B<NOTE: Slash::Custom::Bulkmail is just a custom version of Mail::Bulkmail.
Some minor variations have been made from Mail::Bulkmail 2.05, and
those changes have been supplied back to the author.  Please fetch and
see the Mail::Bulkmail distribution for more information>.

Mail::Bulkmail gives a fairly complete set of tools for managing
mass-mailing lists.  I wrote it because our existing tools were just
too damn slow for mailing out to thousands of recipients.

2.00 is a major major B<major> upgrade to the previous version (1.11).
I literally threw out all of the code from 1.00 and started over.  Well,
almost all of it, I'm really content with the email validation, so I kept
that.  :)

Everything else is brand spanking new.  All of the bugs from the 1.x releases should
be gone (ever try allowing duplicates?  Good.).  And, of course, a bunch of new toys
have been added in.

The two major additions to v2 are the ability to send via envelope and support for dynamic
messaging.  Sending via the envelope allows you to potentially transfer your email I<much>
faster (I've been estimating a 900% speed increase vs. non-envelope sending in 1.11).  Dynamic
messaging allows you to actually construct the message that you're sending out on the fly.
Specify which components of a message you want to include, and Bulkmail will generate the message
for you.  So every person on your list could potentially receive a different message, if you wanted.

Dynamic messaging is a few steps above a simple mail merge.  While you could accomplish the same
effect using a simple mail merge it wouldn't be pretty.  You'd have to duplicate each component
of the message for each person on the list.

Further changes are listed in the version history and FAQ sections below, I just wanted to mention
the big guns up front.

=head1 REQUIRES

Perl5.004, Socket

=head1 OBJECT METHODS

=head2 CREATION

New Mail::Bulkmail objects are created with the new() constructor.  For a minimalist 
creation, do this:

$bulk = Mail::Bulkmail->new();

You can also initialize values at creation time, such as:

 $bulk = Mail::Bulkmail->new(
            From => 'thomasoniii@yahoo.com',
            Smtp => 'some.smtp.com'
 );

When Bulkmail objects are destroyed, they automatically disconnect from the server they're connected to
if they're still connected.

=item add_attr

Mail::Bulkmail is much easier to subclass now (I hope).  I like using arrays for my objects instead of hashes.
Perhaps one day I'll switch to pseudo-hashes, but not yet.

Until that time, you need to allocate new space in the array for your new attributes if you want to subclass
the thing.  But how do you do that nicely?  Push onto the blessed arrayref?  Too messy, and you can't do the
nice trick of setting up a variable with the value of the place in the array.  Besides, if I do switch away from
arrays this'll break.  So use add_attr to tack it onto the end of the object.

package Mail::Bulkmail::My_version;

@ISA = qw(Mail::Bulkmail);

 my $new_attribute = Mail::Bulkmail->add_attr();


 $my_bulk_object->[$new_attribute] = "my value";


=head2 BUILT IN ACCESSORS

Okay, here's where the fun stuff beings.  Since these are objects, the important stuff is how
you access your data.

Object methods work as you probably expect.

$bulk->property

  Will return the value of "property" in $bulk

$bulk->property("new value")

Will set the value of "property" in $bulk to "new value" and return "new value".
The property may not be set if $bulk->Trusting has a false value and the property has a
validation check on it.  See Validated Accessors, below.

All accessor methods are case sensitive.  Be careful!

Here are all of the accessors that come built in to your Mail::Bulkmail objects.

=over 11

=item From

The e-mail address this list is coming from.  This can be either a simple e-mail address 
(thomasoniii@yahoo.com), or a name + e-mail address ("Jim Thomason"<thomasoniii@yahoo.com>).  This is checked
to make sure it's a valid email address unless you have Trusting turned on (see below).

I<v1.x equivalent>:  From 

=item Subject

The subject of the e-mail message.  If it's not set, you'll use the default.

I<v1.x equivalent>:  Subject

=item Message

This is the actual text that will appear in the message body.  You can also specify control fields
to allow your message to be dynamically individually built on the fly, as well as do a mail merge
to personalize your email to each recipient

I<v1.x equivalent>:  Message

=item merge

This is where you define a mail merge for your message.  See the section MERGING below.

A merge is defined with a hashref as follows:

 $bulk->merge(
    "Date"    => "June 22nd",
    "Company" => "Foofram Industries"
 );

I<v1.x equivalent>:  Map

=item Smtp

This sets the SMTP server that you're going to connect to.  You'll probably just want to
use whatever you've set as your default SMTP server in the module.  You did set your default SMTP 
server when you double-checked all the other defaults, right?

I<v1.x equivalent>:  Smtp

=item Port

This sets the port on which to connect to your SMTP server.  You'll probably just want to use
25 (the default).

I<v1.x equivalent>:  Port


=item Tries

This sets the number of times that you will attempt to connect to a server.  You'll probably
just want to use the default.

I<v1.x equivalent>:  Tries

=item Precedence

This sets the precedence of the e-mail message.  This is validated unless you turn off
validation by making your object Trusting.  Default precedence is "list", although you can
set a precedence of either "bulk" (bulk, usually unsolicited mail) or "junk" (totally worthless
message)

I<v1.x equivalent>:  Precedence

=item Domain

You're going to be saying HELO to an SMTP server, you'd better be willing to give it a domain
as well.  You can explicitly set the Domain here, or choose not to.  If no Domain is set, the domain
of the From e-mail address will be used instead.  It doesn't do you any good to set Domain after
you've connected to a server.

I<v1.x equivalent>:  Domain

=item HTML

People can be dopes.  It's very very easy to send out mass HTML email with Mail::Bulkmail, just set
a content-type:

 $bulk->header("Content-type", "text/html");

But most people don't seem to know that, so I've added the HTML accessor.  Give it true value to send
out HTML mail, a false value to send out plaintext.  It's false by default.

=item use_envelope

use_envelope is like lasing a stick of dynamite.  Mail::Bulkmail is fast.  Mail::Bulkmail with use_envelope
is ungodly incredibly unbelievably fast.

For the uninformed, an email message contains two parts, the message itself and the envelope.   Mail servers only
care about the envelope (for the most part), since that's where they find out who the message is to and from, and
they don't really need to know anything else.

A nifty feature of the envelope is that you can submit multiple addresses within the envelope, and then your
mail server will automagically send along the message to everyone contained within the envelope.  You end up
sending a hell of a lot less data across your connection, your SMTP server has less work to do, and everything
ends up working out wonderfully.

There are two catches.  First of all, with envelope sending turned off, the recipient will have their own email
address in the "To" field (To: thomasoniii@yahoo.com, fer instance).  With the envelope on, the recipient will only
receive a generic email address ("To: list@myserver.com", fer instance)  Most people don't care since that's
how most email lists work, but you should be aware of it.

Secondly, you B<MUST> and I mean B<MUST> sort your list by domain.  Envelopes can only be bundled up by domain,
so that we send all email to a domain in one burst, all of the email to another domain in the next burst, and so
on.  So you need to have all of your domains clustered together in your list.  If you don't, your list will still
go out, but it will be a I<lot> slower, since Mail::Bulkmail has a fair amount more processing to do when you send
with then envelope.  This is normally more than offset by the gains received from sending fewer messages.  But with
an unsorted list, you never see the big gains and you see a major slow down.  Sort your lists. 

=item envelope_limit

It's entirely likely that with a very large list you'll have a very large number of people in the
same domain.  For instance, there are an awful lot of people that have yahoo addresses.  So, for example,
say that you have a list of 100,000 people and 20,000 of them are in the foobar.com domain and you're sending
using the envelope.  That means that the server at foobar.com is going to receive one message with 20,000
people in the envelope!

Now, this might be a bad thing.  We don't know if the foobar.com mail server will actually process a message
with 20,000 envelope recipients.  It may or may not and the only way to find out is to try it.  If it does work,
then great no worries, but if it doesn't, then you're stuck.  If you stop using envelope sending, you sacrifice
its major speed gains, but if you keep using it you can't send to foobar.com.

I<envelope_limit> fixes that.

envelope_limit is precisely what it sounds like, it allows you to specify a limit on the number of recipients
that will be specified in your envelope.  That way, with our previous example, you can specify an envelope limit of
1000, for example.

 $bulk->envelope_limit(1000);

This means that foobar.com will get 20 messages, each with 1000 recipients in the envelope.  Of course, this still
may not be small enough, so you can tweak it as much as necessary.

Setting an envelope limit does trade off some of the gains from using the envelope, but it's still over all
a vast speed boost over not using it.

envelope_limit is set to 0 (zero) by default, meaning that there is no limit specified. 

=item LIST

IO is a lot smarter in v2.0.  In Bulkmail 1.x, the various IO methods (LIST, BAD, etc.) had to be
globs to file handles, which was rather restrictive.

In 2.0, you have four options for how you want to import your list, a string, or a reference to either
an array, a glob, or a function.

If you have a flat text file, you can use it by simply passing a string containing the path to the file:

 $bulk->LIST("/home/jim3/list.txt");

And Bulkmail will open the file and manage it internally, so you don't need to worry about polluting
your namespace with filehandles the way you did with 1.x.

Of course, if you I<want> to pollute your namespace, then feel free to.

 open (LIST, "/home/jim3/list.txt");
 $bulk->LIST(\*LIST);

Just note that you now have to pass a reference to the glob, I<not> the glob itself as you did in 1.x.

Flat file lists will read in one entry per line, where a line is determined by whatever value you've
set with lineterm().

Alternatively, you can pass a ref to an array for your list.

my @list = ('thomasoniii@yahoo.com', 'someguy@somewhere.com', 'invalid_@address');

$bulk->LIST(\@list);

#or, with an anonymous array

$bulk->LIST(['thomasoniii@yahoo.com', 'someguy@somewhere.com', 'invalid_@address']);

You probably don't want to use arrays for your lists unless you're doing small tests.  Otherwise, you'll
read your whole list into memory in advance, which is probably not what you wanted to do.

Arrays as lists will return the values in order from the front to the end of the array.

Probably the most powerful method to build your list is to pass a ref to a function.

 {
  my @list = ('thomasoniii@yahoo.com', 'someguy@somewhere.com', 'invalid_@address');

  sub some_function {return shift @list};
 };

 $bulk->LIST(\&some_function);

Of course, in this case it's wasteful to actually pass a function reference instead of just an array ref
to @list, but it serves as a good example.

By passing function refs around, you can extract your list directly from a database if you want.

 my $dbh = DBI->connect();
 my $sth = $dbh->prepare("SELECT name, email FROM MAIL_LIST");
 $sth->execute;

 sub mail_list {return $sth->fetch_row_array};

 $bulk->LIST(\&mail_list);

No more having to export your list to a flat file first.

You can't just pass a ref to $sth->fetch_row_array because it doesn't work that way.  \&{$sth->fetchrow_array}
returns a coderef to a hash containing the return value, which ain't what you want.  &$sth...doesn't work and
so on.  If anyone *does* know a way to do it directly, please do let me know.  :)

The values are returned in whatever order your function returns them in.  Be sure to return undef when you're
done, otherwise Bulkmail won't know when you've finished.

Each of these methods returns "lines" of entries in your mailing list.  So what the hell's a line?  An email
address?  A delimited string?  A code ref?  Actually, it's anything you want.  :)  See the section on MERGING
below.

I<v1.x equivalent>:  LIST

=item BAD

This is an optional item which specifies a place to log bad addresses (invalid, banned, etc.).  Just like LIST
above, in v1.x it had to be a glob to a file handle, but not so any more!

You have the same four options that you did for list, a string, a ref to a glob, a ref to a function, and a ref
to an array.

The string will cause a file to be opened for appending (">>").  The ref to a glob is a file that you already
have open for appending (or simply for writing).

If you pass a ref to an array, any items will be pushed onto the array as they're encountered.

If you pass a ref to a function, then the function will be called with a single argument of whatever it is
that was going to be logged.

For example, if ".thomasoniii@yahoo.com" is encountered (a bad address!), any of the following would end up happening,
depending upon what "BAD" is:

 print BAD ".jim3@ psynet.net", $bulk->lineterm(); #BAD is a file
 push @BAD, ".jim3@ psynet.net";                   #BAD is an array
 &BAD(".jim3@ psynet.net");                        #BAD is a function

I<v1.x equivalent>:  BAD

=item GOOD

This is an optional item which specifies a place to log good addresses (anything not invalid or banned).  That
way, you'll have a list at the end of all of your good addresses with the bad ones weeded out.

There is one issue with the GOOD list, when using the envelope.  You're not guaranteed that everything
in the good list actually went through, unlike when not using the envelope.  When not using the envelope,
a message is logged as being good as soon as it's completely transmitted to the server.  When using the envelope,
however, a message is logged as being good as soon as the attempt is made to transmit it to the server.  As long
as the message is accepted and delivered, everything is fine.  But if the message isn't accepted (if you specified
too many people in the envelope, for instance), you'll log everyone else in the envelope as being good
even though they weren't actually sent to.

This is a terribly irritating bug to me, but I haven't thought of a clever way to handle it perfectly without
caching those recipients elsewhere, which I'd rather not do since it's messy.  Ho hum.  Let me know if you
have a clever solution.

You have the same options as with BAD, above.

I<v1.x equivalent>:  GOOD

=item ERRFILE

This is an optional item which specifies a place to log any and all errors that occur while running.  It is recommended
that you run with this option on, so it's easier to see if anything bad is happening.

I<v1.x equivalent>:  ERROR

=item log_full_line

It occurred to me that log_it was only logging the email address of a person.  So if you encounter
a bad address of, say 'thomasoniii@yahoo', it will log 'thomasoniii@yahoo'.  No problems, right?  But
what if you're using a mailmerge?  Then things can get tricky.  If your line is, for example, 

 #BULK_MAILMERGE is BULK_EMAIL::NAME::TITLE
 thomasoniii@yahoo::Jim::Perl Bulkmail Guru

you would only log (in the bad file):

 thomasoniii@yahoo

This may or may not be what you want.  As of v2.04, you have the option of choosing to log the full
"line" of information.  With log_full_line set to true, this would be in the BAD file:

 thomasoniii@yahoo.com::Jim::Perl Bulkmail Guru

Which may come in handy for you, or it may not.  But you at least have the option of doing it.  Why did
I add this feature?  I was running a list that was extracting information via a SQL query and pulling
out several pieces of information.  After the message was sent, I neede to perform another query to update
that information in the table.  Easily done by setting GOOD to a function reference, but that GOOD was only
receiving the email address back from bulkmail, not the full line of info.  That meant that I had to cache
the other data in a seperate hash table and then come back to it later.  Most inelegent. This is much better.  :)

There are a couple of "gotchas" when it comes to log_full_line that I haven't quite ironed out to my
satisfaction yet.  If you have ideas about better ways to handle them, please let me know.

First of all, remember that when logging a full line, you get back exactly what you put in as your "line"
(recalling that "lines" can be strings, hashes, arrays, codes, etc.)  So if your "line" of information is
an array (ref), then you'll log that array ref.  Mail::Bulkmail tries to guess about a smart way to log
the item if it's logging to a text file.  Arrays will be de-referenced and delimited by whatever ->BMD is.
Hashes will be squashed into their values and delimited by ->BMD.  The keys won't be stored.  Any other reference
will give you an error, and then happily log the reference which is probably useless.  Delimited strings
are logged unchanged.

But this guessing at de-referencing is only done for files.  If you're logging to a function or an 
array, you're expected to know how to de-reference it yourself.  It'll just be a minor code tweak, don't worry.
Just be sure to remember it.

log_full_line is set to false by default, but I may set it to true by default in a long-in-the-future release
(think v2.5 or higher). 

I<No v1.x equivalent>

=item banned

I<banned> will allows you to provide a list of banned email addresses or domains.  These are people that
you never B<ever> want to send email to under any circumstances.  People that email you and say "Remove me
from your mailing list and never email me again!" will go in this category.

A banned list can be built the same way as GOOD, BAD, LIST, etc., with an array, a filehandle, a function, or
a string containing a filename.  Banned entries are one per line.

 thomasoniii@yahoo.com
 yahoo.com

would ban email from thomasoniii@yahoo.com, and anyone within the yahoo.com domain.  Please note that domains will only
be banned upwards, not downwards.  So with an entry like this:

 yahoo.com
 mail.msn.com

your list will be blocked from going to yahoo.com, and mail.msn.com.  It will also be blocked from mail.yahoo.com
(contains yahoo.com), but not from webserver.msn.com (webserver.msn.com does not contain mail.msn.com).

You can also construct a banned list using a hashref, though it must be precisely constructed or you'll shoot
yourself in the foot bigtime.  Fortunately, the format is simple.

 $banned{lowercase email address} = email address.

Mail::Bulkmail needs its banned information in this format to function correctly.  Consequently, if you give
it a non-hashref value (array, glob, etc.) it will construct this hash internally.  So if you have a large
number of banned addresses, you'll probably want to put them in a dbm file and hand in a ref to it, so as not
to store everything in memory.

Why the funky hash format?  One of the screwball, IMHO, things about the email specification is that the domain
part of an email address is case insensitive, but the local part is case sensitive.  This means that 

 thomasoniii@yahoo.com
 ThomasonIII@yahoo.com
 tHOMaSoNIii@yahoo.com

all could be different addresses.  So, in theory, you could have those three addresses in your mailing list and
they're three different people!  Consequently, we need to keep track of exactly how the email address was typed
or we may lose some information.

Yeah, I know it's arguably being silly to do this, since I've never (I<ever>) encountered an email server that
allowed multiple differently-cased email addresses like this, but dammit I want to have the option in here
to deal with it!  :-)

'course, people could very well subscribe to your list using "thomasonIII@yahoo.com" and then try to unsubscribe
using "thomasoniii@yahoo.com" and mess things up royally.  That's why we have the safe_banned method.
I<See safe_banned, below>

I<v1.x equivalent>:  BANNED

=item safe_banned

safe_banned is set to true by default.  safe_banned makes your matches on addresses case insensitive.
So that a request to ban "thomasoniii@yahoo.com" will also ban "ThomasonIII@yahoo.com", and "thomASONIii@yahoo.com".  You
almost definitely want to leave this on, for safety's sake, but you can turn it off if you'd like.

I<See banned above>

=item allow_duplicates

allow_duplicates is off by default.  Setting allow_duplicates to 1 will allow people with multiple
entries in your mailing list to receive multiple copies of the message.  Otherwise, they will
only receive one copy of the message.  Duplicate addresses are printed out to ERRFILE, if you specified
ERRFILE and you didn't turn allow_duplicates on.

allow_duplicates respects safe_banned.  So if safe_banned is false, it will do local-part case-insensitive
matching for duplicates, otherwise it will do local-part case-sensitive matching.

=item Tz

This returns the current timezone.

I<v1.x equivalent>:  _def_Tz

=item Date

This returns the current date in RFC 1123 format.

I<v1.x equivalent>:  _def_Date


=item header

header() is actually a method that pretends to be an accessor.  See ADDTIONAL ACCESSORS, below.

I<v1.x equivalent>:  headset

=item HFM

HFM (Headers From Message) will extract any valid headers from the message body.  A valid header is
of the form "Name:value", one per line with an empty line seperating the headers from the message.

It is B<much> better to explicitly set the headers using the header method because it's a tougher 
to make mistakes using header.  Nonetheless, setting HFM to any true value will cause the module to
look in the message for headers.  Any valid headers extracted from the message will override existing 
headers.  Dynamically generated headers will override extracted headers, however.  
Headers extracted from the message will be removed from the message body.

But be perfectly sure you know what you're doing.

    $bulk->HFM(1);

    $bulk->Message(
        "This is my message.  I'm going to try sending it out to everyone that I know.
        Messages are cool, e-mailing software is neat, and everyone will love me for it.
        Oh happy day, happy happy day.
        Love,

        Jim";

Before v2.03, since HFM is set to true, the first four lines are extracted from the message and sent as headers.
The extent of the message that goes through is "Jim" (everything after the first blank line which separates
headers from message body).

After v2.03, this will generate an error since HFM now makes sure that the headers are formed properly.  It
still doesn't verify its headers, though, so you still need to be careful.  Maybe in the next release...

Prior to v2.03, HFM would unwrap wrapped headers.  Since 2.04, HFM passes any wrapped headers through unchanged.

HFM is off by default.

I<v1.x equivalent>:  HFM


=item BMD

BMD (bulkmail delimiter) tells the module what delimiter to use in the file when using BULK_MAILMERGEs
(see below)

B<Important: BMD I<must> be different than DMD and DHD>

BMD is "::" by default.

I<v1.x equivalent>:  BMD

=item DMD

DMD (dynamic mail delimiter) tells the module what delimiter to use in the file when using dynamic messages
(see below)

DMD is "," by default.

=item DMDE

DMDE (Dynamic Mail delimeter for Equal) tells the module what delimiter to use in the 
file when using for equalities in dynamic messages
(see below)

DMDE is "=" by default.

=item DHD

DHD (dynamic header delimiter) tells the module what delimiter to use in the file when using dynamic headers
(see below)

DHD is "," by default.

=item DHDE

DHDE (Dynamic Header delimeter for Equal) tells the module what delimiter to use in the 
file when using for equalities in dynamic headers
(see below)

DHDE is "=" by default.

=item lineterm

lineterm is nifty.  It allows you to set the ending line character in your files.  So if you have
a file with email addresses that is inexplicably delimited with "<!X!>", then simply set lineterm to 
"<!X!>" and off you go.  No need to convert your files before hand.

lineterm is "\n" by default.

=item Trusting

Trusting() lets you decide to turn off error checking.  By default, Mail::Bulkmail will only allow you
to use valid e-mail addresses (well, kinda see the valid_email method for comments), valid dates, valid
timezones, and valid precedences.  Trusting is off by default.  Turn it on by setting it to some non-zero value.
This will bypass B<all> error checking.  You should probabaly just leave it off so you can check for valid e-mails,
dates, etc.  But you have the option, at least.

I<v1.x equivalent>:  No_errors

=back


=head2 ADDITIONAL ACCESSORS

You're perfectly welcome to access any additional data that you'd like.  We're gonna assume that you're accessing
or setting a header other than the standard ones that are provided.  You even get a special method to access them:
header().  Using it is a piece of cake:

$bulk->header('Reply-to', 'thomasoniii@yahoo.com');

Will set a "Reply-to" header to the value of "thomasoniii@yahoo.com".  Want to access it?

$bulk->header('Reply-to');

What's that you ask?  Why don't we set *all* headers this way?  Well, truth be told you can set them using header.

$bulk->header('From', 'thomasoniii@yahoo.com');

Is the same as:

$bulk->From('thomasoniii@yahoo.com');

Note that you can only set other _headers_ this way.  The headers that have their own methods are From, Subject, and
Precedence.  Calling header on something else, though (like "Smtp") will set a header with that value, which is probably
not what you want to do (a "Smtp: your.server.com" header is reeeeeal useful).  I'd recommend just using the provided
From, Subject, and Precedence headers.  That's what they're there for.

What's that?  Why the hell can't you just say $bulk->my_header('some value')?  It's because you may want to have a header
with a non-word character in it (like "Reply-to"), and methods with non-word characters are a Perl no-no.  So since it's
not possible for me to check every damn header to see if it has a non-word character in it (things get stripped and messed
up and the original value is lost), you'll just have to use header to set or access additional headers.

OR--You can just set your headers at object construction.  Realistically, you're going to be setting all of your headers
at construction time, so this is not a problem.  Just remember to quote those things with non-word characters in them.

 $bulk->Mail::Bulkmail->new(
        From        => 'thomasoniii@yahoo.com',
        Subject     => 'Some mass message',
        'Reply-to'  => 'thomasoniii@yahoo.com'
    );

If you don't quote headers with non-word characters, all sorts of nasty errors may pop up.  And they're tough to track down.
So don't do it.  You've been warned.

As of v2.03, ->header() without a specific header name will return a hashref containing all additional headers that have been set.

I<Also see dynamic headers below>

=head2 VALIDATED ACCESSORS

The properties that have validation checks are "From", "To", "Domain", and "Precedence" to try
to keep you from making mistakes.  The only one that should really ever concern you is perhaps "From"

=over 11

=item From

This checks the return e-mail address against RFC 822 standards.
The validation routine is not perfect as it's really really hard to be perfect, but
it should accept any valid non-group e-mail address.
There is one bug in the routine that will allow "Jim<thomasoniii@yahoo.com" to pass as valid,
but it's a nuisance to fix so I'm not going to.  :-)

I<v1.x equivalent>:  From

=item To

This checks the to e-mail address against RFC 822 standards.
The validation routine is not perfect as it's really really hard to be perfect, but
it should accept any valid non-group e-mail address.
There is one bug in the routine that will allow "Jim<thomasoniii@yahoo.com" to pass as valid,
but it's a nuisance to fix so I'm not going to.  :-)

The ->To address is used when you are sending to a list using the envelope.
I<See use_envelope, above>

=item Domain

Domain sets which domain you'll use to say HELO to your SMTP server.  If no domain is
specified, you'll just use the domain part of your From address.  You probably won't need
to set this ever.

=item Precedence

We are doing bulkmail here, so the precedence should always be "list", "bulk",
or "junk" and nothing else.  We might as well be polite and not make our servers
think that we're sending out 60,000 first-class or special-delivery messages.
You probably don't want to fiddle with this.

I<v1.x equivalent>:  Precedence

If you don't want to do any validation checks, then set Trusting equal to 1 (see Trusting, below).
That will bypass all validation checks and allow you to insert "Garbonzo" as your date if you desire.
It's recommended that you leave error checking on.  It's pretty good.  And you have more important things
to worry about.

=head2 Methods

There are several methods you are allowed to invoke upon your bulkmail object.

=over 10

=item bulkmail (?local merge?)

This method is where the magic is.  This method starts up your mailing, sending 
your message to every person specified in LIST.  bulkmail returns nothing.  
bulkmail merely loops through everything in your LIST file and calls mail on each entry.

bulkmail is a hell of a lot more complex then it used to be.  It used to just pass each address
off to the mail method, so it was essentially just a big for loop.

Now it's gotta do condition checking, verifications, and 4 or 5 method calls instead of one.
Obviously, those 4-5 method calls are going to slow down your list processing, so that's bad.
How much it'll slow down I'm not really sure.  I shouldn't be much...10% I'm guessing.  Maybe.

So why the hell did I complicate this up and make it slower, you ask?  It needs the extra tricks
to enable envelope sending.  Envelope sending will typically provide you with a performance increase
of somewhere around 400%, I'm estimating.  The little slowdown from the method calls seemed unimportant.

bulkmail can be handed a local merge hash.  I<See merging, below>

Returns 1 on success, undef on failure.

=item mail (line ?local merge?)

mail is much much dumber than it used to be.  Give it a line (as in whatever a line would look like
if extracted from your list) and an optional local merge, and it will email that one person.  You can
now very easily accomplish the exact same thing by setting LIST to an array with one item and using
bulkmail, but I figured I'd keep mail around for the heck of it so everyone easily knows that you
can email just one person.

There may be better modules for emailing to just one person, though.

Returns 1 on success, undef on failure.

=item connect (no arguments)

This method connects to your SMTP server.  It is called by the internal build_envelope method.
You can explicitly call it yourself, if you'd like.  That way you can verify that you can connect
to your server in advance, and do something if you can't, I suppose.

Returns 1 on success, undef on failure.

=item disconnect (no arguments)

This method disconnects from your SMTP server.  It is called at object destruction, or
explicitly if you wish to disconnect earlier.  You should never need to call this method.  Returns
nothing.

=item error (no arguments)

error is where the last error message is kept.  Can be used as follows:

$bulk->connect || die $bulk->error;

All B<object> error messages will be logged if you specifed an ERRFILE file.  Class errors will B<not>
be logged internally, you'll have to do that yourself.

error is also usable as a class method:

Mail::Bulkmail->error();

will return whatever the last global class-wide error is, such as an object construction failure.
In fact, currently that's the only error it catches.  But you can now easily do:

 my $bulk = Mail::Bulkmail->new(
    "From" => 'thomasoniiI@yaho'     #invalid address!
 ) or die Mail::Bulkmail->error();

to find out why construction failed.

=back

=head1 MERGING

Finally, the mysterious merging section so often alluded to.

Mail merging is exactly the same as "file mapping" was in v1.x.  I just didn't realize until long after
I released it that "file map" was stupid and that "mail merge" is the correct term.  I'm finally correcting
that error.  If you understood mapping in v1.x, you'll understand merging now.  :-)

You are sending out bulk e-mail to any number of people, but perhaps you would like to personalize
the message to some degree.  That's where merging comes in handy.  You are able to define a merge
to replace certain characters (control strings) in an e-mail message with certain other characters
(values).

Now in v2.0 you can go one step further and use dynamic messages, which actually allows you to construct
your message on the fly, instead of just inserting values.  I<See dynamic messages, below>

Merges can be global so that all control strings in all messages will be replaced with the same value
or local so that control strings are replaced with different values depending upon the recipient.

Merges are declared at object constrution or by using the merge accessor.  merge values are either
anonymous hashes or references to hashes.  For example:

At constrution:

    $bulk = Mail::Bulkmail->new(
                "From"    => "thomasoniii@yahoo.com",
                "merge"   => {
                                'DATE'    => 'today',
                                'company' => 'Thomason Industries'
                             }
            );

Or using the accessor:

    $bulk->merge({'DATE' => 'yesterday'});

Global merges are not terribly useful beyond setting generic values, such as today's date within a message
template or the name of your company.  Local merges are much more helpful since they allow values to be set 
individually in each message.  Local merges can be declared either in a call to the mail method or by using 
the BULK_MAILMERGE key.  Local merges are declared with the same keyword (merge) as global merges.

As a call to mail:

    $bulk->mail(
            'thomasoniii@yahoo.com',
            {
              'ID'   => '36373',
              'NAME' => 'Jim Thomason',
            }
    );

Using BULK_MAILMERGE

    $bulk->merge({'BULK_MAILMERGE'=>'BULK_EMAIL::ID::NAME'});

Be careful with your control strings to make sure that you don't accidentally replace text in the message
that you didn't mean to.  Control strings are case sensitive, so that "name" in a message from the 
above example would not be replaced by "Jim Thomason" but "NAME" would be.

B<NOTE:> I would I<highly> recommend against having "BULK_" or "DYNAMIC_" in any of your keys (except BULK_EMAIL, of course).  
BULK_* keys are used internally by Mail::Bulkmail for keeping track of things that it needs to keep track of.
BULK_MAILMERGE, BULK_EMAIL, DYNAMIC_MESSAGE, and DYNAMIC_HEADERS are examples of internal keys.  BULK_LINE is also hanging around inside, but you
never see it, now do you?  But you never know what keys I may need to add internally at a later date.  I will
I<always> prepend those keys with 'BULK_' or 'DYNAMIC_', so you be sure to I<never> prepend your keys with 'BULK_' or 'DYNAMIC_' 
and we'll all get along just fine.

BULK_MAILMERGE will be explained more below.

=head2 BULK_MAILMERGE

First of all, BULK_MAILMERGE is B<not> compatible with use_envelope.  Use one or the other, but not both.
It'll yell at you if you do.

Earlier we learned that LIST files may be in two main formats, either a single e-mail address per line,
or an email address and several values per "line", either delimited in a line of a file, or stored in
an array or a hash or a function or whatever. 

Delimited lists _must_ be used in conjunction with a BULK_MAILMERGE parameter to merge.  BULK_MAILMERGE
allows you to specify that each e-mail message will have unique values inserted for control strings
without having to loop through the address list yourself and specify a new local merge for every message.
BULK_MAILMERGE may only be set in a global map, its presence is ignored in local merges.

 If your list file is this:
   thomasoniii@yahoo.com::36373::Jim Thomason
   or
   ["thomasoniii@yahoo.com", "36373", "Jim Thomason"]
   or
   {
       "BULK_EMAIL" => "thomasoniii@yahoo.com,
       "ID"         => "36373",
       "NAME"         => "Jim Thomason"
   }

You can have a corresponding merge as any one of the following:

 $bulk->merge({
         'BULK_MAILMERGE'=>'BULK_EMAIL::ID::NAME'
         });

 $bulk->merge({
         'BULK_MAILMERGE'=>["BULK_EMAIL", "ID", "NAME"]
         });

 $bulk->merge({
         'BULK_MAILMERGE'=>
             {"BULK_EMAIL" => undef,
              "ID" => undef,
              "NAME" => undef
             }
         });

This BULK_MAILMERGE will operate the same way that the local merge above operated.  "BULK_EMAIL" is the
only required item, it is case sensitive.  This is where in your delimited line the e-mail
address of the recipient is.  "BULK_EMAIL" _is_ used as a control string in your message.  Be careful.
So if you want to include someone's e-mail address within the text of your message, put the string
"BULK_EMAIL" in your message body wherever you'd like to insert it.

Everything else may be anything you'd like, these are the control
strings that will be substituted for the values at that location in the line in the file.
You may use global merges, BULK_MAILMERGEs and local merges simultaneously.

BULK_MAILMERGEs are declared as delimited by the BMD method (or "::" by default), the data in the actual file
is also delimited by the BMD method.  The default delimiter is "::", but as of version 1.10, 
you may use BMD to choose any arbitrary delimiter in the file.

For example:

    $bulk->BMD("-+-");

    $bulk->merge({'BULK_MAILMERGE'=>'BULK_EMAIL-+-ID-+-NAME'});

    (in your list file)
    thomasoniii@yahoo.com-+-ID #1-+-Jim Thomason
    thomasoniii@yahoo.com-+-ID #2-+-Jim Thomason

If you have set LIST to a function, or array, you can have each line return in an array or a hash.  Obviously,
if LIST is a file, then every line has to be a delimited string as listed above.

But with arrays or functions, you don't have to return a delimited string.  You can return your entry in an
array or in a hash.  An array is listed in the same order as the BULK_MAILMERGE, and operates the same way.
It's just a little cleaner and quicker since we skip the split step.

The hash method is a little slower since it's a hash, and it also takes up a little more memory since you're
returning more values.

You'll almost never want to use the hash method, since the array one is preferrable.  I'm debating whether
or not to expand that hash returning approach to allow you to dynamically construct mail merges on the fly
for each individual item.  What do you think about that idea?

=head2 merge precedence

local merge values will override global merge values.  BULK_MAILMERGE merge values will override anything else.
Evaluation of merge control strings is 

 BULK_MAILMERGE value -> local value -> global value

where the first value found is the one that is used.

=head1 DYNAMIC MESSAGES

Dynamic messages rock.  :)

We had a dotcom company come in one day to try to sell us on their email solution for our mailing lists.  I calmly
sat there, listened to their presentation, and jotted down notes about anything they said that I thought would be
good to incorporate into Mail::Bulkmail.  The best thing that they had was dynamic messages.

Dynamic messages are mail merges taken to the next level. A mail merge allows you to insert simple piece of information
into your message, the person's name or phone number or something for personalization purposes.  But it's not a good
idea to do much beyond that because it gets messy to try to maintain it across your list and keep consistency across everything.
A global mail merge is better, but not great.

Enter dynamic messages.

Dynamic messages allow you to actually construct your message on the fly based upon preferences specified by the user.

Say you've got a mailing list on animals, and you want to maintain one list to send out to the people who like bears,
rabbits, and iguanas.  One list is easier to maintain than three, and conceptually they all like animals, so it makes
sense.  Besides, some people may want info on bears and rabbits and wouldn't it be nice to send them one email instead
of two?

Dynamic messages must be used in conjunction with BULK_MAILMERGE, since we're building them based upon the preferences
of the individual recipient.  Use the DYNAMIC_MESSAGE keyword in your BULK_MAILMERGE:

 "BULK_MAILMERGE" => "BULK_EMAIL::Name::ID::DYNAMIC_MESSAGE"

and then your email entry would be:

 thomasoniii@yahoo.com::Jim Thomason::36373::Bears=yes,Rabbits=no,Iguanas=headlines

To specify that I want info on bears, no info on rabbits, and just headlines on iguanas.

Then you use the ->dynamic method to declare your hash of hashes.

 $bulk->dynamic(
    "Bears" => {
        "yes" => "I see you like bears.  Bears are cuddly and we like them too!",
        "black" => "Here is your update on the black bear...",
        "polar" => "here is your update on the polar bear...",
        "no" => ""
    },
    "Rabbits" => {
        "yes" => "I see that you like rabbits.  Rabbits are cool."
        "cottontail" => "Here is information on the cotton tail rabbit..."
        "no" => ""
    },
    "Iguanas" => {
        "yes" =" Here is info on iguanas",
        "no" => ""
        "headlines" => "Here are important iguana stories"
    }
 );

or at object creation:

 my $bulk = Mail::Bulkmail->new(
     "message" => "
     Bears
     Rabbits
     Iguanas",
     "dynamic" =>
     {
         "Bears" => {
            "yes" => "I see you like bears.  Bears are cuddly and we like them too!",
            "black" => "Here is your update on the black bear...",
            "polar" => "here is your update on the polar bear...",
            "no" => ""
        },
        "Rabbits" => {
            "yes" => "I see that you like rabbits.  Rabbits are cool."
            "cottontail" => "Here is information on the cotton tail rabbit..."
            "no" => ""
        },
        "Iguanas" => {
            "yes" =" Here is info on iguanas",
            "no" => ""
            "headlines" => "Here are important iguana stories"
        }
    }
 );

Which will create this message:

 I see you like bears.  Bears are cuddly and we like them too!
 Here are important iguana stories

It operates the same way as a mail merge, substituting the key word for whatever keyword value is listed
in the DYNAMIC_MESSAGE item.

Dynamic messages execute before mail merges, so you can mail merge a dynamic message as well!

BULK_MAILMERGE = "BULK_EMAIL::NAME::DYNAMIC_MESSAGE";

 $bulk->dynamic(
    "Bears" => {
        "personal" => "I see you like bears, NAME",
        "impersonal" => "I see you like bears, whoever you are"
    }
 );

 thomasoniii@yahoo.com::Jim Thomason::Bears=personal

would send:

I see you like bears, Jim Thomason.

So you can send truly dynamic, personalized messages.

=head1 DYNAMIC HEADERS

Well, I'm kinda spent after the huge lecture on dynamic messages above, so I'll be briefer.

Dynamic headers operate exactly the same way, except with headers instead of message components.  So you can send
individual people individual subjects, for instance.

use DYNAMIC_HEADERS in a BULK_MAILMERGE:

BULK_MAILMERGE = "BULK_EMAIL::DYNAMIC_HEADERS";

Use the dynamic_headers method:

 $bulk->dynamic_headers(
    "Subject" => {
        "Special offer" => "A special offer for valued customers",
        "First time" => "Thanks for your first order!",
        "No order" => "We miss your business!"
    }
 );

or at object construction:

 my $bulk = Mail::Bulkmail->new(
    "dynamic_headers" =>{
        "Subject" => {
            "Special offer" => "A special offer for valued customers",
            "First time" => "Thanks for your first order!",
            "No order" => "We miss your business!"
        }
    }
);    

So that

thomasoniii@yahoo.com::Subject=Special offer

Will send out your email message to thomasoniii@yahoo.com with 
"A special offer for valued customers" as the subject.

Again, you can use a mail merge into a dynamic header, if you'd like.  So you can insert a personalized header
ID, for instance.

=head1 CLASS VARIABLES

(well, I<technically> they aren't class variables, since they're lexically scoped, but the gist is the same)

 my $def_From              = 'Postmaster';
 my $def_To                = 'postmaster@your.smtp.com';
 my $def_Smtp              = 'your.smtp.com';       #<--Set this variable.  Important!
 my $def_Domain            = "smtp.com";
 my $def_Port              = '25';
 my $def_Tries             = '5';
 my $def_Subject           = "(no subject)";
 my $def_Precedence        = "list";                #list, bulk, or junk
 my $def_Trusting          = 0;
 my $def_log_line          = 0;
 my $def_envelope_limit    = 0;
 my $def_allow_duplicates  = 0;

 my $def_BMD               = "::";
 my $def_DHD               = ",";
 my $def_DMD               = ",";
 my $def_DMDE              = "=";
 my $def_DHDE              = "=";

 my $def_lineterm          = "\n";

 my $def_HFM               = 0;

The default values. for various items.  All of which may be overridden in individual objects.

These all should be obvious based upon what you've read so far.

=head1 DIAGNOSTICS

Bulkmail doesn't directly generate any errors.  If something fails, it will return undef
and set the ->error property of the bulkmail object.  If you've provided an error log file,
the error will be printed out to the log file.

Check the return of your functions, if it's false, check ->error to find out what happened.

isDuplicate and isBanned will return 0 if an address is not a duplicate or banned, respectively,
but this is (probably) not an error condition.

=head1 HISTORY

=over 14 

=item - 2.05 10/3/00

Added envelope_limit method.  See 'envelope_limit', above.

Cleaned up the documentation a lot.

Re-wrote the date generation methods.  They're now 5-10% faster and I fixed an *old* bug causing
mail to sometimes appear to have been sent yesterday, or tomorrow.

Altered logging when using the envelope, see item GOOD, above.

Fixed a bug with undefined values in mailmerges

=item - 2.04 8/29/00

Added log_full_line flag.  See 'log_full_line', above.

Trusting is now more trusting.

Domains can once again be banned.

Error checking is done less often and in a slightly different order now

->bulkmail now returns 1 on success.  Doh.

Fixed an annoyingly subtle bug with construction of dynamic messages

Repaired a long-standing bug in the docs.

=item - 2.03 8/22/00

Tweaked the constructor.

Enhanced 'error'.  See 'error', above.

Enhanced HFM.

Various bug fixes.

Enhanced the test suite.

=item - 2.01 8/16/00

Fixed a *really* stupid error.  Merge hashes and dynamic hashes weren't properly initialized. Damn.

=item - 2.00 8/11/00

Re-wrote everything.  Literally B<everything>.  Total re-write.  Should be a much better module now.  :)

=item - 1.11 11/09/99

Banned addresses now checks entire address case insensitively instead of leaving the local part
alone.  Better safe than sorry.

$self->fmdl is now used to split BULK_FILEMAP

Various fixes suggested by Chris Nandor to make B<-w> shut up.

Changed the way to provide local merges to mail and bulkmail so it's more intuitive.

=item - 1.10 09/08/99 

Several little fixes.

The module will now re-connect if it receives a 221 (connection terminated) message from the server.

Fixed a potential near-infinite loop in the _valid_email routine.

_valid_email now merrily strips away comments (even nested ones).  :)

hfm (headers from message) method added.

fmdl (filemap delimiter) method added.

=item - 1.01 09/01/99

E-mail validation and date generation bug fixes

=item - 1.00 08/18/99 

First public release onto CPAN

=item - 0.93 08/12/99

Re-vamped the documentation substantially.

=item - 0.92 08/12/99

Started adding a zero in front of the version name, just like I always should have

Changed accessing of non-standard headers so that they have to be accessed and retrieved
via the "header" method.  This is because methods cannot have non-word characters in them.

From, Subject, and Precedence headers may also be accessed via header, if you so choose.

AUTOLOAD now complains loudly (setting ->error and printing to STDERR) if it's called.

=item - 0.91 08/11/99

Fixed bugs in setting values which require validation checks.
Fixed accessing of non-standard headers so that the returns are identical to every other accesor method.

=item - 0.90

08/10/99 Initial "completed" release.  First release available to general public.

=back

=head1 EXAMPLES

=head2 bulkmailing

Here's how we use Bulkmail in one of our programs:

 use Mail::Bulkmail;

 $bulk = Mail::Bulkmail->new(
    'From'       => $from,
    'Subject'    => $subject,
    'Message'    => $message,
    'X-Header'   => "Rockin' e-mail!",
    'merge'      => {
                     '<DATE>'            => $today,
                     'BULK_MAILMERGE'    => "email::<ID>::<NAME>::<ADDRESS>"
                    },
    'LIST'       => './list.txt',
    'GOOD'       => './good_list.txt',
    'BAD'        => './baddata.txt',
    'ERROR'      => './error.txt',
    'BANNED'     => './banned.txt',
 );

That example will set up a new bulkmail object, fill in who it's from, the subject, and the message,
as well as a "X-header" header which is set to "Rockin' e-mail!".
It will also define a merge to turn "<DATE>" control strings into the $today string, a BULK_MAILMERGE to merge 
in the name, id number, and address of the user.  It opens a LIST file, and sets up GOOD, BAD, and 
ERROR files for logging.  It also uses a BANNED list.

This list is then mailed to by simply calling

$bulk->bulkmail() or die $bulk->error();

Easy as pie.  Especially considering that when we had to write all of this code out in our original
implementation, it took up well over 100 lines (and was 400x slower).

=head2 Single mailing

 use Mail::Bulkmail;

 $bulk = Mail::Bulkmail->new(
     'From'     => $from,
     'Subject'  => $Subject,
     'Message'  => $message,
     'X-Header' => "Rockin' e-mail!"
 );

 $bulk->mail(
      'thomasoniii@yahoo.com',
      {
         '<DATE>'    => $today,
         '<ID>'      => '36373',
         '<NAME>'    => 'Jim Thomason',
         '<ADDRESS>' => 'Chicago, IL'
       }
 );

This will e-mail out a message identical to the one we bulkmailed up above, but it'll only go to
thomasoniii@yahoo.com

=head2 HUGE example with dynamic messaging

 {
    my @stuff = (
        \&solitary_address, 
        ['some_address@somewhere.com', "HOOSIER", "BETDA", "GAMMA",
            "hoosier=alpha,pickle=something", 
            "To=test,From=mike,Subject=special,Marvelous=Charlie"
        ], 
        'some_other_address@somewhere.com::able::baker::charlie::::Subject=special', 
        'some_address@somewhere_else.com::alpha::bravo::niner::::Subject=special'
    );

    sub email_list {
        return shift @stuff;
    };

    sub solitary_address { 
        return ['another_address@some_server_somewhere.com', "hoosier", "betda", "gamma", 
        "hoosier=alpha,pickle=something", 
        "To=admin,From=herbert,Subject=yodel,Marvelous=Charlie"
        ]
    };


 };

 my %hash = ("this" => "That");
 my $bulk = Mail::Bulkmail->new(
    "From"             => "thomasoniii\@yahoo.com",
    "Subject"          => "Test with envelope",
    "Smtp"             => "email.emailserv.com",
    "LIST"             => \&email_list,
    "ERRFILE"          => \*STDERR,
    "use_envelope"     => 0,
    "Trusting"         => 0,
    "To"               => "My_list@my_server.com",
    "allow_duplicates" => 1,
    "Message"          => "azz--hello there who are you? (hoosier) (pickle) I see that you're at BULK_EMAIL",
    "merge" => {
        "this is a test" => "something",
        "who" => "what",
        "where" => "there",
        "ttt" => "things",
        "BULK_MAILMERGE" => "BULK_EMAIL::azz::bzz::czz::DYNAMIC_MESSAGE::DYNAMIC_HEADERS"
    },
    "dynamic" => {
        "hoosier" => {
            "alpha" => "This is an alpha email component",
            "beta" => "This is a beta email component",
            "agent" => "This is an agent email component"
        },
        "pickle" => {
            "something" => "You've requested the pickle agent!"
        }
    },
    "dynamic_headers" => {
        "Subject" => {
            "Hello!" => "Why HELLO there.",
            "yodel" => "I'm yodelling!",
            "special" => "Get this special offer!"
        },
        "From" => {
            "herbert" => 'herber@hoover.com',
            "mike" => 'mike@wallace.com'
        },
        "To" => {
            "admin" => "admin\@somewhere.com",
            "test" => "test\@elsewhere.com"
        },
        "Marvelous" => {
            "Max" => "Max is marvelous!",
            "Charlie" => "Charlie is marvelous!"
        }

    }
 ) or die Mail::Bulkmail->error();


B<Study this example>.  Change the email addresses.  Run it.  Understand it.  Be happy.

=head1 FAQ

B<So just how fast is this thing, anyway?>

I don't know any more, I don't have access to the same gigantic lists I used to anymore.  :~(

Anyway, I'm guesstimating that normal emailing will be about 5-10% slower than before, at most.
But envelope mailing will be 400+ percent faster.

Well, there's a caveat to that.  I'm estimating that normal emailing the same way you'd use v1.11 will be
5-10% slower than before.  "normal" means using flat files as your lists.  If you start using functions or
SQL queries to build your list, then all bets are off.  For instance, one list I'm using now sends to about
50 people in about 50 seconds (terribly slow).  But it's repeatedly performing a SQL query 'til it gets the
result it likes, comparing that result against several conditions, deciding to continue, and then completely
building the message on the fly so every single one is unique.  That's a lot of overhead which slows it down
quite a bit.  So YMMV, as usual.

Here's the 1.x answer, with 2.00 comments

Really fast.  Really stupendously incredibly fast.

The largest list that I have data on has 91,140 people on it.  This list runs through to I<completion> in about
an hour and 43 minutes, which means that Mail::Bulkmail can process (at least) 884 messages per minute or about
53,100 per hour. (I<the guess is that with 2.00 and envelope sending, you could email to these people in roughly
17 minutes>)

B<So? How big were the individual messages sent out?  Total data transferred is what counts, not total recipients!>

How right you are.  The last message sent out was 4,979 bytes.  4979 x 91,140 people is 453,786,060 bytes of data 
transferred, or about 453.786 megabytes in 1 hour and 43 minutes.  This is a sustained transfer rate of about 4.4 megabytes
per minute, or 264.34 megabytes per hour. (I<This hasn't changed in 2.00, we're just smart enough to send less data>)

B<Am I going to see transfer speeds that fast?>

Maybe, maybe not.  It depends on how busy your SMTP server is.  If you have a relatively unused SMTP server with a fair amount
of horsepower, you can easily get these speeds or beyond.  If you have a relatively busy and/or low powered SMTP server, you're
not going to reach speeds that fast.

B<How much faster will Mail::Bulkmail be than my current system?>

This is a very tough question to answer, since it depends highly upon what your current system is.  For the sake of argument,
let's assume that for your current system, you open an SMTP connection to your server, send a message, and close the connection.
And then repeat.  Open, send, close, etc.

Mail::Bulkmail will I<always> be faster than this approach since it opens one SMTP connection and sends every single message across
on that one connection.  How much faster depends on how busy your server is as well as the size of your list.

Lets assume (for simplicity's sake) that you have a list of 100,000 people.  We'll also assume that you have a pretty busy
SMTP server and it takes (on average) 25 seconds for the server to respond to a connection request.  We're making 100,000
connection requests (with your old system).  That means 100,000 x 25 seconds = almost 29 days waiting just to make connections
to the server!  Mail::Bulkmail makes one connection, takes 25 seconds for it, and ends up being 100,000x faster!

But, now lets assume that you have a very unbusy SMTP server and it responds to connection requests in .003 seconds.  We're making
100,000 connection requests.  That means 100,000 x .0003 seconds = about 5 minutes waiting to make connections to the server.
Mail::Bulkmail makes on connection, takes .0003 seconds for it, and ends up only being 1666x faster.  But, even though being
1,666 times faster sounds impressive, the world won't stop spinning on its axis if you use your old system and take up an extra
5 minutes.

And this doesn't even begin to take into account systems that don't open and close SMTP connections for each message.

I<2.00 will probably be a little slower than 1.x without envelope sending.  It'll be B<much> faster with it>

In short, there's no way to tell how much of a speed increase you'll see.

B<Have you benchmarked it against anything else?>

Not scientifically.  I've heard that Mail::Bulkmail is about 4-5x faster than Listcaster from Mustang Software, but I don't
have any hard numbers.  

If you want to benchmark it against some other system and let me know the results, it'll be much appreciated.  :-)

B<Wait a minute!  You said up there that Mail::Bulkmail opens one connection and sends all the messages through.  What happens
if the connection is dropped midway through?>

Well, either something good or something bad depending on what happens.  If it's something good, the server will send a 221 message
(server closing) which Mail::Bulkmail should pick up and some point, realize its disconnected and then reconnect for the next
message.  If it's something bad, the server will just stop replying and Mail::Bulkmail will sit there forever wondering why
the server won't talk to it anymore.  

Realistically, if your server bellyflopped and is not responding at all and won't even alert that it's disconnected, you probably
have something serious to worry about.

A future release will probably have a time-out option so Mail::Bulkmail will bow out and assume its disconnected after a
certain period of time. 

B<What about multipart messages? (MIME attachments)>

*grumble grumble*  This is forthcoming, but it won't be in before version 2.5.  Maybe 3.0...

My current employer absolutely needs a mailing system that can handle attachments, so I figure I might
as well finally get around to building it into the module.

In the mean time, you can set your own headers, boundaries, etc. and just do the MIME encoding yourself.  It will work,
I just won't do it for you.

Note that if you just want to sent out a regular HTML message instead of text that you can just use the ->HTML
flag to tell the module that it's HTML.

B<I'd like to send out a mass-mailing that has different From and To fields in the message and the envelope.  Can I do this?>

Oh all right, go ahead.   I've decided not to punish the legitimate mass emailers because of the spammers.  So go
to town.  I figure it couldn't hurt once people start realizing that a Perl module is one of the fastest freakin'
mass mailers around.  Power to the cause!

B<Can I send spam with this thing?>

No.  Don't be a jerk.

B<So what is it with these version numbers anyway?>

I'm going to I<try> to be consistent in how I number the releases.

The B<hundredths> digit will indicate bug fixes, minor behind-the-scenes changes, etc.

The B<tenths> digit will indicate new and/or better functionality, as well as some minor new features.

The B<ones> digit will indicate a major new feature or re-write.

Basically, if you have x.ab and x.ac comes out, you want to get it guaranteed.  Same for x.ad, x.ae, etc.

If you have x.ac and x.ba comes out, you'll probably want to get it.  Invariably there will be bug fixes from the last "hundredths"
release, but it'll also have additional features.  These will be the releases to be sure to read up on to make sure that nothing
drastic has changes.

If you have x.ac and y.ac comes out, it will be the same as x.ac->x.ba but on a much larger scale.  Judging by the
amount of revision and improvement between 1.11 and 2.00, there's a very good chance you'll want to look at this
release.  But, also judging by 1.11->2.00, you'll want to really pour over the docs, since it probably won't be
backwards compatable and you'll have to fiddle with your script to use it.

B<So what can I expect to see in the future?>

Neat things.  Really I<really> neat things.  I've got a few tricks up my sleeve that will send the performance
through the roof.  In theory.  If I can get them to work.  Be patient.

But good things are in the works.  I just have too much fun developing this module.  :)

B<Wow, this module is really cool.  Have you contributed anything else to CPAN?>

Yes, Carp::Notify and Text::Flowchart

B<Was that a shameless plug?>

Why, yes.  Yes it was.

B<Anything else you want to tell me?>

Sure, anything you need to know.  Just drop me a message.

=head1 MISCELLANEA

Mail::Bulkmail will automatically set three headers for you (well, maybe four).

=over 4

=item 1

Who the message is from (From:....)

=item 2

The subject of the message (Subject:...)

=item 3

The precedence of the message (Precedence:...)

=item 4

 Who the message is to (To:....) I<only if using the envelope>
 (To: will actually always be set, but if not using the envelope it will
 be set to the individual receiving it)

=back

The defaults will be set unless you give them new values, but regardless these headers I<will> be set.  No way
around it.  Additional headers are set solely at the descretion of the user.

Also, this module was originally written to make my life easier by including in one place all the goodies that I
used constantly.  That's not to say that there aren't goodies that I haven't included that would be beneficial to add.
If there's something that you feel would be worthwhile to include, please let me know and I'll consider adding it.

How do you know what's a worthwhile addition?  Basically, if you need to do some sort of pre-processing to your e-mail
addresses so that you have to use your own loop and calls to mail() instead of using bulkmail(), and you're using said
loop and processing in several routines, it may be a useful addition.  Definitely let me know about those.  

That's not to say that random suggestions wouldn't be good, those I'll listen to as well.  But something big like that
is probably a useful thing to have so I'd be most interested in hearing about them.

=head1 COPYRIGHT (again)

Copyright (c) 1999, 2000 James A Thomason III (thomasoniii@yahoo.com). All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 CONTACT INFO

So you don't have to scroll all the way back to the top, I'm Jim Thomason (thomasoniii@yahoo.com) and feedback is appreciated.
Bug reports/suggestions/questions/etc.  Hell, drop me a line to let me know that you're using the module and that it's
made your life easier.  :-)

=cut
