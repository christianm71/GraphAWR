#!/usr/bin/perl -w

# ============================================================================================================
BEGIN {
  use Config;
  my $perlpath=$Config{perlpath};
  my $ORACLE_HOME=$ENV{ORACLE_HOME} || "";
  if (($ORACLE_HOME) && (! ($perlpath=~m/^$ORACLE_HOME/))) {
    my $root=$0;
    $root=~s/\/[^\/]+$//;
    # If $root becomes empty (e.g. $0 was "script.pl"), `cd ''` might be an issue.
    # However, `cd` with an empty argument often defaults to home, or `cd .` for current.
    # Quoting $root handles spaces/special chars if any.
    $root=`cd '$root'; pwd`;
    chomp($root);

    my $executable = "$ORACLE_HOME/perl/bin/perl";
    my @perl_args = (
        "-I", $root,
        "-I", "$root/MyOracle", # MyOracle is a directory relative to $root
        $0,                     # The script name
        @ARGV                   # The original arguments to the script
    );
    system($executable, @perl_args);
    exit($? >> 8); # Use the actual exit code of the re-executed script
  }
}

# ============================================================================================================
use strict;
use dba_hist_sqlstat;
use Common;

# ============================================================================================================
sub help {
  my $script=$0;
  $script=~s/.*\///;

  print "\n$script [-begin_snap_id <snap_id>]
                   [-end_snap_id <snap_id>]
                   [-sql_id <sql_id>]  get data only for a specific sql_id
                   [-module <module>]  get data only for a specific module
                   [-top <n>]  TOP n sql_ids, default 5
                   [-f <local_datafile>]  use data from file
                   [-w]  write results in a file\n\n";

  die;
}

# ============================================================================================================
my $begin_snap_id=0;
my $end_snap_id=0;
my $sql_id="";
my $module="";
my $top=5;
my $local_datafile="";
my $write_into_file=0;

my $i=0;
while ($ARGV[$i]) {
  if    ($ARGV[$i] eq "-begin_snap_id") { $begin_snap_id=$ARGV[$i+1];  $i++; }
  elsif ($ARGV[$i] eq "-end_snap_id")   { $end_snap_id=$ARGV[$i+1];    $i++; }
  elsif ($ARGV[$i] eq "-sql_id")        { $sql_id=$ARGV[$i+1];         $i++; }
  elsif ($ARGV[$i] eq "-module")        { $module=$ARGV[$i+1];         $i++; }
  elsif ($ARGV[$i] eq "-top")           { $top=$ARGV[$i+1];            $i++; }
  elsif ($ARGV[$i] eq "-f")             { $local_datafile=$ARGV[$i+1]; $i++; }
  elsif ($ARGV[$i] eq "-w")             { $write_into_file=1;                }
  elsif ($ARGV[$i] eq "-help")          { help();                            }
  else                                  { print STDERR "Invalid argument: \$ARGV[\$i]\n"; help(); }

  $i++;
}

# ============================================================================================================
my $awr=dba_hist_sqlstat->new("begin_snap_id"=>$begin_snap_id, "end_snap_id"=>$end_snap_id);
my $common=Common->new();

if ($local_datafile) {
  $awr->read_data_from_file($local_datafile);
}
else {
  $awr->connect();
  $awr->check_open_db();
}

# ============================================================================================================
# ----- affichage des donnees pour chaque sql_id -----
sub print_data {
  my (@top_sql_id) = @_;

  my @all_snap_ids=$awr->get_all_snap_ids();
  my $data=$awr->data();

  printf("%-13s %-60s %-15s %-16s %16s %s %s\n", "SQL_ID", "MODULE", "PLAN_HASH_VALUE", "DATE", "ELAPSED_TIME (S)", "EXECUTIONS", "ELAPSED_TIME (MS)/EXECUTIONS");
  printf("%s %s %s %s %s %s %s\n", "-"x13, "-"x60, "-"x15, "-"x16, "-"x16, "-"x10, "-"x28);
  foreach my $sql_id (@top_sql_id) {
    foreach my $snap_id (sort { $a <=> $b } @all_snap_ids) {
      my $date=$awr->snapshot_date($snap_id);

      foreach my $plan_hash_value (keys %{$data->{$snap_id}->{$sql_id}}) {
        my $elapsed_time=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{ELAPSED_TIME} || 0;
        my $executions=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{EXECUTIONS} || 0;
        my $module=$data->{$snap_id}->{$sql_id}->{$plan_hash_value}->{MODULE} || "";

        my $seconds=sprintf("%16.1f", $elapsed_time/1000000);
        $seconds=~s/(\d)(\d{3})\./$1,$2./;
        $seconds=~s/(\d)(\d{3}),/$1,$2,/;
        $seconds=~s/(\d)(\d{3}),/$1,$2,/;

        printf("%s %-60s %15s %s %16s %10d", $sql_id, $module, $plan_hash_value ? $plan_hash_value : "", $date, $seconds, $executions);

        if ($executions) {
          $elapsed_time=$common->round($elapsed_time / 1000 / $executions, 2);
          $elapsed_time=~s/(\d)(\d{3})\./$1,$2./;
          $elapsed_time=~s/(\d)(\d{3}),/$1,$2,/;
          $elapsed_time=~s/(\d)(\d{3}),/$1,$2,/;

          printf(" %28s", $elapsed_time);
        }
        print "\n";
      }
    }
    print "\n";
  }
}

# ============================================================================================================
my @top_sql_id;

@top_sql_id=$awr->get_max_by_execution("sql_id"=>$sql_id, "module"=>$module, "top"=>$top);
print "TOP $top elapsed_time by execution\n";
print_data(@top_sql_id);

@top_sql_id=$awr->get_max("by"=>"top", "sql_id"=>$sql_id, "module"=>$module, "top"=>$top);
print "TOP $top elapsed_time (by maximum)\n";
print_data(@top_sql_id);

@top_sql_id=$awr->get_max("by"=>"cumul", "sql_id"=>$sql_id, "module"=>$module, "top"=>$top);
print "TOP $top elapsed_time (by cumul)\n";
print_data(@top_sql_id);

if (! $local_datafile) {
  $awr->dump_data();
}

