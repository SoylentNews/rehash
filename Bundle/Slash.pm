package Bundle::Slash;

$VERSION = '1.0.2';

1;

__END__

=head1 NAME

Bundle::Slash - A bundle to install all modules used for Slash

=head1 SYNOPSIS

C<perl -MCPAN -e 'install "Bundle::Slash"'>

=head1 CONTENTS

Bundle::libnet

Bundle::LWP         - includes URI, HTML::Parser, MIME::Base64, Digest::MD5

File::Spec

Bundle::DBI

Bundle::DBD::mysql  - includes Data::ShowTable

Date::Parse         - TimeDate

XML::Parser

Date::Manip

Mail::Sender

Apache::DBI

Apache::DBILogConfig

Apache::DBILogger

Compress::Zlib

Image::Size


=head1 DESCRIPTION

Should we do IPC::Shareable too?  It is not as stable, it seems.

Bundle::CPAN would be nice, but Archive::Tar seems broken now.

mod_perl must be installed by hand, because of the special configuration
required for it.

=cut
