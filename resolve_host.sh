#!/bin/bash
#
# Este escript trata de recolver la IP del host solicitado
# Esta versión busca en la lista de contenedores lxd
# TODO: 
#   + buscar en lista de máquinas multipasss
#   + buscar en configuración ~/.ssh/config
#   + resolver por dns

APP_FOLDER=$(dirname $0)

readonly JQ_CMD="jq -rM"

function usage() {
    echo "$(basename $0) host-name"
    echo
}

function print_status() {
  echo "[+] $*"
}

function print_err() {
  echo "[!] $*" 1>&2;
}

if [ $# -lt 1 ]; then
    usage
    exit
fi

readonly CONTAINER_NAME=$1
shift

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

readonly container_ip="$(echo "${container_info}" \
  | ${JQ_CMD} '.network.eth0.addresses[] | select(.family == "inet").address')"
if [[ -z "${container_ip}" ]]; then
    print_err "Failed to determine container IP address."
    exit 1
fi

echo $container_ip
exit 0
