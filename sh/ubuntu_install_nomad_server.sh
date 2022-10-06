#!/bin/bash
REGION=
DC=
LOCAL_IP=$(hostname -I | awk '{print $1}')
IP_NODE1=
IP_NODE2=
IP_NODE3=
HOSTNAME=$(hostname)
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update && apt-get install nomad -y
useradd --no-create-home --shell /bin/false nomad
cat >/etc/systemd/system/nomad.service <<EOF
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Wants=network-online.target
After=network-online.target

# When using Nomad with Consul it is not necessary to start Consul first. These
# lines start Consul before Nomad as an optimization to avoid Nomad logging
# that Consul is unavailable at startup.
#Wants=consul.service
#After=consul.service

[Service]
User=nomad 
Group=nomad
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=65536
LimitNPROC=infinity
Restart=on-failure
RestartSec=2

# StartLimitBurst = 5

## StartLimitIntervalSec is used for systemd versions >= 230
# StartLimitIntervalSec = 10s

## StartLimitInterval is used for systemd versions < 230
# StartLimitInterval = 10s

TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF
mkdir --parents /etc/nomad.d
mkdir --parents /opt/nomad

cat >/etc/nomad.d/server.hcl <<EOF
bind_addr = "0.0.0.0"
log_level = "INFO"
data_dir  = "/opt/nomad"
name      = "${HOSTNAME}"
server {
    enabled          = true
    encrypt          = ""
    bootstrap_expect = 3
    server_join {
        retry_join     = [ "${IP_NODE1}", "${IP_NODE2}", "${IP_NODE3}" ]
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
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
acl {
  enabled = true
  token_ttl = "30s"
  policy_ttl = "60s"
}
EOF

cat >/etc/nomad.d/nomad.hcl <<EOF
region     = "${REGION}"
datacenter = "${DC}"
data_dir   = "/opt/nomad"
EOF
chown -R nomad:nomad /etc/nomad.d
chmod 700 /etc/nomad.d
chown -R nomad:nomad /opt/nomad
chmod 700 /opt/nomad
systemctl enable nomad
systemctl start nomad
systemctl restart nomad
exit 0
