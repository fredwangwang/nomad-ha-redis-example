# nomad-ha-redis-example
example to deploy HA redis on nomad.

## what

It contains two different replication monitoring systems, [resec](https://github.com/YotpoLtd/resec) and [sentinel](https://redis.io/topics/sentinel)

Example to show how to deploy these systems (either resec or sentinel) with nomad.

## how

the setup uses [levant](https://github.com/hashicorp/levant/releases/tag/v0.3.0) for variable rendering, and optionally deploying.

1. cd resec **or** cd sentinel
2. fill in redis.yml
3. NOMAD_TOKEN=... levant deploy -address=$NOMAD_ADDRESS -var-file redis.yml redis.nomad

## notice

the example uses [ephemeral disk](https://www.nomadproject.io/docs/job-specification/ephemeral_disk), which provides _best effort_ persistence.
It might be ok for some use cases, but for absolute data persistence, use host volumes or CSI. ref: https://learn.hashicorp.com/tutorials/nomad/stateful-workloads
