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
use dba_hist_filestatxs;
use Common;
use CanvasJS;

# ============================================================================================================
my $begin_snap_id=0;
my $end_snap_id=0;
my $top=5;
my $local_datafile="";
my $write_into_file=0;

my $i=0;
while ($ARGV[$i]) {
  if    ($ARGV[$i] eq "-begin_snap_id") { $begin_snap_id=$ARGV[$i+1];  $i++; }
  elsif ($ARGV[$i] eq "-end_snap_id")   { $end_snap_id=$ARGV[$i+1];    $i++; }
  elsif ($ARGV[$i] eq "-top")           { $top=$ARGV[$i+1];            $i++; }
  elsif ($ARGV[$i] eq "-f")             { $local_datafile=$ARGV[$i+1]; $i++; }
  elsif ($ARGV[$i] eq "-w")             { $write_into_file=1;                }

  $i++;
}

# ============================================================================================================
my $awr=dba_hist_filestatxs->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
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
my $datafiles=$awr->get_datafiles();

my @top;
my $chart;

# ============================================================================================================
# ----- TOP n des READTIM -----
@top=$awr->get_top("column"=>"READTIM", "by"=>"top", "top"=>$top);

# ----- affichage des donnees READTIM -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_files_by_read_time", $hostname, $dbname, $top));
$chart->title()->set("text"=>"$dbname ($hostname) TOP $top files by Read time");
$chart->axisY()->set("title"=>"milli seconds");

foreach my $file_id (@top) {
  my $c=$chart->allocate_data();

  $c->set("type"=>"stackedColumn");
  my $file_name=$datafiles->{$file_id} || "";
  $file_name=~s/.*\///;
  $c->set("legendText"=>$file_name, "showInLegend"=>"true");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$file_id}->{READTIM};
    if (defined($v)) { $c->add($date, $common->round(10*$v, 2)); }
  }
}

# ----- affichage des donnees READTIM_BY_READ -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_files_by_read_time_by_read", $hostname, $dbname, $top));
$chart->title()->set("text"=>"$dbname ($hostname) TOP $top files by Read time by read");
$chart->axisY()->set("title"=>"milli seconds");

foreach my $file_id (@top) {
  my $c=$chart->allocate_data();

  my $file_name=$datafiles->{$file_id} || "";
  $file_name=~s/.*\///;
  $c->set("type"=>"stackedColumn", "legendText"=>$file_name, "showInLegend"=>"true");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$file_id}->{READTIM_BY_READ};
    if (defined($v)) { $c->add($date, $common->round(10*$v, 2)); }
  }
}

# ============================================================================================================
# ----- TOP n des WRITETIM -----
@top=$awr->get_top("column"=>"WRITETIM", "by"=>"top", "top"=>$top);

# ----- affichage des donnees WRITETIM -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_files_by_write_time", $hostname, $dbname, $top));
$chart->title()->set("text"=>"$dbname ($hostname) TOP $top files by Write time");
$chart->axisY()->set("title"=>"milli seconds");

foreach my $file_id (@top) {
  my $c=$chart->allocate_data();

  my $file_name=$datafiles->{$file_id} || "";
  $file_name=~s/.*\///;
  $c->set("type"=>"stackedColumn", "legendText"=>$file_name, "showInLegend"=>"true");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$file_id}->{WRITETIM};
    if (defined($v)) { $c->add($date, $common->round(10*$v, 2)); }
  }
}

# ----- affichage des donnees WRITETIM_BY_WRITE -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_files_by_write_time_by_write", $hostname, $dbname, $top));
$chart->title()->set("text"=>"$dbname ($hostname) TOP $top files by Write time by write");
$chart->axisY()->set("title"=>"milli seconds");

foreach my $file_id (@top) {
  my $c=$chart->allocate_data();

  my $file_name=$datafiles->{$file_id} || "";
  $file_name=~s/.*\///;
  $c->set("type"=>"stackedColumn", "legendText"=>$file_name, "showInLegend"=>"true");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$file_id}->{WRITETIM_BY_WRITE};
    if (defined($v)) { $c->add($date, $common->round(10*$v, 2)); }
  }
}

# ============================================================================================================
# ----- TOP n des PHYRDS -----
@top=$awr->get_top("column"=>"PHYRDS", "top"=>$top);

# ----- affichage des donnees PHYRDS -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_files_by_physical_reads", $hostname, $dbname, $top));
$chart->title()->set("text"=>"$dbname ($hostname) TOP $top files by physical reads");
$chart->axisY()->set("title"=>"#");

foreach my $file_id (@top) {
  my $c=$chart->allocate_data();

  my $file_name=$datafiles->{$file_id} || "";
  $file_name=~s/.*\///;
  $c->set("type"=>"stackedColumn", "legendText"=>$file_name, "showInLegend"=>"true");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$file_id}->{PHYRDS};
    if (defined($v)) { $c->add($date, $v); }
  }
}

# ============================================================================================================
# ----- TOP n des PHYWRTS -----
@top=$awr->get_top("column"=>"PHYWRTS", "top"=>$top);

# ----- affichage des donnees PHYWRTS -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_files_by_physical_writes", $hostname, $dbname, $top));
$chart->title()->set("text"=>"$dbname ($hostname) TOP $top files by physical writes");
$chart->axisY()->set("title"=>"#");

foreach my $file_id (@top) {
  my $c=$chart->allocate_data();

  my $file_name=$datafiles->{$file_id} || "";
  $file_name=~s/.*\///;
  $c->set("type"=>"stackedColumn", "legendText"=>$file_name, "showInLegend"=>"true");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$file_id}->{PHYWRTS};
    if (defined($v)) { $c->add($date, $v); }
  }
}

# ----- affichage du code html -----
if ($write_into_file) {
  my $html=sprintf("%s_%s_%d_%d_filestats.html", $hostname, $dbname, $begin_snap_id || $awr->get_min_snap_id(), $end_snap_id || $awr->get_max_snap_id());

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

