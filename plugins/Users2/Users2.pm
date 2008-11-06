package Slash::Users2;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants qw(:messages);
use Slash::Utility;

use vars qw($VERSION);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision: 1.1 $ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $plugin = getCurrentStatic('plugin');
	return unless $plugin->{'Users2'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

sub getLatestComments {
        my($self, $uid) = @_;

        return $self->sqlSelectAllHashref(
                'cid',
                "sid, cid, subject, UNIX_TIMESTAMP(date) as date",
                'comments',
                "uid = $uid",
                'order by date desc limit 5');
}

sub getLatestJournals {
        my($self, $uid) = @_;
        
        return $self->sqlSelectAllHashref(
                'id',
                'id, description, UNIX_TIMESTAMP(date) as date',
                'journals',
                "uid = $uid and promotetype = 'publish'",
                'order by date desc limit 5');
}

sub getLatestSubmissions {
        my($self, $uid) = @_;

        my $submissions = $self->sqlSelectAllHashref(
                'id',
                'id, UNIX_TIMESTAMP(createtime) as date',
                'firehose',
                "uid = $uid and rejected = 'no' and (type = 'submission' or type = 'feed')",
                'order by createtime desc limit 5');

        foreach my $subid (keys %$submissions) {
                ($submissions->{$subid}{'title'}, $submissions->{$subid}{'introtext'}) =
                        $self->sqlSelect('title, introtext', 'firehose_text', "id = $subid");
        }

        return $submissions;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

Slash::Users2

=head1 SYNOPSIS

	use Slash::Users2;

=head1 DESCRIPTION

Provides homepages for users.

=head1 AUTHOR

Christopher Brown, cbrown@corp.sourcefore.com

=head1 SEE ALSO

perl(1).

=cut
