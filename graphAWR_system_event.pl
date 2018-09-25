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
use dba_hist_system_event;
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
my $awr=dba_hist_system_event->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
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
# ----- affichage des donnees pour chaque wait class -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_top_%d_wait_events", $hostname, $dbname, $top));
$chart->title()->set("text"=>"$dbname ($hostname) TOP $top wait events");
$chart->axisY()->set("title"=>"seconds / second");

my @top_event_names=$awr->get_top_event_names("column"=>"TIME_WAITED_MICRO", "exclude_wait_class_list"=>"Idle");

foreach my $event_name_wait_class (@top_event_names) {
  my ($event_name, $wait_class)=split(/;/, $event_name_wait_class);

  my $c=$chart->allocate_data();
  $c->set("type"=>"stackedColumn");
  $c->set("legendText"=>"$event_name ($wait_class)", "showInLegend"=>"true", "name"=>"$event_name ($wait_class)");

  foreach my $snap_id (@all_snap_ids) {
    my $date=$awr->snapshot_date($snap_id);
    my $delta=$awr->snapshot_delta($snap_id);
    my $v=$data->{$snap_id}->{$event_name}->{$wait_class}->{TIME_WAITED_MICRO};

    if ((defined($v)) && ($delta)) { $c->add($date, $common->round($v / 1000000 / $delta, 2)); }
  }
}

# ----- affichage du code html -----
if ($write_into_file) {
  my $html=sprintf("%s_%s_%d_%d_system_event.html", $hostname, $dbname, $begin_snap_id || $awr->get_min_snap_id(), $end_snap_id || $awr->get_max_snap_id());

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

