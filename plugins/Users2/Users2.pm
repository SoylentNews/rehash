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
                "sid, cid, subject, points, reason, UNIX_TIMESTAMP(date) as date",
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
                "uid = $uid_q and (type = 'submission' or type = 'feed')",
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

sub getLatestBookmarks {
        my($self, $uid, $latest_journals, $latest_submissions) = @_;

        # Get the latest n bookmarks. These could be contained in journals and
        # submissions, so we want journal size + submissions size + 5.
        #my $num_bookmarks = scalar(keys %$latest_journals) + scalar(keys %$latest_submissions) + 5;
        my $uid_q = $self->sqlQuote($uid);
        my $bookmarks_reader = getObject('Slash::Bookmark');
        my $latest_bookmarks = $bookmarks_reader->getRecentBookmarksByUid($uid_q, 5);

        # Make bookmarks unique against journals
        my $bookmark_count = 0;
        foreach my $bookmark (@$latest_bookmarks) {
                foreach my $journal (keys %$latest_journals) {
                        if ($bookmark->{initialtitle} eq $latest_journals->{$journal}->{description}) {
                                delete @$latest_bookmarks[$bookmark_count];
                                last;
                        }
                }
                ++$bookmark_count;
        }

        # Make bookmarks unique against submissions
        $bookmark_count = 0;
        foreach my $bookmark (@$latest_bookmarks) {
                foreach my $submission (keys %$latest_submissions) {
                        if ($bookmark->{initialtitle} eq $latest_submissions->{$submission}->{title}) {
                                delete @$latest_bookmarks[$bookmark_count];
                                last;
                        }
                }
                ++$bookmark_count;
        }

        return $latest_bookmarks;
}

sub getCommentsDatapane {
        my($self, $uid, $user, $requested_user) = @_;
        my $commentstruct = [];
        my $form = getCurrentForm();
        my $constants = getCurrentStatic();

        my $min_comment = $form->{min_comment} || 0;
        $min_comment = 0 unless $user->{seclev} > $constants->{comments_more_seclev}
                || $constants->{comments_more_seclev} == 2 && $user->{is_subscriber};
        my $comments_wanted = $user->{show_comments_num} || $constants->{user_comment_display_default};
        my $commentcount = $self->countCommentsByUID($uid);
        my $comments = $self->getCommentsByUID($uid, $comments_wanted, $min_comment) if $commentcount;

        if (ref($comments) eq 'ARRAY') {
                my $kinds = $self->getDescriptions('discussion_kinds');
                for my $comment (@$comments) {
                       # This works since $sid is numeric.
                       $comment->{replies} = $self->countCommentsBySidPid($comment->{sid}, $comment->{cid});

                # This is ok, since with all luck we will not be hitting the DB
                # ...however, the "sid" parameter here must be the string
                # based SID from either the "stories" table or from
                # pollquestions.
                my $discussion = $self->getDiscussion($comment->{sid});

                        if ($kinds->{ $discussion->{dkid} } =~ /^journal(?:-story)?$/) {
                                $comment->{type} = 'journal';
                        } elsif ($kinds->{ $discussion->{dkid} } eq 'poll') {
                                $comment->{type} = 'poll';
                        } else {
                                $comment->{type} = 'story';
                        }
                        $comment->{disc_title}  = $discussion->{title};
                        $comment->{url} = $discussion->{url};
                }
        }

        my $mod_reader = getObject("Slash::$constants->{m1_pluginname}", { db_type => 'reader' });
        my $datapane = slashDisplay('u2CommentsDatapane', {
                nick           => $requested_user->{nickname},
                useredit       => $requested_user,
                nickmatch_flag => ($user->{uid} == $uid ? 1 : 0),
                commentstruct  => $comments,
                commentcount   => $commentcount,
                min_comment    => $min_comment,
                reasons        => $mod_reader->getReasons(),
                karma_flag     => 0,
                admin_flag     => $user->{is_admin},
        }, { Page => 'users', Return => 1});

        return $datapane;
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
			$tags_reader->getGroupedTagsFromUser($uid, { tagnameid => $tagnameid },
				{ limit => 5000, orderby => 'tagid', orderdir => 'DESC' });
                my $tags_ar = $tags_hr->{$tagname} || [ ];
                return slashDisplay('usertagsforname', {
                        useredit => $requested_user,
                        tagname  => $tagname,
                        tags     => $tags_ar,
                        notitle  => 1,
                }, { Page => 'users', Return => 1 });
        } else {
                my $tags_hr =
			$tags_reader->getGroupedTagsFromUser($uid, { include_private => $private },
				{ limit => 5000, orderby => 'tagid', orderdir => 'DESC' });
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

sub getFireHoseMarquee {
	my ($self, $uid) = @_;
	my $fh = getObject("Slash::FireHose");

	my $fhe_opts = {
		type 		=> ['journal', 'submission', 'comment', 'feed'], 
		orderby 	=> 'createtime', 
		orderdir 	=> 'DESC', 
		color 		=> 'black',
		duration 	=> '-1',
		limit		=> 1,
		uid		=> $uid
	};

	my($items, $results, $count, $future_count, $day_num, $day_label, $day_count) = $fh->getFireHoseEssentials($fhe_opts);

	return @$items >=1 ? $items->[0]: 0;
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

sub truncateMarquee {
        my($self, $marquee) = @_;

        my $text;
        my $linebreak = qr{(?:
                <br>\s*<br> |
                </?p> |
                </(?:
                        div | (?:block)?quote | [oud]l
                )>
        )}x;
	my $min_chars = 50;
        my $max_chars = 1500;
        my $orig_len = length($marquee->{body});

	if (length($marquee->{body}) < $min_chars) {
                $text = $marquee->{body};
        } else {
                $text = $1 if $marquee->{body} =~ m/^(.{$min_chars,$max_chars})?$linebreak/s;
        }

        $text ||= chopEntity($marquee->{body}, $max_chars);
        local $Slash::Utility::Data::approveTag::admin = 1;
        $text = strip_html($text);
        $text = balanceTags($text, { admin => 1 });
        $text = addDomainTags($text);

        $marquee->{body} = $text;

        if ($orig_len > length($text)) {
                $marquee->{truncated} = 1;
        }

        return $marquee;

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
