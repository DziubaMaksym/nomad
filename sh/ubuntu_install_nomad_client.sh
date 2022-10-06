#!/bin/bash
set -e
PURPLE='\033[0;35m'
NC='\033[0m'
read -r -p "Enter DC default is [KY1]:" DC
DC=${DC:-KY1}
echo -e "${PURPLE}${DC}${NC} will be used!"

read -r -p "Enter SERVICE default is [test]:" SERVICE
SERVICE=${SERVICE:-test}
echo -e "${PURPLE}${SERVICE}${NC} will be used!"

read -r -p "Enter CLASS default is [test]:" CLASS
CLASS=${CLASS:-test}
echo -e "${PURPLE}${CLASS}${NC} will be used!"

read -r -p "Enter VERSION default is [0.0.1]:" VERSION
VERSION=${VERSION:-0.0.1}
echo -e "${PURPLE}${VERSION}${NC} will be used!"

read -r -p "Enter OWNER default is [devops]:" OWNER
OWNER=${OWNER:-devops}
echo -e "${PURPLE}${OWNER}${NC} will be used!"

read -r -p "Enter CMD default is [0]:" CMD
CMD=${CMD:-0}
echo -e "${PURPLE}${CMD}${NC} will be used!"

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "${PURPLE}${LOCAL_IP}${NC} will be used!"

IP_NODE1=
IP_NODE2=
IP_NODE3=
HOSTNAME=$(hostname)
FORMAT=${crashformat:-crash.%e.%p.%c.%h.%t}
CRASHDIR=${DIR:-/opt/nomad/crash}
function setcrashdir() {
  echo "${CRASHDIR}"/"${FORMAT}" >/proc/sys/kernel/core_pattern
}
CLASS=prod
DATA_VOLUME=/opt/local/data
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update && apt-get install nomad -y
mkdir -p $DATA_VOLUME
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
User=root
Group=root
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
chmod 0700 /etc/nomad.d

cat >/etc/nomad.d/client.hcl <<EOF
bind_addr = "0.0.0.0"
log_level = "INFO"
data_dir  = "/opt/nomad"
name      = "${HOSTNAME}"
client {
    enabled                  = true
    node_class               = "prod"
    state_dir                = "/opt/nomad/client"
    gc_interval              = "1m"
    gc_disk_usage_threshold  = 80
    gc_inode_usage_threshold = 70
    gc_max_allocs            = 50
    gc_parallel_destroys     = 2
    server_join {
        retry_join     = [ "${IP_NODE1}", "${IP_NODE2}", "${IP_NODE3}" ]
        retry_max      = 3
        retry_interval = "15s"
  }
     meta {
        owner           = "${OWNER}"
        service         = "${SERVICE}"
        version         = "${VERSION}"
        cmd             = "${CMD}"
        class           = "${CLASS}"
  }
host_volume "crash" {
    path      = "/opt/nomad/crash"
    read_only = false
  }
host_volume "data" {
    path      = "${DATA_VOLUME}"
    read_only = false
  }
}
advertise {
    http = "${LOCAL_IP}"
    rpc  = "${LOCAL_IP}"
    serf = "${LOCAL_IP}"
}
plugin "raw_exec" {
  config {
    enabled = true
  }
}
telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
EOF

cat >/etc/nomad.d/nomad.hcl <<EOF
datacenter = "${DC}"
data_dir   = "/opt/nomad"
EOF
ufw allow in on eth0 proto tcp to any port 4646 comment \"nomad_http\"
ufw allow in on eth0 proto tcp to any port 4647 comment \"nomad_rpc\"
ufw allow in on eth0 proto tcp to any port 4648 comment \"nomad_server_wan_tcp\"
ufw allow in on eth0 proto udp to any port 4648 comment \"nomad_server_wan_udp\"
setcrashdir
systemctl enable nomad
systemctl start nomad
systemctl restart nomad
exit 0
