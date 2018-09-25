package dba_hist_buffer_pool_stat;
use base qw(MyAWR);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{view}="dba_hist_buffer_pool_stat";

  $self->{buffers}={};

  bless $self, $class;

  return $self;
}

# ============================================================================================================
sub get_buffers_name {
  my ($self)=@_;

  my $buffers=$self->{buffers};

  my $sql;
  $sql="select distinct name,
               block_size
        from
          dba_hist_buffer_pool_stat";

  my $sth=$self->_request($sql);
  if (! $sth) { return 0; }

  while (my $row = $sth->fetchrow_hashref()) {
    my $name=$row->{NAME};
    my $block_size=$row->{BLOCK_SIZE};

    $buffers->{$name}=$block_size;
  }
}

# ============================================================================================================
sub request_data {
  my ($self)=@_;

  my $buffers=$self->{buffers};
  if (! %{$buffers}) { $self->get_buffers_name(); }

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
               name,
               free_buffer_inspected,
               dirty_buffers_inspected,
               db_block_change,
               db_block_gets,
               consistent_gets,
               physical_reads,
               physical_writes,
               free_buffer_wait,
               write_complete_wait,
               buffer_busy_wait
        from
          dba_hist_buffer_pool_stat
        where
          $query_condition
        order by name, snap_id";

  return $self->SUPER::request_data("query"=>$sql,
                                    "delta_columns"=>"free_buffer_inspected, dirty_buffers_inspected, db_block_change, db_block_gets, consistent_gets, physical_reads, physical_writes, free_buffer_wait, write_complete_wait, buffer_busy_wait",
                                    "match_columns"=>"name",
                                    "index_columns"=>"snap_id, name");
}

1;
