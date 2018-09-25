package CanvasJS_data;

use strict;
use Attributes;

our $common=Common->new();

# ========================================================================
sub new {
  my ($class, $chart) = @_;

  my $self = {
    attributes => Attributes->new(),
    dataPoints => {},
    chart => $chart  # le CanvasJS_chart auquel ce CanvasJS_data appartient
                     # afin de creer le lien CanvasJS_data <-> CanvasJS_chart <-> AxisY
  };

  $self->{_min_date}="";  # la date la plus petite (mise a jour lors de l'affichage: generate_code())

  bless $self, $class;

  # ----- allocation de l'objet axe axisY -----
  #$self->set("axisYType"=>"primary", "axisYIndex"=>0);
  $self->set("showInLegend"=>"true");

  return $self;
}

# ========================================================================
sub set {
  my ($self, %args)=@_;

  $self->{attributes}->set(%args);

  my $axisYType=$args{axisYType} || "primary";
  my $axisYIndex=$args{axisYIndex} || 0;

  my $chart=$self->{chart};

  # ----- allocation implicite des objets axes axisY ou axisY2 en fonction des attributs (%args) -----
  if ($axisYType eq "primary")   { $chart->axisY($axisYIndex);  }
  if ($axisYType eq "secondary") { $chart->axisY2($axisYIndex); }
}

# ========================================================================
sub get {
  my ($self, $key)=@_;

  $self->{attributes}->get($key);
}

# ========================================================================
sub add {
  my ($self, $date, $value)=@_;

  $self->{dataPoints}->{$date}=$value;
}

# ========================================================================
sub cumul {
  my ($self, $date, $value)=@_;

  $self->{dataPoints}->{$date}=($self->{dataPoints}->{$date} || 0) + $value;
}

# ========================================================================
sub get_min_date {
  my ($self)=@_;

  my $dataPoints=$self->{dataPoints};

  foreach my $date (sort keys %{$dataPoints}) {
    return $date;
  }
}

# ========================================================================
sub get_max_date {
  my ($self)=@_;

  my $dataPoints=$self->{dataPoints};

  foreach my $date (reverse sort keys %{$dataPoints}) {
    return $date;
  }
}

# ========================================================================
sub get_dates_delta {
  my ($self)=@_;

  my $min_date=$self->get_min_date();
  my $max_date=$self->get_max_date();

  if (($min_date) && ($max_date)) {
    our $common;

    return $common->get_dates_delta($min_date, $max_date);
  }
  return 0;
}

# ========================================================================
sub get_min_value {
  my ($self)=@_;

  my $dataPoints=$self->{dataPoints};

  foreach my $value (sort { $a <=> $b } values %{$dataPoints}) {
    return $value;
  }
}

# ========================================================================
sub get_max_value {
  my ($self)=@_;

  my $dataPoints=$self->{dataPoints};

  foreach my $value (reverse sort { $a <=> $b } values %{$dataPoints}) {
    return $value;
  }
}

# ========================================================================
sub _print_date_value {
  my ($self, $date, $value)=@_;

  # ----- $date est sous la forme 2017/12/06 18:00 -----
  my @t=split(/[\s+\/:]/, $date);
  $self->{_min_date}=$self->{_min_date} || "2000/01/01";
  my $minutes=int($common->get_dates_delta($self->{_min_date}, $date)/60);

  return sprintf("{x: new Date(%d, %02d, %02d, %02d, %02d), y: %s}", @t, $value);
  #return sprintf("{x: %d, y: %s, label: \"%d/%02d/%02d %02d:%02d\"}", $minutes, $value, @t);
}

# ========================================================================
sub generate_code {
  my ($self, %args)=@_;

  my $default_attributes=$args{default_attributes} || 0;  # objet Attributes
  my $margin=$args{margin} || 0;

  my $dataPoints=$self->{dataPoints};
  my $attributes=$self->{attributes};  # objet Attributes

  # ----- prise en compte de la couleur -----
  my $color=$attributes->get("color");
  my $default_color=$attributes->get("default_color");
  if ($default_color) {
    if (! $color) {
      $attributes->set("color"=>$default_color);
    }
    $attributes->unset("default_color");  # pour ne pas que cet attribut soit affiche dans le html
  }

  # ----- generation du code des attributs -----
  my $str=$attributes->generate_code("default_attributes"=>$default_attributes, "margin"=>2);

  # ----- affichage des datapoints, couples x: y: -----
  $self->{_min_date}=$self->get_min_date();

  $str=sprintf("{\n%s,\n  dataPoints: [", $str);

  foreach my $date (sort keys %{$dataPoints}) {
    my $value=$dataPoints->{$date};

    if (defined($value)) {
      $str=$str."\n    ".$self->_print_date_value($date, $value).",";
    }
  }
  $str=$str."\n  ]\n";
  $str=$str."}";

  $str=~s/,(\s*\])/$1/s;
  $str=~s/,(\s+#.*\n\s*\])/$1/;

  $margin=" " x $margin;
  $str=~s/\n/\n$margin/g;

  return "$margin$str";
}

1;
