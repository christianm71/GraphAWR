package CanvasJS_chart;

use strict;
use Attributes;
use CanvasJS_data;
use Common;

our @color_names=("DarkCyan", "LightSeaGreen", "DarkSeaGreen", "DarkOliveGreen", "OliveDrab", "YellowGreen", "DarkGreen", "Green", "MediumSeaGreen", "LimeGreen", "RebeccaPurple", "DarkSlateBlue", "MediumSlateBlue", "Purple", "Magenta", "Orchid", "Thistle", "Salmon", "Red", "FireBrick", "DarkOrange", "Blue", "RoyalBlue", "DodgerBlue", "DeepSkyBlue", "SteelBlue", "Gray", "SlateGray", "Black");

# ========================================================================
sub new {
  my ($class) = @_;

  my $self = {
    attributes => Attributes->new(),
    title      => Attributes->new(),
    axisX      => [],    # liste de type Attributes
    axisY      => [],    # liste de type Attributes
    axisY2     => [],    # liste de type Attributes
    data       => [],    # liste de type CanvasJS_data
    html_style => Attributes->new()
  };

  bless $self, $class;

  # ----- initialisation des parametres par defaut pour le HTML style -----
  $self->{html_style}->set("height"=>"500px", "width"=>"100%");
  $self->{attributes}->set("exportEnabled"=>"true", "zoomEnabled"=>"true", "zoomType"=>"xy");
  $self->{title}->set("fontSize"=>25);

  # ----- allocation du 1er Axis X -----
  #$self->axisX()->set("labelAngle"=>-50, "valueFormatString"=>"YYYY/MM/DD HH:mm", "intervalType"=>"minute");
  $self->axisX()->set("labelAngle"=>-50, "valueFormatString"=>"YYYY/MM/DD HH:mm");

  # ----- allocation du 1er Axis Y -----
  $self->axisY();

  return $self;
}

# ========================================================================
# ----- methode generique (privee) pour les objets axisX, axisY, axisY2 -----
sub _get_object {
  my ($self, $object, $id)=@_;

  $id=$id || 0;

  my $item=$$object[$id];
  if (! defined($item)) {
    $$object[$id]=Attributes->new();
    $item=$$object[$id];
  }

  return $item;
}

# ========================================================================
sub attributes { my ($self)=@_; return $self->{attributes}; }
sub title      { my ($self)=@_; return $self->{title};      }
sub html_style { my ($self)=@_; return $self->{html_style}; }

# ========================================================================
sub axisX {
  my ($self, $id)=@_;

  return $self->_get_object($self->{axisX},  $id);
}

# ========================================================================
sub axisY {
  my ($self, $id)=@_;

  my $item=$self->_get_object($self->{axisY}, $id);

  return $item;
}

# ========================================================================
sub axisY2 {
  my ($self, $id)=@_;

  my $item=$self->_get_object($self->{axisY2}, $id);

  return $item;
}

# ========================================================================
sub data {
  my ($self, $id)=@_;

  my $data=$self->{data};

  if (defined($id)) {
    return $$data[$id];
  }
  else {
    return $data;
  }
}

# ========================================================================
sub allocate_data {
  my ($self)=@_;

  my $d=CanvasJS_data->new($self);  # on indique a l'objet CanvasJS_data le Chart auquel il appartient
                                    # afin de creer le lien CanvasJS_data <-> CanvasJS_chart <-> AxisY
  my $data=$self->{data};
  push @$data, $d;

  return $d;
}

# ========================================================================
sub get_min_date {
  my ($self)=@_;

  my $data=$self->{data};

  my $top_min_date="";
  foreach my $d (@$data) {
    my $min_date=$d->get_min_date();
    if ((! $top_min_date) || ($top_min_date > $min_date)) { $top_min_date=$min_date; }
  }

  return $top_min_date;
}

# ========================================================================
sub get_max_date {
  my ($self)=@_;

  my $data=$self->{data};

  my $top_max_date="";
  foreach my $d (@$data) {
    my $max_date=$d->get_max_date();
    if ((! $top_max_date) || ($top_max_date < $max_date)) { $top_max_date=$max_date; }
  }

  return $top_max_date;
}

# ========================================================================
sub get_max_value {
  my ($self, %args)=@_;

  my $axisYType=$args{axisYType} || "primary";
  my $axisYIndex=$args{axisYIndex} || 0;

  my $data=$self->{data};

  my $max=0;
  foreach my $d (@$data) {
    if (($d->get("axisYType") eq $axisYType) && ($d->get("axisYIndex") == $axisYType)) {
    }
  }

  return $max;
}

# ========================================================================
# ----- methode generique (privee) pour les objets axisX, axisY, axisY2 -----
sub _generate_code_for_object {
  my ($self, $object, $default_attributes, $margin)=@_;

  my $str="";

  if (scalar(@$object) > 1) { $str="$str\["; }
  foreach my $item (@$object) {
    $str=$str . "{\n" . $item->generate_code("default_attributes"=>$default_attributes, "margin"=>2) . "\n},";
  }
  if (scalar(@$object) > 1) { $str="$str\n]"; }

  $str=~s/,(\s*\])/$1/s;
  $str=~s/,$//;

  $margin=" " x ($margin || 0);
  $str=~s/\n/\n$margin/g;

  return "$margin$str";
}

# ========================================================================
sub generate_code {
  my ($self, %args)=@_;

  my $chart_name=$args{chart_name};
  my $chart_template=$args{chart_template} || 0;
  my $margin=$args{margin} || 0;

  my $axisX=$self->{axisX};
  my $axisY=$self->{axisY};
  my $axisY2=$self->{axisY2};
  my $data=$self->{data};

  my $default_attributes;

  my $attributes=$self->{attributes};
  $default_attributes=$chart_template->{attributes};
  my $attributes_string=$attributes->generate_code("default_attributes"=>$default_attributes, "margin"=>6);

  my $title=$self->{title};
  $default_attributes=$chart_template->{title};
  my $title_attributes_string=$title->generate_code("default_attributes"=>$default_attributes, "margin"=>8);

  # ----- deduction prealable de l'intervalle des dates (axeX) -----
  my $max_delta=0;
  foreach my $d (@$data) {
    my $delta=$d->get_dates_delta();
    if ($max_delta < $delta) { $max_delta=$delta; }
  }

  if ($max_delta) {
    my $ticks=40;

    my $c=Common->new();
    my $interval=$c->round($max_delta / 3600 / $ticks, 1);
    if ($interval - int($interval) < 0.5) { $interval=int($interval);   }
    else                                  { $interval=int($interval)+1; }
    $interval=$interval*60; # passage en minutes

    $$axisX[0]->set("interval"=>$interval);
  }

  # ----- affichage axeX -----
  $default_attributes=$chart_template->axisX();  # le template est le 1er axisX du $chart_template
  my $axisX_string=$self->_generate_code_for_object($axisX, $default_attributes, 6);
  $axisX_string=~s/^ *//;

  # ----- affichage axeY -----
  $default_attributes=$chart_template->axisY();  # le template est le 1er axisY du $chart_template
  my $axisY_string=$self->_generate_code_for_object($axisY, $default_attributes, 6);
  $axisY_string=~s/^ *//;

  # ----- affichage axeY2 -----
  $default_attributes=$chart_template->axisY2(); # le template est le 1er axisY2 du $chart_template
  my $axisY2_string=$self->_generate_code_for_object($axisY2, $default_attributes, 6);
  $axisY2_string=~s/^ *//;

  my $code="
    var $chart_name = new CanvasJS.Chart(\"$chart_name\", {
      {attributes_string},
      title: {
        {title_attributes_string}
      },
      axisX: $axisX_string,
      axisY: $axisY_string,
      axisY2: $axisY2_string,
      data: [
        {DATA}
      ]
    });
    $chart_name.render();";

  $code=~s/^ *\n//;
  $code=~s/ *axisY2: ,\n//;

  $code=~s/ *{title_attributes_string}/$title_attributes_string/;
  $code=~s/ *{attributes_string}/$attributes_string/;

  # ----- affichage des dataPoints -----
  our @color_names;

  my $color=0;
  foreach my $d (@$data) {
    $d->set("default_color"=>$color_names[$color] || "");

    my $str=$d->generate_code("margin"=>4);
    $code=~s/ *{DATA}/$str,\n{DATA}/;

    $color++;
  }

  $code=~s/,?\s*{DATA}//s;

  $margin=" " x $margin;
  $code=~s/\n/\n$margin/g;

  return "$margin$code";
}

1;
