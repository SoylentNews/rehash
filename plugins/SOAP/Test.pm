package Slash::SOAP::Test;
use Slash::Utility;

sub get_user {
	my($self, $uid) = @_;
	return getCurrentDB()->getUser($uid);
}

1;
