package dba_hist_sga_target_advice;
use base qw(MyAWR);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{view}="dba_hist_sga_target_advice";

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
  if ($begin_snap_id) { push @conditions, "snap_id >= $begin_snap_id"; } # pas de delta des valeurs, on commence au $begin_snap_id
  if ($end_snap_id)   { push @conditions, "snap_id <= $end_snap_id";   }
  my $query_condition=join(" and ", @conditions);

  my $sql;
  $sql="select snap_id,
               sga_size,
               sga_size_factor,
               estd_db_time,
               estd_physical_reads
        from
          dba_hist_sga_target_advice
        where
          $query_condition";

  return $self->SUPER::request_data("query"=>$sql,
                                    "columns"=>"sga_size_factor, estd_db_time, estd_physical_reads",
                                    "index_columns"=>"snap_id, sga_size");
}

# ============================================================================================================
sub get_all_sga_size {
  my ($self)=@_;

  my $data=$self->{data};
  if (! %{$data}) { $self->request_data(); }

  my %all_sga_size=();

  foreach my $snap_id (keys %{$data}) {
    foreach my $sga_size (keys %{$data->{$snap_id}}) {
      $all_sga_size{$sga_size}=1;
    }
  }

  return sort { $a <=> $b } keys %all_sga_size;
}

1;
