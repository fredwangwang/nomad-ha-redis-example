// almost same from https://github.com/seatgeek/resec 
job "redis" {
  datacenters = [[ .datacenters | toJson ]]
  type        = "service"

  update {
    max_parallel = 1
    stagger      = "10s"
  }

  group "redis" {
    count = [[ .redis.count ]]

    network {
      mode = "bridge"

      port "db" {
        static = 6379
      }
    }

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }

    task "redis" {
      driver = "docker"
      config {
        image   = "redis:6.2"
        command = "redis-server"
        args = [
          "/local/redis.conf"
        ]
      }

      // Let Redis know how much memory he can use not to be killed by OOM
      template {
        data        = <<EORC
loglevel verbose
maxmemory {{ env "NOMAD_MEMORY_LIMIT" | parseInt | subtract 16 }}mb

dir /alloc/data
EORC
        destination = "local/redis.conf"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }

    task "resec" {
      driver = "docker"
      config {
        image = "yotpo/resec"
      }

      env {
        CONSUL_HTTP_ADDR  = "http://${attr.unique.network.ip-address}:8500"
        CONSUL_HTTP_TOKEN = "[[ .consul_token ]]"
        REDIS_ADDR        = "localhost:6379"

        CONSUL_SERVICE_NAME = "redis"
        MASTER_TAGS         = "primary"
        SLAVE_TAGS          = "replica"
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}