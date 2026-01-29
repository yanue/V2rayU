#!/bin/bash

set -e

COMMAND="$1"

case "$COMMAND" in

    setup)
        SERVER_IP="$2"
        TUN_IF="$3"
        TUN_LOCAL="$4"
        TUN_REMOTE="$5"
        DNS1="$6"
        DNS2="$7"
        DNS3="$8"
        NETWORK_IF="$9"

        DEFAULT_ROUTE=$(route -n get default 2>/dev/null)
        GW=$(echo "$DEFAULT_ROUTE" | awk '/gateway:/{print $2}')

        if [[ -z "$GW" ]]; then
            echo "ERROR: Could not detect default gateway."
            exit 1
        fi

        route -n delete -host ${SERVER_IP} 2>/dev/null || true
        route -n add -host ${SERVER_IP} ${GW}

        ifconfig ${TUN_IF} inet ${TUN_LOCAL} ${TUN_REMOTE} netmask 255.255.255.252 up

        route -n delete -net 0.0.0.0/1 -interface ${TUN_IF} 2>/dev/null || true
        route -n delete -net 128.0.0.0/1 -interface ${TUN_IF} 2>/dev/null || true

        route -n add -net 0.0.0.0/1 -interface ${TUN_IF}
        route -n add -net 128.0.0.0/1 -interface ${TUN_IF}

        route -n delete -host ${DNS1} ${GW} 2>/dev/null || true
        route -n delete -host ${DNS2} ${GW} 2>/dev/null || true
        route -n delete -host ${DNS3} ${GW} 2>/dev/null || true
        route -n add -host ${DNS1} ${GW}
        route -n add -host ${DNS2} ${GW}
        route -n add -host ${DNS3} ${GW}

        networksetup -setdnsservers ${NETWORK_IF} ${DNS1} ${DNS2} ${DNS3}

        echo "TUN setup completed"
        ;;

    teardown)
        SERVER_IP="$2"
        TUN_IF="$3"
        DNS1="$4"
        DNS2="$5"
        DNS3="$6"
        NETWORK_IF="$7"

        DEFAULT_ROUTE=$(route -n get default 2>/dev/null)
        GW=$(echo "$DEFAULT_ROUTE" | awk '/gateway:/{print $2}')

        route -n delete -net 0.0.0.0/1 -interface ${TUN_IF} 2>/dev/null || true
        route -n delete -net 128.0.0.0/1 -interface ${TUN_IF} 2>/dev/null || true
        route -n delete -host ${DNS1} ${GW} 2>/dev/null || true
        route -n delete -host ${DNS2} ${GW} 2>/dev/null || true
        route -n delete -host ${DNS3} ${GW} 2>/dev/null || true
        route -n delete -host ${SERVER_IP} 2>/dev/null || true

        networksetup -setdnsservers ${NETWORK_IF} Empty

        ifconfig ${TUN_IF} down 2>/dev/null || true

        echo "TUN teardown completed"
        ;;

    *)
        echo "Usage: $0 {setup|teardown} [args...]"
        exit 1
        ;;
esac