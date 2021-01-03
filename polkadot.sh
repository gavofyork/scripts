#!/bin/bash

# Gav's Polkadot provisioning script.
# By Gav.

VERSION="0.3.1"

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

		CUT=$(which gcut || which cut)
		if [[ "$HOST_NODES" != "" ]]; then
			LOCAL_NODES="$(echo $HOST_NODES | $CUT --complement -d ' ' -f $INSTANCE)"
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

		echo "$HOST: $FULLNAME"
		echo "MODE: $MODE"
		echo "OPTIONS: $OPTIONS"
		echo "OTHER_HOSTS: $OTHER_HOSTS"
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
		if [[ -x $POLKADOT ]]; then
			chmod -x $POLKADOT
			pkill -x $EXE 2> /dev/null
			sleep 1
			chmod +x $POLKADOT
		fi
		;;
	restart)
		echo "Restarting..."
		pkill -x $EXE
		;;
	address)
		BEGIN=1
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
		BEGIN=1
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
	init-sentry)
		if [ $# -lt 4 ]; then
			echo "Usage: $0 init-sentry <name> <instances> <validators-name> [<offset>]"
			exit
		fi
		[[ -e polkadot.config ]] && mv -f polkadot.config polkadot.config.old
		OFFSET=$5 || "0"
		cat > polkadot.config << EOF
NAME="$2"
INSTANCES=$3
VALIDATORS="$4"
HOST=$(hostname)
HOST_NODES=
RESERVED_ONLY=0
OFFSET=$OFFSET
# Optional config (defaults given)
#BASE=/home/polkadot
#EXE=polkadot
#IN_PEERS=25
#OUT_PEERS=25
#PRUNING=16384
#DB=paritydb
#WASM_EXECUTION=compiled
#DOMAIN=polka.host
EOF
		;;
	init-validator)
		if [ $# -lt 4 ]; then
			echo "Usage: $0 init-validator <name> <instances> <sentries-name> [<offset>]"
			exit
		fi
		[[ -e polkadot.config ]] && mv -f polkadot.config polkadot.config.old
		OFFSET=$5 || "0"
		cat > polkadot.config << EOF
NAME="$2"
INSTANCES=$3
SENTRIES="$4"
BASE=$(pwd)
HOST=$(hostname)
HOSTS=$(hostname)
OFFSET=$OFFSET
# Optional config (defaults given)
#BASE=/home/polkadot
#EXE=polkadot
#RESERVED_ONLY=1
#IN_PEERS=25
#OUT_PEERS=25
#PRUNING=16384
#DB=paritydb
#WASM_EXECUTION=compiled
#DOMAIN=polka.host
EOF
		;;
	--version | -v)
		echo "$0 v$VERSION"
		;;
	*)
		echo "Usage: $0 [COMMAND] [OPTIONS]"
		echo "Commands:"
		echo "  init-sentry"
		echo "  init-validator"
		echo "  start"
		echo "  stop"
		echo "  restart"
		echo "  update"
		;;
esac
