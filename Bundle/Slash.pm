package Bundle::Slash;

$Bundle::Slash::VERSION = '1.0.11';

1;

__END__

=head1 NAME

Bundle::Slash - A bundle to install all modules used for Slash


=head1 SYNOPSIS

C<perl -MCPAN -e 'install "Bundle::Slash"'>

=head1 CONTENTS

Bundle::CPAN		- File::Spec,Digest::MD5,Compress::Zlib,libnet,Archive::Tar,Data::Dumper

Bundle::LWP		- URI,HTML::Parser,MIME::Base64

Bundle::DBI		- Storable

DBI::FAQ

Bundle::DBD::mysql	- Data::ShowTable

Date::Parse		- TimeDate

XML::Parser

XML::RSS

Date::Manip

Mail::Sendmail

Apache::DBI

Image::Size

Template		- Template Toolkit


=head1 DESCRIPTION

mod_perl must be installed by hand, because of the special configuration
required for it.

If CPAN starts downloading "perl-5.6.0" or somesuch, ctrl-C it, exit
the CPAN shell, and start it again.  The latest CPAN.pm version does not
have this problem, but older ones do, and you may have an older one
installed.

=cut
