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
use dba_hist_sga_target_advice;
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
my $awr=dba_hist_sga_target_advice->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
my $canvas=CanvasJS->new();
my $common=Common->new();

$awr->connect();
$awr->check_open_db();

my $dbname=$awr->dbname();
my $hostname=$awr->hostname();

# ============================================================================================================
$awr->request_data();

$awr->dump_data();
my $data=$awr->data();

my @all_sga_size=$awr->get_all_sga_size();
my @all_snap_ids=$awr->get_all_snap_ids();

my @top;
my $chart;

# ============================================================================================================
# ----- affichage des donnees -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_sga_advizor_estimated_db_time", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) SGA advizor (estimated DB time)");
$chart->axisY()->set("title"=>"seconds / second");

foreach my $sga_size (@all_sga_size) {
  my $c=$chart->allocate_data();
  $c->set("type"=>"stackedColumn");
  $c->set("showInLegend"=>"true");

  my $sga_size_factor=0;  # indique que "legendText" n'a pas encore ete initialise

  foreach my $snap_id (@all_snap_ids) {
    my $delta=$awr->snapshot_delta($snap_id);
    if (! $delta) { next; }

    my $date=$awr->snapshot_date($snap_id);

    if (! $sga_size_factor) {
      $sga_size_factor=$data->{$snap_id}->{$sga_size}->{SGA_SIZE_FACTOR};
      if ($sga_size_factor) {
        $sga_size_factor=~s/^,/0,/;  # ajout d'un zero devant la virgule
        $c->set("legendText"=>"$sga_size Mo (x $sga_size_factor)");
      }
    }

    my $estd_db_time=$data->{$snap_id}->{$sga_size}->{ESTD_DB_TIME};
    if (defined($estd_db_time)) { $c->add($date, $common->round($estd_db_time / $delta, 2)); }
  }
}

# ============================================================================================================
# ----- affichage des donnees estimated physical reads -----
$chart=$canvas->allocate_chart();
$chart->attributes()->set("exportFileName"=>sprintf("%s_%s_sga_advizor_estimated_physical_reads", $hostname, $dbname));
$chart->title()->set("text"=>"$dbname ($hostname) SGA advizor (estimated physical reads)");
$chart->axisY()->set("title"=>"#");

foreach my $sga_size (@all_sga_size) {
  my $c=$chart->allocate_data();
  $c->set("type"=>"stackedColumn");
  $c->set("showInLegend"=>"true");

  my $sga_size_factor=0;  # indique que "legendText" n'a pas encore ete initialise

  foreach my $snap_id (@all_snap_ids) {
    my $delta=$awr->snapshot_delta($snap_id);
    if (! $delta) { next; }

    my $date=$awr->snapshot_date($snap_id);

    if (! $sga_size_factor) {
      $sga_size_factor=$data->{$snap_id}->{$sga_size}->{SGA_SIZE_FACTOR};
      if ($sga_size_factor) {
        $sga_size_factor=~s/^,/0,/;  # ajout d'un zero devant la virgule
        $c->set("legendText"=>"$sga_size Mo (x $sga_size_factor)");
      }
    }

    my $estd_physical_reads=$data->{$snap_id}->{$sga_size}->{ESTD_PHYSICAL_READS};
    if (defined($estd_physical_reads)) { $c->add($date, $common->round($estd_physical_reads / $delta, 2)); }
  }
}

# ----- affichage du code html -----
if ($write_into_file) {
  my $html=sprintf("%s_%s_%d_%d_sga_target_advice.html", $hostname, $dbname, $begin_snap_id || $awr->get_min_snap_id(), $end_snap_id || $awr->get_max_snap_id());

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

