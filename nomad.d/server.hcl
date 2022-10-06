bind_addr = "0.0.0.0"
log_level = "INFO"
data_dir  = "/opt/nomad"
name      = "${HOSTNAME}"
server {
  enabled          = true
  encrypt          = "${ENCRYPT_KEY}"
  bootstrap_expect = 3
  server_join {
    retry_join     = ["${IP_NODE1}", "${IP_NODE2}", "${IP_NODE3}"]
    retry_max      = 3
    retry_interval = "15s"
  }
}
advertise {
  http = "${LOCAL_IP}"
  rpc  = "${LOCAL_IP}"
  serf = "${LOCAL_IP}"
}
autopilot {
  cleanup_dead_servers      = true
  last_contact_threshold    = "200ms"
  max_trailing_logs         = 250
  server_stabilization_time = "10s"
  enable_redundancy_zones   = false
  disable_upgrade_migration = false
  enable_custom_upgrades    = false
}
telemetry {
  collection_interval        = "1s"
  disable_hostname           = true
  prometheus_metrics         = true
  publish_allocation_metrics = true
  publish_node_metrics       = true
}
vault {
  enabled          = true
  address          = ""
  token            = ""
  create_from_role = "nomad-server-policy"
}