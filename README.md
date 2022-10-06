# Nomad
[License](https://github.com/hashicorp/nomad/blob/main/LICENSE)
## Nomad install server
### Resources (RAM, CPU, etc.)
Nomad servers may need to be run on large machine instances. We suggest having between **4-8+** cores, **16-32 GB+** of memory, **40-80 GB+** of **fast disk** and significant network bandwidth.  
The core count and network recommendations are to ensure high throughput as Nomad heavily relies on network communication and as the Servers are managing all the nodes in the region and performing scheduling. The memory and disk requirements are due to the fact that Nomad stores all state in memory and will store two snapshots of this data onto disk, which causes high IO in busy clusters with lots of writes.  
Thus disk should be at least 2 times the memory available to the server when deploying a high load cluster. When running on AWS prefer NVME or Provisioned IOPS SSD storage for data dir.

### Ports Used
Nomad requires 3 different ports to work properly on servers and 2 on clients, some on TCP, UDP, or both protocols. Below we document the requirements for each port.

`HTTP API (Default 4646)` - This is used by clients and servers to serve the HTTP API. TCP only.

`RPC (Default 4647)` - This is used for internal RPC communication between client agents and servers, and for inter-server traffic. TCP only.

`Serf WAN (Default 4648)` - This is used by servers to gossip both over the LAN and WAN to other servers. It isn't required that Nomad clients can reach this address. TCP and UDP.

When tasks ask for dynamic ports, they are allocated out of the port range between 20,000 and 32,000. This is well under the ephemeral port range suggested by the IANA. If your operating system's default ephemeral port range overlaps with Nomad's dynamic port range, you should tune the OS to avoid this overlap.

### Bridge Networking and iptables
Nomad's task group networks and Consul Connect integration use bridge networking and iptables to send traffic between containers. The Linux kernel bridge module has three "tunables" that control whether traffic crossing the bridge are processed by iptables. Some operating systems (RedHat, CentOS, and Fedora in particular) configure these tunables to optimize for VM workloads where iptables rules might not be correctly configured for guest traffic.

These tunables can be set to allow iptables processing for the bridge network as follows:
```sh
$ echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
$ echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
$ echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
```
To preserve these settings on startup of a client node, add a file including the following to /etc/sysctl.d/ or remove the file your Linux distribution puts in that directory.
```sh
net.bridge.bridge-nf-call-arptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
```

### User Permissions
Nomad servers and Nomad clients have different requirements for permissions.

Nomad servers should be run with the **lowest possible permissions**. They need access to their own data directory and the ability to bind to their ports. You should create a nomad user with the minimal set of required privileges.

Nomad clients must be run as **root** due to the OS isolation mechanisms that require root privileges (see also Linux Capabilities below). The Nomad client's data directory should be owned by root with filesystem permissions set to 0700.

---
## Nomad Vocabulary
### Nomad cluster
 - `agent` - A Nomad agent is a Nomad process running in server or client mode. Agents are the basic building block of a Nomad cluster.  
 - `dev agent` - A Nomad development agent is a special configuration that provides useful defaults for running experiments with Nomad. It runs in server and client mode and does not persist its cluster state to disk, which allows your agent to start from a repeatable clean state without having to remove disk based state between runs. **Nomad dev agents are for development and experimental use only.**   
 - `server` - A Nomad agent running in server mode. Nomad servers are the brains of the cluster. There is a cluster of servers per region and they manage all jobs and clients, run evaluations, and create task allocations. The servers replicate data between each other and perform leader election to ensure high availability. Servers federate across regions to make Nomad globally aware. All servers in a region are members of the same gossip domain and consensus group.
 - `leader` - The leader is a Nomad server that performs the bulk of the cluster management. It is in charge of applying plans, deriving Vault tokens for the workloads, and maintaining the cluster state.
 - `follower` - Non-leader Nomad servers. Followers create scheduling plans and submit them to the leader to provide more scheduling capacity to the cluster.
 - `client` - A Nomad agent running in client mode. Client agents are responsible for registering themselves with the servers, watching for any work to be assigned, and executing tasks. Clients create a multiplexed connection to the servers. This enables topologies that require NAT punch-through. Once connected, the servers use this connection to forward RPC calls to the clients as necessary.

### Nomad objects
 - `job` - A job defines one or more task groups which contain one or more tasks.

 - `job specification` - The Nomad job specification (or "jobspec" for short) defines the schema for Nomad jobs. This describes the type of the job, the tasks and resources necessary for the job to run, and also includes additional job information (like constraints, spread, autoscaler policies, Consul service information, and more)

 - `task group` - A task group is a set of tasks that must be run together. For example, a web server may require that a log shipping co-process is always running as well. A task group is the unit of scheduling, meaning the entire group must run on the same client node and cannot be split. A running instance of a task group is an allocation.

 - `task driver` - A task driver represents the basic means of executing your tasks. Nomad provides several built-in task drivers: Docker, QEMU, Java, and static binaries. Nomad also allows for third-party task drivers through its pluggable architecture.

 - `task` - A task is the smallest unit of work in Nomad. Tasks are executed by task drivers, which allow Nomad to be flexible in the types of tasks it supports. Tasks specify their required task driver, configuration for the driver, constraints, and resources required.

 - `allocation` - An allocation is a mapping between a task group in a job and a client node. A single job may have hundreds or thousands of task groups, meaning an equivalent number of allocations must exist to map the work to client machines. Allocations are created by the Nomad servers as part of scheduling decisions made during an evaluation.

 - `evaluation` - Evaluations are the mechanism by which Nomad makes scheduling decisions. When either the desired state (jobs) or actual state (clients) changes, Nomad creates a new evaluation to determine if any actions must be taken. An evaluation may result in changes to allocations if necessary.

### Scheduling
 - `bin packing` - Bin packing is an algorithm that gets its name from the real world exercise of arranging irregularly sized objects into boxes or bins. The bin packing algorithm attempts to create the most-dense arrangement of objects thereby using the fewest boxes. In Nomad's case, these objects are deployed allocations. Bin packing benefits people who are using metered-billing platforms by consolidating the utilization and highlighting over-provisioning which could then be reduced.

 - `spread scheduling` - Spread scheduling is the opposite of bin packing. The goal of spread scheduling is to distribute as level a load as possible across a fleet of machines. This scheduling algorithm is best for people who have on-premises datacenters or committed nodes that they are already invested in.

## SystemD service

The following parameters are set for the [Unit] stanza:

`Description` - Free-form string describing the Nomad service

`Documentation` - Link to the Nomad documentation

`Wants` - Configure a dependency on the network service

`After` - Configure an ordering dependency on the network service being started before the Nomad service

The following parameters are set for the [Service] stanza:

`ExecReload` - Send Nomad a SIGHUP signal to trigger a configuration reload

`ExecStart` - Start Nomad with the agent argument and path to a directory of configuration files

`KillMode` - Treat Nomad as a single process

`LimitNOFILE`, `LimitNPROC` - Disable limits for file descriptors and processes

`RestartSec` - Restart Nomad after 2 seconds of it being considered 'failed'

`Restart` - Restart Nomad unless it returned a clean exit code

`StartLimitBurst`, `StartLimitIntervalSec` - Configure unit start rate limiting

`TasksMax` - Disable task limits (only available in systemd >= 226)

The following parameters are set for the [Install] stanza:

`WantedBy` - Creates a weak dependency on Nomad being started by the multi-user run level
