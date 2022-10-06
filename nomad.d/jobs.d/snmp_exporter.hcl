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
job "snmp_exporter" {
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
    task "snmp_exporter" {
      driver = "docker"
      resources {
        cpu    = 1000
        memory = 512
      }
      service {
        name      = "snmp-exporter"
        tags      = ["snmp-exporter", "${var.datacenters}"]
        on_update = "require_healthy"
        meta {
          version     = "${var.version}"
          datacenters = "${var.datacenters}"
        }
        check {
          address_mode = "driver"
          type         = "tcp"
          port         = "9116"
          interval     = "10s"
          timeout      = "2s"
        }
      }
      config {
        network_mode = "host"
        image        = "prom/snmp-exporter:${var.version}"
      }
    }
  }