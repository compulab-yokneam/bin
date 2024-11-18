function get_device() {
	[[ -d /sys/devices/soc0 ]] && device=$(udevadm info -ap /sys/devices/soc0 | awk -F"\"" '(/machine/)&&($0=$2)' | cut -d" " -f2 | tr '[:upper:]' '[:lower:]') || device=iotdin
	echo ${device}
}

[[ -z "${IOTDIN}" ]] && export IOTDIN=$(get_device)

# LOGs stuff
export LOGS_HOME=/run/${IOTDIN}/log
TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"

# gpiolib version
gpioinfo --help | grep -q -- "--chip" && export c_opt="-c " || export c_opt=" "
