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

if [ ! -e "$1" ]; then
    echo "Config file `$1` doesn't exist"
    exit
fi

CONFIG=$1
USER=$2
source "$CONFIG"

echo "Setting up host..."
hostname $HOST
if [[ "$DOMAIN" != "" ]]; then
  domainname $DOMAIN
fi

if [[ ~polkadot == '~polkadot' ]] ; then
  echo "Adding users..."
  useradd -s /bin/bash -m polkadot
  cp -r ~/.ssh ~polkadot
  chown -R polkadot ~polkadot
  useradd -s /bin/bash -m $USER
  cp -r ~/.ssh /home/$USER
  chown -R $USER /home/$USER
  echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER-user
fi

echo "Installing screen, wget, ufw..."
apt-get update > /dev/null 2> /dev/null
apt-get install -y screen wget ufw > /dev/null 2> /dev/null

echo "Setting up firewall..."
ufw allow 22/tcp # SSH incoming
for (( i = 0; i < $INSTANCES; i += 1 )); do
  ufw allow $((30333 + i))/tcp  # polkadot NET incoming
  if [[ "$PANIC_HOST" != "" ]]; then
    ufw allow from $PANIC_HOST to any port $((9944 + i))  # polkadot RPC incoming from panic
  fi
done
ufw --force enable

if [[ "$USE_PROMETHEUS" != "" ]] ; then
  echo "Installing Prometheus..."
  apt-get install -y gpg-agent apt-transport-https software-properties-common prometheus > /dev/null 2> /dev/null
  cat >> /etc/prometheus/prometheus.yml << EOL
  - job_name: polkadot
    scrape_interval: 1s
    static_configs:
    - targets: ['127.0.0.1:9615']
EOL
  service prometheus restart

  if [[ "$USE_GRAFANA" != "" ]] ; then
    echo "Installing Grafana..."
    wget -q -O - https://packages.grafana.com/gpg.key | apt-key add - > /dev/null 2> /dev/null
    add-apt-repository "deb https://packages.grafana.com/oss/deb stable main" > /dev/null
    apt-get install -y grafana > /dev/null 2> /dev/null
    service grafana-server restart
  fi
fi

echo "Fetching and installing script..."
wget -q https://raw.githubusercontent.com/gavofyork/scripts/master/polkadot.sh
chmod +x polkadot.sh
mv polkadot.sh /usr/bin
ln -s /usr/bin/polkadot.sh /usr/bin/polka

if [[ ! -e nodes ]]; then mkdir nodes; fi
if [[ -e db.tgz ]]; then
    echo "Unpacking database..."
    mv db.tgz nodes
    cd nodes
    tar xzf db.tgz
    for (( i = 1; i < $INSTANCES; i += 1 )); do
        echo "Cloning database $((i)) of $((INSTANCES - 1))..."
        cp -r instance-1 instance-$((i + 1))
    done
    cd ..
    mv nodes ~polkadot
else 
    echo "No database found; will sync from scratch :-("
fi

echo "Initialising node(s)..."
cp -f "$CONFIG" ~polkadot/polkadot.config
chown -R polkadot ~polkadot
cd ~polkadot

echo "Starting node(s)..."
su polkadot -c "polkadot.sh"

echo "NODE DEPLOYED"
su polkadot -c "polkadot.sh address"
