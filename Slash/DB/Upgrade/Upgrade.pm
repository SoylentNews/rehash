package Slash::DB::Upgrade;

use Slash;
use Slash::DB;
use Slash::Install;
use base 'Slash::DB::Utility';

use strict;

#BEGIN {
#    use Exporter ();
#    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
#    $VERSION     = '0.01';
#    @ISA         = qw(Exporter);
    #Give a hoot don't pollute, do not export more than needed by default
#    @EXPORT      = qw();
#    @EXPORT_OK   = qw();
#    %EXPORT_TAGS = ();
#}


=head2 new 

 Usage     : constructor 
 Purpose   : initializes upgrade method; handles DB connection
 Returns   : itself, or 0 if DB connection failed
 Argument  : username as first arguement

See Also   : 

=cut

# C*P-ed from Install.pm
sub new
{
	my($class, $user) = @_;
	return undef unless $class->isInstalled();
	my $self = {};
	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;
	return undef unless $self->init();

	# XXX Anyone know why this is called directly?  We use $self->{slashdb}
	# at a number of places below and I can't figure out why we don't just
	# use getCurrentDB(). -- jamie
	# beats me! -- pudge
	$self->{slashdb} = Slash::DB->new($user);

	return $self;
}

=head2 getSchemaVersions 

 Usage:    : takes no arguments
 Purpose     : retrieves a table of all schema versions in the database 
 Returns   : hashref of master schema version and all plugins schema versions
 Argument  : username as first arguement

See Also   : 

=cut

sub getSchemaVersions
{
    my ($self) = @_;
    my $constants = getCurrentStatic();
    my $slashdb = getCurrentDB();

    my %schema_vers = ();

    # So in the database, we have key->value pairs for schema versioning
    # but not all keys exist; we assume a schema version of 0 in that
    # case
    my $current_versions = $slashdb->getDBSchemaVersions();

    # db_schema_core by itself references to all SQL not part of a plugin
    if (exists $current_versions->{db_schema_core}) {
        $schema_vers{core} = $current_versions->{db_schema_core};
    } else {
        $schema_vers{core} = 0;
    }


    # installed plugins exist as a list of keys under $constants->{'plugin'}
    # we only consider versions for plugins we have installed
    my $plugin_db_prefix = "db_schema_plugin_";

    # This might seem complicated, but the odds are there are plugins we never
    # have to touch, and this prevents us from manually having to add schema
    # rows to every single plugin (as well as providing nice failsafe logic)
    # such as bad plugin table names

    my $plugins = $constants->{plugin};
    while ( my ($key, $value) = each %$plugins ) {
        my $rowname = $plugin_db_prefix . $key;
        if (exists $current_versions->{$rowname}) {
            $schema_vers{$rowname} = int($current_versions->{$rowname});
         } else {
            $schema_vers{$rowname} = 0;
         }
    }

    return \%schema_vers;
}

#################### main pod documentation begin ###################
## Below is the stub of documentation for your module. 
## You better edit it!


=head1 NAME

Slash::DB::Upgrades - slash database upgrade system

=head1 SYNOPSIS

  use Slash::DB::Upgrades;
  blah blah blah


=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.


=head1 USAGE



=head1 BUGS



=head1 SUPPORT



=head1 AUTHOR

    Michael Casadevall
    SoylentNews
    mcasadevall@ubuntu.com
    http://soylentnews.org

=head1 COPYRIGHT

This program is free software licensed under the...

	The General Public License (GPL)
	Version 2, June 1991

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

#################### main pod documentation end ###################


1;
# The preceding line will help the module return a true value

