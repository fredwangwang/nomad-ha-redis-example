#!/bin/bash

REDIS_CONFIG_PATH=/local/redis.conf

SENTINEL_URL=redis-sentinel.service.consul
SENTINEL_PORT=26379

INIT_MASTER=0.redis.service.consul

REDIS_CONFIG_TMPL='
loglevel verbose
dir /alloc/data

masterauth password
requirepass password
'

echo "$REDIS_CONFIG_TMPL" >$REDIS_CONFIG_PATH

echo "finding master..."
if [ "$(redis-cli -h $SENTINEL_URL -p $SENTINEL_PORT ping)" != "PONG" ]; then
    echo "sentinel not found, defaulting to redis-0"
    if [[ "$NOMAD_GROUP_NAME" == "redis-0" ]]; then
        echo "this is redis-0, not updating config..."
    else
        echo "updating redis.conf..."
        echo "slaveof $INIT_MASTER $NOMAD_PORT_db" >>$REDIS_CONFIG_PATH
    fi
else
    echo "sentinel found, finding master"
    MASTER="$(redis-cli --raw -h $SENTINEL_URL -p $SENTINEL_PORT sentinel get-master-addr-by-name mymaster | head -1 | tr -d '\n\r')"
    echo "master found: $MASTER"
    if [[ "$MASTER" == "$NOMAD_HOST_IP_db" ]]; then
        echo "master is self, not updating config..."
    else
        echo "updating redis.conf..."
        echo "slaveof $MASTER $NOMAD_PORT_db" >>$REDIS_CONFIG_PATH
    fi
fi

exec redis-server $REDIS_CONFIG_PATH
