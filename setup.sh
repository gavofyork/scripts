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
echo $HOST > /etc/hostname
hostname $HOST
if [[ "$DOMAIN" != "" ]]; then
  domainname $DOMAIN
fi
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.old
sed '/^AcceptEnv LANG LC_/ s/./#&/' /etc/ssh/sshd_config.old | sed '/^PermitRootLogin without-password/ s/./#&/' >/etc/ssh/sshd_config
sudo chmod 644 /etc/ssh/sshd_config
service sshd restart

if [[ ~polkadot == '~polkadot' ]] ; then
  echo "Adding user `polkadot`..."
  useradd -s /bin/bash -m polkadot
  mkdir ~polkadot/.ssh
  mv ~/id_polkadot.pub ~polkadot/.ssh/authorized_keys
  echo >> ~polkadot/.ssh/authorized_keys
  cat ~/id_head.pub >> ~polkadot/.ssh/authorized_keys
  rm -f ~/id_head.pub
  chmod 700 ~polkadot/.ssh
  chmod 644 ~polkadot/.ssh/authorized_keys
  chown -R polkadot:polkadot ~polkadot
fi
if [[ ! -e /home/$USER ]] ; then
  echo "Adding sudo user `$USER`..."
  useradd -s /bin/bash -m $USER
  mkdir /home/$USER/.ssh
  mv ~/id_admin.pub /home/$USER/.ssh/authorized_keys
  chmod 700 /home/$USER/.ssh
  chmod 644 /home/$USER/.ssh/authorized_keys
  chown -R $USER:$USER /home/$USER
  echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER-user
fi

echo "Installing screen, wget, ufw, unattended-upgrades..."
apt-get update > /dev/null 2> /dev/null
apt-get install -y screen wget ufw unattended-upgrades > /dev/null 2> /dev/null

echo "Ensuring up to date..."
unattended-upgrade -v

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

echo "Installing script..."
chmod +x host-polkadot.sh
mv host-polkadot.sh /usr/bin/polkadot.sh
chown polkadot:polkadot /usr/bin/polkadot.sh
ln -s /usr/bin/polkadot.sh /usr/bin/polka

echo "Ensuring activation on startup..."
cat <<EOF > start-polkadot
#!/bin/bash
cd ~polkadot
su polkadot -c "polka start"
EOF
chmod +x start-polkadot
chown polkadot:polkadot start-polkadot
mv start-polkadot ~polkadot
cat <<EOF > /etc/systemd/system/polkadot.service
[Unit]
After=network.service

[Service]
ExecStart=/home/polkadot/start-polkadot

[Install]
WantedBy=default.target
EOF
sudo chmod 664 /etc/systemd/system/polkadot.service
systemctl daemon-reload
systemctl enable polkadot.service

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
su polkadot -c "polkadot.sh start"

echo "🎉 $INSTANCES node(s) deployed successfully!"
echo
echo "Addresses:"
su polkadot -c "polkadot.sh addresses"
echo "Keys:"
su polkadot -c "polkadot.sh keys"
