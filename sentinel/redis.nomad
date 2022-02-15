job "redis" {
  datacenters = [[ .datacenters | toJson ]]
  type        = "service"

  update {
    max_parallel = 1
    stagger      = "10s"
  }

  // add 0 to force convert int to int64, otherwise loop will error
  [[ range $id := loop ( add .redis.count 0 ) ]]
  group "redis-[[$id]]" {
    count = 1

    network {
      mode = "bridge"

      port "db" {
        static = 6379
      }
    }

    service {
      name = "redis"
      tags = ["[[$id]]"]

      port = "db"

      check {
        type     = "script"
        task     = "redis"
        name     = "Redis Leader or Follower Check"
        command  = "/bin/bash"
        args     = ["/local/redis-hc.sh"]
        interval = "5s"
        timeout  = "5s"
      }
    }

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }

    task "redis" {
      driver = "docker"

      template {
        data = <<EOH
[[ fileContents ( print "./scripts/redis-hc.sh" ) ]]
        EOH

        destination = "local/redis-hc.sh"
        change_mode = "noop"
      }

      config {
        image   = "redis:6.2"
        command = "bash"
        args = [
          "-c",
          <<EOH
[[ fileContents ( print "./scripts/redis.sh" ) ]]
EOH
        ]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
  [[- end ]]

  group "sentinel" {
    count = 3

    network {
      mode = "bridge"

      port "sentinel" {
        static = 26379
      }
    }

    service {
      name = "redis-sentinel"
      port = "sentinel"
    }

    ephemeral_disk {
      migrate = true
      size    = 500
      sticky  = true
    }

    task "sentinel" {
      driver = "docker"

      env {
        // n/2 + 1
        QUORUM = "[[ (add (divide  2 .sentienl.count) 1) ]]"
      }

      config {
        image = "redis:6.2"

        command = "bash"
        args = [
          "-c",
          <<EOH
[[ fileContents ( print "./scripts/sentinel.sh" ) ]]
EOH
        ]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}