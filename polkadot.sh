#!/bin/bash

# Gav's Polkadot provisioning script.
# By Gav.

VERSION="0.4.7"

count() {
	printf $#
}
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Set up defaults.
DB="paritydb"
WASM_EXECUTION="compiled"
PRUNING=16384
IN_PEERS=25
OUT_PEERS=25
EXE=polkadot
BASE=/home/polkadot

# Bring in user config.
if [[ "$1" != "init-sentry" && "$1" != "init-validator" ]]; then
	source ./polkadot.config
fi

# Bring in head nodes
HEAD_NODE_FILE=$BASE/headnodes
if [[ -e $HEAD_NODE_FILE ]]; then
	HEAD_NODES="$(cat $HEAD_NODE_FILE)"
fi

if [[ "$INSTANCES" == "" ]]; then
	if [[ "$HOST_NODES" == "" ]]; then
		INSTANCES=1
	else
		INSTANCES=`count $HOST_NODES`
	fi
fi
POLKADOT=$BASE/$EXE

# Integrate config into final options.
[[ "$RESERVED_ONLY" != "0" && "$RESERVED_ONLY" != "" ]] && OPTIONS="$OPTIONS --reserved-only"
[[ $DB ]] && OPTIONS="$OPTIONS --db=$DB"
[[ $WASM_EXECUTION ]] && OPTIONS="$OPTIONS --wasm-execution=$WASM_EXECUTION"
[[ $IN_PEERS ]] && OPTIONS="$OPTIONS --in-peers=$IN_PEERS"
[[ $OUT_PEERS ]] && OPTIONS="$OPTIONS --out-peers=$OUT_PEERS"
[[ "$PRUNING" != "" ]] && OPTIONS="$OPTIONS --unsafe-pruning --pruning=$PRUNING"

case "$1" in 
	run)
		if [ $# -lt 2 ]; then
			echo "Usage: $0 run <instance>"
			exit
		fi
		INSTANCE=$2

		if [[ "$INSTANCES" == "1" ]]; then
			FULLNAME="$NAME"
		else
			FULLNAME="$NAME-$INSTANCE"
		fi

		# Identify the hub instance - the others connect to these, and it connects to all others locally.
		CUT=$(which gcut || which cut)
		if [[ "$HOST_NODES" != "" ]]; then
			if [[ "$INSTANCE" == "1" ]]; then
				LOCAL_NODES="$(echo $HOST_NODES | $CUT --complement -d ' ' -f $INSTANCE)"
			else
				LOCAL_NODES="$(echo $HOST_NODES | $CUT -d ' ' -f $INSTANCE)"
			fi
		fi
		if [[ "$SENTRIES" != "" ]]; then
			SENTRY_NODE="$(echo $SENTRIES | $CUT -d ' ' -f $((INSTANCE + OFFSET)))"
			MODE="--validator"
		elif [[ "$VALIDATORS" != "" ]]; then
			VALIDATOR_NODE="$(echo $VALIDATORS | $CUT -d ' ' -f $((INSTANCE + OFFSET)))"
			MODE="--sentry $VALIDATOR_NODE"
		elif [[ "$VALIDATOR" != "" ]]; then
			MODE="--validator"
		else
			MODE=""
		fi

		for N in $HEAD_NODES; do
			if [[ "$(echo $HOST_NODES | grep $N)" == "" ]]; then
				RESERVED="$RESERVED $N"
			fi
		done

		echo "$HOST: $FULLNAME"
		echo "MODE: $MODE"
		echo "OPTIONS: $OPTIONS"
		echo "LOCAL_NODES: $LOCAL_NODES"
		echo "RESERVED: $RESERVED"
		if [[ "$SENTRIES" != "" ]]; then
			echo "SENTRY_NODE: $SENTRY_NODE"
		elif [[ "$VALIDATORS" != "" ]]; then
			echo "VALIDATOR_NODE: $VALIDATOR_NODE"
		else
			echo "(FULL NODE)"
		fi

		if [[ ! -e $BASE/nodes/instance-$INSTANCE ]]; then
			if [[ -e $BASE/nodes/val-$INSTANCE ]]; then
				mv $BASE/nodes/val-$INSTANCE $BASE/nodes/instance-$INSTANCE
			elif [[ -e ~/.local/share/polkadot ]]; then
				mv ~/.local/share/polkadot $BASE/nodes/instance-$INSTANCE
			fi
		fi

		if [[ "$LOCAL_NODES$RESERVED$SENTRY_NODE" != "" ]]; then
			RESERVED_NODES="--reserved-nodes $LOCAL_NODES $RESERVED $SENTRY_NODE"
		fi

		DB_PATH="$BASE/nodes/instance-$INSTANCE"

		if [[ "$TELEMETRY" != "" ]]; then
			TELEMETRY_OPT="--telemetry-url"
			TELEMETRY_ARG="$TELEMETRY 0"
		fi

		$POLKADOT $MODE $OPTIONS $TELEMETRY_OPT "$TELEMETRY_ARG" \
			-d $DB_PATH \
			--name "$FULLNAME" \
			$RESERVED_NODES \
			--port $((30332 + INSTANCE)) \
			--prometheus-port $((9614 + INSTANCE)) \
			--ws-port $((9943 + INSTANCE)) \
			--rpc-port $((9934 - INSTANCE))
		;;
	loop)
		if [ $# -lt 2 ]; then
			echo "Usage: $0 loop <instance>"
			exit
		fi
		while [[ -x $POLKADOT ]] ; do
			$0 run $2
		done
		;;
	start | "")
		[[ -x $POLKADOT ]] && $0 stop || $0 update
		if [[ "$HOST_NODES" == "" ]]; then
			for (( i = 0; i < $INSTANCES; i += 1 )); do
				screen -d -m $0 loop $((i + 1))
			done
			echo "HOST_NODES='$(echo)$($0 address)'" >> ./polkadot.config
			$0 stop
		fi
		for (( i = 0; i < $INSTANCES; i += 1 )); do
			echo "Starting instance $((i + 1)) of $INSTANCES..."
			screen -d -m $0 loop $((i + 1))
		done
		;;
	stop)
		chmod -x $POLKADOT
		while [[ `ps aux | grep $POLKADOT | grep -v grep | wc -l` != "0" ]]; do
			pkill -x $EXE 2> /dev/null
			sleep 1
		done
		chmod +x $POLKADOT
		;;
	add-head-node)
		if [ $# -lt 2 ]; then
			echo "Usage: $0 add-head-node <multiaddr>"
			exit
		fi
		if [[ "$HEAD_NODE_FILE" == "" ]]; then
			echo "Cannot add head node when no head node file exists"
			exit
		fi
		HEAD_NODES="$HEAD_NODES $2"
		echo "$HEAD_NODES" > "$HEAD_NODE_FILE"
		for N in $HEAD_NODES; do
			if [[ "$(echo $HOST_NODES | grep $N)" == "" ]]; then
				X=${N/\/ip4\//}
				IP=${X/\/*/}
				echo -n "Propagating to $IP..."
				H=$(echo $HEAD_NODES | ssh -o StrictHostKeyChecking=no polkadot@$IP "cat > headnodes && hostname && /usr/bin/polkadot.sh restart > /dev/null")
				echo "propagated to $H."
			fi
		done
		$0 restart
		;;
	restart)
		echo "Restarting..."
		pkill -x $EXE
		;;
	address | addresses)
		BEGIN=0
		END=$INSTANCES
		if [ $# -eq 2 ]; then
			END=$2
			BEGIN=$((END - 1))
		fi
		if [ $# -eq 3 ]; then
			I=$2
			BEGIN=$(($I - 1))
			I=$3
			END=$(($BEGIN + I))
		fi
		for (( i = $BEGIN; i < $END; i += 1 )); do
			M=""
			while [[ "$M" == "" ]]; do
				M=$(curl -s -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "system_localPeerId", "params":[]}' http://localhost:$((9933 - i)) | cut -d '"' -f 8)
				[[ "$M" == "" ]] && sleep 1
			done
			IP=$(hostname -I | cut -f 1 -d ' ')
			echo "/ip4/$IP/tcp/$((30333 + i))/p2p/$M"
		done
		;;
	key | keys)
		BEGIN=0
		END=$INSTANCES
		if [ $# -eq 2 ]; then
			END=$2
			BEGIN=$((END - 1))
		fi
		if [ $# -eq 3 ]; then
			I=$2
			BEGIN=$(($I - 1))
			I=$3
			END=$(($BEGIN + I))
		fi
		for (( i = $BEGIN; i < $END; i += 1 )); do
			echo -n "$((i + 1)): "
			curl -s -H "Content-Type: application/json" -d '{"id":1, "jsonrpc":"2.0", "method": "author_rotateKeys", "params":[]}' http://localhost:$((9933 - i)) | cut -d '"' -f 8
		done
		;;
	update | upgrade)
		mv -f $POLKADOT $POLKADOT.old 2> /dev/null
		echo "Downloading latest release..."
		wget -q https://github.com/paritytech/polkadot/releases/latest/download/polkadot
		chmod +x $POLKADOT
		$0 restart
		;;
	update-self)
		wget -q https://raw.githubusercontent.com/gavofyork/scripts/master/polkadot.sh
		chmod +x polkadot.sh
		sudo mv polkadot.sh $0
		;;
	pack-db)
		$0 stop
		cd $BASE/nodes
		mv instance-1/chains/polkadot/network instance-1/chains/polkadot/keystore .
		tar czf db.tgz instance-1
		mv network keystore instance-1/chains/polkadot
		cd ..
		$0 start
		;;
	--version | -v)
		echo "$0 v$VERSION"
		;;
	*)
		echo "Usage: $0 [COMMAND] [OPTIONS]"
		echo "Commands:"
		echo "  start"
		echo "  stop"
		echo "  restart"
		echo "  update"
		echo "  update-self"
		echo "  add-head-node"
		echo "  packdb"
		echo "  key INDEX"
		echo "  address INDEX"
		echo "  keys ( START_INDEX COUNT ? ) ?"
		echo "  addresses ( START_INDEX COUNT ? ) ?"
		;;
esac
