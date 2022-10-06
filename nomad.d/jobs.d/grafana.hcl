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
job "grafana" {
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
    network {
      port "grafana_port" {
        static = 3000
      }
    }
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
    task "grafana" {
      driver = "docker"
      user   = "root"
      env {
        GF_SECURITY_ADMIN_USER     = ""
        GF_SECURITY_ADMIN_PASSWORD = ""
      }
      volume_mount {
        volume      = "data"
        destination = "/var/lib/grafana"
        read_only   = false
      }
      resources {
        cpu    = 500
        memory = 512
      }
      service {
        name      = "grafana"
        tags      = ["grafana", "${var.datacenters}"]
        on_update = "require_healthy"
        port      = "grafana_port"
        meta {
          version     = "${var.version}"
          datacenters = "${var.datacenters}"
        }
        check {
          address_mode = "driver"
          type         = "tcp"
          port         = "3000"
          interval     = "10s"
          timeout      = "2s"
        }
      }
      config {
        network_mode = "host"
        image        = "grafana/grafana:${var.version}"
      }
    }
  }
}