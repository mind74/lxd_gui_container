#!/bin/bash
#
# Wrapper to attach to running GUI app. Run on host.
APP_FOLDER=$(dirname $0)
CONF_FOLDER="$APP_FOLDER/conf.d/"


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

function cleanup() {
  xpra stop ssh:ubuntu@"${container_ip}""${display_num}"
  ssh ubuntu@"${container_ip}" xauth remove ${display_num}
}

if [ $# -lt 1 ]; then
    usage
    exit
fi

readonly CONTAINER_NAME=$1
shift
readonly APP_CMDLINE=$XPRA_APP_CMDLINE
#shift

params=$@

#cargo la configuración
params=""
if [ -f  "${CONF_FOLDER}${CONTAINER_NAME}.conf" ]; then
  print_status "using ${CONF_FOLDER}${CONTAINER_NAME}.conf"
  conf=$(cat "${CONF_FOLDER}${CONTAINER_NAME}.conf")
else
  print_status "using ${CONF_FOLDER}default.conf"
  conf=$(cat "${CONF_FOLDER}default.conf")
fi

paramaList=($(echo "${conf// /}" | grep -Po ".+"))
length=${#paramaList[@]}
for ((i = 0; i != length; i++)); do
  p=$(echo "${paramaList[i]// /}")
  params="$params --${p}"
done
params="$params $@"


print_status "params: $params"

container_ip=$($APP_FOLDER/resolve_host.sh ${CONTAINER_NAME})
print_status "ip a conectar: $container_ip"

if [[ -z "${container_ip}" ]]; then
    print_err "Failed to determine host IP address."
    exit 1
fi


print_status "...Searching for active xpra session"
display_num=$(ssh ubuntu@"${container_ip}" xpra list | grep -oP -m 1 ":\d{2,}")
echo "$display_num"
if [ "$display_num" == "" ] ; then
  print_status "No active xpra session found!"
  display_num=$((${RANDOM} % 1000))
  display_num=":$display_num"
  #display_num=":100"
  notify-send "Iniciando XPRA en $CONTAINER_NAME"
  print_status "Starting xpra server in ${container_ip} , using DISPLAY $display_num"
  ssh ubuntu@"${container_ip}" xpra start $display_num \
      --start-via-proxy=no \
      --attach=no \
      --mdns=no \
      --html=off || exit 1
#      --no-pulseaudio 

  print_status "Waiting for Xpra server"

  ssh ubuntu@"${container_ip}" bash -c "'
  declare -i try_count=0
  while [ \$((try_count++)) -lt ${NUM_ATTEMPTS} ]; do
      echo \"Attempt \${try_count}/${NUM_ATTEMPTS}: Connecting to xpra server.\"
      sleep 5
      if xpra list | grep -o \"$display_num\"; then
          break
      fi
  done
  '"
sleep 2

#  if  ! ssh ubuntu@"${container_ip}" xpra list | grep -o "$display_num" ; then
#    notify-send -i error "No se pudo conectar al servidor xpra $CONTAINER_NAME${display_num}"
#    print_err "Failed to connect to xpra server."
#    exit 1
#  fi
#else  
#  print_status "using existing session $display_num "
fi

trap cleanup EXIT

print_status "ejecutando [$APP_CMDLINE]"
if [ "$APP_CMDLINE" == ""  ]; then
    xpra attach ssh:ubuntu@"${container_ip}"$display_num $params \
       --session-name=$CONTAINER_NAME \
       || notify-send -i error "No se pudo atachar sesion XPRA en $CONTAINER_NAME"
else
    xpra attach ssh:ubuntu@"${container_ip}"$display_num $params \
       --session-name=$CONTAINER_NAME \
       --start=$APP_CMDLINE \
       || notify-send -i error "No se pudo atachar sesion XPRA en $CONTAINER_NAME"
fi

