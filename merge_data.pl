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
my $rc;

foreach my $file (@ARGV) {
  $rc=$awr->read_data_from_file($file);
  if ($rc) {
    print "error reading file $file (error $rc)\n";
  }
}

$rc=$awr->dump_data("force"=>"yes");

