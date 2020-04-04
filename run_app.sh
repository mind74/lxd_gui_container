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
echo "$display_num"
if [ "$display_num" == "" ] ; then
  ./attach.sh "${CONTAINER_NAME}" --border=auto,4 &
  sleep 5

  ssh ubuntu@"${container_ip}" bash -c "'
  declare -i try_count=0
  while [ \$((try_count++)) -lt ${NUM_ATTEMPTS} ]; do
      echo \"Attempt \${try_count}/${NUM_ATTEMPTS}: Connecting to xpra server.\"
      sleep 2
      if xpra list | grep -o \"$display_num\"; then
          break
      fi
  done
  '"
fi
display_num=$(ssh ubuntu@"${container_ip}" xpra list | grep -oP -m 1 ":\d{2,}")
if [ "$display_num" == "" ] ; then
  print_err "No active xpra session found!"
  exit 1
fi

ssh ubuntu@"${container_ip}" "DISPLAY=$display_num $APP_CMDLINE"  &