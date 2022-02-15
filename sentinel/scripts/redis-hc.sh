#!/bin/bash

REDIS_PASSWORD=password

# check if is master or replica of a master

export REDISCLI_AUTH="$REDIS_PASSWORD"

replication_output="$(redis-cli --raw -h localhost -p 6379 info replication)"
echo "$replication_output" | grep "role:master" >/dev/null
is_master=$?

if [[ $is_master -eq 0 ]]; then
    echo "current node is master"
    exit 0
fi

echo "current node is replica"
master_host="$(echo "$replication_output" | grep "master_host:" | cut -d: -f2 | tr -d '\n\r')"
echo "ping to server @ $master_host"
timeout 1 redis-cli -h $master_host --raw ping
conn_success=$?

if [[ $conn_success -eq 0 ]]; then
    echo "master @ $master_host reachable"
    exit 0
else
    echo "connection to master @ $master_host failed"
    exit 1
fi
