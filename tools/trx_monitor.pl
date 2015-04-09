#!/usr/bin/perl
# Description:
#   Quick and dirty perl script to find the longest transaction in
#   MySQL, try to get a query, and then kill the TRX.
#   NOTE: this will run tcpdump in an attemp to get a sample query
#   from the longest transaction.
#
# Authors:
#   Gavin Towey <gavin@box.com>
#   Geoffrey Anderson <geoff@box.com>
#

use strict;
use DBI;
use Data::Dumper;
use Getopt::Long;
use Sys::Hostname;

my %opt;
GetOptions(\%opt,
	'user=s',
	'password=s',
	'kill-trx',
	'collect',
	'host=s',
);
my $my_cnf = $ENV{HOME}."/.my.cnf";

my $host = 'localhost';
if ($opt{'host'})
{
	$host = $opt{'host'};
}
my $dsn = "DBI:mysql::host=$host;mysql_read_default_file=$my_cnf";

my $dbh = DBI->connect($dsn, $opt{'user'}, $opt{'password'}, {RaiseError => 1} ) or die $DBI::errstr;

my $where = '';
if ($#ARGV >= 0) {
	print Dumper \@ARGV;
	$where = " WHERE trx_id = '$ARGV[0]' ";
}
my $query = "SELECT *,unix_timestamp()-unix_timestamp(trx_started) as duration FROM INFORMATION_SCHEMA.INNODB_TRX $where ORDER BY trx_started LIMIT 1";
print $query ."\n";
my $sth = $dbh->prepare($query);
$sth->execute() or die $dbh->errstr;
my $data1 = get_query_id($sth);
my $query_id = $data1->{trx_mysql_thread_id};

$query = "SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE id=$query_id";
$sth = $dbh->prepare($query);
$sth->execute() or die $dbh->errstr;

my $data2 = get_source($sth);
my $source = $data2->{HOST};
my ($host,$port) = split(/:/, $source);

print "Found $host $port; attaching tcpdump\n";
my $pid = handle_tcpdump($host, $port);
wait_for_queries($dbh, $query_id);
kill_tcpdump($pid);
print "\n";
if ($opt{'kill-trx'}) {
	kill_query($dbh,$query_id);
}
exit;

sub wait_for_queries(@,@) {
	my ($dbh, $query_id) = @_;

	my $last_query_time = 0;
	my $done= 0;
	my $start_time = time();
	while (!$done and time()-$start_time < 300) {
		my $sth = $dbh->prepare("SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE id=$query_id");
		my $result = $sth->execute();
		if (!$result) { $done = 1; }
		my $row = $sth->fetchrow_hashref;
		if (!$row) { $done = 1; }
		if ($row->{TIME_MS} < $last_query_time) { $done = 1; }
		$last_query_time = $row->{TIME_MS};
		sleep(5);
	}
	if (time()-$start_time >= 600 )
	{
		print "max time reached ... quiting without query capture\n";
	} else {
		print "Found query .. waiting for more\n";
	}
	sleep(5);
}

sub kill_tcpdump(@) {
	my ($pid) = shift;

	print "Killing tcpdump with parent pid $pid\n";
	system("sudo kill -9 \$( ps --ppid $pid -o \"\%p\" | tail -n1)");
}

sub handle_tcpdump(@,@) {
	my ($host,$port) = @_;

	my $pid = fork();
	if (!$pid) {
		my $cmd = "sudo tcpdump -i vlan64 -nn -s0 -q -w - 'src host $host and dst port 3306 and src port $port' | strings";
		print $cmd."\n";
		exec($cmd);
	} else {
		return $pid;
	}
}

sub get_source(@) {
	my $sth = shift;
	while (my $row = $sth->fetchrow_hashref) {
		print Dumper($row);
		return $row;
	}
}

sub get_query_id(@) {
	my $sth = shift;
	while (my $row = $sth->fetchrow_hashref)
	{
		print Dumper($row);
		return $row;
		return $row->{trx_mysql_thread_id};
	}
}

sub kill_query(@,@) {
	my ($dbh, $query_id)  = @_;
	print "Killing query with thread id $query_id\n";
	$dbh->do("KILL $query_id");
}

