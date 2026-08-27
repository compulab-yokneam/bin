prod_name="/proc/device-tree/prod.info/prod.name"
prod_name_default="iot-gateway"

function get_device() {
	[[ -f ${prod_name} ]] && device=$(cat ${prod_name} | tr -d '\0') || device=${prod_name_default}
	echo ${device,,}
}

[[ -z "${IOTG}" ]] && export IOTG=$(get_device)

# Board specific stuff
export BOARDS_HOME=/usr/share/cl-iotg-config/boards

# LOGs stuff
export LOGS_HOME=/run/${IOTG}/log
TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"

# Genaral stuff
export DUMMY_PATH=/dev/null
export I2C_BUS=/sys/bus/i2c/devices
export IIO_BUS=/sys/bus/iio/devices
export USB_BUS=/sys/bus/usb/devices
