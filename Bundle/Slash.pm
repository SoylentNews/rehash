package Bundle::Slash;

$Bundle::Slash::VERSION = '1.0.4';

1;

__END__

=head1 NAME

Bundle::Slash - A bundle to install all modules used for Slash

=head1 SYNOPSIS

C<perl -MCPAN -e 'install "Bundle::Slash"'>

=head1 CONTENTS

Bundle::CPAN	- File::Spec,Digest::MD5,Compress::Zlib,libnet,Archive::Tar,Data::Dumper

Bundle::LWP	- URI,HTML::Parser,MIME::Base64

Bundle::DBI	- Storable

Bundle::DBD::mysql  - Data::ShowTable

Date::Parse         - TimeDate

XML::Parser

Date::Manip

Mail::Sendmail

Apache::DBI

Apache::DBILogConfig

Apache::DBILogger

Image::Size


=head1 DESCRIPTION

mod_perl must be installed by hand, because of the special configuration
required for it.

IPC::Shareable no longer required for IPC, since we are no longer doing
IPC.

=cut
