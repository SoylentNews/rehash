package Slash::Users2;

use strict;
use DBIx::Password;
use Slash;
use Slash::Constants qw(:messages);
use Slash::Display;
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

	my $uid_q = $self->sqlQuote($uid);
        return $self->sqlSelectAllHashref(
                'cid',
                "sid, cid, subject, UNIX_TIMESTAMP(date) as date",
                'comments',
                "uid = $uid_q",
                'order by date desc limit 5');
}

sub getLatestJournals {
        my($self, $uid) = @_;
        
	my $uid_q = $self->sqlQuote($uid);
        return $self->sqlSelectAllHashref(
                'id',
                'id, description, UNIX_TIMESTAMP(date) as date',
                'journals',
                "uid = $uid_q and promotetype = 'publish'",
                'order by date desc limit 5');
}

sub getLatestSubmissions {
        my($self, $uid) = @_;

	my $uid_q = $self->sqlQuote($uid);
        my $submissions = $self->sqlSelectAllHashref(
                'id',
                'id, UNIX_TIMESTAMP(createtime) as date',
                'firehose',
                "uid = $uid_q and rejected = 'no' and (type = 'submission' or type = 'feed')",
                'order by createtime desc limit 5');

        foreach my $subid (keys %$submissions) {
                ($submissions->{$subid}{'title'}, $submissions->{$subid}{'introtext'}) =
                        $self->sqlSelect('title, introtext', 'firehose_text', "id = $subid");
        }

        return $submissions;
}

sub getLatestFriends {
        my($self, $uid) = @_;

        my $uid_q = $self->sqlQuote($uid);
        my $friends = $self->sqlSelectAllHashref(
                'person',
                'person',
                'people',
                "uid = $uid_q and type = 'friend'",
                "order by id limit 5"
        );

        foreach my $id (keys %$friends) {
                $friends->{$id}->{nickname} = $self->sqlSelect('nickname', 'users', "uid = $id");
        }

        return $friends;
}

sub getTagsDatapane {
        my($self, $uid, $requested_user, $private) = @_;

        my $form = getCurrentForm();
        my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });

        my $tagname = $form->{tagname} || '';
        $tagname = '' if !$tags_reader->tagnameSyntaxOK($tagname);
        my $tagnameid = $tags_reader->getTagnameidFromNameIfExists($tagname);

        if ($tagnameid) {
		# Show all user's tags for one particular tagname.
		my $tags_hr =
			$tags_reader->getGroupedTagsFromUser($uid, { tagnameid => $tagnameid });
                my $tags_ar = $tags_hr->{$tagname} || [ ];
                return slashDisplay('usertagsforname', {
                        useredit => $requested_user,
                        tagname  => $tagname,
                        tags     => $tags_ar,
                        notitle  => 1,
                }, { Page => 'users', Return => 1 });
        } else {
                my $tags_hr =
			$tags_reader->getGroupedTagsFromUser($uid, { include_private => $private });
                my $num_tags = 0;
                for my $tn (keys %$tags_hr) {
                        $num_tags += scalar @{ $tags_hr->{$tn} };
                }

		# Show all user's tagnames, with links to show all
		# tags for each particular tagname.
		my $tagname_ar = [ sort keys %$tags_hr ];
		return slashDisplay('usertagnames', {
                        useredit => $requested_user,
                        tagnames => $tagname_ar,
                        notitle  => 1,
                }, { Page => 'users', Return => 1 });
        }
}

#sub getBookmarksDatapane {
#        my($self, $uid, $requested_user) = @_;

#        my $tags_reader = getObject('Slash::Tags', { db_type => 'reader' });
#        my $tags_ar =
#		$tags_reader->getGroupedTagsFromUser($uid, { type => "urls", only_bookmarked => 1 });
#        return $tags_ar;
#}

sub getRelations {
        my($self, $requested_uid, $relation, $nick, $user_uid) = @_;

        my $zoo = getObject('Slash::Zoo', { db_type => 'reader' });
        my $people = $zoo->getRelationships($requested_uid, $relation);
        my $datapane;

        if (@$people) {
                $datapane = slashDisplay('plainlist', {
                        people   => $people,
                }, { Page => 'zoo', Return => 1 });
        } else {
		# Return a message stating the requested user has no such relationships.
		# Need better use of Zoo constants here.
		my %values = (
                        1 => 'nofriends',
                        2 => 'nofreaks',
                        3 => 'nofans',
                        4 => 'nofoes',
                        5 => 'nofriendsoffriends',
                        6 => 'nofriendsenemies',
                );
                my $value = $values{$relation} || 'noall';
                $value = 'your' . $value if ($requested_uid == $user_uid);
		$datapane = slashDisplay('data', {
                        uid      => $requested_uid,
                        nickname => $nick,
                        value    => $value,
                }, { Page => 'zoo', Return => 1 });
        }

        return $datapane;
}

sub getMarquee {
        my($self, $latest_comments, $latest_journals, $latest_submissions) = @_;

        my $latest_comment;
        $latest_comment->{'ts'} = 0;
        foreach my $latest_id (keys %$latest_comments) {
                my ($id, $ts) = ($latest_id, $latest_comments->{$latest_id}{'date'});
                ($latest_comment->{'id'}, $latest_comment->{'ts'})
                        = ($id, $ts) if ($ts > $latest_comment->{'ts'});
        }

        my $latest_journal;
        $latest_journal->{ts} = 0;
        foreach my $latest_id (keys %$latest_journals) {
                my ($id, $ts) = ($latest_id, $latest_journals->{$latest_id}{'date'});
                ($latest_journal->{'id'}, $latest_journal->{'ts'})
                        = ($id, $ts) if ($ts > $latest_journal->{'ts'});
        }

        my $latest_submission;
        $latest_submission->{ts} = 0;
        foreach my $latest_id (keys %$latest_submissions) {
                my ($id, $ts) = ($latest_id, $latest_submissions->{$latest_id}{'date'});
                ($latest_submission->{'id'}, $latest_submission->{'ts'})
                        = ($id, $ts) if ($ts > $latest_submission->{'ts'});
        }

        my $latest_thing;
        if (($latest_comment->{'ts'} > $latest_journal->{'ts'}) &&
            ($latest_comment->{'ts'} > $latest_submission->{'ts'})) {
                my $id = $latest_comment->{'id'};
                $latest_thing->{'type'} = 'comment';
                $latest_thing->{'id'} = $id;
                $latest_thing->{'sid'} = $latest_comments->{$id}{'sid'};
                $latest_thing->{'subject'} = $latest_comments->{$id}{'subject'};
                $latest_thing->{'body'} = $self->sqlSelect('comment', 'comment_text', "cid = $id");

        } elsif (($latest_journal->{'ts'} > $latest_comment->{'ts'}) &&
                 ($latest_journal->{'ts'} > $latest_submission->{'ts'})) {
                my $id = $latest_journal->{'id'};
                $latest_thing->{'type'} = 'journal';
                $latest_thing->{'id'} = $id;
                $latest_thing->{'subject'} = $latest_journals->{$id}{'description'};
                $latest_thing->{'body'} = $self->sqlSelect('article', 'journals_text', "id = $id");

        } elsif (($latest_submission->{'ts'} > $latest_comment->{'ts'}) &&
                 ($latest_submission->{'ts'} > $latest_journal->{'ts'})) {
                my $id = $latest_submission->{'id'};
                $latest_thing->{'type'} = 'submission';
                $latest_thing->{'id'} = $id;
                $latest_thing->{'subject'} = $latest_submissions->{$id}{'title'};
                $latest_thing->{'body'} = $latest_submissions->{$id}{'introtext'};
        }

        return $latest_thing;
}

sub getMarqueeFireHoseId {
	my($self, $marquee) = @_;
	my $fhid;
	if ($marquee && $marquee->{type}) {
		if ($marquee->{type} eq "submission") {
			$fhid = $marquee->{id};
		} elsif ($marquee->{type} eq "journal" || $marquee->{type} eq "comment") {
			my $fh_reader = getObject("Slash::FireHose", { db_type => "reader" });
			my $item = $fh_reader->getFireHoseByTypeSrcid($marquee->{type}, $marquee->{id});
			$fhid = $item->{id} if $item;

		}
	}
	return $fhid;
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
