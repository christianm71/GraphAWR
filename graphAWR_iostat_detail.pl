#!/usr/bin/perl -w

# ============================================================================================================
BEGIN {
  use Config;
  my $perlpath=$Config{perlpath};
  my $ORACLE_HOME=$ENV{ORACLE_HOME} || "";
  if (($ORACLE_HOME) && (! ($perlpath=~m/^$ORACLE_HOME/))) {
    my $root=$0;
    $root=~s/\/[^\/]+$//;
    $root=`cd $root; pwd`;
    chomp($root);
    my $cmd="$ORACLE_HOME/perl/bin/perl -I $root -I $root/MyOracle $0";
    foreach my $arg (@ARGV) { $arg=~s/\$/\\\$/g; $cmd.=" \"$arg\""; }
    system($cmd);
    exit($?);
  }
}

# ============================================================================================================
use strict;
use dba_hist_iostat_detail;
use Common;
use CanvasJS;

# ============================================================================================================
my $begin_snap_id=0;
my $end_snap_id=0;
my $local_datafile="";
my $write_into_file=0;

my $i=0;
while ($ARGV[$i]) {
  if    ($ARGV[$i] eq "-begin_snap_id") { $begin_snap_id=$ARGV[$i+1];  $i++; }
  elsif ($ARGV[$i] eq "-end_snap_id")   { $end_snap_id=$ARGV[$i+1];    $i++; }
  elsif ($ARGV[$i] eq "-f")             { $local_datafile=$ARGV[$i+1]; $i++; }
  elsif ($ARGV[$i] eq "-w")             { $write_into_file=1;                }

  $i++;
}

# ============================================================================================================
my $awr=dba_hist_iostat_detail->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
my $common=Common->new();
my $canvas=CanvasJS->new();

$awr->connect();
$awr->check_open_db();

my $dbname=$awr->dbname();
my $hostname=$awr->hostname();

# ============================================================================================================
$awr->request_data();

$awr->dump_data();
my $data=$awr->data();

my @all_snap_ids=$awr->get_all_snap_ids();

my $chart;

my $function_filetype=$awr->{function_filetype};

foreach my $function_name (keys %{$function_filetype}) {
  foreach my $filetype_name (keys %{$function_filetype->{$function_name}}) {
    $chart=$canvas->allocate_chart();
    $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_io_stat_details_%s_%s", $hostname, $dbname, $function_name, $filetype_name));
    $chart->title()->set("text"=>"$dbname ($hostname) IO stat details ($function_name-$filetype_name)");
    $chart->axisY()->set("title"=>"# / second");

    foreach my $col ("SMALL_READ_MEGABYTES", "SMALL_WRITE_MEGABYTES", "LARGE_READ_MEGABYTES", "LARGE_WRITE_MEGABYTES") {
      my $c=$chart->allocate_data();
      $c->set("type"=>"line", "showInLegend"=>"true", "legendText"=>lc($col));
      if    ($col eq "SMALL_READ_MEGABYTES")  { $c->set("color"=>"Chocolate");  }
      elsif ($col eq "SMALL_WRITE_MEGABYTES") { $c->set("color"=>"Red");   }
      elsif ($col eq "LARGE_READ_MEGABYTES")  { $c->set("color"=>"Blue");  }
      else                                    { $c->set("color"=>"Green"); }

      foreach my $snap_id (@all_snap_ids) {
        my $delta=$awr->snapshot_delta($snap_id);
        if (! $delta) { next; }

        my $date=$awr->snapshot_date($snap_id);

        my $v=$data->{$snap_id}->{$function_name}->{$filetype_name}->{$col} || 0;
        $c->add($date, $common->round($v / $delta, 2));
      }
    }
  }
}

# ----- affichage du code html -----
if ($write_into_file) {
  my $html=sprintf("%s_%s_%d_%d_iostat_detail.html", $hostname, $dbname, $begin_snap_id || $awr->get_min_snap_id(), $end_snap_id || $awr->get_max_snap_id());

  if (-f $html) {
    my $old_html=sprintf("$html.%s", $common->get_tag_date());
    rename $html, $old_html;
  }
  open(F, ">$html");
  print F $canvas->generate_code()."\n";
  close(F);
}
else {
  print $canvas->generate_code()."\n";
}

