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
use dba_hist_buffer_pool_stat;
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
my $awr=dba_hist_buffer_pool_stat->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
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

my $buffers=$awr->{buffers};

# ----- CONSISTENT_GETS PHYSICAL_READS PHYSICAL_WRITES -----
my @columns=("CONSISTENT_GETS", "PHYSICAL_READS", "PHYSICAL_WRITES");

foreach my $name (keys %{$buffers}) {
  # ----- affichage des donnees pour chaque buffer -----
  $chart=$canvas->allocate_chart();
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_buffer_%s_statistics_1.3", $hostname, $dbname, $name));
  $chart->title()->set("text"=>"$dbname ($hostname) buffer $name statistics 1.3");
  $chart->axisY()->set("title"=>"# / second");
  $chart->axisY2()->set("title"=>"# / second");

  foreach my $col (@columns) {
    my $c=$chart->allocate_data();
    $c->set("type"=>"line", "showInLegend"=>"true");
    if    ($col eq "CONSISTENT_GETS") { $c->set("legendText"=>lc($col) . "(Y1)",                           "color"=>"Blue");  }
    elsif ($col eq "PHYSICAL_READS")  { $c->set("legendText"=>lc($col) . "(Y2)", "axisYType"=>"secondary", "color"=>"Red");   }
    else                              { $c->set("legendText"=>lc($col) . "(Y2)", "axisYType"=>"secondary", "color"=>"Green"); }

    foreach my $snap_id (@all_snap_ids) {
      my $delta=$awr->snapshot_delta($snap_id);
      if (! $delta) { next; }

      my $date=$awr->snapshot_date($snap_id);

      my $v=$data->{$snap_id}->{$name}->{$col} || 0;
      $c->add($date, $common->round($v / $delta, 2));
    }
  }
}

# ----- FREE_BUFFER_INSPECTED DIRTY_BUFFERS_INSPECTED DB_BLOCK_CHANGE DB_BLOCK_GETS -----
@columns=("FREE_BUFFER_INSPECTED", "DIRTY_BUFFERS_INSPECTED", "DB_BLOCK_CHANGE", "DB_BLOCK_GETS");

foreach my $name (keys %{$buffers}) {
  # ----- affichage des donnees pour chaque buffer -----
  $chart=$canvas->allocate_chart();
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_buffer_%s_statistics_2.3", $hostname, $dbname, $name));
  $chart->title()->set("text"=>"$dbname ($hostname) buffer $name statistics 2.3");
  $chart->axisY()->set("title"=>"# / second");
  $chart->axisY2()->set("title"=>"# / second");

  foreach my $col (@columns) {
    my $c=$chart->allocate_data();
    $c->set("type"=>"line", "showInLegend"=>"true");
    if    ($col eq "FREE_BUFFER_INSPECTED")   { $c->set("legendText"=>lc($col) . "(Y1)",                           "color"=>"Blue");  }
    elsif ($col eq "DIRTY_BUFFERS_INSPECTED") { $c->set("legendText"=>lc($col) . "(Y1)",                           "color"=>"Red");   }
    elsif ($col eq "DB_BLOCK_CHANGE")         { $c->set("legendText"=>lc($col) . "(Y2)", "axisYType"=>"secondary", "color"=>"Green"); }
    else                                      { $c->set("legendText"=>lc($col) . "(Y2)", "axisYType"=>"secondary", "color"=>"Black"); }

    foreach my $snap_id (@all_snap_ids) {
      my $delta=$awr->snapshot_delta($snap_id);
      if (! $delta) { next; }

      my $date=$awr->snapshot_date($snap_id);

      my $v=$data->{$snap_id}->{$name}->{$col} || 0;
      $c->add($date, $common->round($v / $delta, 2));
    }
  }
}

# ----- FREE_BUFFER_WAIT WRITE_COMPLETE_WAIT BUFFER_BUSY_WAIT -----
@columns=("FREE_BUFFER_WAIT", "WRITE_COMPLETE_WAIT", "BUFFER_BUSY_WAIT");

foreach my $name (keys %{$buffers}) {
  # ----- affichage des donnees pour chaque buffer -----
  $chart=$canvas->allocate_chart();
  $chart->attributes()->set("exportFileName"=>sprintf("%s_%s_buffer_%s_statistics_3.3", $hostname, $dbname, $name));
  $chart->title()->set("text"=>"$dbname ($hostname) buffer $name statistics 3.3");
  $chart->axisY()->set("title"=>"# / second");

  foreach my $col (@columns) {
    my $c=$chart->allocate_data();
    $c->set("type"=>"line", "showInLegend"=>"true", "legendText"=>lc($col));
    if    ($col eq "FREE_BUFFER_WAIT")    { $c->set("color"=>"Blue");  }
    elsif ($col eq "WRITE_COMPLETE_WAIT") { $c->set("color"=>"Red");   }
    else                                  { $c->set("color"=>"Green"); }

    foreach my $snap_id (@all_snap_ids) {
      my $delta=$awr->snapshot_delta($snap_id);
      if (! $delta) { next; }

      my $date=$awr->snapshot_date($snap_id);

      my $v=$data->{$snap_id}->{$name}->{$col} || 0;
      $c->add($date, $common->round($v / $delta, 2));
    }
  }
}

# ----- affichage du code html -----
if ($write_into_file) {
  my $html=sprintf("%s_%s_%d_%d_buffer_pool_stat.html", $hostname, $dbname, $begin_snap_id || $awr->get_min_snap_id(), $end_snap_id || $awr->get_max_snap_id());

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

