#!perl -w
# we could probably add these in automatically with some work, but it
# would be somewhat unreliable, so we need to keep this file up to date
# just record what module depends on what ... ha ha ha

use Data::Dumper;

my %data = (
	'Slash' => [qw(
		Slash::Constants
		Slash::DB
		Slash::Display
		Slash::Utility
	)],
	'Slash::Apache' => [qw(
		Slash
		Slash::DB
		Slash::Display
		Slash::Utility
	)],
	'Slash::Apache::Log' => [qw(
		Slash::Utility
	)],
	'Slash::Apache::User' => [qw(
		Slash
		Slash::Apache
		Slash::Display
		Slash::Utility
	)],
	'Slash::Constants' => [qw(
	)],
	'Slash::DB' => [qw(
		Slash::DB::Utility
	)],
	'Slash::DB::MySQL' => [qw(
		Slash::DB
		Slash::DB::Utility
		Slash::Utility
	)],
	'Slash::DB::Static::MySQL' => [qw(
		Slash::DB::Utility
		Slash::Utility
	)],
	'Slash::DB::Utility' => [qw(
		Slash::Utility
	)],
	'Slash::Display' => [qw(
		Slash::Display::Provider
		Slash::Utility::Data
		Slash::Utility::Environment
		Slash::Utility::System
	)],
	'Slash::Display::Plugin' => [qw(
		Slash
		Slash::Utility
	)],
	'Slash::Display::Provider' => [qw(
		Slash::Utility::Environment
	)],
	'Slash::Install' => [qw(
		Slash
		Slash::DB
		Slash::DB::Utility
	)],
	'Slash::Test' => [qw(
		Slash
		Slash::Constants
		Slash::Display
		Slash::Utility
		Slash::XML
	)],
	'Slash::Utility' => [qw(
		Slash::Utility::Access
		Slash::Utility::Anchor
		Slash::Utility::Data
		Slash::Utility::Display
		Slash::Utility::Environment
		Slash::Utility::System
	)],
	'Slash::Utility::Access' => [qw(
		Slash::Display
		Slash::Utility::Data
		Slash::Utility::System
		Slash::Utility::Environment
	)],
	'Slash::Utility::Anchor' => [qw(
		Slash::Display
		Slash::Utility::Data
		Slash::Utility::Display
		Slash::Utility::Environment
	)],
	'Slash::Utility::Data' => [qw(
		Slash::Constants
		Slash::Utility::Environment
	)],
	'Slash::Utility::Display' => [qw(
		Slash::Display
		Slash::Utility::Data
		Slash::Utility::Environment
	)],
	'Slash::Utility::Environment' => [qw(
	)],
	'Slash::Utility::System' => [qw(
		Slash::Utility::Environment
	)],
);

for my $class (keys %data) {
	my $aref = $data{$class};
	$data{$class} = { map { ($_ => 1) } @$aref };
}

my %checked;
for my $class (keys %data) {
	for my $sub (keys %{$data{$class}}) {
		check($class, $sub, [$class, $sub]);
	}
}

print "All OK!\n";

sub check {
	my($class, $sub, $trace) = @_;

	return if $checked{$class,$sub};
	$checked{$class,$sub}++;

	for (keys %{$data{$sub}}) {
		my $ntrace = [@$trace, $_, $class];
		local $" = " =>\n\t";
		if (exists $data{$_}{$class}) {
			die "damn:\n\t@$ntrace\n";
		}
		check($class, $_, [@$trace, $_]);
	}
}


__END__
