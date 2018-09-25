package dba_hist_system_event;
use base qw(MyAWR);

# ============================================================================================================
sub new {
  my ($class, %args) = @_;

  my $self = $class->SUPER::new(%args);

  $self->{view}="dba_hist_system_event";

  bless $self, $class;

  return $self;
}

# ============================================================================================================
sub request_data {
  my ($self, %args)=@_;

  my $data=$self->{data};
  my $instance_number=$self->{instance_number};
  my $begin_snap_id=$self->{begin_snap_id};
  my $end_snap_id=$self->{end_snap_id};

  my @conditions=("instance_number=$instance_number", "(   total_waits != 0
                                                        or total_timeouts != 0
                                                        or time_waited_micro != 0
                                                        or total_waits_fg != 0
                                                        or total_timeouts_fg != 0
                                                        or time_waited_micro_fg != 0)");
  if ($begin_snap_id) { push @conditions, "snap_id >= $begin_snap_id-1"; }
  if ($end_snap_id)   { push @conditions, "snap_id <= $end_snap_id";     }
  if ($event_name)    { push @conditions, "event_name='$event_name'";    }
  if ($wait_class)    { push @conditions, "wait_class='$wait_class'";    }
  my $query_condition=join(" and ", @conditions);

  my $event_name=$args{event_name} || "";
  my $wait_class=$args{wait_class} || "";

  my $sql;
  $sql="select snap_id,
               wait_class,
               event_name,
               total_waits,
               total_timeouts,
               time_waited_micro,
               total_waits_fg,
               total_timeouts_fg,
               time_waited_micro_fg
        from
          dba_hist_system_event
        where
          $query_condition
        order by wait_class, event_name, snap_id";

  $self->SUPER::request_data("query"=>$sql,
                             "delta_columns"=>"total_waits, total_timeouts, time_waited_micro, total_waits_fg, total_timeouts_fg, time_waited_micro_fg",
                             "match_columns"=>"wait_class, event_name",
                             "index_columns"=>"snap_id, event_name, wait_class");
}

# ============================================================================================================
sub request_all_wait_classes {
  my ($self)=@_;

  my $data=$self->{data};
  if (! %{$data}) { $self->request_data(); }

  %all_wait_classes=();
  foreach my $snap_id (keys %{$data}) {
    foreach my $event_name (keys %{$data->{$snap_id}}) {
      foreach my $wait_class (keys %{$data->{$snap_id}->{$event_name}}) {
        $all_wait_classes{$wait_class}=1;
      }
    }
  }

  return keys %all_wait_classes;
}

# ============================================================================================================
sub get_top_wait_classes {
  my ($self, %args)=@_;

  my $column=uc($args{column} || "TIME_WAITED_MICRO");
  my $top=$args{top} || 5;
  my $by=$args{by} || "cumul";

  my $data=$self->{data};
  if (! %{$data}) { $self->request_data(); }

  %max=();
  foreach my $snap_id (keys %{$data}) {
    foreach my $event_name (keys %{$data->{$snap_id}}) {
      foreach my $wait_class (keys %{$data->{$snap_id}->{$event_name}}) {
        my $v=$data->{$snap_id}->{$event_name}->{$wait_class}->{$column} || 0;
        $max{$wait_class}=$max{$wait_class} || 0;
        if ($by eq "top")   { if ($v > $max{$wait_class}) { $max{$wait_class}=$v; } }
        if ($by eq "cumul") { $max{$wait_class}=$max{$wait_class} + $v; }
      }
    }
  }

  # ----- TOP 5 des $wait_class -----
  my @desc_order=reverse(sort { $max{$a} <=> $max{$b} } keys %max);
  $top=$top <= scalar(@desc_order) ? $top : scalar(@desc_order);
  $top--;
  return @desc_order[0..$top];
}

# ============================================================================================================
sub get_top_event_names {
  my ($self, %args)=@_;

  my $wait_class_list=$args{wait_class_list} || "";
  my $exclude_wait_class_list=$args{exclude_wait_class_list} || "";
  my $column=uc($args{column} || "TIME_WAITED_MICRO");
  my $top=$args{top} || 5;
  my $by=$args{by} || "cumul";

  my $data=$self->{data};
  if (! %{$data}) { $self->request_data(); }

  $exclude_wait_class_list=",$exclude_wait_class_list,";
  $wait_class_list=",$wait_class_list,";

  %max=();
  foreach my $snap_id (keys %{$data}) {
    foreach my $event_name (keys %{$data->{$snap_id}}) {
      foreach my $wait_class (keys %{$data->{$snap_id}->{$event_name}}) {
        if ($exclude_wait_class_list=~m/,\s*$wait_class\s*,/is) { next; }
        if (($wait_class_list eq ",,") || ($wait_class_list=~m/,\s*$wait_class\s*,/is)) {
          my $v=$data->{$snap_id}->{$event_name}->{$wait_class}->{$column} || 0;
          $max{"$event_name;$wait_class"}=$max{"$event_name;$wait_class"} || 0;
          if ($by eq "top")   { if ($v > $max{"$event_name;$wait_class"}) { $max{"$event_name;$wait_class"}=$v; } }
          if ($by eq "cumul") { $max{"$event_name;$wait_class"}=$max{"$event_name;$wait_class"} + $v; }
        }
      }
    }
  }

  # ----- TOP 5 des $event_name -----
  my @desc_order=reverse(sort { $max{$a} <=> $max{$b} } keys %max);
  $top=$top <= scalar(@desc_order) ? $top : scalar(@desc_order);
  $top--;
  return @desc_order[0..$top];
}

1;
