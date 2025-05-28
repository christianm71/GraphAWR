# Oracle AWR Performance Analysis Scripts

## Overview

This repository contains a collection of Perl scripts and modules designed for interacting with Oracle's Automatic Workload Repository (AWR). These tools help in extracting, storing, and analyzing performance data from Oracle databases.

## Scripts and Modules

### Key Scripts:
*   `awr_sqlstat.pl`: Analyzes SQL statistics from AWR data.
*   `graphAWR_summary.pl`: Generates summary graphs from AWR data.
*   `graphAWR_active_sess_history.pl`: Visualizes Active Session History.
*   `graphAWR_sysstat.pl`: Graphs system statistics from AWR.
*   `graphAWR_system_event.pl`: Graphs system event data.
*   `graphAWR_filestats.pl`: Graphs I/O statistics for database files.
*   `graphAWR_sqlstat.pl`: Visualizes SQL statistics (likely complements `awr_sqlstat.pl`).
*   *(User can add more scripts here as they document them)*

The `graphAWR_*.pl` scripts likely generate charts using the `CanvasJS.pm` module.

### Core Modules:
*   `MyAWR.pm`: Handles AWR data extraction, file dumping, and reading.
*   `MyOracle.pm`: Provides the basic Oracle database connection and query functionalities.
*   `Common.pm`: Contains common utility functions (e.g., for date calculations).
*   `dba_hist_*.pm` modules (e.g., `dba_hist_sqlstat.pm`): Likely represent specific AWR views and their data structures.

## Prerequisites

*   **Oracle Database:** Access to an Oracle database with AWR licensing and data.
*   **Oracle Client:** Oracle client libraries/instant client might be needed on the machine running the scripts if the database is remote.
*   **Perl:** A working Perl installation.
    *   The scripts may attempt to use the Perl interpreter from `$ORACLE_HOME/perl` if available and not already running from it.
*   **Perl Modules:**
    *   `DBI`
    *   `DBD::Oracle`
    *   `Storable` (used for data file serialization)
    *   The graphing scripts (`graphAWR_*.pl`) depend on `CanvasJS.pm` (included in this repository) to generate HTML/JavaScript charts.
    *   *(User should list any other non-core modules identified during usage)*

## Basic Usage

This section will provide examples of how to run the scripts.

The scripts are typically run from the command line. For example, to get the top 10 SQL statements by elapsed time between snapshot IDs 100 and 101, and write the raw data to a file:

```bash
perl awr_sqlstat.pl -begin_snap_id 100 -end_snap_id 101 -top 10 -w
```

**Common options for `awr_sqlstat.pl`:**
*   `-begin_snap_id <id>`: Starting snapshot ID.
*   `-end_snap_id <id>`: Ending snapshot ID.
*   `-sql_id <sql_id>`: Filter by a specific SQL ID.
*   `-module <module_name>`: Filter by a specific module name.
*   `-top <n>`: Display the top N SQL statements (default is 5).
*   `-f <local_datafile>`: Use data from a previously saved local file instead of connecting to the database.
*   `-w`: Write the fetched AWR data to a local file.
*   `-help`: Display the help message.

Other scripts will have similar command-line interfaces. Use the `-help` option (if available) for specific details.

## Data Files

*   Scripts like `awr_sqlstat.pl` can dump AWR data into local files using the `-w` option. The filename typically follows the pattern: `AWR_<instance_name>_<instance_number>_<hostname>_<view_name>_<min_snap_id>_<max_snap_id>.txt` (or `.txt.gz` if compressed).
*   These data files can then be used for offline analysis using the `-f <datafile>` option, reducing load on the database for repeated analyses.
*   These files are serialized using Perl's `Storable` module.

## Contributing

*(Placeholder: Specify contribution guidelines if applicable, e.g., "Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.")*

## License

*(Placeholder: Specify License Here, e.g., MIT License, Apache 2.0, or "Proprietary - All Rights Reserved")*
