Patches
==============

A collection of patches to improve existing tools.

Percona
=======

A quick improvement to Percona's `pt-kill` command. It adds The extra options `--dynamic-time` and `--dynamic-user-time` causes `pt-kill` to monitor the ratio of `(max_connections-threads_connected)/ max_connections` or `(max_user_connections-user_threads_connected)/ max_user_connections)`, respectively.  This gives us a percentage of connections available (globally, or per-user), and if that percentage drops below the argument to `--dynamic-time` or `--dynamic-user-time`, then `pt-kill` will modify the value of busy-time (globally, or per user) so it can kill queries more aggressively.

Installation
============
To apply this patch, simply update and run the following command:
`patch -l /path/to/pt-kill ./mysqlutilities/patches/pt-kill_dynamic-time_2.1.1.patch`

See more details on the box blog, https://blog.box.com/blog/how-one-small-change-to-percona-tools-helped-prevent-downtime/


