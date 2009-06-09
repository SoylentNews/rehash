package Slash::Edit;

use strict;
use Slash;
use Slash::Utility;
use Slash::Display;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}

sub getOrCreatePreview {
	my($self) = @_;
	my $user = getCurrentUser();
	return if $user->{is_anon};

	my $id = $self->sqlSelect("MAX(id)", "firehose", "uid = $user->{uid} AND preview='yes'");
	
	if ($id) {
		return $id;
	} else {
		my $fh = getObject("Slash::FireHose");
		my $id = $fh->createFireHose({ uid => $user->{uid}, preview => "yes"});
		return $id;
	}
}

sub showEditor {
	my($self, $options) = @_;

	my $p_id = $self->getOrCreatePreview();
	my $editor;
	$editor .=  "ID: $p_id<br>";
	

	my $fh = getObject("Slash::FireHose");
	my $p_item = $fh->getFireHose($p_id);
	$editor .= $fh->dispFireHose($p_item, { view_mode => 1 });
	
	$editor .= slashDisplay('editor', {}, { Page => 'edit', Return => 1 });
	return $editor;
}


1;

__END__
