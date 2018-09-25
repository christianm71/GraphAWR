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
use dba_hist_active_sess_history;
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
my $awr=dba_hist_active_sess_history->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
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
my %stats=();
my %cumul=();

foreach my $snap_id (keys %{$data}) {
  foreach my $sample_id (keys %{$data->{$snap_id}}) {
    foreach my $session_id (keys %{$data->{$snap_id}->{$sample_id}}) {
      my $date=$awr->snapshot_date($snap_id);

      my $href=$data->{$snap_id}->{$sample_id}->{$session_id};

      my $session_type=$href->{SESSION_TYPE};
      my $wait_time=$href->{WAIT_TIME} || 0;
      my $time_waited=$href->{TIME_WAITED} || 0;
      my $event=$href->{EVENT} || "CPU";

      $stats{$snap_id}{$session_type}{count}=$stats{$snap_id}{$session_type}{count} || 0;
      $stats{$snap_id}{$session_type}{$event}{wait_time}=$stats{$snap_id}{$session_type}{$event}{wait_time} || 0;
      $stats{$snap_id}{$session_type}{$event}{time_waited}=$stats{$snap_id}{$session_type}{$event}{time_waited} || 0;

      $stats{$snap_id}{$session_type}{count}++;
      $stats{$snap_id}{$session_type}{$event}{wait_time}+=$wait_time;
      $stats{$snap_id}{$session_type}{$event}{time_waited}+=$time_waited;

      $cumul{$session_type}{$event}=$cumul{$session_type}{$event} || 0;
      $cumul{$session_type}{$event}+=$time_waited;
    }
  }
}

# ============================================================================================================
# ----- affichage du wait time FOREGROUND -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_foreground_session_statistics_cpu", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) foreground session statistics (wait time on CPU)");
$chart->axisY()->set("title"=>"seconds");

my $session_type="FOREGROUND";

my %mem_allocate_data=();
foreach my $snap_id (@all_snap_ids) {
  my $delta=$awr->snapshot_delta($snap_id);
  if (! $delta) { next; }

  foreach my $event (keys %{$stats{$snap_id}{$session_type}}) {
    if ($event ne "CPU") { next; }

    my $c=$mem_allocate_data{$event} || 0;
    if (! $c) {
      $c=$chart->allocate_data();
      $mem_allocate_data{$event}=$c;
    }
    $c->set("type"=>"stackedColumn");
    $c->set("legendText"=>"wait time on CPU", "name"=>"wait time on CPU");

    my $date=$awr->snapshot_date($snap_id);

    my $v=$stats{$snap_id}{$session_type}{$event}{wait_time} || 0;
    $c->add($date, $common->round($v / 100 / $delta, 2));
  }
}

# ----- affichage du time waited FOREGROUND -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_foreground_session_statistics_events", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) foreground session statistics (time waited on events)");
$chart->axisY()->set("title"=>"seconds");

my @top=reverse sort { $cumul{$session_type}{$a} <=> $cumul{$session_type}{$b} } keys %{$cumul{$session_type}};
while (scalar(@top) > 10) { pop(@top); }

%mem_allocate_data=();
foreach my $snap_id (@all_snap_ids) {
  my $delta=$awr->snapshot_delta($snap_id);
  if (! $delta) { next; }

  foreach my $event (@top) {
    if ($event eq "count") { next; }
    if ($event eq "CPU") { next; }

    my $c=$mem_allocate_data{$event} || 0;
    if (! $c) {
      $c=$chart->allocate_data();
      $mem_allocate_data{$event}=$c;
    }
    $c->set("type"=>"stackedColumn");
    $c->set("legendText"=>"$event", "name"=>"$event");

    my $date=$awr->snapshot_date($snap_id);

    my $v=$stats{$snap_id}{$session_type}{$event}{time_waited} || 0;
    $c->add($date, $common->round($v / 100 / $delta, 2));
  }
}

# ============================================================================================================
# ----- affichage du wait time BACKGROUND -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_background_session_statistics_cpu", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) background session statistics (wait time on CPU)");
$chart->axisY()->set("title"=>"seconds");

$session_type="BACKGROUND";

%mem_allocate_data=();
foreach my $snap_id (@all_snap_ids) {
  my $delta=$awr->snapshot_delta($snap_id);
  if (! $delta) { next; }

  foreach my $event (keys %{$stats{$snap_id}{$session_type}}) {
    if ($event ne "CPU") { next; }

    my $c=$mem_allocate_data{$event} || 0;
    if (! $c) {
      $c=$chart->allocate_data();
      $mem_allocate_data{$event}=$c;
    }
    $c->set("type"=>"stackedColumn");
    $c->set("legendText"=>"wait time on CPU", "name"=>"wait time on CPU");

    my $date=$awr->snapshot_date($snap_id);

    my $v=$stats{$snap_id}{$session_type}{$event}{wait_time} || 0;
    $c->add($date, $common->round($v / 100 / $delta, 2));
  }
}

# ----- affichage du time waited BACKGROUND -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_background_session_statistics_events", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) background session statistics (time waited on events)");
$chart->axisY()->set("title"=>"seconds");

@top=reverse sort { $cumul{$session_type}{$a} <=> $cumul{$session_type}{$b} } keys %{$cumul{$session_type}};
while (scalar(@top) > 10) { pop(@top); }

%mem_allocate_data=();
foreach my $snap_id (@all_snap_ids) {
  my $delta=$awr->snapshot_delta($snap_id);
  if (! $delta) { next; }

  foreach my $event (@top) {
    if ($event eq "count") { next; }
    if ($event eq "CPU") { next; }

    my $c=$mem_allocate_data{$event} || 0;
    if (! $c) {
      $c=$chart->allocate_data();
      $mem_allocate_data{$event}=$c;
    }
    $c->set("type"=>"stackedColumn");
    $c->set("legendText"=>"$event", "name"=>"$event");

    my $date=$awr->snapshot_date($snap_id);

    my $v=$stats{$snap_id}{$session_type}{$event}{time_waited} || 0;
    $c->add($date, $common->round($v / 100 / $delta, 2));
  }
}

# ----- affichage du code html -----
if ($write_into_file) {
  my $html=sprintf("%s_%s_%d_%d_active_sess_history.html", $hostname, $dbname, $begin_snap_id || $awr->get_min_snap_id(), $end_snap_id || $awr->get_max_snap_id());

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

