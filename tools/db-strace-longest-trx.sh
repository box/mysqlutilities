#!/bin/bash
# Description:
#   Quick and dirty script to strace the longest transaction on a
#   MySQL instance by discovering the source host information
#   SSHing to that source host, and running strace on it.
#   Note: This was written to run in a linux environment and requires
#   SSH key forwarding and sudo to be all setup for your user!
#
# Authors:
#   Geoffrey Anderson <geoff@geoffreyanderson.net>
#

[[ -z "$1" ]] && { echo -e "Usage $0 <DB hostname> <db port>"; exit 1; }

BSSH="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "

function get_long_trx() {
        local db_host="$1"
        local db_port="${2:-3306}"
        echo -e "\nLongest transaction on ${db_host}:${db_port}"

        # Get client info from the database server
        read -r client_host client_port lock_count tid duration <<< $(mysql -h "$db_host" -P"$db_port" information_schema \
                -ss \
                -e "SELECT SUBSTRING_INDEX(p.HOST, ':', 1) as source_host,      \
                           SUBSTRING_INDEX(p.HOST, ':', -1) as source_port,     \
                           t.trx_rows_locked,                                   \
                           t.trx_mysql_thread_id,                               \
                           timediff(now(), t.trx_started) as duration           \
                    FROM information_schema.innodb_trx t                        \
                    JOIN information_schema.PROCESSLIST p                       \
                    ON t.trx_mysql_thread_id=p.ID                               \
                    ORDER BY trx_started ASC                                    \
                    LIMIT 1")

        echo "MySQL thread id is ${tid}, client is ${client_host}:${client_port}, ${lock_count} locked rows, running for ${duration}"

        # Connect to the client, discover the pid responsible for the long TRX, and begin strace'ing
        $BSSH "$client_host" "p=\"\$(sudo /usr/sbin/lsof -P 2>/dev/null | grep -E '${client_port}->${db_host}.*:${db_port}' | awk '{print \$2}')\"; \
                              sudo /usr/bin/strace -p \$p -s 16480 -f"

}

db_port="${2:-3306}"
get_long_trx "$1" "$db_port"
exit 0
