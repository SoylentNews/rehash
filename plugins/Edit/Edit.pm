package Slash::Edit;

use strict;
use Slash;
use Slash::Utility;
use Slash::Display;

use base 'Slash::Plugin';

our $VERSION = $Slash::Constants::VERSION;


sub getOrCreatePreview {
	my($self) = @_;
	my $user = getCurrentUser();
	return if $user->{is_anon};

	my $id = $self->sqlSelect("MAX(preview_id)", "preview", "uid = $user->{uid}");
	
	if ($id) {
		return $id;
	} else {
		my $id = $self->createPreview({ uid => $user->{uid} });

		my $fh = getObject("Slash::FireHose");
		my $fhid = $fh->createFireHose({ uid => $user->{uid}, preview => "yes"});
		$self->setPreview({ preview_fhid => $fhid });
		return $id;
	}
}

sub showEditor {
	my($self, $options) = @_;

	my $preview_id = $self->getOrCreatePreview();
	my $editor;
	$editor .=  "ID: $preview_id<br>";

	my $preview = $self->getPreview($preview_id);
	

	my $fh = getObject("Slash::FireHose");
	my $p_item = $fh->getFireHose($preview->{preview_fhid});
	$editor .= $fh->dispFireHose($p_item, { view_mode => 1, mode => "full" });
	
	$editor .= slashDisplay('editor', { id => $preview_id, item => $p_item }, { Page => 'edit', Return => 1 });
	return $editor;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__
