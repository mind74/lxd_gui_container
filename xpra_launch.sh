#!/bin/bash
#
# Wrapper to run an app. Run on host.


# number of times to connect to xpra server
declare -ri NUM_ATTEMPTS=10

readonly JQ_CMD="jq -rM"

function usage() {
    echo "$(basename $0) container-name [xpra-options...]"
    echo
}

function print_status() {
  echo "[+] $*"
}

function print_err() {
  echo "[!] $*"
}

if [ $# -lt 1 ]; then
    usage
    exit
fi

readonly CONTAINER_NAME=$1
shift
readonly APP_CMDLINE=$1
shift


# Check for running container #

container_info="$(lxc query \
  --wait "/1.0/containers/${CONTAINER_NAME}/state" 2>/dev/null)"
if [[ -n "${container_info}" ]]; then
    if [[ $(echo "${container_info}" | ${JQ_CMD} .status) != "Running" ]]; then
        print_status "Container not in \"Running\" state. Starting it."
        lxc start "${CONTAINER_NAME}" || exit 1
        lxc exec "${CONTAINER_NAME}" -- cloud-init status --wait || exit 1
        container_info="$(lxc query \
            --wait "/1.0/containers/${CONTAINER_NAME}/state" 2>/dev/null)"
    fi
else
    print_err "Container \"${CONTAINER_NAME}\" does not exist."
    exit 1
fi

# Start an xpra server in container for target app #

readonly container_ip="$(echo "${container_info}" \
  | ${JQ_CMD} '.network.eth0.addresses[] | select(.family == "inet").address')"
if [[ -z "${container_ip}" ]]; then
    print_err "Failed to determine container IP address."
    exit 1
fi

print_status "Searching for active xpra session"
display_num=$(ssh ubuntu@"${container_ip}" xpra list | grep -oP -m 1 ":\d{2,}")
if [ "$display_num" == "" ] ; then
 print_status "Iniciando una nueva instancia de xpra"
 XPRA_APP_CMDLINE=$APP_CMDLINE  "$(dirname $0)/xpra_attach.sh" "${CONTAINER_NAME}" 
else
  print_status "Ejecutando $APP_CMDLINE en $container_ip"
  ssh ubuntu@"${container_ip}" "DISPLAY=$display_num $APP_CMDLINE" &
fi

