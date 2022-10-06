variable datacenters {
  type        = string
  default     = ""
  description = "in what datacenter deploy will go"
}
variable version {
  type        = string
  default     = "latest"
  description = "version of container image"
}
job "prometheus" {
  meta {
    run_uuid = "${uuidv4()}"
  }
  datacenters = ["${var.datacenters}"]
  type        = "service"
  update {
    max_parallel     = 1
    min_healthy_time = "1m"
    health_check     = "task_states"
    auto_revert      = true
  }
  group "monitoring" {
    restart {
      attempts = 2
      delay    = "15s"
      interval = "1m"
      mode     = "delay"
    }
    count = 1
    constraint {
      attribute = "${meta.service}"
      value     = "prometheus"
    }
    volume "data" {
      type      = "host"
      read_only = false
      source    = "data"
    }
    task "prometheus" {
      driver = "docker"
      user   = "root"
      volume_mount {
        volume      = "data"
        destination = "/var/lib/prometheus/"
        read_only   = false
      }
      resources {
        cpu    = 2000
        memory = 1024
      }
      service {
        name      = "prometheus"
        tags      = ["prometheus", "${var.datacenters}"]
        on_update = "require_healthy"
        meta {
          version     = "${var.version}"
          datacenters = "${var.datacenters}"
        }
        check {
          address_mode = "driver"
          type         = "tcp"
          port         = "9090"
          interval     = "10s"
          timeout      = "2s"
        }
      }
      config {
        network_mode = "host"
        image        = "prom/prometheus:${var.version}"
        args = [
          "--config.file=/etc/prometheus/prometheus.yml",
          "--storage.tsdb.path=/var/lib/prometheus",
          "--storage.tsdb.retention.time=90d",
          "--web.enable-lifecycle",
          "--web.listen-address=0.0.0.0:9090"
        ]
        mount {
          type     = "bind"
          target   = "/etc/prometheus/prometheus.yml"
          source   = "alloc/conf.d/prometheus.yml"
          readonly = false
          bind_options {
            propagation = "rshared"
          }
        }
        mount {
          type     = "bind"
          target   = "/etc/prometheus/rules/alert.rules.yml"
          source   = "alloc/conf.d/alert.rules.yml"
          readonly = false
          bind_options {
            propagation = "rshared"
          }
        }
      }
      template {
        change_mode = "restart"
        perms       = "600"
        data        = "{{ key \"devops/infrastructure/prometheus/config\" }}"
        destination = "alloc/conf.d/prometheus.yml"
      }
      template {
        change_mode = "restart"
        perms       = "600"
        data        = "{{ key \"devops/infrastructure/prometheus/alert-rules\" }}"
        destination = "alloc/conf.d/alert.rules.yml"
      }
    }
  }
}