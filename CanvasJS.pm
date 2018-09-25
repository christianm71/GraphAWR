package CanvasJS;

use strict;
use CanvasJS_chart;

# ========================================================================
sub new {
  my ($class) = @_;

  my $self = {
    chart_template => 0,
    all_charts => []
  };

  bless $self, $class;

  $self->{chart_template}=CanvasJS_chart->new();  # chart template pour les valeurs par defaut

  return $self;
}

# ========================================================================
sub set_default         { my ($self, %args)=@_; $self->{chart_template}->attributes()->set(%args); }
sub set_default_title   { my ($self, %args)=@_; $self->{chart_template}->title()->set(%args);      }
sub set_default_axisX   { my ($self, %args)=@_; $self->{chart_template}->axisX()->set(%args);      }
sub set_default_axisY   { my ($self, %args)=@_; $self->{chart_template}->axisY()->set(%args);      }
sub set_default_axisY2  { my ($self, %args)=@_; $self->{chart_template}->axisY2()->set(%args);     }

# ========================================================================
sub allocate_chart {
  my ($self)=@_;

  my $all_charts=$self->{all_charts};

  my $chart=CanvasJS_chart->new();
  push @$all_charts, $chart;

  return $chart;
}

# ============================================================================================================
sub generate_code {
  my ($self)=@_;

  my $code="<!DOCTYPE HTML>
    <html>
    <head>
      <script type=\"text/javascript\">
      window.onload = function () {
        {CHART}
      }
      </script>
      <script type=\"text/javascript\" src=\"../canvasjs.min.js\"></script>
    </head>
    <body>
      {DIV}
    </body>
    </html>\n";
  $code=~s/\n    /\n/g;

  my $all_charts=$self->{all_charts};
  my $chart_template=$self->{chart_template};

  my $i=0;
  foreach my $chart (@$all_charts) {
    my $attributes=$chart->{attributes};

    my $chart_name=sprintf("chartContainer%d", $i);

    my $str=$chart->generate_code("chart_name"=>$chart_name, "chart_template"=>$chart_template, "margin"=>4);
    if ($i) {
      $code=~s/( *{CHART})/\n$str\n$1/s;
    }
    else {
      $code=~s/( *{CHART})/$str\n$1/s;
    }

    my $div=sprintf("  <div id=\"%s\" style=\"height: %s; width: %s\"></div><br>", $chart_name, $chart->html_style()->get("height"), $chart->html_style()->get("width"));
    $code=~s/( *{DIV})/$div\n$1/s;

    $i++;
  }

  $code=~s/\n *{CHART}//;
  $code=~s/\n *{DIV}//;

  # ----- clean code -----
  $code=~s/(\{\s*),/$1/gs;

  return $code;
}

1;
