bind_addr = "0.0.0.0"
log_level = "INFO"
data_dir  = "/opt/nomad"
name      = "${CLIENT_NAME}"
client {
  enabled                  = true
  node_class               = "prod"
  state_dir                = "/opt/nomad/client"
  gc_interval              = "1m"
  gc_disk_usage_threshold  = 80
  gc_inode_usage_threshold = 70
  gc_max_allocs            = 50
  gc_parallel_destroys     = 2
  host_volume "persistent_volume" {
    path      = "/opt/nomad/persistent_volume"
    read_only = false
  }
  server_join {
    retry_join     = ["${IP_NODE1}", "${IP_NODE2}", "${IP_NODE3}"]
    retry_max      = 3
    retry_interval = "15s"
  }
  meta {
    owner   = "${OWNER}"
    service = "${SERVICE}"
    version = "${VERSION}"
    cmd     = "${CMD_INSTALL}"
    class   = "${node.class}"

  }
  host_volume "data" {
    path      = "${DATA_VOLUME}"
    read_only = false
  }
  host_volume "crash" {
    path      = "/opt/nomad/crash"
    read_only = false
  }
  host_volume "docker-sock" {
    path      = "/var/run/docker.sock"
    read_only = true
  }
  host_volume "run" {
    path      = "/var/run/"
    read_only = true
  }
  host_volume "sys" {
    path      = "/sys"
    read_only = true
  }
}
advertise {
  http = "${IP_NODE}"
  rpc  = "${IP_NODE}"
  serf = "${IP_NODE}"
}
plugin "raw_exec" {
  config {
    enabled = true
  }
}
plugin "docker" {
  volumes {
    enabled      = true
    selinuxlabel = "z"
  }
}
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
acl {
  enabled    = true
  token_ttl  = "30s"
  policy_ttl = "60s"
}
vault {
  enabled = true
  address = ""
}