function get_device() {
    local board_name="/proc/device-tree/som.info/board.name"
    local device=$( [[ -f ${board_name} ]] && cat ${board_name} )
    device=${device:-"iot-gate-imx8plus"}
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

DEV_ID="/opt/iot-gate-imx8plus/shell/iotg_id.sh"

# Full stop if the device id is incorrect
${DEV_ID} || exit 0
