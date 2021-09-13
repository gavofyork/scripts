#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <config-file> <user>"
    exit
fi

source config
source $1

echo "Copying database..."
ssh -o StrictHostKeyChecking=no root@$HOST.$DOMAIN "echo $HEAD_HOST_PUBKEY >> .ssh/authorized_keys" > /dev/null 2> /dev/null
ssh polkadot@$HEAD_HOST scp -o StrictHostKeyChecking=no /home/polkadot/nodes/db.tgz /home/polkadot/net.config root@$HOST.$DOMAIN: > /dev/null 2> /dev/null

echo "Copying setup script and config..."
scp setup.sh root@$HOST.$DOMAIN:
ssh root@$HOST.$DOMAIN chmod +x setup.sh
scp $1 root@$HOST.$DOMAIN:polkadot.config

echo "Setting up..."
ssh root@$HOST.$DOMAIN "./setup.sh polkadot.config $2" > tee /tmp/output

echo "Adding new head-node..."
HEAD_NODE="$(ssh polkadot@$HOST.$DOMAIN /usr/bin/polkadot.sh address 1)"
ssh polkadot@$HEAD_HOST /usr/bin/polkadot.sh add-head-node $HEAD_NODE
