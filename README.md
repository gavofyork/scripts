# Some scripts which might be helpful

**DISCLAIMER:**

**PLEASE NOTE: THESE SCRIPTS ARE INCOMPLETE, NOT ESPECIALLY WELL TESTED, PROBABLY INSECURE AND
ALMOST CERTAINLY AT LEAST A BIT BUGGY. I'M PUTTING THEM OUT HERE IN THE INTEREST OF SHARING WORK
AND IDEAS, NOT FOR REAL-WORLD USAGE. IF YOU DO ANYTHING REMOTELY IMPORTANT WITH THEM THEN YOU'RE
MAD. DON'T BLAME ME WHEN THEY GO WRONG OR DO SOMETHING YOU DON'T EXPECT.**

These scripts form some pretty opinionated Polkadot node deployment tooling. They support:

- running multiple nodes on a single host;
- setting up validators or non-validating full-nodes;
- easy updating of the node software and scripts;
- easy determining of keys and addresses of each node;
- easy (re-)starting and stopping nodes;
- avoiding all but one manual chain synchronization;
- automatic interconnection of deployed nodes using a two-level star network and reserved peers,
  where the first node on each host connects to all nodes on the same host as well as all first
  nodes on all other hosts;
- optional set up of each host with Grafana and Prometheus;
- configuration of a baseline firewall on each host;
- running all node instances in a `screen` session for easily seeing what is happening on each;
- updating all hosts at once with a single CLI command;
- auto-generating configurations for Polkadot PANIC;
- nodes running on the same host to be configured with arbitrary CLI options;
- setup of a non-sudo `polkadot` user on hosts which owns all node-related operations;
- setup of a sudo user on the hosts which can be used for any other maintenance tasks.

NOTE: These scripts only support Ubuntu 20.04 hosts and require a single DNS domain with `A`
records for each host.

## Usage

0. Link the `polkadot.sh` file as the `polka` binary:

```sh
sudo ln -s $PWD/polkadot.sh /usr/local/bin/polka
```

NOTE: You don't need to do this, but if you don't then you should replace any usages of `polka` here with `./polkadot.sh`.



1. Copy and edit your first host config file, which will become your head host:

```sh
$ cp node.config.example my-first-host.config
$ vim my-first-host.config
```

**NOTE THERE ARE REQUIREMENTS**:

All hosts in your network must share a DNS domain and have each have an `A` record with their host name.

2. Deploy to a new machine:

```sh
$ polka deploy my-first-host.config `whoami`
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
$ polka deploy my-second-host.config `whoami`
```

(There is no special process for decommissioning a host.)

### Network Maintenance

`polka` has a number of maintenance commands:

- `polka help`: Information about these commands.
- `polka update-binary`: Update Polkadot binary on all deployments.
- `polka update-script`: Update host maintenance scripts on all deployments.
- `polka panic-config`: Generate configuration files for Polkadot PANIC.
- `polka api-config`: Generate configuration files for Polkadot API Server.
- `polka host HOSTNAME COMMAND`: Run `polka` command on a deployed host.

### Host/Node Maintenance

Each host may be `ssh`ed into with the `polkadot` user and controlled individually with the
installed `polka` script. This script also has a `help` command. e.g.:

```sh
$ ssh polkadot@my-first-host.my-domain.com
% polka help
```

Unless you need to do substantial maintenance, then there is no great need to SSH in to the host,
rather it can also be done from the local machine with the local `polka` script, using the `host`
command. For example, the following is equivalent to the previous:

```sh
$ polka host my-first-host help
```

I'll use this form for the other examples, but you can also SSH in and use the same commands if
you wish. If you do that, then don't forget to drop the `host my-first-host` parameters.

#### Examples:

Start (or restart) all Polkadot nodes on `my-first-host`:
```sh
$ polka host my-first-host start
```

Stop all Polkadot nodes on `my-first-host`:
```sh
$ polka host my-first-host stop
```

Update Polkadot binary to latest release and restart all nodes on `my-first-host`:
```sh
$ polka host my-first-host update
```

List the network addresses for each node on `my-first-host`:
```sh
$ polka host my-first-host addresses
```

Rotate and dump the validator keys for each node on `my-first-host`:
```sh
$ polka host my-first-host keys
```

Open a login on the host with `ssh` under the `polkadot` user:
```sh
$ polka host my-first-host
```

All nodes are running in a `screen` instance on the host. You can use `polka screen` to
temporarily attach to this and view the node's logs in realtime. Use `Ctrl-A Ctrl-D` to exit the
`screen` session without stopping/restarting the node. If there is more than one instance running,
then you should suffix with the instance number (1, 2, 3 &c).

```sh
$ polka host my-first-host screen
```

The `host` part of the above commands is actually optional, so as long as your hosts are not
called something which is a valid first parameter the `polka` script, then you can skip it. For example, the follow is equivalent to the previous command:

```sh
$ polka my-first-host screen
```

## Future work

- Initialization of head host should wait for sync then packdb
- packdb should run nightly
- Remove requirement for DNS names
- Singleton Prometheus/Grafana setup
- Scripted setup for panic and telemetry
- Make `polka deploy host.domain.com --instances 4 --name Host` work