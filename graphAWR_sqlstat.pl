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
use dba_hist_sqlstat;
use Common;
use CanvasJS;

# ============================================================================================================
my $begin_snap_id=0;
my $end_snap_id=0;
my $sql_id="";
my $top=5;
my $local_datafile="";
my $write_into_file=0;

my $i=0;
while ($ARGV[$i]) {
  if    ($ARGV[$i] eq "-begin_snap_id") { $begin_snap_id=$ARGV[$i+1];  $i++; }
  elsif ($ARGV[$i] eq "-end_snap_id")   { $end_snap_id=$ARGV[$i+1];    $i++; }
  elsif ($ARGV[$i] eq "-sql_id")        { $sql_id=$ARGV[$i+1];         $i++; }
  elsif ($ARGV[$i] eq "-top")           { $top=$ARGV[$i+1];            $i++; }
  elsif ($ARGV[$i] eq "-f")             { $local_datafile=$ARGV[$i+1]; $i++; }
  elsif ($ARGV[$i] eq "-w")             { $write_into_file=1;                }

  $i++;
}

# ============================================================================================================
my $awr=dba_hist_sqlstat->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
my $common=Common->new();
my $canvas=CanvasJS->new();

$awr->connect();
$awr->check_open_db();

my $dbname=$awr->dbname();
my $hostname=$awr->hostname();

# ============================================================================================================
my @top_sql_id=$awr->get_max_by_execution("by"=>"top", "sql_id"=>$sql_id, "top"=>$top);

$awr->dump_data();
my $data=$awr->data();

my @all_snap_ids=$awr->get_all_snap_ids();

my $chart;

# ----- affichage des donnees pour chaque sql_id -----
$chart=$canvas->allocate_chart();
if (scalar(@top_sql_id) == 1) {
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_%s_elapsed_time_by_execution", $hostname, $dbname, $top_sql_id[0]));
  $chart->title()->set("text"=>"$dbname ($hostname) $top_sql_id[0] elapsed time by execution");
}
else {
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_elapsed_time_by_execution", $hostname, $dbname, $top));
  $chart->title()->set("text"=>"$dbname ($hostname) TOP $top elapsed time by execution");
}
$chart->axisY()->set("title"=>"seconds / execution");

foreach my $sql_id (@top_sql_id) {
  my $c=$chart->allocate_data();
  $c->set("type"=>"stackedColumn", "legendText"=>$sql_id, "showInLegend"=>"true", "name"=>$sql_id);

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);

    foreach my $plan_hash_value (keys %{$data->{$snap_id}->{$sql_id}}) {
      my $v=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{ELAPSED_TIME} || 0;
      my $e=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{EXECUTIONS} || 0;

      if (($v) && ($e)) { $c->cumul($date, $common->round($v / 1000000 / $e, 2)); }
    }
  }
}

# ----- affichage des donnees pour chaque sql_id -----
$chart=$canvas->allocate_chart();
if (scalar(@top_sql_id) == 1) {
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_%s_elapsed_time", $hostname, $dbname, $top_sql_id[0]));
  $chart->title()->set("text"=>"$dbname ($hostname) $top_sql_id[0] elapsed time");
}
else {
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_elapsed_time", $hostname, $dbname, $top));
  $chart->title()->set("text"=>"$dbname ($hostname) TOP $top elapsed time");
}
$chart->axisY()->set("title"=>"seconds");

foreach my $sql_id (@top_sql_id) {
  my $c=$chart->allocate_data();

  $c->set("type"=>"stackedColumn", "legendText"=>"$sql_id",  "showInLegend"=>"true", "name"=>"$sql_id");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);

    foreach my $plan_hash_value (keys %{$data->{$snap_id}->{$sql_id}}) {
      my $v=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{ELAPSED_TIME} || 0;

      $c->cumul($date, $common->round($v / 1000000, 2));
    }
  }
}

# ----- affichage des donnees pour chaque sql_id -----
$chart=$canvas->allocate_chart();
if (scalar(@top_sql_id) == 1) {
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_%s_executions", $hostname, $dbname, $top_sql_id[0]));
  $chart->title()->set("text"=>"$dbname ($hostname) $top_sql_id[0] executions");
}
else {
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_executions", $hostname, $dbname, $top));
  $chart->title()->set("text"=>"$dbname ($hostname) TOP $top executions");
}
$chart->axisY()->set("title"=>"#");

foreach my $sql_id (@top_sql_id) {
  my $c=$chart->allocate_data();

  $c->set("type"=>"stackedColumn", "legendText"=>"$sql_id",  "showInLegend"=>"true", "name"=>"$sql_id");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);

    foreach my $plan_hash_value (keys %{$data->{$snap_id}->{$sql_id}}) {
      my $e=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{EXECUTIONS} || 0;

      $c->cumul($date, $e);
    }
  }
}

# ----- affichage du code html -----
if ($write_into_file) {
  $begin_snap_id=$begin_snap_id || $awr->get_min_snap_id();
  $end_snap_id=$end_snap_id || $awr->get_max_snap_id();

  my $html;
  if (scalar(@top_sql_id) == 1) {
    $html=sprintf("%s_%s_%s_%d_%d_sqlstat.html", $hostname, $dbname, $top_sql_id[0], $begin_snap_id, $end_snap_id);
  }
  else {
    $html=sprintf("%s_%s_%d_%d_sqlstat.html", $hostname, $dbname, $begin_snap_id, $end_snap_id);
  }

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

