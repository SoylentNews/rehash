package Slash::Subscribe::IPN;

# $Id: IPN.pm,v 1.18 2003/08/19 07:47:08 sherzodr Exp $

use strict;
use Carp 'croak';
use vars qw($VERSION $GTW $AUTOLOAD $SUPPORTEDV $errstr);

# Supported version of PayPal's IPN API
$SUPPORTEDV = '1.5';

# Gateway to PayPal's validation server as of this writing
$GTW = 'https://www.paypal.com/cgi-bin/webscr';

# Revision of the library
$VERSION = '1.94';

# Preloaded methods go here.

# Allows access to PayPal IPN's all the variables as method calls
sub AUTOLOAD {
	my $self = shift;

	unless ( ref($self) ) {
		croak "Method $AUTOLOAD is not a class method. You should call it on the object";
	}
	my ($field) = $AUTOLOAD =~ m/([^:]+)$/;
	unless ( exists $self->{_PAYPAL_VARS}->{$field} ) {
		return undef;
	}
	no strict 'refs';
	# Following line is not quite required to get it working,
	# but will speed-up subsequent accesses to the same method
	*{$AUTOLOAD} = sub { return $_[0]->{_PAYPAL_VARS}->{$field} };
	return $self->{_PAYPAL_VARS}->{$field};
}



# So that AUTOLOAD does not look for destructor. Expensive!
sub DESTROY { }



# constructor method. Initializes and returns Slash::Subscribe::IPN object
sub new {
	my ($class, $data) = @_;
	return undef unless $data;
	$class = ref($class) || $class;

	my $self = { 
		_PAYPAL_VARS => {},
		data => $data,
		ua => undef,
	};

	bless $self, $class;

	$self->_init(); #or return undef;
	$self->_validate_txn(); #or return undef;

	return $self;
}



# initializes class object. Mainly, takes all query parameters presumably
# that came from PayPal, and assigns them as object attributes
sub _init {
	my $self = shift;

	foreach(split(/&/, $self->{data})){
		/^(.*?)=(.*?)$/ or die "$_\n";
		$self->{_PAYPAL_VARS}->{$1} = $2;
	}

	unless ( scalar( keys %{$self->{_PAYPAL_VARS}} > 3 ) ) {
		$errstr = "Insufficient content from the invoker:\n" . $self->dump();
		return undef;
	}
	print STDERR "Content from the invoker quite sufficient, thanks\n" . $self->dump();
	return 1;
}



# validates the transaction by re-submitting it to the PayPal server
# and reading the response.
sub _validate_txn {
	my $self = shift;

	#my $request = $self->request(); #unused?!
	my $ua	= $self->user_agent();

	# Adding a new field according to PayPal IPN manual
	my $query = 'cmd=_notify-validate&'.$self->{data};

	# making a POST request to the server with all the variables
	my $responce	= $ua->post( $GTW, $query );
	# caching the response object in case anyone needs it
	$self->{response} = $responce;
	
	if ( $responce->is_error() ) {
		$errstr = "Couldn't connect to '$GTW': " . $responce->status_line();
		print STDERR $errstr;
		return undef;
	}

	print $responce->content()."\n";

	if ( $responce->content() eq 'INVALID' ) {
		$errstr = "Couldn't validate the transaction. Responce: " . $responce->content();
	}
	elsif ( $responce->content() eq 'VERIFIED' ) {
		return 1;
	}
	else{

		# if we came this far, something is really wrong here:
		$errstr = "Vague response: " . substr($responce->content(), 0, 255);
		return undef;
	}
}



# returns all the PayPal's variables in the form of a hash
sub vars {
	my $self = shift;

	return $self->{_PAYPAL_VARS};
}



# returns already created response object
sub response {
	my $self = shift;

	if ( defined $self->{response} ) {
		return $self->{response};
	}

	return undef;
}



# returns user agent object
sub user_agent {
	my $self = shift;

	if ( defined $self->{ua} ) {
		return $self->{ua};
	}

	use LWP::UserAgent;
	
	my $ua = LWP::UserAgent->new();
	$ua->agent( sprintf("Slash::Subscribe::IPN/%s (%s)", $VERSION, $ua->agent) );
	$self->{ua} = $ua;
	return $self->user_agent();
}



# The same as payment_status(), but shorter :-).
sub status {
	my $self = shift;
	return $self->{_PAYPAL_VARS}{payment_status};
}



# returns true if the payment status is completed
sub completed {
	my $self = shift;

	unless ( defined $self->status() ) {
		return undef;
	}
	($self->status() eq 'Completed') and return 1;
	return 0;
}



# returns true if the payment status is failed
sub failed {
	my $self = shift;

	unless ( defined $self->status() ) {
		return undef;
	}
	($self->status() eq 'Failed') and return 1;
	return 0;
}



# returns the reason for pending if the payment status
# is pending.
sub pending {
	my $self = shift;
	unless ( defined $self->status() ) {
		return undef;
	}
	if ( $self->status() eq 'Pending' ) {
		return $self->{_PAYPAL_VARS}{pending_reason};
	}
	return 0;
}



# returns true if payment status is denied
sub denied {
	my $self = shift;

	unless ( defined $self->status() ) {
		return undef;
	}
	($self->status() eq 'Denied') and return 1;
	return 0;
}



# internally used to assign error messages to $errstr.
# Public interface should use it without any arguments
# to get the error message
sub error {
	my ($self, $msg) = @_;

	if ( defined $msg ) {
		$errstr = $msg;
	}
	return $errstr;
}



# for debugging purposes only. Returns the whole object
# as a perl data structure using Data::Dumper
sub dump {
	my ($self, $file, $indent) = @_;

	$indent ||= 1;

	require Data::Dumper;
	my $d = new Data::Dumper([$self], [ref($self)]);
	$d->Indent( $indent );

	if ( (defined $file) && (not -e $file) ) {
		open(FH, '>' . $file) or croak "Couldn't dump into $file: $!";		
		print FH $d->Dump();
		close(FH) or croak "Object couldn't be dumped into $file: $!";
	}
	return $d->Dump();
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Slash::Subscribe::IPN - Perl extension that implements PayPal IPN v1.5

=head1 SYNOPSIS

	use Slash::Subscribe::IPN;

	my $ipn = new Slash::Subscribe::IPN() or die Slash::Subscribe::IPN->error();

	if ( $ipn->completed ) {
		# ...
	}

=head1 ABSTRACT

Slash::Subscribe::IPN implements PayPal IPN version 1.5. It validates transactions 
and gives you means to get notified of payments to your PayPal account. If you don't already
know what PayPal IPN is this library may not be for you. Consult with respective manuals 
provided by PayPal.com, http://www.paypal.com/.

=head2 WARNING

I<$Revision: 1.18 $> of Slash::Subscribe::IPN supports version 1.5 of the API. This was the latest
version as of Tuesday, August 19, 2003. Supported version number is available in 
C<$Slash::Subscribe::IPN::SUPPORTEDV> global variable. If PayPal introduces new response variables,
Slash::Subscribe::IPN automatically supports those variables thanks to AUTOLOAD. For any further
updates, you can contact me or send me a patch.

=head1 PAYPAL IPN OVERVIEW

As soon as you receive payment to your PayPal account, PayPal posts the transaction details to
your specified URL, which you either configure in your PayPal preferences, or in your HTML forms'
"notify_url" hidden field.

When the payment details are received from, supposedly, PayPal server, your application should 
check with the PayPal server to make sure it is indeed a valid transaction, and that PayPal is aware
of it. This can be achieved by re-submitting the transaction details back to 
https://www.paypal.com/cgi-bin/webscr and check the integrity of the data.

If the transaction is valid, PayPal will respond to you with a single string "VERIFIED", 
and you can proceed safely. If the transaction is not valid, you will receive "INVALID", and you can
log the request for further investigation. 

So why this verification step is necessary? Because it is very easy for others to simulate a PayPal
transaction. If you do not take this step, your program will be tricked into thinking it was a valid
transaction, and may act the way you wouldn't want it to act. So you take extra step and check directly
with PayPal and see if such a transaction really happened

Slash::Subscribe::IPN is the library which encapsulates all the above complexity into this compact form:

	my $ipn = new Slash::Subscribe::IPN() or die Slash::Subscribe::IPN->error();

	# if we come this far, we're guaranteed it was a valid transaction.
	if ( $ipn->completed() ) {
		# means the funds are already in our paypal account.

	} elsif ( $ipn->pending() ) {
		# the payment was made to your account, but its status is still pending
		# $ipn->pending() also returns the reason why it is so.

	} elsif ( $ipn->denied() ) {
		# the payment denied

	} elsif ( $ipn->failed() ) {
		# the payment failed

	}

=head1 PREREQUISITES

=over 4

=item *

LWP - to make HTTP requests

=item *

Crypt::SSLeay - to enable LWP perform https (SSL) requests. If for any reason you
are not able to install Crypt::SSLeay, you will need to update $Slash::Subscribe::IPN::GTW to
proper, non-ssl URL.

=back

=head1 METHODS

=over 4

=item *

C<new()> - constructor. Validates the transaction and returns IPN object. Optionally you may pass 
it B<query> and B<ua> options. B<query> denotes the CGI object to be used. B<ua> denotes the
user agent object. If B<ua> is missing, it will use LWP::UserAgent by default. If the transaction
could not be validated, it will return undef and you should check the error() method for a more
detailed error string:

	$ipn = new Slash::Subscribe::IPN() or die Slash::Subscribe::IPN->error();

=item *

C<vars()> - returns all the returned PayPal variables and their respective values in the 
form of a hash.

	my %paypal = $ipn->vars();
	if ( $paypal{payment_status} eq 'Completed' ) {
		print "Payment was made successfully!";
	}

=item *

C<query()> - can also be accessed via C<cgi()> alias, returns respective query object

=item *

C<response()> - returns HTTP::Response object, which is the response returned while verifying
transaction through PayPal. You normally never need this method. In case you do for any reason,
here it is.

=item *

C<user_agent()> - returns user agent object used by the library to verify the transaction.
Name of the agent is C<Slash::Subscribe::IPN/#.# (libwww-perl/#.##)>.

=back

Slash::Subscribe::IPN supports all the variables supported by PayPal IPN independent of its 
version. To access the value of any variable, use the corresponding method name. For example, 
if you want to get the first name of the user who made the payment ('first_name' variable):

	my $fname = $ipn->first_name()

To get the transaction id ('txn_id' variable)

	my $txn = $ipn->txn_id()

To get payment type ('payment_type' variable)

	$type = $ipn->payment_type()

and so on. For the list of all the available variables, consult IPN Manual provided by PayPal
Developer Network. You can find the link at the bottom of http://www.paypal.com.

In addition to the above scheme, the library also provides convenience methods
such as:

=over 4

=item *

C<status()> - which is a shortcut to C<payment_status()>

=item *

C<completed()> - returns true if C<payment_status> is "Completed".

=item *

C<failed()> - returns true if C<payment_status> is "Failed". 

=item *

C<pending()> - returns true if C<payment_status> is "Pending". Return
value is also the string that explains why the payment is pending.

=item *

C<denied()> - returns true if C<payment_status> is "Denied".

=back

=head1 RETURN VALUES OF METHODS

Methods can return 1, 0 or undefined as well as any other true value. The distinction
between 0 (which is false) and undefined (which is also false) is important:

	$ipn->completed eq undef and print "Not relevant for this transaction type";
	$ipn->completed == 1 and print "Transaction was completed";
	$ipn->completed == 0 and print "Transaction was NOT completed";

In other words, methods return undef indicating this variable is not relevant for
this transaction type ("txn_type"). A good example for such transactions is "subscr_signup"
transaction, that do not return any "payment_status" nor "txn_id" variables. Methods return
0 (zero) indicating failure. They return 1 (one) or any other true value indicating success.

=head1 DEBUGGING

If for any reason your PayPal IPN solutions don't work as expected, you have no other
choice but debugging the process. Although it sounds complex, it really is not.All you need
to do is get your IPN script to dump Slash::Subscribe::IPN object into a file and investigate
to see what exactly is happening. For this reason, we provide C<dump()> method which does
just that:

=over 4

=item * 

C<dump([$filename] [,$indent])> - for dumping Slash::Subscribe::IPN object.
If used without any arguments, simply returns the object as Perl data structure.
If filename is passed as the first argument, object is dumped into the file.
The second argument, if present, should be a value between 1 and 3 to indicate how well
indented the dump file should be. For debugging purposes, I believe 2 is enough, but
go ahead and try out for yourself to compare differences.

=back

	Note that the object is dumped only once to the same file. So after investigating the dump,
	you may need to remove the file or dump to another file instead.

Interpreting the dump file may seem tricky, since it is relatively big file. But you don't
need to understand everything in it. Simply look for the attribute called "_PAYPAL_VARS".
It is a hashref that keeps all the variables returned from PayPal server. These are also
the methods that are available through Slash::Subscribe::IPN object.

You can also investigate the content of "response" attribute. It holds the HTTP::Response
object. Look for the "_content" attribute of this object. This is what was returned from
PayPal.com in response to your request. Ideally, this should hold "VERIFIED". "INVALID"
is also explainable though :-).

Before you do any "dumping" around, include the following lines on top of your IPN script
if you haven't done so already. This will ensure that when PayPal.com calls your IPN script, 
all the warnings and error messages, if any, will be saved in this file.

	use CGI::Carp 'carpout';
	BEGIN {
		open(LOG, '>>path/to/error.log') && carpout(\*LOG);
	}

=head1 VARIABLES

Following global variables are available:

=over 4

=item *

$Slash::Subscribe::IPN::GTW - gateway url to PayPal's Web Script. Default
is "https://www.paypal.com/cgi-bin/webscr", which you may not want to 
change. But it comes handy while testing your application through a PayPal simulator.

=item *

$Slash::Subscribe::IPN::SUPPORTEDV - supported version of PayPal's IPN API.
Default value is "1.5". You can modify it before creating ipn object (as long as you
know what you are doing. If not don't touch it!)

=item *

$Slash::Subscribe::IPN::VERSION - version of the library

=back

=head1 AUTHOR

Sherzod B. Ruzmetov E<lt>sherzodr@cpan.orgE<gt>

=head1 CREDITS

Following people contributed to this library with their patches and suggestions. It's very
possible that list is not complete. Help me with it.

=over 4

=item B<Brian Grossman>

Fixes in the source code. F<pathces/brian-grososman>.

=item B<Thomas J Mather>

Documentation fixes. F<patches/thomas-mather.patch>

=back

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

THIS LIBRARY IS PROVIDED WITH THE USEFULNESS IN MIND, BUT WITHOUT EVEN IMPLIED 
GUARANTEE OF MERCHANTABILITY NOR FITNESS FOR A PARTICULAR PURPOSE. USE IT AT YOUR OWN RISK.

=head1 REVISION

$Revision: 1.18 $

=cut
