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
use MyAWR;

# ============================================================================================================
my $awr=MyAWR->new();

$awr->connect();
my $dbname=$awr->dbname();
my $hostname=$awr->hostname();

my $db_informations=$awr->get_db_informations();
if (! ($db_informations->{OPEN_MODE}=~/READ/)) {
  printf("\nla base $dbname n'est pas ouverte en lecture (OPEN_MODE=%s)\n\n", $db_informations->{OPEN_MODE});
  exit(1);
}

# ============================================================================================================
$awr->get_snapshot_dates();
my @all_snap_ids=$awr->get_all_snap_ids();

foreach my $snap_id (@all_snap_ids) {
  printf("%d : %s : %d seconds\n", $snap_id, $awr->snapshot_dates->{$snap_id}->{end_interval_time}, $awr->snapshot_dates->{$snap_id}->{end_interval_delta_seconds} || 0);
}
