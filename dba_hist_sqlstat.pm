package dba_hist_sqlstat;
use base qw(MyAWR);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{view}="dba_hist_sqlstat";

  bless $self, $class;

  return $self;
}

# ============================================================================================================
sub request_data {
  my ($self, %args)=@_;

  my $sql_id=$args{sql_id} || "";
  my $module=$args{module} || "";

  my $data=$self->{data};
  my $instance_number=$self->{instance_number};
  my $begin_snap_id=$self->{begin_snap_id};
  my $end_snap_id=$self->{end_snap_id};

  my @conditions=("instance_number=$instance_number");
  if ($begin_snap_id) { push @conditions, "snap_id >= $begin_snap_id"; }  # pas de delta des valeurs, on commence au $begin_snap_id
  if ($end_snap_id)   { push @conditions, "snap_id <= $end_snap_id";   }
  if ($sql_id)        { push @conditions, "sql_id = '$sql_id'";        }
  if ($module)        { push @conditions, "module = '$module'";        }
  my $query_condition=join(" and ", @conditions);

  my $sql;
  $sql="select snap_id,
               sql_id,
               plan_hash_value,
               module,
               fetches_delta fetches,
               end_of_fetch_count_delta end_of_fetch_count,
               sorts_delta sorts,
               executions_delta executions,
               px_servers_execs_delta px_servers_execs,
               loads_delta loads,
               invalidations_delta invalidations,
               parse_calls_delta parse_calls,
               disk_reads_delta disk_reads,
               buffer_gets_delta buffer_gets,
               rows_processed_delta rows_processed,
               cpu_time_delta cpu_time,
               elapsed_time_delta elapsed_time,
               iowait_delta iowait,
               clwait_delta clwait,
               apwait_delta apwait,
               ccwait_delta ccwait,
               direct_writes_delta direct_writes,
               plsexec_time_delta plsexec_time,
               javexec_time_delta javexec_time,
               io_offload_elig_bytes_delta io_offload_elig_bytes,
               io_interconnect_bytes_delta io_interconnect_bytes,
               physical_read_requests_delta physical_read_requests,
               physical_read_bytes_delta physical_read_bytes,
               physical_write_requests_delta physical_write_requests,
               physical_write_bytes_delta physical_write_bytes,
               optimized_physical_reads_delta optimized_physical_reads,
               cell_uncompressed_bytes_delta cell_uncompressed_bytes,
               io_offload_return_bytes_delta io_offload_return_bytes
        from
          dba_hist_sqlstat
        where
          $query_condition";

  return $self->SUPER::request_data("query"=>$sql,
                                    "columns"=>"module,
                                                fetches,
                                                end_of_fetch_count,
                                                sorts,
                                                executions,
                                                px_servers_execs,
                                                loads,
                                                invalidations,
                                                parse_calls,
                                                disk_reads,
                                                buffer_gets,
                                                rows_processed,
                                                cpu_time,
                                                elapsed_time,
                                                iowait,
                                                clwait,
                                                apwait,
                                                ccwait,
                                                direct_writes,
                                                plsexec_time,
                                                javexec_time,
                                                io_offload_elig_bytes,
                                                io_interconnect_bytes,
                                                physical_read_requests,
                                                physical_read_bytes,
                                                physical_write_requests,
                                                physical_write_bytes,
                                                optimized_physical_reads,
                                                cell_uncompressed_bytes,
                                                io_offload_return_bytes",
                                    "index_columns"=>"snap_id, sql_id, plan_hash_value");
}

# ============================================================================================================
sub get_max {
  my ($self, %args)=@_;

  my $sql_id=$args{sql_id} || "";
  my $module=$args{module} || "";
  my $column=uc($args{column} || "ELAPSED_TIME");
  my $top=$args{top} || 5;
  my $by=$args{by} || "cumul";

  my $data=$self->{data};
  if (! %{$data}) { $self->request_data("sql_id"=>$sql_id, "module"=>$module); }

  %max=();
  foreach my $snap_id (keys %{$data}) {
    foreach my $sql_id (keys %{$data->{$snap_id}}) {
      foreach my $plan_hash_value (keys %{$data->{$snap_id}->{$sql_id}}) {
        my $v=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{$column} || 0;
        $max{$sql_id}=$max{$sql_id} || 0;
        if ($by eq "top")   { if ($v > $max{$sql_id}) { $max{$sql_id}=$v; } }
        if ($by eq "cumul") { $max{$sql_id}=$max{$sql_id} + $v; }
      }
    }
  }

  # ----- TOP n des $event_name -----
  my @desc_order=reverse(sort { $max{$a} <=> $max{$b} } keys %max);
  $top=$top <= scalar(@desc_order) ? $top : scalar(@desc_order);
  $top--;
  return @desc_order[0..$top];
}

# ============================================================================================================
sub get_max_by_execution {
  my ($self, %args)=@_;

  my $sql_id=$args{sql_id} || "";
  my $module=$args{module} || "";
  my $column=uc($args{column} || "ELAPSED_TIME");
  my $top=$args{top} || 5;

  my $data=$self->{data};
  if (! %{$data}) { $self->request_data("sql_id"=>$sql_id, "module"=>$module); }

  %max=();
  foreach my $snap_id (keys %{$data}) {
    foreach my $sql_id (keys %{$data->{$snap_id}}) {
      foreach my $plan_hash_value (keys %{$data->{$snap_id}->{$sql_id}}) {
        my $v=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{$column} || 0;
        my $e=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{EXECUTIONS} || 0;
        if ($e >0) {
          $v=$v/$e;
          $max{$sql_id}=$max{$sql_id} || 0;
          if ($v > $max{$sql_id}) { $max{$sql_id}=$v; }
        }
      }
    }
  }

  # ----- TOP n des $event_name -----
  my @desc_order=reverse(sort { $max{$a} <=> $max{$b} } keys %max);
  $top=$top <= scalar(@desc_order) ? $top : scalar(@desc_order);
  $top--;
  return @desc_order[0..$top];
}

1;
