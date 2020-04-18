#!/bin/bash
#
# Wrapper to run an app in a xpra server.
APP_FOLDER=$(dirname $0)


# number of times to connect to xpra server
declare -ri NUM_ATTEMPTS=10


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

container_ip=$($APP_FOLDER/resolve_host.sh ${CONTAINER_NAME})
print_status "ip a conectar: $container_ip"

if [[ -z "${container_ip}" ]]; then
    print_err "Failed to determine host IP address."
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

