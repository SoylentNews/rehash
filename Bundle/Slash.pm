package Bundle::Slash;

$Bundle::Slash::VERSION = '2.32';

1;

__END__

=head1 NAME

Bundle::Slash - A bundle to install all modules used for Slash


=head1 SYNOPSIS

C<perl -MCPAN -e 'install "Bundle::Slash"'>

=head1 CONTENTS

Net::Cmd                - libnet

Digest::MD5             - Instead of Bundle::CPAN

MD5

Compress::Zlib          - ditto

Archive::Tar            - ditto

File::Spec              - ditto

Storable

MIME::Base64            - why after URI if URI needs it?

Bundle::LWP		- URI,HTML::Parser,MIME::Base64

HTML::Element           - For doing HTML-to-text

Font::AFM               - ditto

HTML::FormatText        - ditto

HTML::TokeParser

HTML::CalendarMonth	- used for Events plugin

Mail::Sendmail

Mail::Address

Email::Valid

Getopt::Long

Image::Size

Time::HiRes

Date::Parse		- TimeDate

Date::Manip             - Still needed, but only in utils/

Date::Calc		- Use sparingly, only when necessary

Time::ParseDate         - Time-modules; Needed for Schedule::Cron

Schedule::Cron

XML::Parser

XML::RSS

XML::Simple

DBI

Data::ShowTable

Bundle::DBD::mysql	- ???

DBIx::Password

Apache::Test

Apache::DBI

Apache::Request		- libapreq; also includes Apache::Cookie

AppConfig		- Should be installed with TT, but sometimes not?

Template		- Template Toolkit


=head1 DESCRIPTION

mod_perl must be installed by hand, because of the special configuration
required for it.

=cut
