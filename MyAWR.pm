package MyAWR;
use base qw(MyOracle);

use Storable qw(nstore_fd fd_retrieve);
use Common;

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  # %args : instance_number
  # %args : begin_snap_id
  # %args : end_snap_id

  my $self = $class->SUPER::new(%args);

  $self->{snapshot_dates}={};    # $snapshot_dates->{$snap_id}->{end_interval_time}=$end_interval_time; (format "yyyy/mm/dd hh24:mi")
  $self->{data}={};              # data from dba_hist_... views
  $self->{begin_snap_id}=$args{begin_snap_id} || 0;
  $self->{end_snap_id}=$args{end_snap_id} || 0;

  bless $self, $class;

  return $self;
}

# ============================================================================================================
sub connect {
  my ($self)=@_;

  my $rc=$self->SUPER::connect();

  if ($rc == 0) {
    my $row=$self->get_db_informations();
    my $open_mode=$row->{OPEN_MODE} || "";

    if ($open_mode=~m/READ/) { $self->get_snapshot_dates(); }
  }

  return $rc;
}

# ============================================================================================================
sub data           { my ($self)=@_; return $self->{data};           }
sub snapshot_dates { my ($self)=@_; return $self->{snapshot_dates}; }

# ============================================================================================================
sub get_snapshot_dates {
  my ($self)=@_;

  my $instance_number=$self->{instance_number};
  my $begin_snap_id=$self->{begin_snap_id};
  my $end_snap_id=$self->{end_snap_id};

  my @conditions=("instance_number=$instance_number");
  if ($begin_snap_id) { push @conditions, "snap_id >= $begin_snap_id-1"; }
  if ($end_snap_id)   { push @conditions, "snap_id <= $end_snap_id";     }
  my $query_condition=join(" and ", @conditions);

  my $format="yyyy/mm/dd hh24:mi";

  my $query="select snap_id,
                    to_char(end_interval_time, '$format') end_interval_time,
                    to_char(startup_time, '$format')      startup_time
             from
               dba_hist_snapshot
             where
               $query_condition
             order by 1";

  my $sth=$self->_request($query);
  if (! $sth) { return 1; }

  my $snapshot_dates=$self->{snapshot_dates};

  my $common=Common->new();

  my %p_row=();
  while (my $row = $sth->fetchrow_hashref()) {
    my $snap_id=$row->{SNAP_ID};
    my $end_interval_time=$row->{END_INTERVAL_TIME} || "";
    my $startup_time=$row->{STARTUP_TIME} || "";

    $snapshot_dates->{$snap_id}->{end_interval_time}=$end_interval_time;

    my $p_end_interval_time=$p_row{END_INTERVAL_TIME} || "";

    if ($p_end_interval_time) {
      if (($startup_time) && ($startup_time gt $p_end_interval_time)) {
        $snapshot_dates->{$snap_id}->{end_interval_delta_seconds}=$common->get_dates_delta($startup_time, $end_interval_time);
      }
      else {
        $snapshot_dates->{$snap_id}->{end_interval_delta_seconds}=$common->get_dates_delta($p_end_interval_time, $end_interval_time);
      }
    }

    %p_row=%{$row};
  }
}

# ============================================================================================================
sub get_min_snap_id {
  my ($self)=@_;

  my $snapshot_dates=$self->{snapshot_dates};
  my ($snap_id) = sort { $a <=> $b } keys %{$snapshot_dates};
  return $snap_id;
}

# ============================================================================================================
sub get_max_snap_id {
  my ($self)=@_;

  my $snapshot_dates=$self->{snapshot_dates};
  my ($snap_id) = reverse sort { $a <=> $b } keys %{$snapshot_dates};
  return $snap_id;
}

# ============================================================================================================
sub get_all_snap_ids {
  my ($self)=@_;

  my $snapshot_dates=$self->{snapshot_dates};
  return sort { $a <=> $b } keys %{$snapshot_dates}
}

# ============================================================================================================
sub snapshot_date {
  my ($self, $snap_id)=@_;

  return $self->{snapshot_dates}->{$snap_id}->{end_interval_time} || "";
}

# ============================================================================================================
sub snapshot_delta {
  my ($self, $snap_id)=@_;

  my $snapshot_dates=$self->{snapshot_dates};

  return $snapshot_dates->{$snap_id}->{end_interval_delta_seconds} || 0;
};

# ============================================================================================================
sub dump_data {
  my ($self, %args)=@_;

  my $gzip=lc($args{gzip} || "yes");      # gzip: yes/no
  my $force=lc($args{force} || "no");     # ecrase le dump existant (s'il existe) yes/no
  my $file_name=$args{file_name} || "";   # le nom du fichier dump

  my $data=$self->{data};

  if (! $file_name) {
    $file_name=sprintf("AWR_%s_%d_%s_%s_%d_%d.txt%s", $self->{instance_name},
                                                      $self->{instance_number},
                                                      $self->{hostname},
                                                      $self->{view},
                                                      $self->get_min_snap_id(),
                                                      $self->get_max_snap_id(),
                                                      $gzip eq "yes" ? ".gz" : "");
  }

  if ((-f $file_name) && ($force eq "no")) { return 2; }

  my %database_info=("view"=>$self->{view},
                     "dbid"=>$self->{dbid},
                     "dbname"=>$self->{dbname},
                     "hostname"=>$self->{hostname},
                     "instance_name"=>$self->{instance_name},
                     "instance_number"=>$self->{instance_number});

  my $fh;
  if ($gzip eq "yes") {
    open $fh, "|-", "gzip -c > $file_name" or die "Cannot open gzip pipe to $file_name: $!";
  }
  else {
    open($fh, ">$file_name") or die "Cannot open file $file_name for writing: $!";
  }

  my $snapshot_dates=$self->{snapshot_dates};

  # $Data::Dumper::Sortkeys = 1; # Not needed for Storable
  # print $fh Data::Dumper->Dump([$snapshot_dates], ["*snapshot_dates"]);
  # print $fh Data::Dumper->Dump([$data], ["*data"]);
  # print $fh Data::Dumper->Dump([\%database_info], ["*database_info"]);
  eval {
    nstore_fd([$snapshot_dates, $data, \%database_info], $fh);
  };
  if ($@) {
    close $fh;
    # TODO: Consider logging the error $@
    return 1; # Indicate error
  }
  close $fh;

  return 0;
}

# ============================================================================================================
sub read_data_from_file {
  my ($self, $datafile)=@_;

  my $self_data=$self->{data};
  my $self_snapshot_dates=$self->{snapshot_dates};

  my $fh;
  if ($datafile=~m/\.gz$/) {
    # ----- si le fichier est compresse -----
    open $fh, "-|", "gzip -dc \"$datafile\"" or die "Cannot open gzip process for $datafile: $!";
  }
  else {
    # ----- si le fichier n'est pas compresse -----
    open $fh, "<", $datafile or die "Cannot open file $datafile for reading: $!";
  }

  my $retrieved_data;
  eval {
    $retrieved_data = fd_retrieve($fh);
  };
  if ($@) {
    close $fh;
    # TODO: Consider logging the error $@
    return 1; # Indicate error
  }
  close $fh;

  my ($retrieved_snapshot_dates_ref, $retrieved_data_hash_ref, $retrieved_database_info_ref) = @$retrieved_data;

  # ----- verification du meme dbid, instance_number, view -----
  # Initialize $self properties if they are not already set, using data from the file.
  $self->{view}            = $self->{view}            || $retrieved_database_info_ref->{view};
  $self->{instance_number} = $self->{instance_number} || $retrieved_database_info_ref->{instance_number};
  $self->{dbid}            = $self->{dbid}            || $retrieved_database_info_ref->{dbid};

  # Now perform the verification checks.
  if (   (($self->{view})            && ($self->{view}            ne $retrieved_database_info_ref->{view}))
      || (($self->{instance_number}) && ($self->{instance_number} ne $retrieved_database_info_ref->{instance_number}))
      || (($self->{dbid})            && ($self->{dbid}            ne $retrieved_database_info_ref->{dbid}))) { return 2; }

  # Merge the retrieved data into the object's existing data structures.
  %$self_data = (%$self_data, %$retrieved_data_hash_ref);
  %$self_snapshot_dates = (%$self_snapshot_dates, %$retrieved_snapshot_dates_ref);

  # ----- alimentation des donnees relatives a la base -----
  $self->{dbid}=$retrieved_database_info_ref->{dbid};
  $self->{dbname}=$retrieved_database_info_ref->{dbname};
  $self->{hostname}=$retrieved_database_info_ref->{hostname};
  $self->{instance_name}=$retrieved_database_info_ref->{instance_name};
  $self->{instance_number}=$retrieved_database_info_ref->{instance_number};

  return 0;
}

# ============================================================================================================
sub request_data {
  my ($self, %args)=@_;

  my $query=$args{query};
  my $index_columns=$args{index_columns};
  my $delta_columns=$args{delta_columns} || "";
  my $match_columns=$args{match_columns} || "";
  my $columns=$args{columns} || "";
  my $condition=$args{condition} || "";
  my $order_by=$args{order_by} || "";

  my $data=$self->{data};

  my $sth=$self->_request($query);
  if (! $sth) { return 1; }

  my %old_row;
  my @array_index_columns=split(/\s*,\s*/, uc($index_columns));
  my @array_delta_columns=split(/\s*,\s*/, uc($delta_columns));
  my @array_match_columns=split(/\s*,\s*/, uc($match_columns));
  my @array_columns=split(/\s*,\s*/,       uc($columns));

  my $col;

  while (my $row = $sth->fetchrow_hashref()) {
    if ($delta_columns) {
      my $flag=0;

      # ----- on verifie que les valeurs entre les colonnes de la ligne precedente et de la courante correspondent -----
      #       (uniquement pour les colonnes definies dans '$match_columns'
      if (%old_row) {
        $flag=1;
        foreach $col (@array_match_columns) {
          if ($row->{$col} ne $old_row{$col}) {
            $flag=0;
            last;
          }
        }
      }

      # ----- si les colonnes correspondent (@array_match_columns) -----
      #       on calcule le delta
      my %delta=();
      if (($flag) && (%old_row)) {

        $flag=1;
        foreach $col (@array_delta_columns) {
          $row->{$col}=$row->{$col} || 0;
          $old_row{$col}=$old_row{$col} || 0;
          $delta{$col}=$row->{$col}-$old_row{$col};

          if ($delta{$col} < 0) {
            $flag=0;
            next;
          }
        }
      }

      # ----- si tous les deltas sont >= 0 -----
      if ($flag) {
        my $current_level_ref = $data;
        foreach my $index_col_name (@array_index_columns) {
            my $key_value = $row->{$index_col_name} || $index_col_name; # Use column name if row value is false

            unless (exists $current_level_ref->{$key_value} && defined $current_level_ref->{$key_value} && ref $current_level_ref->{$key_value} eq 'HASH') {
                $current_level_ref->{$key_value} = {}; # Create new hash if not exists or not a hash ref
            }
            $current_level_ref = $current_level_ref->{$key_value};
        }
        foreach my $delta_col_name (@array_delta_columns) {
            $current_level_ref->{$delta_col_name} = $delta{$delta_col_name}; # Assign directly
        }
      }

      %old_row=(%$row);
    }
    else {
      # ----- les donnees sans faire le delta entre les lignes -----
      my $current_level_ref = $data;
      foreach my $index_col_name (@array_index_columns) {
          my $key_value = defined $row->{$index_col_name} ? $row->{$index_col_name} : ""; # Use empty string if row value is undefined

          unless (exists $current_level_ref->{$key_value} && defined $current_level_ref->{$key_value} && ref $current_level_ref->{$key_value} eq 'HASH') {
              $current_level_ref->{$key_value} = {}; # Create new hash if not exists or not a hash ref
          }
          $current_level_ref = $current_level_ref->{$key_value};
      }
      foreach my $value_col_name (@array_columns) {
          my $value_to_assign = defined $row->{$value_col_name} ? $row->{$value_col_name} : ""; # Assign empty string if undefined
          $current_level_ref->{$value_col_name} = $value_to_assign; # Assign directly
      }
    }
  }

  return 0;
}

# ============================================================================================================
sub check_open_db {
  my ($self, %args)=@_;

  my $message=$args{message} || "\nla base {DBNAME} n'est pas ouverte en lecture (OPEN_MODE={OPEN_MODE})\n\n";
  my $rc=$args{rc} || 1;

  my $db_informations=$self->get_db_informations();
  my $dbname=$self->dbname();
  my $open_mode=$db_informations->{OPEN_MODE};

  $message=~s/{DBNAME}/$dbname/g;
  $message=~s/{OPEN_MODE}/$open_mode/g;

  if (! ($db_informations->{OPEN_MODE}=~/READ/)) {
    die $message;
  }
}

1;
