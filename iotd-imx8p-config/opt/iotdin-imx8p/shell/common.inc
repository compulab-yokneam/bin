function get_device() {
    local board_name="/proc/device-tree/som.info/board.name"
    local device=$( [[ -f ${board_name} ]] && cat ${board_name} )
    device=${device:-"iotdin-imx8p"}
    echo ${device}
}

[[ -z "${IOTDIN}" ]] && export IOTDIN=$(get_device)

# LOGs stuff
export LOGS_HOME=/run/${IOTDIN}/log
TIMESTAMP_FORMAT="%Y%m%d_%H%M%S"

DEV_ID="opt/iotdin-imx8p/shell/iotdin_id.sh"

# Full stop if the device id is incorrect
${DEV_ID} || exit 0
