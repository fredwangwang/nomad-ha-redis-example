#!/bin/bash

SENTINEL_CONFIG_PATH=/local/sentinel.conf

REDIS_PASSWORD=password

# TODO: wait for discovery of redis first in consul dns sd.

FORCE_INIT=false
RETRY_WAIT=5

export REDISCLI_AUTH="$REDIS_PASSWORD"

# https://download.redis.io/redis-stable/sentinel.conf
function init_config {
    SENTINEL_CONFIG="
dir /alloc/data

sentinel resolve-hostnames yes

sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
sentinel auth-pass mymaster $REDIS_PASSWORD
"

    echo "$SENTINEL_CONFIG" >$SENTINEL_CONFIG_PATH
}

# in case the underlying host for this job changes,
# the existing configuration would contain wrong announce ip that still pointing to the old node
# always fixup the announce ip by updating it to the current
function patch_announce_ip {
    echo "updating announce ip to $NOMAD_HOST_IP_sentinel"
    # 1a --> append 1st line, prepend
    sed -i.bk '/^sentinel announce-ip/d' $SENTINEL_CONFIG_PATH
    sed -i.bk "1asentinel announce-ip $NOMAD_HOST_IP_sentinel" $SENTINEL_CONFIG_PATH
}


discover_count=0
function patch_master_replica {
    for node in $${REDIS_NODES//,/ }; do
        echo "finding master at $node"
        MASTER="$(redis-cli --raw -h $node info replication | grep master_host: | cut -d: -f2 | tr -d '\n\r')"
        if [[ "$MASTER" == "" ]]; then
            echo "no master found"
        else
            echo "** found $MASTER **"
            break
        fi
    done

    if [[ "$MASTER" == "" ]]; then
        discover_count=$(( discover_count + 1))
        echo "discovered $discover_count time"
        if [[ $discover_count -ge 5 ]]; then
            echo "too many discover failures, crash"
            exit 1
        fi
        echo "no master found from any redis instance, wait $RETRY_WAIT s before retry"
        sleep $RETRY_WAIT
        patch_master_replica
    fi

    sed -i.bk '/^sentinel monitor mymaster/d' $SENTINEL_CONFIG_PATH
    sed -i.bk '/^sentinel known-replica mymaster/d' $SENTINEL_CONFIG_PATH
    sed -i.bk "1asentinel monitor mymaster $MASTER 6379 $QUORUM" $SENTINEL_CONFIG_PATH
}

if [[ -f $SENTINEL_CONFIG_PATH ]] && [[ $FORCE_INIT != 'true' ]]; then
    echo "found existing config, skip init config"
else
    init_config
fi

patch_announce_ip
patch_master_replica

exec redis-sentinel $SENTINEL_CONFIG_PATH
