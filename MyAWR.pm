package MyAWR;
use base qw(MyOracle);

use Data::Dumper;
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
    open $fh, "|-", "gzip -c > $file_name" || return 1;
  }
  else {
    open($fh, ">$file_name") || return 1;
  }

  my $snapshot_dates=$self->{snapshot_dates};

  $Data::Dumper::Sortkeys = 1;
  print $fh Data::Dumper->Dump([$snapshot_dates], ["*snapshot_dates"]);
  print $fh Data::Dumper->Dump([$data], ["*data"]);
  print $fh Data::Dumper->Dump([\%database_info], ["*database_info"]);
  close $fh;

  return 0;
}

# ============================================================================================================
sub read_data_from_file {
  my ($self, $datafile)=@_;

  my %snapshot_dates;
  my %data;
  my %database_info;

  my $buffer="";
  my $fh;

  my $self_data=$self->{data};
  my $self_snapshot_dates=$self->{snapshot_dates};

  if ($datafile=~m/\.gz$/) {
    # ----- si le fichier est compresse -----
    open $fh, "-|", "gzip", "-dc", $datafile || return 1;
    while (<$fh>) { $buffer.=$_; }
    close($fh);
  }
  else {
    # ----- si le fichier n'est pas compresse -----
    open($fh, $datafile) || return 1;
    while (<$fh>) { $buffer.=$_; }
    close($fh);
  }

  eval($buffer);

  # ----- verification du meme dbid, instance_number, view -----
  $self->{view}=$self->{view} || $database_info{view};                                   # si la connexion a la base n'a pas pu se faire
  $self->{instance_number}=$self->{instance_number} || $database_info{instance_number};  # si la connexion a la base n'a pas pu se faire
  $self->{dbid}=$self->{dbid} || $database_info{dbid};                                   # si la connexion a la base n'a pas pu se faire

  if (   (($self->{view})            && ($self->{view}            ne $database_info{view}))
      || (($self->{instance_number}) && ($self->{instance_number} ne $database_info{instance_number}))
      || (($self->{dbid})            && ($self->{dbid}            ne $database_info{dbid}))) { return 2; }

  %$self_data = (%$self_data, %data);
  %$self_snapshot_dates = (%$self_snapshot_dates, %snapshot_dates);

  # ----- alimentation des donnees relatives a la base -----
  $self->{dbid}=$database_info{dbid};
  $self->{dbname}=$database_info{dbname};
  $self->{hostname}=$database_info{hostname};
  $self->{instance_name}=$database_info{instance_name};
  $self->{instance_number}=$database_info{instance_number};

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
        my $ref="\$data";
        foreach $col (@array_index_columns) {
          $ref=sprintf("%s->{\"%s\"}", $ref, $row->{$col} || $col);
        }
        foreach $col (@array_delta_columns) {
          my $value=$delta{$col};   $value=~s/\\/\\\\/g;       # pour ne pas que le \ suivi d'un caractere ne soit interprete comme un regexp
                                    $value=~s/([@\$]+)/\\$1/g; # pour ne pas que le $ ou @ soit interprete

          my $cmd=sprintf("%s->{\"%s\"}=\"%s\";", $ref, $col, $value);
          eval($cmd);
        }
      }

      %old_row=(%$row);
    }
    else {
      # ----- les donnees sans faire le delta entre les lignes -----
      my $ref="\$data";
      foreach $col (@array_index_columns) {
        my $v=$row->{$col};
        if (! defined($v)) { $v=""; }
        $ref=sprintf("%s->{\"%s\"}", $ref, $v);
      }
      foreach $col (@array_columns) {
        if (! defined($row->{$col})) { $row->{$col}=""; }

        my $value=$row->{$col};  $value=~s/\\/\\\\/g;       # pour ne pas que le \ suivi d'un caractere ne soit interprete comme un regexp
                                 $value=~s/([@\$]+)/\\$1/g; # pour ne pas que le $ ou @ soit interprete

        #$row->{$col}=~s/([@\$]+)/\\$1/g;
        my $cmd=sprintf("%s->{\"%s\"}=\"%s\";", $ref, $col, $value);
        eval($cmd);
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
    print $message;
    exit($rc);
  }
}

1;
