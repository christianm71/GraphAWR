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
my $awr=dba_hist_sysstat->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
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

# ============================================================================================================
my @sort_statistics=$awr->sort_statistics("statistics"=>"DBWR checkpoint buffers written, DBWR object drop buffers written, DBWR parallel query checkpoint buffers written, DBWR revisited being-written buffer, DBWR tablespace checkpoint buffers written, DBWR thread checkpoint buffers written");

$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_dbwr_statistics_1", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) DBWR statistics");
$chart->axisY()->set("title"=>"#");

foreach my $stat_name (@sort_statistics) {
  my $c=$chart->allocate_data();
  $c->set("type"=>"stackedColumn");
  $c->set("legendText"=>$stat_name, "name"=>$stat_name);

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$stat_name}->{VALUE};
    if (defined($v)) { $c->add($date, $v); }
  }
}

# ============================================================================================================
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_dbwr_statistics_2", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) DBWR statistics");
$chart->axisY()->set("title"=>"checkpoints");
$chart->axisY2()->set("title"=>"lru scans");

# ----- DBWR checkpoints -----
my $stat_name="DBWR checkpoints";
my $c=$chart->allocate_data();
$c->set("type"=>"line");
$c->set("legendText"=>$stat_name, "name"=>$stat_name, "color"=>"Red");

foreach my $snap_id (@all_snap_ids) {
  my $date=$awr->snapshot_date($snap_id);
  my $v=$data->{$snap_id}->{$stat_name}->{VALUE};
  if (defined($v)) { $c->add($date, $v); }
}

# ----- DBWR lru scans -----
$stat_name="DBWR lru scans";
$c=$chart->allocate_data();
$c->set("type"=>"line");
$c->set("legendText"=>$stat_name, "name"=>$stat_name, "axisYType"=>"secondary", "color"=>"Blue");

foreach my $snap_id (@all_snap_ids) {
  my $date=$awr->snapshot_date($snap_id);
  my $v=$data->{$snap_id}->{$stat_name}->{VALUE};
  if (defined($v)) { $c->add($date, $v); }
}

# ============================================================================================================
@sort_statistics=$awr->sort_statistics("statistics"=>"DBWR fusion writes, DBWR transaction table writes, DBWR undo block writes");

$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_dbwr_statistics_3", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) DBWR statistics");
$chart->axisY()->set("title"=>"#");

foreach my $stat_name (@sort_statistics) {
  my $c=$chart->allocate_data();
  $c->set("type"=>"stackedColumn");
  $c->set("legendText"=>$stat_name, "name"=>$stat_name);

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$stat_name}->{VALUE};
    if (defined($v)) { $c->add($date, $v); }
  }
}

# ============================================================================================================
@sort_statistics=$awr->sort_statistics("statistics"=>"db block changes db block gets, db block gets direct, db block gets from cache, db block gets from cache (fastpath), db corrupt blocks detected, db corrupt blocks recovered");

$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_dbwr_statistics_4", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) DBWR statistics");
$chart->axisY()->set("title"=>"#");

foreach my $stat_name (@sort_statistics) {
  my $c=$chart->allocate_data();
  $c->set("type"=>"stackedColumn");
  $c->set("legendText"=>$stat_name, "name"=>$stat_name);

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$stat_name}->{VALUE};
    if (defined($v)) { $c->add($date, $v); }
  }
}

# ============================================================================================================
@sort_statistics=$awr->sort_statistics("statistics"=>"application wait time,
                                                      change write time,
                                                      cluster wait time,
                                                      concurrency wait time,
                                                      DX/BB enqueue lock background get time,
                                                      DX/BB enqueue lock foreground wait time,
                                                      Effective IO time,
                                                      file io service time,
                                                      file io wait time,
                                                      global enqueue get time,
                                                      max cf enq hold time,
                                                      non-idle wait time,
                                                      OS CPU Qt wait time,
                                                      OS System time used,
                                                      OS User time used,
                                                      parse time cpu,
                                                      parse time elapsed,
                                                      process last non-idle time,
                                                      recovery array read time,
                                                      scheduler wait time,
                                                      securefile inode ioreap time,
                                                      securefile inode read time,
                                                      securefile inode write time,
                                                      segment prealloc time (ms),
                                                      session connect time,
                                                      total cf enq hold time,
                                                      transaction lock background get time,
                                                      transaction lock foreground wait time,
                                                      user I/O wait time");

$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_dbwr_statistics_5", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) DBWR statistics");
$chart->axisY()->set("title"=>"#");

foreach my $stat_name (@sort_statistics) {
  my $c=$chart->allocate_data();
  $c->set("type"=>"stackedColumn");
  $c->set("legendText"=>$stat_name, "name"=>$stat_name);

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$stat_name}->{VALUE};
    if (defined($v)) { $c->add($date, $v); }
  }
}

# ============================================================================================================
foreach my $stat_name ("redo blocks checksummed by FG (exclusive)",
                       "redo blocks checksummed by LGWR",
                       "redo blocks read for recovery",
                       "redo blocks written",
                       "redo buffer allocation retries",
                       "redo entries",
                       "redo entries for lost write detection",
                       "redo KB read",
                       "redo KB read for transport",
                       "redo KB read (memory)",
                       "redo KB read (memory) for transport",
                       "redo k-bytes read for recovery",
                       "redo k-bytes read for terminal recovery",
                       "redo log space requests",
                       "redo log space wait time",
                       "redo ordering marks",
                       "redo size",
                       "redo size for direct writes",
                       "redo size for lost write detection",
                       "redo subscn max counts",
                       "redo synch long waits",
                       "redo synch poll writes",
                       "redo synch polls",
                       "redo synch time",
                       "redo synch time overhead count (<128 msec)",
                       "redo synch time overhead count (>=128 msec)",
                       "redo synch time overhead count (<2 msec)",
                       "redo synch time overhead count (<32 msec)",
                       "redo synch time overhead count (<8 msec)",
                       "redo synch time overhead (usec)",
                       "redo synch time (usec)",
                       "redo synch writes",
                       "redo wastage",
                       "redo write broadcast ack count",
                       "redo write broadcast ack time",
                       "redo write broadcast lgwr post count",
                       "redo write info find",
                       "redo write info find fail",
                       "redo write time",
                       "redo writes") {
  $chart=$canvas->allocate_chart();
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_dbwr_statistics_6_%s", $hostname, $dbname, $stat_name));
  $chart->title()->set("text"=>"$dbname ($hostname) $stat_name");
  $chart->axisY()->set("title"=>"#");

  my $c=$chart->allocate_data();
  #$c->set("type"=>"stackedColumn");
  $c->set("type"=>"line");
  $c->set("legendText"=>$stat_name, "name"=>$stat_name);

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $v=$data->{$snap_id}->{$stat_name}->{VALUE};
    if (defined($v)) { $c->add($date, $v); }
  }
}

# ----- affichage du code html -----
if ($write_into_file) {
  my $html=sprintf("%s_%s_%d_%d_sysstat.html", $hostname, $dbname, $begin_snap_id || $awr->get_min_snap_id(), $end_snap_id || $awr->get_max_snap_id());

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

