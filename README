# Simple deployment and maintenance scripts for running Polkadot nodes.

Scripts assume a fresh Ubuntu 20.04 host with local account having root access.

## Usage

1. Copy and edit the config:

```
$ cp config.example config
$ vim config
```

2. Copy and edit the node config file then deploy to a fresh Ubuntu host with root access:

```
$ cp node.config.example my-first-node.config
$ vim my-first-node.config
$ ./deploy.sh my-first-node.config gav
```

Maintenance scripts:
- `./update.sh`: Updates all hosts and auto-generates config files.
- (On each host) `polka`: Manages the nodes.

