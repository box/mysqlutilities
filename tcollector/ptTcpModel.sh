#!/bin/bash
# Tcollector to do some TCP analysis for throughput
# Created by: Gavin Towey <gavin@box.com>
# Created on: 2012-12-19
# Updated by: Geoffrey Anderson <geoff@box.com>
# Updated on: 2012-12-21

d="$(date +%Y_%m_%d_%H_%M_%S)"
self="$(basename $0)"
sleep_time=11 # duration to capture tcpdump data in seconds
tmp_dir='/tmp'
lock_file="${self}.lockfile"
tcpdump_raw_file="tcpdump.out"
model_work_file="tcpdump.temp"
result_file="sliced.txt"

cleanup_pt_tcp_collector()
{
	rm -f "${tmp_dir}/${model_work_file}" "${tmp_dir}/${result_file}" "${tmp_dir}/${lock_file}" "${tmp_dir}/${tcpdump_raw_file}"
}

# check lock file
if [[ -e "${tmp_dir}/${lock_file}" ]]
then
	echo "${self}: lock file ${lock_file} already exists, aborting"
	exit 1
fi

# Set a trap for if the script is killed before the wait time is over
trap 'rm -f "${tmp_dir}/${lock_file}"; exit' INT TERM EXIT
touch "${tmp_dir}/${lock_file}"

current_time="$(date +%s)"
next_time="$( echo "${current_time} 10" | awk '{ print (int( $1/$2)+1)*$2 }' )"
let wait_time=($next_time-$current_time-1)

if (( $wait_time < 0 ))
then
	wait_time=9
fi

#echo "waiting for $wait_time"
sleep $wait_time

# set trap to be sure tcpdump doesn't run for ever and clean up the temp file too
trap 'rm -f "${tmp_dir}/${lock_file}"; kill $tcpdump_pid; rm -f "${tmp_dir}/${tcpdump_raw_file}"; exit' INT TERM EXIT

# run the tcpdump & write to remote file and sleep for a bit
tcpdump -s 384 -i any -nnq -tttt -w "${tmp_dir}/${tcpdump_raw_file}" \
	'tcp port 3306 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)' \
	2>/dev/null &

tcpdump_pid="$!"
sleep $sleep_time
kill $tcpdump_pid

# set trap to be sure both remote files are removed
trap 'rm -f "${tmp_dir}/${model_work_file}" "${tmp_dir}/${result_file}" "${tmp_dir}/${lock_file}" "${tmp_dir}/${tcpdump_raw_file}"; exit' INT TERM EXIT

# digest the result, copy to localhost, then email it
tcpdump -nnq -tttt -r "${tmp_dir}/${tcpdump_raw_file}" 2>/dev/null > "${tmp_dir}/${model_work_file}"

# if the ASCII version of the tcpdump is empty, bail out
if [[ ! -s "${tmp_dir}/${model_work_file}" ]]
then
	cleanup_pt_tcp_collector
	exit 0
fi

pt-tcp-model "${tmp_dir}/${model_work_file}" | sort -n -k1,1 | pt-tcp-model --type=requests --run-time=10 > "${tmp_dir}/${result_file}"
data=($(sed -ne '2 p' "${tmp_dir}/${result_file}"))

let i=0
for metric in concurrency throughput arrivals completions busy_time weighted_time sum_time variance_mean quantile_time obs_time
do
	let i=i+1
	if [[ -z "${data[$i]}" ]]
	then
		data[$i]=0
	fi
	echo "db.tcpdump.${metric} ${current_time} ${data[$i]}"

done

if [[ -z "${data[2]}" || "${data[2]}" -eq 0 ]]
then
	avg_time=0
else
	avg_time="$( echo "${data[7]} ${data[2]}" | awk '{ print $1/$2 }' )"
fi
echo "db.tcpdump.avg_time ${current_time} ${avg_time}"

# clean up files
cleanup_pt_tcp_collector

trap - INT TERM EXIT
exit 0
