package dba_hist_active_sess_history;
use base qw(MyAWR);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{view}="dba_hist_active_sess_history";

  bless $self, $class;

  return $self;
}

# ============================================================================================================
sub request_data {
  my ($self)=@_;

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
               sample_id,
               session_id||','||session_serial# session_id,
               session_type,
               session_state,
               program,
               module,
               machine,
               event,
               wait_time,
               time_waited,
               pga_allocated,
               temp_space_allocated
        from
          dba_hist_active_sess_history
        where
          $query_condition";

  return $self->SUPER::request_data("query"=>$sql,
                                    "columns"=>"session_type, session_state, program, module, machine, event, wait_time, time_waited, pga_allocated, temp_space_allocated",
                                    "index_columns"=>"snap_id, sample_id, session_id");
}

1;
