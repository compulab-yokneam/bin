function get_device() {
	[[ -d /sys/devices/soc0 ]] && device=$(udevadm info -ap /sys/devices/soc0 | awk -F"\"" '(/machine/)&&($0=$2)' | cut -d" " -f2 | tr '[:upper:]' '[:lower:]') || device=iot-gate-imx8plus
	echo ${device}
}

[[ -z "${IOTG}" ]] && export IOTG=$(get_device)

# LOGs stuff
export LOGS_HOME=/run/${IOTG}/log
TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"

# Genaral stuff
export DUMMY_PATH=/dev/null
export I2C_BUS=/sys/bus/i2c/devices
export IIO_BUS=/sys/bus/iio/devices
export USB_BUS=/sys/bus/usb/devices
