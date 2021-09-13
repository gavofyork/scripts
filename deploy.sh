#!/bin/bash
#   Copyright 2019-2021 Gavin Wood
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

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
