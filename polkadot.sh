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
if [[ -e config ]]; then
	source ./config
	if [[ "$HEAD_HOST" == "" || "$HEAD_HOST_PUBKEY" == "" ]]; then
		echo "Network config (`config`) file must contain `HEAD_HOST` and `HEAD_HOST_PUBKEY` definitions"
		exit 1
	fi
	HEAD_HOSTNAME=${HEAD_HOST/.*/}
	DOMAIN=${HEAD_HOST/$HEAD_HOSTNAME./}
	HAVE_NETWORK_CONFIG=1
fi

declare -A HOST_CACHE
[[ -e $HOST_CACHE_FILE ]] && source $HOST_CACHE_FILE

function hostname {
	local IP=$1
	if [[ "${HOST_CACHE[$IP]}" == "" ]]; then
		HOSTNAME=$(ssh -o StrictHostKeyChecking=no polkadot@$IP hostname)
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
	update-script)
		VERSION=$(grep VERSION= host-polkadot.sh)
		echo Updating polkadot.sh to version ${VERSION/VERSION=/}...
		OUTPUT=`mktemp /tmp/polkadot.output-XXXXXXXX`
		HOSTNAMES=""
		for IP in $(node_ips); do
			HOSTNAME="$(hostname $IP)"
			HOSTNAMES="$HOSTNAMES $HOSTNAME"
			echo "Installing on $HOSTNAME..."
			ssh polkadot@$HOSTNAME.$DOMAIN "cat > /usr/bin/polkadot.sh" < ./host-polkadot.sh > $OUTPUT.$HOSTNAME &
		done
		wait
		for HOSTNAME in $HOSTNAMES; do
			if [[ `cat $OUTPUT.$HOSTNAME | wc -l` -gt 0 ]]; then
				echo
				echo "$HOSTNAME:"
				cat $OUTPUT.$HOSTNAME
			fi
		done
		;;
	update-binary)
		HOSTNAMES=""
		for IP in $(node_ips); do
			HOSTNAME="$(hostname $IP)"
			HOSTNAMES="$HOSTNAMES $HOSTNAME"
			echo "Updating $HOSTNAME..."
			ssh polkadot@$HOSTNAME.$DOMAIN "/usr/bin/polkadot.sh update" > /tmp/$HOSTNAME.output &
		done
		wait
		for HOSTNAME in $HOSTNAMES; do
			if [ `grep "No new release" /tmp/$HOSTNAME.output | wc -l` -eq 1 ]; then
				echo "$HOSTNAME: Up-to-date"
			else
				echo "$HOSTNAME: Upgraded"
			fi
		done
		;;
	list-nodes)
		for IP in $(node_ips); do
			HOSTNAME="$(hostname $IP)"
			echo "$HOSTNAME: $IP"
		done
		;;
	update-security)
		VERSION=$(grep VERSION= host-polkadot.sh)
		echo Ensuring OS is secure...
		CMD="sudo unattended-upgrade -v; \
		if [[ -e /var/run/reboot-required ]] ; then \
			echo Rebooting... ; \
			cd ~polkadot ; \
			sudo su polkadot -c 'polka stop-all' ; \
			sudo reboot ; \
		fi"
		HOSTNAMES=""
		if [ $# -ge 2 ]; then
			for HOSTNAME in "${@:2}"; do
				echo "Securing $HOSTNAME..."
				ssh $HOSTNAME.$DOMAIN "$CMD" > /tmp/$HOSTNAME.output 2> /dev/null &
				HOSTNAMES="$HOSTNAMES $HOSTNAME"
			done
		else
			for IP in $(node_ips); do
				HOSTNAME="$(hostname $IP)"
				echo "Securing $HOSTNAME..."
				ssh $HOSTNAME.$DOMAIN "$CMD" > /tmp/$HOSTNAME.output 2> /dev/null &
				HOSTNAMES="$HOSTNAMES $HOSTNAME"
			done
		fi
		wait
		for HOSTNAME in $HOSTNAMES; do
			echo
			echo "$HOSTNAME:"
			cat /tmp/$HOSTNAME.output | grep '^Packages\|^All \|^Writing dpkg\|^No packages\|^Rebooting\|log for details\|^ [a-z]\|^Errors were\|^upgrades failed'
		done
		;;
	api-config)
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
	panic-config)
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
	deploy)
		if [ $# -lt 3 ]; then
			echo "Usage: $0 deploy CONFIG_FILE USER"
			exit 1
		fi

		if [[ "$POLKADOT_PUBKEY" == "" || "$ADMIN_PUBKEY" == "" ]]; then
			echo "Ensure POLKADOT_PUBKEY and ADMIN_PUBKEY are set properly in node config."
		fi

		NEW_CONFIG=`mktemp /tmp/polkadot.config-XXXXXXXX`
		echo "Using config file $NEW_CONFIG"

		cp $2 $NEW_CONFIG
		# A newline.
		echo >> $NEW_CONFIG
		SKIP_DB=""
		for arg in "${@:4}"; do
			case $arg in
				-n=*|--name=*)
					NAME="${arg#*=}"
					echo "Name is <<$NAME>>"
					echo "NAME=\"$NAME\"" >> $NEW_CONFIG
				;;
    				-h=*|--host=*)
					HOST="${arg#*=}"
					echo "Host is <<$HOST>>"
					echo "HOST=\"$HOST\"" >> $NEW_CONFIG
				;;
				-i=*|--instances=*)
					INSTANCES="${arg#*=}"
					echo "Instances: <<$INSTANCES>>"
					echo "INSTANCES=\"$INSTANCES\"" >> $NEW_CONFIG
				;;
				-s|--skip-db)
					SKIP_DB=1
				;;
				*)
					echo "Unknown option: $arg"
					exit -1
				;;
			esac
		done
		source $NEW_CONFIG

		if [[ $HAVE_NETWORK_CONFIG && ! $SKIP_DB ]]; then
			echo "Copying database..."
			ssh -o StrictHostKeyChecking=no root@$HOST.$DOMAIN "echo $HEAD_HOST_PUBKEY >> .ssh/authorized_keys" > /dev/null 2> /dev/null
			ssh polkadot@$HEAD_HOST scp -o StrictHostKeyChecking=no /home/polkadot/nodes/db.tgz /home/polkadot/net.config root@$HOST.$DOMAIN: > /dev/null 2> /dev/null
		fi

		echo "Copying setup script and config..."
		scp host-polkadot.sh setup.sh root@$HOST.$DOMAIN:
		ssh root@$HOST.$DOMAIN "\
			chmod +x setup.sh ; \
			echo $HEAD_HOST_PUBKEY > id_head.pub ; \
			echo $POLKADOT_PUBKEY > id_polkadot.pub ; \
			echo $ADMIN_PUBKEY > id_admin.pub ; \
		"
		scp $NEW_CONFIG root@$HOST.$DOMAIN:polkadot.config
		rm -f $NEW_CONFIG

		echo "Setting up..."
		OUTPUT=`mktemp /tmp/polkadot.output-XXXXXXXX`
		ssh root@$HOST.$DOMAIN "./setup.sh polkadot.config $3" | tee $OUTPUT

		tail -n $INSTANCES $OUTPUT | cut -d ' ' -f 2 > $HOST.keys

		if [[ $HAVE_NETWORK_CONFIG ]]; then
			echo "Adding new head-node..."
			HEAD_NODE="$(ssh polkadot@$HOST.$DOMAIN /usr/bin/polkadot.sh address 1)"
			ssh polkadot@$HEAD_HOST /usr/bin/polkadot.sh add-head-node $HEAD_NODE
		else
			echo "Writing initial network config file..."
			SSH_ID="$(ssh -o StrictHostKeyChecking=no polkadot@$HOST.$DOMAIN ssh-keygen -t rsa -q -f .ssh/id_rsa -N '' && cat .ssh/id_rsa.pub)"
			echo > config < EOF
DOMAIN=$DOMAIN
HEAD_HOST=$HOST.$DOMAIN
HEAD_HOST_PUBKEY="$SSH_ID"
EOF
			echo
			echo "Once your node is synchronized, run the following command on it to ensure future deployments need"
			echo "not synchronize again:"
			echo
			echo "  ssh polkadot@$HOST.$DOMAIN polka pack-db"
			echo
			echo "Once done, further nodes may be deployed."
		fi
		;;
	help | --help | -h)
		echo "Usage:"
		echo "  $0 update-script   Update the polkadot.sh script on all nodes."
		echo "  $0 update-binary   Update the polkadot binary on all nodes."
		echo "  $0 api-config      Auto-generate a polkadot_api_server 'user_config_nodes.ini' file."
		echo "  $0 panic-config    Auto-generate a panic_polkadot 'user_config_nodes.ini' file."
		echo "  $0 deploy CONFIG_FILE USER   Deploy a new Polkadot host."
		echo "  $0 host HOST COMMAND   Execute a command on a deployed host."
		;;
	host)
		if [ $# -lt 2 ]; then
			echo "Unknown usage. Use $0 help for more information."
			exit 1
		fi
		if [ $# -eq 2 ]; then
			ssh -t polkadot@$2.$DOMAIN
		else
			ssh -t polkadot@$2.$DOMAIN polka "${@:3}"
		fi
		;;
	*)
		if [ $# -lt 1 ]; then
			echo "Unknown usage. Use $0 help for more information."
			exit 1
		fi
		if [ $# -eq 1 ]; then
			ssh -t polkadot@$1.$DOMAIN
		else
			ssh -t polkadot@$1.$DOMAIN polka "${@:2}"
		fi
esac

[[ $(echo $SCREENS | wc -l) != "$INSTANCES" ]]
