Patches
==============

A collection of patches to improve existing tools.

Percona
=======

A quick improvement to Percona's `pt-kill` command. It adds The extra option `--dynamic-time` causes `pt-kill` to monitor the ratio of `(max_connections-threads_connected)/ max_connections`.  This gives us a percentage of connections available, and if that percentage drops below the argument to `--dynamic-time`, then `pt-kill` will modify the value of busy-time so it can kill queries more aggressively.

See more details on the box blog, at 


