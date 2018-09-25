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
use dba_hist_sys_time_model;
use dba_hist_sysstat;
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
my $awr=dba_hist_sys_time_model->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
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

# ============================================================================================================
# ----- affichage du DB time & DB CPU -----
my $chart0=$canvas->allocate_chart();
my $chart1=$canvas->allocate_chart();
my $chart2=$canvas->allocate_chart();

$chart0->attributes()->set("exportFileName"=>sprintf("%s_%s_DB_summary_db_time", $hostname, $dbname));
$chart0->title()->set("text"=>"$dbname ($hostname) DB summary");

$chart1->attributes()->set("exportFileName"=>sprintf("%s_%s_DB_summary_gets", $hostname, $dbname));
$chart1->title()->set("text"=>"$dbname ($hostname) DB summary");

$chart2->attributes()->set("exportFileName"=>sprintf("%s_%s_DB_summary_undo", $hostname, $dbname));
$chart2->title()->set("text"=>"$dbname ($hostname) DB summary");

$chart0->axisY()->set("title"=>"seconds / second");
$chart1->axisY()->set("title"=>"# / second");
$chart2->axisY()->set("title"=>"Mo");

my $c0;
my $c1;
my $c2;

$c0=$chart0->allocate_data();
$c1=$chart0->allocate_data();

$c0->set("type"=>"splineArea", "legendText"=>"DB time", "showInLegend"=>"true", "fillOpacity"=>0.3, "color"=>"Red");
$c1->set("type"=>"spline",     "legendText"=>"DB CPU",  "showInLegend"=>"true", "color"=>"Blue");

my @all_snap_ids=$awr->get_all_snap_ids();

foreach my $snap_id (@all_snap_ids) {
  my $date=$awr->snapshot_date($snap_id);
  my $delta=$awr->snapshot_delta($snap_id);

  my $value;

  $value=$data->{$snap_id}->{"DB time"}->{VALUE} || 0;
  if ((defined($value)) && ($delta)) { $c0->add($date, $common->round($value / 1000000 / $delta, 2)); }

  $value=$data->{$snap_id}->{"DB CPU"}->{VALUE} || 0;
  if ((defined($value)) && ($delta)) { $c1->add($date, $common->round($value / 1000000 / $delta, 2)); }
}

# ----- affichage du consistent gets & physical reads -----
$c0=$chart1->allocate_data();
$c1=$chart1->allocate_data();
$c2=$chart2->allocate_data();

$c0->set("type"=>"stackedColumn", "legendText"=>"consistent gets", "showInLegend"=>"true");
$c1->set("type"=>"stackedColumn", "legendText"=>"physical reads",  "showInLegend"=>"true");
$c2->set("type"=>"stackedColumn", "legendText"=>"redo size",       "showInLegend"=>"true");

$awr=dba_hist_sysstat->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
$awr->connect();
$awr->request_data();

$awr->dump_data();
$data=$awr->data();

@all_snap_ids=$awr->get_all_snap_ids();
foreach my $snap_id (@all_snap_ids) {
  my $date=$awr->snapshot_date($snap_id);
  my $delta=$awr->snapshot_delta($snap_id);

  my $value;

  $value=$data->{$snap_id}->{"consistent gets"}->{VALUE} || 0;
  if ((defined($value)) && ($delta)) { $c0->add($date, $common->round($value / $delta, 2)); }

  $value=$data->{$snap_id}->{"physical reads"}->{VALUE} || 0;
  if ((defined($value)) && ($delta)) { $c1->add($date, $common->round($value / $delta, 2)); }

  $value=$data->{$snap_id}->{"redo size"}->{VALUE} || 0;
  if ((defined($value)) && ($delta)) { $c2->add($date, $common->round($value / 1204 / 1024, 2)); }
}

# ----- affichage du code html -----
if ($write_into_file) {
  my $html=sprintf("%s_%s_%d_%d_summary.html", $hostname, $dbname, $begin_snap_id || $awr->get_min_snap_id(), $end_snap_id || $awr->get_max_snap_id());

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

