package Slash::SOAP::Test;
use Slash::Utility;

sub get_nickname {
	my($self, $uid) = @_;
	return getCurrentDB()->getUser($uid, "nickname");
}

sub get_uid {
	my($self, $nickname) = @_;
	return getCurrentDB()->getUserUID($nickname);
}

1;
