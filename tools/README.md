Tools
==============

A collection of small tools we use!


`trx_monitor.pl`
=======

This is a simple perl script that you can interactively run to try and get a query out of the longest transaction on a specific MySQL server.  A sample invocation would be:
  `./trx_monitor.pl --host db.example.com --collect --kill-trx`


`db-strace-longest-trx.sh`
========================

This is a simple shell script that you interactively run in order to `strace` the process responsible for the longest transaction on a MySQL instance.  A sample invocation would be:
  `./db-strace-longest-trx.sh db.example.com`

NOTE: This assumes you have SSH key forwarding setup in your environment and root-level permissions in order to run `lsof` and `strace` on a machine that is connecting to your database.

