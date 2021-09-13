# Some scripts which might be helpful


**DISCLAIMER:**

**PLEASE NOTE: THESE SCRIPTS ARE PROBABLY INSECURE AND QUITE POSSIBLY BUGGY. I'M PUTTING THEM OUT HERE IN THE INTEREST OF SHARING WORK AND IDEAS, NOT FOR REAL-WORLD USAGE. IF YOU DO ANYTHING REMOTELY IMPORTANT WITH THEM THEN YOU'RE MAD. DON'T BLAME ME WHEN THEY GO WRONG OR DO SOMETHING YOU DON'T EXPECT.**

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

First wait until the node is synced; you can check by looking at the telemetry entrty for your node. Once synced run:

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

`update.sh` is a script which may be used to update all hosts, either their polkadot binaries `./update.sh binary` or their host maintenance scripts `./update.sh script`. It can also be used to auto-generates configuration files for PANIC `./update.sh panic` and polkadot-api `./update.sh api`.


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

### Adding more nodes

More nodes may be configured and deployed at any time following:

```
$ cp node.config.example my-second-host.config
$ vim my-second-host.config
$ ./deploy.sh my-second-host.config `whoami`
```

There is no special process for decommissioning a host.
