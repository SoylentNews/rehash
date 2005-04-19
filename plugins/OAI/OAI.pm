# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

package Slash::XML::OAI;

=head1 NAME

Slash::XML::OAI - Perl extension for OAI2 Repository Responses


=head1 SYNOPSIS

	use Slash::XML;
	xmlDisplay(%data);


=head1 DESCRIPTION

LONG DESCRIPTION.


=head1 EXPORTED FUNCTIONS

=cut

use strict;
use Slash;
use Slash::Utility;
use XML::RSS;
use base 'Slash::XML';
use vars qw($VERSION);

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

our %Requests = (
	GetRecord		=> \&GetRecord,
	Identify		=> \&Identify,
	ListIdentifiers		=> \&ListIdentifiers,
	ListMetadataFormats	=> \&ListMetadataFormats,
	ListRecords		=> \&ListRecords,
	ListSets		=> \&ListSets,
);

our %Formats = (
	oai_dc => {
		schema    => 'http://www.openarchives.org/OAI/2.0/oai_dc.xsd',
		namespace => 'http://www.openarchives.org/OAI/2.0/oai_dc/',
	}
);

our %Sets = (
#	article	=> {
#		name => 'Article',
#	},
);


#========================================================================

=head2 create(PARAM)

Creates OAI repository responses.

=over 4

=item Parameters

=over 4

=item PARAM

Hashref of parameters.  Currently supported options are below.

=over 4

=item request

Required.  Must be one of C<GetRecord>, C<Identify>, C<ListIdentifiers>,
C<ListMetadataFormats>, C<ListRecords>, C<ListSets>.

=back

=back

=item Return value

The complete XML data as a string.

=back

=cut

sub create {
	my($class, $params) = @_;
	my $self = bless {}, $class;

	my $constants = getCurrentStatic();
	my $gSkin = getCurrentSkin();

	my $options = {
		request	=> $params->{request},
		url	=> $params->{url} || "$constants->{absolutedir}/oai.pl", 
		args	=> $params->{args} || {}
	};

	my $xml;
	my $request = $Requests{$params->{request}};
	if (! $request) {
		$options->{error} = 'badVerb';
	} else {
		$xml = $self->$request($options);
	}

	my $header = $self->header($options);
	my $footer = $self->footer($options);

	return $header . $xml . $footer;
}


# oai:slashdot.org:article/$id
sub _get_identifier {
	my($self, $identifier) = @_;
	my $slashdb = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();

	my $site = $constants->{basedomain};
	my $data = { identifier => $identifier };

	$identifier =~ m|^oai:\Q$site\E:(\w+)/(\w+)$|;
	$data->{type} = $1;
	$data->{id}   = $2;

	if ($data->{type} eq 'article') {
		my $record = $slashdb->getStory($data->{id});
		if ($record) {
			$data->{datestamp} = $record->{'time'};

			my $md = {};
			$md->{title}       = $record->{title};
			$md->{creator}     = $slashdb->getUser($record->{uid}, 'nickname');
			$md->{description} = $record->{introtext} . "\n<p>\n" . $record->{bodytext};
			$md->{date}        = $record->{'time'};
			$md->{identifier}  = "$constants->{absolutedir}/article.pl?sid=$record->{sid}";

			my $topics = $slashdb->getStoryTopicsRendered($record->{stoid});
			my $tree = $slashdb->getTopicTree;
			$md->{subject} = [
				map { $tree->{$_}{keyword} }
				@$topics
			];

			$data->{metadata}  = $md;
		}
	}

	return $data;
}

sub _create_identifier {
	my($self, $data) = @_;
	my $site = getCurrentStatic('basedomain');
	my $identifier = 'oai:';

	$identifier .= $site;
	$identifier .= ":$data->{type}/$data->{id}";

	return $identifier;
}

sub _print_record {
	my($self, $records) = @_;
	my $xml;

	for my $record (@$records) {
		# setSpec not included now, as no sets for now
		my $identifier = $self->encode($record->{identifier}, 'link');
		my $datestamp  = $self->date2iso8601($record->{datestamp}, 1);
		$xml .= sprintf(<<EOT, $identifier, $datestamp);
  <record>
   <header>
    <identifier>%s</identifier>
    <datestamp>%s</datestamp>
   </header>
   <metadata>
    <oai_dc:dc
     xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
     xmlns:dc="http://purl.org/dc/elements/1.1/"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/
     http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
EOT

		# same on all: publisher, rights, type, format, language
		# dunno: source, relation, coverage
		for my $dc (qw(title creator subject description contributor date identifier)) {
			next unless defined $record->{metadata}{$dc}
				&& length $record->{metadata}{$dc};

			my $values = $record->{metadata}{$dc};
			unless (ref $values eq 'ARRAY') {
				$values = [ $values ];
			}

			for (@$values) {
				my $value = $dc eq 'date'
					? $self->date2iso8601($_, 1)
					: $self->encode($_, 'link');
				$xml .= sprintf(<<EOT, $dc, $value, $dc);
     <dc:%s>%s</dc:%s>
EOT
			}
		}
		$xml .= <<EOT;
    </oai_dc:dc>
   </metadata>
  </record>
EOT
	}

	return $xml;
}

sub GetRecord {
	my($self, $options) = @_;
	my $xml;

	# copy args
	my %args = map { $_ => $options->{args}{$_} } keys %{$options->{args}};
	my $identifier     = delete $args{identifier};
	my $metadataPrefix = delete $args{metadataPrefix};

	if (keys %args || !$identifier || !$metadataPrefix) {
		push @{$options->{error}}, 'badArgument';
	}
	if (!$Formats{$metadataPrefix}) {
		push @{$options->{error}}, 'cannotDisseminateFormat';
	}

	my $record = $self->_get_identifier($identifier);
	if (!$record->{metadata}) {
		push @{$options->{error}}, 'idDoesNotExist';
	}
	return if $options->{error};

	$xml = $self->_print_record([$record]);

	return $xml;
}


sub ListIdentifiers {
	my($self, $options) = @_;
	my $xml;

	return $xml;
}


sub ListRecords {
	my($self, $options) = @_;
	my $xml;

	return $xml;
}


sub ListMetadataFormats {
	my($self, $options) = @_;
	my $xml;

	# identifier is only allowed argument, and we ignore it at this time,
	# as we do the same format for everything
	# if we do support identifier, also support
	# idDoesNotExist and noMetadataFormats errors
	if (grep {$_ ne 'identifier' } keys %{$options->{args}}) {
		$options->{error} = 'badArgument';
		return;
	}

	for my $prefix (keys %Formats) {
		my $schema    = $self->encode($Formats{$prefix}{schema},    'link');
		my $namespace = $self->encode($Formats{$prefix}{namespace}, 'link');
		$xml .= <<EOT;
  <metadataFormat>
   <metadataPrefix>$prefix</metadataPrefix>
   <schema>$schema</schema>
   <metadataNamespace>$namespace</metadataNamespace>
  </metadataFormat>
EOT
	}

	return $xml;
}


{
# compression currently unsupported
my @elements = qw(
	repositoryName
	baseURL
	protocolVersion
	adminEmail
	earliestDatestamp
	deletedRecord
	granularity
);
#	compression

my @descriptions;
push @descriptions, <<'EOT';
   <oai-identifier 
    xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai-identifier 
    http://www.openarchives.org/OAI/2.0/oai-identifier.xsd">
   <scheme>oai</scheme>
   <repositoryIdentifier>DLIST.OAI2</repositoryIdentifier>
   <delimiter>:</delimiter>
   <sampleIdentifier>oai:DLIST.OAI2:23</sampleIdentifier>
  </oai-identifier>
EOT

sub Identify {
	my($self, $options) = @_;
	my $xml;
	my $constants = getCurrentStatic();

	if (keys %{$options->{args}}) {
		$options->{error} = 'badArgument';
		return;
	}

	for my $el (@elements) {
		my $value;
		if ($el eq 'repositoryName') {
			$value = "$constants->{sitename} OAI Repository",
		} elsif ($el eq 'baseURL') {
			$value = $options->{url},
		} elsif ($el eq 'protocolVersion') {
			$value = '2.0';
		} elsif ($el eq 'adminEmail') {
			# we could use a new var for this, and have multiple values
			$value = $constants->{adminmail};
		} elsif ($el eq 'earliestDatestamp') {
			# XXX this should be better somehow ... probably a var
			$value = Slash::XML->date2iso8601(0, 1);
		} elsif ($el eq 'deletedRecord') {
			# no, persistent, transient
			$value = 'no';
		} elsif ($el eq 'granularity') {
			$value = 'YYYY-MM-DDThh:mm:ssZ';
		}

		$xml .= sprintf("  <%s>%s</%s>\n",
			$el, $self->encode($value, 'link'), $el,
		);
	}

	if (@descriptions) {
		$xml .= "  <description>\n$_  </description>\n"
			for @descriptions;
	}

	return $xml;
}
}


sub ListSets {
	my($self, $options) = @_;
	my $xml;

	if (!keys %Sets) {
		push @{$options->{error}}, 'noSetHierarchy';
	}
	# resumptionToken is only allowed argument, and we ignore it at this time
	if (grep {$_ ne 'resumptionToken' } keys %{$options->{args}}) {
		push @{$options->{error}}, 'badArgument';
	}
	if ($options->{args}{resumptionToken}) {
		push @{$options->{error}}, 'badResumptionToken';
	}
	return if $options->{error};

	for my $set (keys %Sets) {
		$xml .= sprintf(<<EOT, map { $self->encode($_, 'link') } $set, $Sets{$set}{name});
  <set>
   <setSpec>%s</setSpec>
   <setName>%s</setName>
  </set>
EOT
	}

	return $xml;
}


sub header {
	my($self, $options) = @_;
	my $date    = $self->date2iso8601($options->{date}, 1);
	my $url     = $self->encode($options->{url}, 'link');

	my $args = '';
	# no args if error
	if (!$options->{error}) {
		$args = qq[ verb="$options->{request}"];
		for my $key (keys %{$options->{args}}) {
			my $val = strip_attribute($options->{args}{$key}, 'link');
			$args .= qq[ $key="$val"];
		}
	}

	# third param is results, unless error, in which case it is the error
	my $third;
	if ($options->{error}) {
		my $errs = $options->{error};
		if (!ref $errs) {
			$errs = [ $errs ];
		}

		if (ref $errs eq 'ARRAY') {
			for my $err (@$errs) {
				$third .= qq[ <error code="$err" />\n];
			}
		} elsif (ref $errs eq 'HASH') {
			for my $err (keys %$errs) {
				my $str = $self->encode($errs->{$err});
				if ($str) {
					$third .= sprintf(
						qq[ <error code="$err">%s</error>\n],
					);
				} else {
					$third .= qq[ <error code="$err" />\n];
				}
			}
		}
		chomp $third;
	} else {
		$third = " <$options->{request}>";	
	}

	return <<EOT;
<?xml version="1.0" encoding="UTF-8" ?>
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/
         http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
 <responseDate>$date</responseDate>
 <request$args>$url</request>
$third
EOT
}

sub footer {
	my($self, $options) = @_;
	my $close = $options->{error} ? '' : " </$options->{request}>\n";
	return <<EOT;
$close</OAI-PMH>      
EOT
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::XML(3), L<http://www.openarchives.org/OAI/openarchivesprotocol.html>.

=head1 VERSION

$Id$
