#!/bin/bash

# Gav's Polkadot provisioning script.
# By Gav.

VERSION="0.1.3"

# Set up defaults.
DB="paritydb"
WASM_EXECUTION="compiled"
PRUNING=16384
IN_PEERS=25
OUT_PEERS=25
RESERVED_ONLY=1
EXE=polkadot

# Bring in user config.
if [[ "$1" != "init-sentry" && "$1" != "init-validator" ]]; then
	source ~/polkadot.config
fi

POLKADOT=$BASE/$EXE

# Integrate config into final options.
[[ "$RESERVED_ONLY" != "0" && "$RESERVED_ONLY" != "" ]] && OPTIONS="$OPTIONS --reserved-only"
[[ $DB ]] && OPTIONS="$OPTIONS --db=$DB"
[[ $WASM_EXECUTION ]] && OPTIONS="$OPTIONS --wasm-execution=$WASM_EXECUTION"
[[ $IN_PEERS ]] && OPTIONS="$OPTIONS --in-peers=$IN_PEERS"
[[ $OUT_PEERS ]] && OPTIONS="$OPTIONS --out-peers=$OUT_PEERS"
[[ "$PRUNING" != "" ]] && OPTIONS="$OPTIONS --unsafe-pruning --pruning=$PRUNING"
if [[ "$INSTANCES" == "1" ]]; then
	FULLNAME="$NAME"
else
	FULLNAME="$NAME-$INSTANCE"
fi

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"   
    printf '%s' "$var"
}

case "$1" in 
	run)
		if [ $# -lt 2 ]; then
			echo "Usage: $0 run <instance>"
			exit
		fi
		INSTANCE=$2

		CUT=$(which gcut || which cut)
		OTHER_HOSTS="$(for i in $HOSTS; do if [[ $i != $HOST ]]; then echo -n $i ''; fi; done)"
		if [[ -e $BASE/nodes/addrs.$HOST ]]; then
			LOCAL_NODES="$($CUT --complement -d ' ' -f $INSTANCE < $BASE/nodes/addrs.$HOST)"
		else
			LOCAL_NODES=""
		fi
		if [[ "$VALIDATORS" == "" ]]; then
			S="$SENTRIES" || "sentries"
			SENTRY_NODE="$($CUT -d ' ' -f $((INSTANCE + OFFSET)) < "$BASE/nodes/$S")"
			MODE="--validator"
		else
			VALIDATOR_NODE="$($CUT -d ' ' -f $((INSTANCE + OFFSET)) < "$BASE/nodes/addrs.$VALIDATORS")"
			MODE="--sentry $VALIDATOR_NODE"
		fi

		REMOTE_NODES="$(for i in $OTHER_HOSTS; do cat $BASE/nodes/addrs.$i; done)"

		echo "$HOST: $FULLNAME"
		echo "MODE: $MODE"
		echo "OPTIONS: $OPTIONS"
		echo "OTHER_HOSTS: $OTHER_HOSTS"
		echo "LOCAL_NODES: $LOCAL_NODES"
		echo "REMOTE_NODES: $REMOTE_NODES"
		if [[ "$VALIDATORS" == "" ]]; then
			echo "SENTRY_NODE: $SENTRY_NODE"
		else
			echo "VALIDATOR_NODE: $VALIDATOR_NODE"
		fi

		if [[ ! -e $BASE/nodes/instance-$INSTANCE ]]; then
			if [[ -e $BASE/nodes/val-$INSTANCE ]]; then
				mv $BASE/nodes/val-$INSTANCE $BASE/nodes/instance-$INSTANCE
			elif [[ -e ~/.local/share/polkadot ]]; then
				mv ~/.local/share/polkadot $BASE/nodes/instance-$INSTANCE
			fi
		fi

		if [[ "$LOCAL_NODES$REMOTE_NODES$SENTRY_NODE" != "" ]]; then
			RESERVED_NODES="--reserved-nodes $LOCAL_NODES $REMOTE_NODES $SENTRY_NODE"
		fi

		DB_PATH="$BASE/nodes/instance-$INSTANCE"
		$POLKADOT $MODE $OPTIONS \
			-d $DB_PATH \
			--name "$FULLNAME" \
			$RESERVED_NODES \
			--port $((30332 + INSTANCE)) \
			--prometheus-port $((9614 + INSTANCE)) \
			--ws-port $((9943 + INSTANCE)) \
			--rpc-port $((9932 + INSTANCE))
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
		$0 stop
		[[ -x $POLKADOT ]] || $0 update
		for (( i = 0; i < $INSTANCES; i += 1 )); do
			echo "Starting instance $((i + 1)) of $INSTANCES..."
			screen -d -m $0 loop $((i + 1))
		done
		;;
	stop)
		chmod -x $POLKADOT
		pkill -x $EXE 2> /dev/null
		sleep 1
		chmod +x $POLKADOT
		;;
	restart)
		echo "Restarting..."
		pkill -x $EXE
		;;
	update)
		mv -f $POLKADOT $POLKADOT.old 2> /dev/null
		echo "Downloading latest release..."
		wget -q https://github.com/paritytech/polkadot/releases/latest/download/polkadot
		chmod +x $POLKADOT
		$0 restart
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
BASE=$(pwd)
HOST=$(hostname)
HOSTS=$(hostname)
RESERVED_ONLY=0
OFFSET=$OFFSET
# Optional config (defaults given)
#EXE=polkadot
#IN_PEERS=25
#OUT_PEERS=25
#PRUNING=16384
#DB=paritydb
#WASM_EXECUTION=compiled
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
#EXE=polkadot
#RESERVED_ONLY=1
#IN_PEERS=25
#OUT_PEERS=25
#PRUNING=16384
#DB=paritydb
#WASM_EXECUTION=compiled
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