# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2004 by Open Source Development Network. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::DB;

use strict;
use DBIx::Password;
use Slash::DB::Utility;
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

# FRY: Would you cram a sock in it, Bender?

# Registry of DBI DSNs => Slash::DB driver modules
# If you add another driver, make sure there's an entry here
my $dsnmods = {
	mysql	=> 'MySQL',
	Oracle	=> 'Oracle',
	Pg	=> 'PostgreSQL'
};

sub new {
	my($class, $user) = @_;
	my $dsn = DBIx::Password::getDriver($user);
	if (my $modname = $dsnmods->{$dsn}) {
		my $dbclass = ($ENV{GATEWAY_INTERFACE})
			? "Slash::DB::$modname"
			: "Slash::DB::Static::$modname";
		eval "use $dbclass"; die $@ if $@;

		# Bless into the class we're *really* wanting -- thebrain
		my $self = bless {
			virtual_user		=> $user,
			db_driver		=> $dsn,
			# See setPrepareMethod below -- thebrain
			_dbh_prepare_method	=> 'prepare_cached'
		}, $dbclass;
		$self->sqlConnect();
		return $self;
	} elsif ($dsn) {
		die "Database $dsn unsupported! (virtual user: $user)";
	} else {
		die "DBIx::Password returned *nothing* for virtual user $user DSN (is the username correct?)";
	}
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect
		if ! $ENV{GATEWAY_INTERFACE} && defined $self->{_dbh};
}

1;

__END__

=head1 NAME

Slash::DB - Database Class for Slash

=head1 SYNOPSIS

	use Slash::DB;
	my $object = Slash::DB->new("virtual_user");

=head1 DESCRIPTION

This package is the front end interface to slashcode.
By looking at the database parameter during creation
it determines what type of database to inherit from.

=head1 METHODS

=head2 createComment(FORM, USER, POINTS, DEFAULT_USER)

This is an awful method. You use it to create a new
comments. This will go away. It locks tables, so
fear calling it.

"Its like a party in my mouth and everyone threw up."

=over 4

=item Parameters

=over 4

=item FORM

FORM, as in a form structure. Pretty much no
good reason why we have to pass this.

=item USER

USER, as in a USER structure. Pretty much no
good reason why we have to pass this.

=item POINTS

Points for the comment.

=item DEFAULT_USER

Default user to use if the person is being a coward about
posting.

=back

=item Return value

Return -1 on failure, and maxcid otherwise.

=back

=head2 setModeratorLog(CID, SID, UID, VAL, REASON)

This set has some logic to it and is not a
generic set method. All values must be accounted
for or this will not work. Basically this
creates an entry in the moderator log.

=over 4

=item Parameters

=over 4

=item CID

Comment ID.

=item SID

Story ID.

=item UID

UID of the user doing the moderation.

=item VAL

Value for moderation

=item REASON

Reason for moderation

=back

=item Return value

No defined value.

=back

=head2 getMetamodComments(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getModeratorCommentLog(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getModeratorLogID(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 unsetModeratorlog(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getContentFilters()

This returns all content filters in an array of arrays.
It does not return filters that have been created but
not defined.

=over 4

=item Return value

This return an array of arrays. The order is currently
defined by the schema.

=back

=head2 createPollVoter(QID, AID)

Increment the poll count for a given answer.

=over 4

=item Parameters

=over 4

=item QID

QID is a question ID for polls.

=item AID

Answer ID for the poll

=back

=item Return value

No defined value.

=back

=head2 createSubmission(FORM)

This creates a submission. Passing in the
form is optional.

=over 4

=item Parameters

=over 4

=item FORM

Standard form structure.

=back

=item Return value

No defined value.

=back

=head2 getSessionInstance(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setContentFilter(FORM)

Save data into a filter.

=over 4

=item Parameters

=over 4

=item FORM

Optional form.

=back

=item Return value

Fixed KEY.

=back

=head2 createAccessLog(OP, DATA)

This creates an entry into the access log. Keep
in mind that this uses different environmental
variables for its entry.

=over 4

=item Parameters

=over 4

=item OP

Opcode for this entry

=item DATA

Optional data for the accesslog

=back

=item Return value

Fixed KEY.

=back

=head2 getDescriptions(CODETYPE, OPTIONAL, CACHE_FLAG)

The mother of all methods for HTML selects. It returns
a hash with key pairs pulled from the database. The
following are valid types:
sortcodes
statuscodes
tzcodes
tzdescription
dateformats
datecodes
commentmodes
threshcodes
postmodes
issuemodes
vars
topics
maillist
(this list is WAY out of date)

=over 4

=item Parameters

=over 4

=item CODETYPE

This is one of the valid types

=item OPTIONAL

Sometypes have an option flag

=item CACHE_FLAG

By placing a value in this parameter you force the database
to reload the caches hash for this type.

=back

=item Return value

Hash reference filled with the codes.

=back

=head2 getUserInstance(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteUser(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getUserAuthenticate(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getNewPasswd(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getUserUID(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getCommentsByUID(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createContentFilter(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createUser(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setVar(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setSession(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setBlock(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setDiscussion(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setTemplate(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getCommentChildren(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteComment(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getCommentPid(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setSection(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setStoriesCount(SID, COUNT)

You should call this whenever you delete comments
belonging to a story with the count of the number
of comments you deleted.

=over 4

=item Parameters

=over 4

=item SID

Valid Story ID

=item COUNT

Count which will be subtracted from a stories comment count

=back

=item Return value

None Returned.

=back

=head2 getSectionTitle(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteSubmission(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteSession(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteAuthor(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteTopic(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 revertBlock(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteTemplate(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteSection(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteContentFilter(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 saveTopic(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 saveBlock(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 saveColorBlock(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSectionBlock(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSectionBlocks(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getAuthorDescription(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 isPollOpen(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 hasVotedIn(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 savePollQuestion(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getPollQuestionList(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getPollAnswers(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getPollQuestions(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteStory(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteStoryAll(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setStory(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSubmissionLast(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 updateFormkeyId(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createFormkey(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 checkFormkey(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 checkTimesPosted(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 formSuccess(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 formFailure(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createAbuse(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 checkForm(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 currentAdmin(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getTopNewsstoryTopics(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getPoll(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSubmissionsSections(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSubmissionsPending(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSubmissionCount(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getPortals(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getPortalsCommon(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 countComments(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 countStory(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 checkForMetaModerator(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getAuthorNames(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getStoryByTime(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 countStories(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setModeratorVotes(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setMetaMod(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 countUsers(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 countStoriesStuff(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 countStoriesAuthors(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 countPollquestions(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createVar(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 deleteVar(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setCommentForMod(KEY)

Adjust a comment in the database for being moderated.  This only
affects the comment data, not the data for the user moderating
or being moderated, doesn't log to moderatorlog, etc.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

If the moderation failed for some reason, undef.  Otherwise, a
numeric value indicating the comment's new point score.  If the
new point score is 0, "0 but true" is returned.

=back

=head2 countUsersIndexSlashboxesByBid(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getCommentReply(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getCommentsForUser(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getComments(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getStoriesEssentials(KEY)

Get basic information about stories, suitable for displaying headline type information
and designed to be fed to getOlderStories.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getCommentsTop(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSubmissionsMerge(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setSubmissionsMerge(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSubmissionForUser(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getIsTroll(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createDiscussion(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createStory(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 updateStory(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSlashConf(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 autoUrl(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getUrlFromTitle(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getTime(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getDay(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getStoryList(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getPollVotesMax(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getStory(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getAuthor(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getAuthors(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getPollQuestion(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getDiscussion(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getBlock(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getTemplate(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getTemplateByName(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getTopic(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getTopics(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getTemplates(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getContentFilter(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSubmission(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSection(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSections(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getModeratorLog(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getNewStory(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getVar(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 setUser(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getUser(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getStories(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getSessions(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createBlock(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createTemplate(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 createMenuItem(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getMenuItems(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getMenus(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 sqlReplace(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 getKeys(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 sqlTableExists(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 sqlSelectColumns(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back

=head2 generatesession(KEY)

I am the default documentation, short and stout.

=over 4

=item Parameters

=over 4

=item KEY

Key, as in the KEY

=back

=item Return value

Fixed KEY.

=back


=head1 SEE ALSO

Slash(3), Slash::DB::Utility(3).

=cut
