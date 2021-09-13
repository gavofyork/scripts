# Some scripts which might be helpful

**DISCLAIMER:**

**PLEASE NOTE: THESE SCRIPTS ARE INCOMPLETE, NOT ESPECIALLY WELL TESTED, PROBABLY INSECURE AND ALMOST CERTAINLY AT LEAST A BIT BUGGY. I'M PUTTING THEM OUT HERE IN THE INTEREST OF SHARING WORK AND IDEAS, NOT FOR REAL-WORLD USAGE. IF YOU DO ANYTHING REMOTELY IMPORTANT WITH THEM THEN YOU'RE MAD. DON'T BLAME ME WHEN THEY GO WRONG OR DO SOMETHING YOU DON'T EXPECT.**

These scripts were created to help me deploy and maintain a bunch of validator nodes. They support:

- running multiple nodes on a single host;
- setting up validators or non-validating full-nodes;
- easy updating of the node software and scripts;
- easy determining of keys and addresses of each node;
- easy (re-)starting and stopping nodes;
- avoiding all but one manual chain synchronization;
- automatic interconnection of deployed nodes using a two-level star network and reserved peers, where the first node on each host connects to all nodes on the same host as well as all first nodes on all other hosts;
- optionally set up of each host with Grafana and Prometheus;
- configuration of a baseline firewall on each host;
- running all node instances in a `screen` session for easily seeing what is happening on each;
- updating all hosts at once with a single CLI command;
- auto-generating configurations for Polkadot PANIC;
- nodes running on the same host to be configured with arbitrary CLI options;
- setup of a non-sudo `polkadot` user on hosts which owns all node-related operations;
- setup of a sudo user on the hosts which can be used for any other maintenance tasks.

NOTE: These scripts only support Ubuntu 20.04 hosts and require a single DNS domain with `A` records for each host.

## Usage

1. Copy and edit your first host config file, which will become your head host:

```sh
$ cp node.config.example my-first-host.config
$ vim my-first-host.config
```

**NOTE THERE ARE REQUIREMENTS**:

All hosts in your network must share a DNS domain and have each have an `A` record with their host name.

2. Deploy to a new machine:

```sh
$ ./deploy.sh my-first-host.config `whoami`
```

**NOTE THERE ARE REQUIREMENTS**:

- Machine must be a fresh Ubuntu 20.04 host;
- the local running user must have password-less SSH root access to the machine (this may be rescinded after deployment if desired).

## Maintenance

### Adding more hosts/nodes

More nodes may be configured and deployed at any time following:

```sh
$ cp node.config.example my-second-host.config
$ vim my-second-host.config
$ ./deploy.sh my-second-host.config `whoami`
```

(There is no special process for decommissioning a host.)

### Network Maintenance

`update.sh` is a script which may be used to perform certain maintenance tasks:

- `./update.sh -h`: Get some help.
- `./update.sh binary`: Update Polkadot binary on all deployments.
- `./update.sh script`: Update host maintenance scripts on all deployments.
- `./update.sh panic`: Generate configuration files for Polkadot PANIC.
- `./update.sh api`: Generate configuration files for Polkadot API Server.

### Host/Node Maintenance

Each host may be SSHed into individually and controlled with the `polka` script. General help is available:

```sh
$ ssh polkadot@my-first-host.my-domain.com polka help
```

#### Examples:

Start all Polkadot nodes on `my-first-host`:
```sh
$ ssh polkadot@my-first-host.my-domain.com polka start
```

Stop all Polkadot nodes running on `my-first-host`:
```sh
$ ssh polkadot@my-first-host.my-domain.com polka stop
```

Stop, update Polkadot binary to latest release and restart all nodes on `my-first-host`:
```sh
$ ssh polkadot@my-first-host.my-domain.com polka update
```

List the network addresses for each node on `my-first-host`:
```sh
$ ssh polkadot@my-first-host.my-domain.com polka addresses
```

Rotate and dump the validator keys for each node on `my-first-host`:
```sh
$ ssh polkadot@my-first-host.my-domain.com polka keys
```

All nodes are running in a `screen` instance on the host. You can `ssh` in and use `screen -r` to list the screen sessions and attach to one. Use `Ctrl-A Ctrl-D` to exit the `screen` session without stopping/restarting the node.

## Future work

- Initialization of head host should wait for sync then packdb
- packdb should run nightly
- `polka screen <instance>` command
- Remove requirement for DNS names
- Singleton Prometheus/Grafana setup
- Scripted setup for panic and telemetry
- `polka <host> <command>` to run a `polka` command on a named host from the local machine