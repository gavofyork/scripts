# Some scripts which might be helpful

**DISCLAIMER:**

**PLEASE NOTE: THESE SCRIPTS ARE INCOMPLETE, NOT ESPECIALLY WELL TESTED, PROBABLY INSECURE AND ALMOST CERTAINLY AT LEAST A BIT BUGGY. I'M PUTTING THEM OUT HERE IN THE INTEREST OF SHARING WORK AND IDEAS, NOT FOR REAL-WORLD USAGE. IF YOU DO ANYTHING REMOTELY IMPORTANT WITH THEM THEN YOU'RE MAD. DON'T BLAME ME WHEN THEY GO WRONG OR DO SOMETHING YOU DON'T EXPECT.**

These scripts were created to help me deploy and maintain a bunch of validator nodes. They support running multiple nodes on a single host. Nodes may be validators or non-validating full nodes. Scripts allow easy updating of the node software, determining keys and addresses of each node, starting and stopping them and avoiding all but one manual synchronization. Nodes are automatically interconnected using a two-level star network, where the first node on each host connects to all nodes on the same host as well as all first nodes on all other hosts. It sets up each host with Grafana, Prometheus and a firewall, as well as running all node instances in a `screen` session for easily seeing what is happening on each. It allows all nodes to have their software updated at once with a single CLI command and provides auto-generated configurations for Polkadot PANIC. It allows nodes running on the same host to be configured with arbitrary CLI options. It only supports Ubuntu 20.04 hosts and requires a single DNS domain with `A` records for each host.

## Usage

1. Copy and edit the network config:

```
$ cp config.example config
$ vim config
```

2. Copy and edit your first node config file:

```
$ cp node.config.example my-first-host.config
$ vim my-first-host.config
```

**NOTE**: All hosts in your network should share a DNS domain and have each have an `A` record with their host name;

3. Deploy to a fresh Ubuntu host with root access:

**NOTE**: Scripts assume:

- a fresh Ubuntu 20.04 host;
- the local running user must have password-less SSH root access (though only for this step);

```
$ ./deploy.sh my-first-host.config `whoami`
```

4. Create a packed DB dump:

Once the first host has been synced, you probably want to create a packed database dump, so that you won't need to manually sync any other hosts you deploy.

First wait until the node is synced; you can check by looking at the telemetry entry for your node. Once synced run:

```
$ ssh polkadot@my-first-host.my-domain.com polka packdb
```

You'll also need to make the first node the Head Node: do this by generating an SSH key and dumping it:

```
$ ssh polkadot@my-first-host.my-domain.com ssh-keygen && cat ~/.ssh/*.pub
```

And then altering your network config in order to reference `my-first-node.my-domain.com` and that SSH key.

## Maintenance

### Network Maintenance

`update.sh` is a script which may be used to update all hosts, either their Polkadot binaries `./update.sh binary` or their host maintenance scripts `./update.sh script`. It can also be used to auto-generates configuration files for Polkadot PANIC `./update.sh panic` and Polkadot API Server `./update.sh api`.


### Host/Node Maintenance

Each host may be SSHed into individually and controlled with the `polka` script. General help is available:

```
$ ssh polkadot@my-first-host.my-domain.com polka help
```

#### Examples:

Start all polkadot nodes on `my-first-host`:
```
$ ssh polkadot@my-first-host.my-domain.com polka start   
```

Stop all polkadot nodes running on `my-first-host`:
```
$ ssh polkadot@my-first-host.my-domain.com polka stop    
```

Stop, update polkadot binary to latest release and restart all nodes on `my-first-host`:
```
$ ssh polkadot@my-first-host.my-domain.com polka update  
```

List the network addresses for each node on `my-first-host`:
```
$ ssh polkadot@my-first-host.my-domain.com polka addresses
```

Rotate and dump the validator keys for each node on `my-first-host`:
```
$ ssh polkadot@my-first-host.my-domain.com polka keys
```

All nodes are running in a `screen` instance on the host. You can `ssh` in and use `screen -r` to list the screen sessions and attache to one. Use `Ctrl-A Ctrl-D` to exit the `screen` session without stopping/restarting the node.

### Adding more hosts/nodes

More nodes may be configured and deployed at any time following:

```
$ cp node.config.example my-second-host.config
$ vim my-second-host.config
$ ./deploy.sh my-second-host.config `whoami`
```

There is no special process for decommissioning a host.

## Future work

- Better initialization story and support for first node
- `polka screen <instance>` command
- Remove requirement for DNS
