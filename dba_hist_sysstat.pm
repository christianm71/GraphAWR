package dba_hist_sysstat;
use base qw(MyAWR);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{view}="dba_hist_sysstat";

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
  if ($begin_snap_id) { push @conditions, "snap_id >= $begin_snap_id-1"; }
  if ($end_snap_id)   { push @conditions, "snap_id <= $end_snap_id";     }
  my $query_condition=join(" and ", @conditions);

  my $sql;
  $sql="select snap_id,
               stat_name,
               value
        from
          dba_hist_sysstat
        where
          $query_condition
        order by stat_name, snap_id";

  return $self->SUPER::request_data("query"=>$sql,
                                    "delta_columns"=>"value",
                                    "index_columns"=>"snap_id, stat_name");
}

# ============================================================================================================
sub sort_statistics {
  my ($self, %args)=@_;

  my $statistics=$args{statistics} || "";
  my $by=$args{by} || "cumul";

  if ($statistics) { $statistics=",$statistics,"; }

  my $data=$self->{data};
  if (! %{$data}) { $self->request_data(); }

  %max=();
  foreach my $snap_id (keys %{$data}) {
    foreach my $stat_name (keys %{$data->{$snap_id}}) {
    if ((! $statistics) || ($statistics=~m/,\s*$stat_name\s*,/is)) {
        my $v=$data->{$snap_id}->{$stat_name}->{VALUE} || 0;
        $max{$stat_name}=$max{$stat_name} || 0;
        if ($by eq "top")   { if ($v > $max{$stat_name}) { $max{$stat_name}=$v; } }
        if ($by eq "cumul") { $max{$stat_name}=$max{$stat_name} + $v; }
      }
    }
  }

  # ----- TOP 5 des $stat_name -----
  return reverse(sort { $max{$a} <=> $max{$b} } keys %max);
}

1;
