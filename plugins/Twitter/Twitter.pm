package Slash::Twitter;

use strict;
use warnings;
use Twitter::API;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub push_story_to_twitter() {
     my ($self, $constants, $story) = @_;
     my $nt = Twitter::API->new_with_traits(
          traits => [ qw/Migration ApiMethods RetryOnError/ ],
          consumer_key => $constants->{twit_consumer_key},
          consumer_secret => $constants->{twit_consumer_secret},
          access_token => $constants->{twit_access_token},
          access_token_secret => $constants->{twit_access_token_secret},
     );
     if(! $nt->verify_credentials ) {
          print "push_story_to_twitter(): Not authorized\n";
          return 0;
     }
     $nt->update("$story->{title} - $story->{link}");
     return 1;
}

sub log_story_pushed() {
     my ($self, $slashdb, $story, $shown) = @_;
     my $data = {
          sid       => $story->{sid},
          title     => $story->{title},
     };
     my $rows = $slashdb->sqlInsert(
          "twitter_log",
          $data
     );
     if(defined($rows) && $rows == 0) {
          print "Failed to log sid $story->{sid} as pushed to Twitter.\n";
     }
     return;
}

sub trim_stories_table() {
     my ($self, $slashdb, $constants) = @_;
     $slashdb->sqlDo("DELETE FROM twitter_log WHERE time < DATE_SUB(NOW(), INTERVAL $constants->{discussion_archive_delay} DAY)");
     return;
}
