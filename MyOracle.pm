package MyOracle;

use DBI;
use DBD::Oracle qw(:ora_session_modes);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = {
    dbh => "",
    dbid => 0,
    dbname => "",
    hostname => "",
    instance_name => "",
    instance_number => $args{instance_number} || 0,
    datafiles => {}
  };

  bless $self, $class;

  #$self->connect();
  return $self;
}

# ============================================================================================================
sub dbh             { my ($self)=@_; return $self->{dbh};             }
sub dbid            { my ($self)=@_; return $self->{dbid};            }
sub dbname          { my ($self)=@_; return $self->{dbname};          }
sub hostname        { my ($self)=@_; return $self->{hostname};        }
sub instance_name   { my ($self)=@_; return $self->{instance_name};   }
sub instance_number { my ($self)=@_; return $self->{instance_number}; }

# ============================================================================================================
sub connect {
  my ($self)=@_;

  delete $ENV{TWO_TASK};
  $self->{dbh} = DBI->connect("dbi:Oracle:", "", "", {ora_session_mode=>ORA_SYSDBA}) || return 1;

  if ($self->_request_db_informations() == 0) { return 1; }
  return 0;
}

# ============================================================================================================
sub _request {
  my ($self, $query)=@_;

  my $dbh=$self->{dbh};

  my $sth=$dbh->prepare($query) || return 0;
  $sth->execute() || return 0;

  return $sth;
}

# ============================================================================================================
sub _request_db_informations {
  my ($self)=@_;

  my $instance_number=$self->{instance_number};

  my $query="select D.dbid,
                    D.name,
                    I.host_name,
                    I.instance_name,
                    I.instance_number
             from
               v\$database D,
               gv\$instance I
             where
               instance_number=decode($instance_number, 0, (select instance_number from v\$instance), $instance_number)";

  my $sth=$self->_request($query);
  if (! $sth) { return 0; }

  my $row = $sth->fetchrow_hashref();

  $self->{dbid} = $row->{DBID};
  $self->{dbname} = $row->{NAME};
  $self->{hostname} = lc($row->{HOST_NAME});
  $self->{instance_name} = $row->{INSTANCE_NAME};
  $self->{instance_number} = $row->{INSTANCE_NUMBER};

  $self->{hostname}=~s/\..*//;
  $self->{hostname}=lc($self->{hostname});

  return 1;
}

# ============================================================================================================
sub get_db_informations {
  my ($self)=@_;

  my $query="select open_mode,
                    database_role,
                    protection_mode,
                    protection_level,
                    switchover_status,
                    standby_became_primary_scn
             from
               v\$database";

  my $sth=$self->_request($query);
  if (! $sth) { return 0; }

  return $sth->fetchrow_hashref();
}

# ============================================================================================================
sub get_datafiles {
  my ($self)=@_;

  my $datafiles=$self->{datafiles};

  my $query="select file_id,
                    file_name
             from
               dba_data_files";

  my $sth=$self->_request($query);
  if (! $sth) { return 0; }

  while (my $row = $sth->fetchrow_hashref()) {
    my $file_id=$row->{FILE_ID};
    my $file_name=$row->{FILE_NAME} || "";

    $datafiles->{$file_name}=$file_id;
    $datafiles->{$file_id}=$file_name;
  }

  return $datafiles;
}

1;
