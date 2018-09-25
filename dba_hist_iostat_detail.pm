package dba_hist_iostat_detail;
use base qw(MyAWR);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{view}="dba_hist_iostat_detail";

  $self->{function_filetype}={};  # $self->{function_filetype}->{Data Pump}->{Control File}=1;
                              # $self->{function_filetype}->{Data Pump}->{Data File}=1;
  bless $self, $class;

  return $self;
}

# ============================================================================================================
sub get_function_filetype {
  my ($self)=@_;

  my $function_filetype=$self->{function_filetype};

  my $sql;
  $sql="select distinct function_name,
                        filetype_name
        from
          dba_hist_iostat_detail";

  my $sth=$self->_request($sql);
  if (! $sth) { return 0; }

  while (my $row = $sth->fetchrow_hashref()) {
    my $function_name=$row->{FUNCTION_NAME};
    my $filetype_name=$row->{FILETYPE_NAME};

    $function_filetype->{$function_name}->{$filetype_name}=1;
  }
}

# ============================================================================================================
sub request_data {
  my ($self)=@_;

  my $function_filetype=$self->{function_filetype};
  if (! %{$function_filetype}) { $self->get_function_filetype(); }

  my $data=$self->{data};
  my $instance_number=$self->{instance_number};
  my $begin_snap_id=$self->{begin_snap_id};
  my $end_snap_id=$self->{end_snap_id};

  my @conditions=("instance_number=$instance_number");
  if ($begin_snap_id) { push @conditions, "snap_id >= $begin_snap_id"; }  # pas de delta des valeurs, on commence au $begin_snap_id
  if ($end_snap_id)   { push @conditions, "snap_id <= $end_snap_id";   }
  my $query_condition=join(" and ", @conditions);

  my $sql;
  $sql="select snap_id,
               function_name,
               filetype_name,
               small_read_megabytes,
               small_write_megabytes,
               large_read_megabytes,
               large_write_megabytes,
               small_read_reqs,
               small_write_reqs,
               large_read_reqs,
               large_write_reqs,
               number_of_waits,
               wait_time
        from
          dba_hist_iostat_detail
        where
          $query_condition
        order by function_name, filetype_name, snap_id";

  return $self->SUPER::request_data("query"=>$sql,
                                    "delta_columns"=>"small_read_megabytes, small_write_megabytes, large_read_megabytes, large_write_megabytes, small_read_reqs, small_write_reqs, large_read_reqs, large_write_reqs, number_of_waits, wait_time",
                                    "match_columns"=>"function_name, filetype_name",
                                    "index_columns"=>"snap_id, function_name, filetype_name");
}

1;
