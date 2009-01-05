# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.

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

our $VERSION = $Slash::Constants::VERSION;

our %Verbs = (
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
	article	=> {
		name => 'Article',
	},
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

=item verb

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
		verb	=> $params->{verb},
		url	=> $params->{url} || "$constants->{absolutedir}/oai.pl", 
		args	=> $params->{args} || {}
	};

	my $xml;
	my $verb = $Verbs{$params->{verb}};
	if (! $verb) {
		$options->{error} = 'badVerb';
	} else {
		$xml = $self->$verb($options);
	}

	my $header = $self->head($options);
	my $footer = $self->foot($options);

	return $header . $xml . $footer;
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
	if ($metadataPrefix && !$Formats{$metadataPrefix}) {
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


sub ListIdsOrRecords {
	my($self, $options) = @_;
	my $xml;
	my %dates;

	# copy args
	my %args = map { $_ => $options->{args}{$_} } keys %{$options->{args}};
	my $resumptionToken	= delete $args{resumptionToken};

	if ($resumptionToken) {
		# resumptionToken is exclusive
		if (scalar(keys %{$options->{args}}) > 1) {
			push @{$options->{error}}, 'badArgument';
		}

		my $rt_args = $self->_parse_resumptionToken($resumptionToken);
		if (keys %$rt_args) {
			my $optargs = $options->{args};
			$optargs->{metadataPrefix}	= delete $rt_args->{metadataPrefix};
			$optargs->{set}			= delete $rt_args->{set};
			$optargs->{from}		= delete $rt_args->{from};
			$optargs->{'until'}		= delete $rt_args->{'until'};
			$options->{nextStart}		= delete $rt_args->{nextStart};
			%args = map { $_ => $options->{args}{$_} } keys %{$options->{args}};
			delete $args{resumptionToken};
		} else {
			push @{$options->{error}}, 'badResumptionToken';
		}

		return if $options->{error};
	}

	my $metadataPrefix	= delete $args{metadataPrefix};
	my $set			= delete $args{set};
	$dates{from}		= delete $args{from};
	$dates{'until'}		= delete $args{'until'};

	# metadataPrefix required
	if (keys %args || !$metadataPrefix) {
		push @{$options->{error}}, 'badArgument';
	}
	if ($metadataPrefix && !$Formats{$metadataPrefix}) {
		push @{$options->{error}}, 'cannotDisseminateFormat';
	}
	if ($set && !keys %Sets) {
		push @{$options->{error}}, 'noSetHierarchy';
	}
	return if $options->{error};

	if (defined $options->{nextStart} && $options->{nextStart} =~ /\D/) {
		$options->{error} = {
			badArgument => "nextStart must be an integer"
		};
		return;
	}

	for my $date (qw(from until)) {
		next unless $dates{$date};
		if ($dates{$date} =~ /^(\d{4})-(\d{2})-(\d{2})(T(\d{2}):(\d{2}):(\d{2})Z)?$/) {	
			if (!$4) {
				$dates{$date} .= $date eq 'from'
					? 'T00:00:00Z'
					: 'T23:59:59Z';
			}
		} else {
			$options->{error} = {
				badArgument => "Incorrectly formed '$date' date: $dates{$date}"
			};
			return;
		}
	}

	if ($dates{from} && $dates{'until'} && $dates{from} gt $dates{'until'}) {
		$options->{error} = {
			badArgument => "'from' date $dates{from} is greater than 'until' date $dates{until}"
		};
		return;
	}


	my($records, $next) = $self->_find_records($options, \%dates, $set);
	if (!@$records) {
		push @{$options->{error}}, 'noRecordsMatch';
		return;
	} else {
		$xml .= $self->_print_record($records, $options);
	}

	$xml .= $self->_print_resumptionToken($options, $next) if $next;

	# clean up ... we know if we are here, this is correct
	$options->{args} = { resumptionToken => $resumptionToken } if $resumptionToken; 

	return $xml;
}


sub ListIdentifiers {
	my($self, $options) = @_;
	$options->{identifiers} = 1;
	return $self->ListIdsOrRecords($options);
}


sub ListRecords {
	my($self, $options) = @_;
	$options->{records} = 1;
	return $self->ListIdsOrRecords($options);
}


sub ListMetadataFormats {
	my($self, $options) = @_;
	my $xml;

	# identifier is only allowed argument, and we ignore it at this time,
	# as we do the same format for everything
	# if we do support identifier, also support
	# idDoesNotExist and noMetadataFormats errors
	if (grep {$_ ne 'identifier' } keys %{$options->{args}}) {
		push @{$options->{error}}, 'badArgument';
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
   <oai-identifier xmlns="http://www.openarchives.org/OAI/2.0/oai-identifier"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai-identifier http://www.openarchives.org/OAI/2.0/oai-identifier.xsd">
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
			# XXX this could be better somehow ... probably a var
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
	# resumptionToken is the only allowed argument, and we ignore it at this time
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


sub head {
	my($self, $options) = @_;
	my $date    = $self->date2iso8601($options->{date}, 1);
	my $url     = $self->encode($options->{url}, 'link');

	my $args = '';
	# no args if error
	if (!$options->{error}) {
		$args = qq[ verb="$options->{verb}"];
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
						$errs->{$err}
					);
				} else {
					$third .= qq[ <error code="$err" />\n];
				}
			}
		}
		chomp $third;
	} else {
		$third = " <$options->{verb}>";	
	}

	return <<EOT;
<?xml version="1.0" encoding="UTF-8" ?>
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">
 <responseDate>$date</responseDate>
 <request$args>$url</request>
$third
EOT
}

sub foot {
	my($self, $options) = @_;
	my $close = $options->{error} ? '' : " </$options->{verb}>\n";
	return <<EOT;
$close</OAI-PMH>
EOT
}



# oai:slashdot.org:article/$id
sub _get_identifier {
	my($self, $identifier) = @_;
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $constants = getCurrentStatic();

	my $site = $constants->{basedomain};
	my $data = { identifier => $identifier };

	$identifier =~ m|^oai:\Q$site\E:(\w+)/(\w+)$|;
	$data->{type} = $1;
	$data->{id}   = $2;

	if ($data->{type} eq 'article') {
		my $record = $reader->getStory($data->{id});
		if ($record) {
			($data->{datestamp} = $record->{'archive_last_update'}) =~
				s{^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})}
				 {$1-$2-$3T$4:$5:$6Z}x;

			my $md = {};
			$md->{title}       = $record->{title};
			$md->{creator}     = $reader->getUser($record->{uid}, 'nickname');
			$md->{date}        = $record->{'time'};
			$md->{identifier}  = "$constants->{absolutedir}/article.pl?sid=$record->{sid}";

			$md->{description} = <<EOT;
<div>
$record->{introtext}
</div>
EOT
			$md->{description} .= <<EOT if $record->{bodytext};

<div>
$record->{bodytext}
</div>
EOT
			$md->{description} = parseSlashizedLinks(processSlashTags($md->{description}));


			my $topics = $reader->getStoryTopicsRendered($record->{stoid});
			my $tree = $reader->getTopicTree;
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
	my($self, $records, $options) = @_;
	my $xml;

	my $source = [ getCurrentStatic('basedomain') ];

	for my $record (@$records) {
		# XXX setSpec hardcoded for now
		my $identifier = $self->encode($record->{identifier}, 'link');
		my $datestamp  = $self->date2iso8601($record->{datestamp}, 1);
		$xml .= <<'EOT' unless $options->{verb} eq 'ListIdentifiers';
  <record>
EOT

		$xml .= sprintf(<<EOT, $identifier, $datestamp);
   <header>
    <identifier>%s</identifier>
    <datestamp>%s</datestamp>
    <setSpec>article</setSpec>
   </header>
EOT
		next if $options->{verb} eq 'ListIdentifiers';
		$xml .= <<'EOT';
   <metadata>
    <oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
               xmlns:dc="http://purl.org/dc/elements/1.1/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
EOT

		# same on all: publisher, rights, type, format, language
		# dunno: source, relation, coverage
		for my $dc (qw(source title creator subject description contributor date identifier)) {
			my $values;
			if ($dc eq 'source') {
				$values = $source;
			} else {
				next unless defined $record->{metadata}{$dc}
					&& length $record->{metadata}{$dc};
				$values = $record->{metadata}{$dc};
			}
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


sub _find_records {
	my($self, $options, $dates, $set) = @_;

	my $limit  = 100; # XXX var, oai_list_limit?
	my $reader = getObject('Slash::DB', { db_type => 'reader' });
	my $type = $options->{type} || 'article';
	my($records, @return);

	my $timecol = 'archive_last_update';

	my $start = $options->{nextStart} || 1;

	my @where;
	push @where, "$timecol >= '$dates->{from}'" if $dates->{from};
	push @where, "$timecol <= '$dates->{'until'}'" if $dates->{'until'};
	push @where,  "__ID__ >= $start";

	my $where = join ' AND ', @where;

	if ($type eq 'article') {
		$where =~ s/__ID__/stoid/;
		$records = $reader->sqlSelectAll(
			'stoid', 'stories', $where,
			"ORDER BY stoid LIMIT " . ($limit + 1)
		) || [];
	}

	for my $i (0 .. $limit-1) {
		my $record = $records->[$i] or last;
		my $identifier = $self->_create_identifier({ type => $type, id => $record->[0] });
		push @return, $self->_get_identifier($identifier);
	}

	my $next = $records->[$limit] ? $records->[$limit][0] : 0;
	return \@return, $next;
}

sub _print_resumptionToken {
	my($self, $options, $next) = @_;
	return unless $next;
	my $xml;

	my $resumptionToken = "nextStart=$next";
	for my $name (qw(metadataPrefix set from until)) {
		my $value = strip_attribute($options->{args}{$name});
		$resumptionToken .= "&$name=$value" if $value;
	}

	$xml = sprintf <<EOT, $self->encode($resumptionToken, 'link');
  <resumptionToken>%s</resumptionToken>
EOT

	return $xml;
}

sub _parse_resumptionToken {
	my($self, $resumptionToken) = @_;

	my(%rt_args, $error);

	my @pairs = split /&/, $resumptionToken;
	return unless @pairs;

	for my $pair (@pairs) {
		my($name, $value) = split /=/, $pair, 2;
		if ($name =~ /^(?:metadataPrefix|set|from|until|nextStart)$/) {
			$rt_args{$name} = $value;
		} else {
			return;
		}
	}

	return \%rt_args;
}

1;

__END__


=head1 SEE ALSO

Slash(3), Slash::XML(3), L<http://www.openarchives.org/OAI/openarchivesprotocol.html>.
