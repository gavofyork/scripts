#!/usr/bin/env bash
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

declare -A STASH
HOST_CACHE_FILE=.hosts.cache
source ./config
HEAD_HOSTNAME=${HEAD_HOST/.*/}
DOMAIN=${HEAD_HOST/$HEAD_HOSTNAME./}

declare -A HOST_CACHE
[[ -e $HOST_CACHE_FILE ]] && source $HOST_CACHE_FILE

function hostname {
	local IP=$1
	if [[ "${HOST_CACHE[$IP]}" == "" ]]; then
		HOSTNAME=$(ssh $IP hostname)
		HOST_CACHE[$IP]=$HOSTNAME
		echo "HOST_CACHE["$IP"]=$HOSTNAME" >> $HOST_CACHE_FILE
	fi
	echo ${HOST_CACHE[$IP]}
}
function node_ips {
	local HEAD_NODES=$(ssh polkadot@$HEAD_HOST cat headnodes)
	for NODE in $HEAD_NODES; do
		X=${NODE/\/ip4\//}
		IP=${X/\/*/}
		echo -n "$IP "
	done
}

case "$1" in
	script)
		VERSION=$(grep VERSION= polkadot.sh)
		echo Updating polkadot.sh to version ${VERSION/VERSION=/}...
		for IP in $(node_ips); do
			HOSTNAME="$(hostname $IP)"
			echo "Installing on $HOSTNAME..."
			ssh $IP "cat > /tmp/polkadot.sh && chmod +x /tmp/polkadot.sh && sudo chown polkadot /tmp/polkadot.sh && sudo mv /tmp/polkadot.sh /usr/bin" < ./polkadot.sh
		done
		;;
	binary)
		for IP in $(node_ips); do
			HOSTNAME="$(hostname $IP)"
			echo "Updating $HOSTNAME..."
			ssh $IP "/usr/bin/polkadot.sh update > /dev/null" < ./polkadot.sh
		done
		;;
	api)
		I=1
		for IP in $(node_ips); do
			J=1
			HOSTNAME="$(hostname $IP)"
			NODES=$(ssh polkadot@$IP /usr/bin/polkadot.sh address)
			for NODE in $NODES; do
				X=${N/\/ip4\//}
				IP=${X/\/*/}
				echo "[node_$I]"
				echo "node_name=${HOSTNAME}_$J"
				echo "ws_url=ws://$HOSTNAME.$DOMAIN:$((9943+J))"
				I=$((I + 1))
				J=$((J + 1))
			done
		done
		;;
	panic)
		I=1
		for IP in $(node_ips); do
			J=1
			HOSTNAME="$(hostname $IP)"
			NODES=$(ssh polkadot@$IP /usr/bin/polkadot.sh address)
			for NODE in $NODES; do
				X=${N/\/ip4\//}
				IP=${X/\/*/}
				echo "[node_$I]"
				echo "node_name=${HOSTNAME}_$J"
				echo "chain_name=Polkadot"
				echo "node_ws_url=ws://$HOSTNAME.$DOMAIN:$((9943+J))"
				echo "node_is_validator=true"
				echo "is_archive_node=false"
				echo "monitor_node=true"
				echo "use_as_data_source=true"
				echo "stash_account_address=${STASH[${HOSTNAME}_$J]}"
				I=$((I + 1))
				J=$((J + 1))
			done
		done
		;;
	*)
		echo "Usage:"
		echo "  $0 script   Update the polkadot.sh script on all nodes."
		echo "  $0 binary   Update the polkadot binary on all nodes."
		echo "  $0 api      Auto-generate a polkadot_api_server 'user_config_nodes.ini' file."
		echo "  $0 panic    Auto-generate a panic_polkadot 'user_config_nodes.ini' file."
	;;
esac

