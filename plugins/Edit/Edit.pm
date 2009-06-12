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
		$self->setPreview($id, { preview_fhid => $fhid });
		return $id;
	}
}

sub savePreview {
	my($self, $options) = @_;
	my $user = getCurrentUser();
	my $form = getCurrentForm();
	return if $user->{is_anon} || !$form->{id};
	
	my $preview = $self->getPreview($form->{id});
	return if !$preview && $preview->{preview_id};

	return if $user->{uid} != $preview->{uid};

	my($p_data, $fh_data);

	$p_data->{introtext} = $form->{introtext};
	$p_data->{bodytext} = $form->{bodytext};

	$fh_data->{createtime} = $form->{createtime} if $form->{createtime} =~ /\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/;
	$fh_data->{media} = $form->{media};
	$fh_data->{dept} = $form->{dept};

	#XXXEdit strip / balance
	$fh_data->{introtext} = $form->{introtext};
	$fh_data->{bodytext} = $form->{bodytext};

	$self->setPreview($preview->{preview_id}, $p_data);
	$self->setFireHose($preview->{preview_fhid}, $fh_data);

}

sub showEditor {
	my($self, $options) = @_;

	my $preview_id = $self->getOrCreatePreview();
	my $editor;
	$editor .=  "PREVIEW ID: $preview_id<br>";

	my $preview = $self->getPreview($preview_id);
	

	my $fh = getObject("Slash::FireHose");
	my $p_item = $fh->getFireHose($preview->{preview_fhid});
	$editor .=  "PREVIEW FHID: $preview->{preview_fhid}<br>";
	if ($p_item && $p_item->{title} && $p_item->{introtext}) {
		$editor .= $fh->dispFireHose($p_item, { view_mode => 1, mode => "full" });
	}
	
	$editor .= slashDisplay('editor', { id => $preview_id, item => $p_item }, { Page => 'edit', Return => 1 });
	return $editor;
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__
