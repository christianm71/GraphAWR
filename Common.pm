package Common;

# ============================================================================================================
sub new {
  my ($class) = @_;

  my $self = {
  };

  bless $self, $class;

  return $self;
}

# ============================================================================================================
sub _days_in_month {
  my ($self, $yyyy, $mm) = @_;

  if (($mm==1) || ($mm==3) || ($mm==5) || ($mm==7) || ($mm==8) || ($mm==10) || ($mm==12)) { return 31; }
  if (($mm==4) || ($mm==6) || ($mm==9) || ($mm==11)) { return 30; }
  if (   ((($yyyy%4) == 0) && (($yyyy%100) != 0))
      || (($yyyy%400) == 0)) { return 29; }
  return 28;
}

# ============================================================================================================
sub get_dates_delta {
  my ($self, $begin_date, $end_date) = @_;

  if ($begin_date gt $end_date) {
    return -$self->get_dates_delta($end_date, $begin_date);
  }

  my @tmparray_min=split(/\/|:| /, $begin_date);    my @tmparray_max=split(/\/|:| /, $end_date);
  my $min_yyyy=$tmparray_min[0];                  my $max_yyyy=$tmparray_max[0];
  my $min_mm  =$tmparray_min[1];                  my $max_mm  =$tmparray_max[1];
  my $min_dd  =$tmparray_min[2];                  my $max_dd  =$tmparray_max[2];
  my $min_hh  =$tmparray_min[3] || 0;             my $max_hh  =$tmparray_max[3] || 0;
  my $min_mi  =$tmparray_min[4] || 0;             my $max_mi  =$tmparray_max[4] || 0;
  my $min_ss  =$tmparray_min[5] || 0;             my $max_ss  =$tmparray_max[5] || 0;

  my $delta=0;

  # ----- si les annees sont differentes -----
  if ($max_yyyy > $min_yyyy) {
    $delta = $self->get_dates_delta($begin_date, "$min_yyyy/12/31 23:59:59") + 1;
    $begin_date=sprintf("%d/01/01 00:00", $min_yyyy+1);
    return $delta + $self->get_dates_delta($begin_date, $end_date);
  }

  for (my $i=$min_mm; $i<$max_mm; $i++) { $delta=$delta + $self->_days_in_month($max_yyyy, $i) * 24*3600; }

  $delta=$delta + ($max_dd-$min_dd)*24*3600 + ($max_hh-$min_hh)*3600 + ($max_mi-$min_mi)*60 + $max_ss-$min_ss;

  return $delta;
}

# ============================================================================================================
sub round {
  my ($self, $value, $precision)=@_;

  $precision=$precision || 2;

  if ($precision == 0) { return int($value); }

  my $sign=1;
  if ($value < 0) {
    $value=-$value;
    $sign=-1;
  }

  my $p=10**$precision;
  my $d=int($value*$p*10) % 10;

  if ($d < 5) { return $sign*int($value*$p)/$p; } else { return $sign*int($value*$p+1)/$p; }
}

# ============================================================================================================
sub get_tag_date {
  my ($self)=@_;

  (my $second, my $minute, my $hour, my $dayOfMonth, my $month, my $yearOffset)=localtime();
  return sprintf("%04d/%02d/%02d %02d:%02d:%02d", 1900+$yearOffset, $month+1, $dayOfMonth, $hour, $minute, $second);
}

1;
