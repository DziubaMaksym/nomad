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
job "alertmanager" {
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
    task "alertmanager" {
      driver = "docker"
      resources {
        cpu    = 500
        memory = 512
      }
      service {
        name      = "alertmanager"
        tags      = ["alertmanager", "${var.datacenters}"]
        on_update = "require_healthy"
        meta {
          version     = "${var.version}"
          datacenters = "${var.datacenters}"
        }
        check {
          address_mode = "driver"
          type         = "tcp"
          port         = "9093"
          interval     = "10s"
          timeout      = "2s"
        }
      }
      config {
        network_mode = "host"
        image        = "prom/alertmanager:${var.version}"
        mount {
          type     = "bind"
          target   = "/etc/alertmanager/alertmanager.yml"
          source   = "alloc/conf.d/alertmanager.yml"
          readonly = true
          bind_options {
            propagation = "rshared"
          }
        }
        mount {
          type     = "bind"
          target   = "/etc/alertmanager/template.tmpl"
          source   = "alloc/conf.d/template.tmpl"
          readonly = true
          bind_options {
            propagation = "rshared"
          }
        }
      }
      template {
        change_mode = "restart"
        perms       = "777"
        data        = "{{ key \"devops/infrastructure/prometheus/alertmanager.yml\" }}"
        destination = "alloc/conf.d/alertmanager.yml"
      }
      template {
        change_mode = "restart"
        perms       = "777"
        data        = "{{ key \"devops/infrastructure/prometheus/template\" }}"
        destination = "alloc/conf.d/template.tmpl"
      }
    }
    task "alertbot" {
      driver = "docker"
      resources {
        cpu    = 128
        memory = 128
      }
      service {
        name      = "alertbot"
        tags      = ["alertbot", "${var.datacenters}"]
        on_update = "require_healthy"
        meta {
          version     = "${var.version}"
          datacenters = "${var.datacenters}"
        }
        check {
          address_mode = "driver"
          type         = "tcp"
          port         = "9087"
          interval     = "10s"
          timeout      = "2s"
        }
      }
      config {
        network_mode = "host"
        image        = "sdgit.pinesoftware.com.cy:5050/devops/docker/container-images:alertbot"

        auth {
          username       = "gitlab+deploy-token-92"
          password       = "UaLWGiWQWdWEs3MELQ7W"
          server_address = "sdgit.pinesoftware.com.cy:5050"
        }
        command = "./prometheus_bot"
        args = [
          "-c",
          "/etc/telegrambot/config.yaml"
        ]
        mount {
          type     = "bind"
          target   = "/etc/telegrambot/config.yaml"
          source   = "alloc/conf.d/alertbot_config.yaml"
          readonly = true
          bind_options {
            propagation = "rshared"
          }
        }
        mount {
          type     = "bind"
          target   = "/etc/telegrambot/template.tmpl"
          source   = "alloc/conf.d/template.tmpl"
          readonly = true
          bind_options {
            propagation = "rshared"
          }
        }
      }
      template {
        change_mode = "restart"
        perms       = "777"
        data        = "{{ key \"devops/infrastructure/prometheus/alertbotconfig.yaml\" }}"
        destination = "alloc/conf.d/alertbot_config.yaml"
      }
      template {
        change_mode = "restart"
        perms       = "777"
        data        = "{{ key \"devops/infrastructure/prometheus/template.tmpl\" }}"
        destination = "alloc/conf.d/template.tmpl"
      }
    }
  }
}
