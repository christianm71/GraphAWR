package dba_hist_filestatxs;
use base qw(MyAWR);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{view}="dba_hist_filestatxs";

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

  my @conditions=("instance_number=$instance_number", "(readtim > 0 or writetim > 0)");
  if ($begin_snap_id) { push @conditions, "snap_id >= $begin_snap_id-1"; }
  if ($end_snap_id)   { push @conditions, "snap_id <= $end_snap_id";     }
  my $query_condition=join(" and ", @conditions);

  my $sql;
  $sql="select snap_id,
               file#,
               phyrds,
               phywrts,
               readtim,
               writetim,
               time
        from
          dba_hist_filestatxs
        where
          $query_condition
        order by file#, snap_id";

  $self->SUPER::request_data("query"=>$sql,
                             "delta_columns"=>"phyrds, phywrts, readtim, writetim, time",
                             "match_columns"=>"file#",
                             "index_columns"=>"snap_id, file#");

  foreach my $snap_id (keys %{$data}) {
    foreach my $file_id (keys %{$data->{$snap_id}}) {
      my $phyrds=$data->{$snap_id}->{$file_id}->{PHYRDS} || 0;
      my $phywrts=$data->{$snap_id}->{$file_id}->{PHYWRTS} || 0;
      my $readtim=$data->{$snap_id}->{$file_id}->{READTIM} || 0;
      my $writetim=$data->{$snap_id}->{$file_id}->{WRITETIM} || 0;

      if ($phyrds)  { $data->{$snap_id}->{$file_id}->{READTIM_BY_READ}=$readtim/$phyrds;     }
      if ($phywrts) { $data->{$snap_id}->{$file_id}->{WRITETIM_BY_WRITE}=$writetim/$phywrts; }
    }
  }

  return $data;
}

# ============================================================================================================
sub get_top {
  my ($self, %args)=@_;

  my $column=$args{column};  # PHYRDS, PHYWRTS, READTIM, WRITETIM, READTIM_BY_READ, WRITETIM_BY_WRITE
  my $top=$args{top} || 5;
  my $by=$args{by} || "cumul";

  my $data=$self->{data};
  if (! %{$data}) { $self->request_data(); }

  %max=();
  foreach my $snap_id (keys %{$data}) {
    foreach my $file_id (keys %{$data->{$snap_id}}) {
      my $v=$data->{$snap_id}->{$file_id}->{$column} || 0;
      $max{$file_id}=$max{$file_id} || 0;
      if ($by eq "top")   { if ($v > $max{$file_id}) { $max{$file_id}=$v; } }
      if ($by eq "cumul") { $max{$file_id}=$max{$file_id} + $v; }
    }
  }

  # ----- TOP 5 des $column -----
  my @desc_order=reverse(sort { $max{$a} <=> $max{$b} } keys %max);
  $top=$top <= scalar(@desc_order) ? $top : scalar(@desc_order);
  $top--;
  return @desc_order[0..$top];
}

1;
