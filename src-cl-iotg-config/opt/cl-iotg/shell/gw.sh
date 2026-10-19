#! /bin/bash

[[ -z ${IOTG_LIB_HOME} ]] && export IOTG_LIB_HOME=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

# Includes
## Common lib
. ${IOTG_LIB_HOME}/common.inc
## Generic Gateway lib
. ${IOTG_LIB_HOME}/gw.inc
## Device specific Gateway lib
[[ -e ${IOTG_LIB_HOME}/${IOTG}/gw.inc ]] && . ${IOTG_LIB_HOME}/${IOTG}/gw.inc

function gw_info_frontplane() {
	[[ -n ${1} ]] && echo "${1}"
	echo ""
	LC_CTYPE=C tree --noreport ${GW_ACCESS}
	echo ""
}

function gw_load_modules() {
	declare -n GW_KO_LIST=$(gw_get_ko_arr)
	for m in ${GW_KO_LIST[@]} ; do
		modprobe ${m} > /dev/null 2>&1
		sleep 0.5
	done
}

function gw_unload_modules() {
	declare -n GW_KO_LIST=$(gw_get_ko_arr)
	for m in ${GW_KO_LIST[@]} ; do
		modprobe ${m} -r > /dev/null 2>&1
	done
}

#############################################################################
# Grant access: populate the Gateway access directory
#############################################################################
function gw_grant_access() {
	# Make GW access homedir
	local access_home=${GW_ACCESS}
	rm -rf ${access_home}
	mkdir -p ${access_home}

	# Load kenel modules associated with the GW peripherals and interfaces
	gw_load_modules
	# Connectivity/Network
	mkdir -p ${GW_ACCESS_NET}
	## WiFi/BT
	if [[ -d ${GW_WIFI_DEV_HOME} ]]; then
		local wlan=$(ls ${GW_WIFI_DEV_HOME})
		[[ -L ${GW_WIFI_HOME}/${wlan} ]] && ln -s ${GW_WIFI_HOME}/${wlan} ${GW_ACCESS_NET}/${GW_ACCESS_WLAN}
	fi
	if [[ -d ${GW_BT_DEV_HOME} ]]; then
		local bt=$(ls ${GW_BT_DEV_HOME})
		[[ -L ${GW_BT_HOME}/${bt} ]] && ln -s ${GW_BT_HOME}/${bt} ${GW_ACCESS_NET}/${GW_ACCESS_BT}
	fi

	## Modem
	mkdir -p ${GW_ACCESS_MODEM_HOME}
	[[ -L /dev/${GW_MODEM_TTY}${GW_MODEM_AT1^^} ]]  && ln -s /dev/${GW_MODEM_TTY}${GW_MODEM_AT1^^} ${GW_ACCESS_MODEM_HOME}/${GW_MODEM_AT1}
	[[ -L /dev/${GW_MODEM_TTY}${GW_MODEM_AT2^^} ]]  && ln -s /dev/${GW_MODEM_TTY}${GW_MODEM_AT2^^} ${GW_ACCESS_MODEM_HOME}/${GW_MODEM_AT2}
	[[ -L /dev/${GW_MODEM_TTY}${GW_MODEM_GPS^^} ]]  && ln -s /dev/${GW_MODEM_TTY}${GW_MODEM_GPS^^} ${GW_ACCESS_MODEM_HOME}/${GW_MODEM_GPS}
	[[ -L /dev/${GW_MODEM_TTY}${GW_MODEM_QCDM^^} ]] && ln -s /dev/${GW_MODEM_TTY}${GW_MODEM_QCDM^^} ${GW_ACCESS_MODEM_HOME}/${GW_MODEM_QCDM}

	# LEDs
	mkdir -p ${GW_ACCESS_LED_HOME}
	declare -n GW_ULED_ARR=$(gw_get_uled_arr)
	for led in ${GW_ULED_ARR[@]} ; do
		[[ -L ${LED_HOME}/${led} ]]  && ln -s ${LED_HOME}/${led} ${GW_ACCESS_LED_HOME}/${led,,}
	done

	# CMD Button
	mkdir -p ${GW_ACCESS_CMD_BTN_HOME}
	[[ -L ${GW_CMD_BTN_DEV} ]] && ln -s $(readlink -f ${GW_CMD_BTN_DEV}) ${GW_ACCESS_CMD_BTN_HOME}/${GW_ACCESS_CMD_BTN}

	# TPM
	mkdir -p ${GW_ACCESS_TPM_HOME}
	if [[ -d ${TPM_DEV_HOME} ]]; then
		local tpm=$(ls ${TPM_DEV_HOME})
		[[ -L ${TPM_HOME}/${tpm} ]] && ln -s ${TPM_HOME}/${tpm} ${GW_ACCESS_TPM_HOME}/${GW_ACCESS_TPM}
	fi
	if [[ -d ${TPMRM_DEV_HOME} ]]; then
		local tpmrm=$(ls ${TPMRM_DEV_HOME})
		[[ -L ${TPMRM_HOME}/${tpmrm} ]] && ln -s ${TPMRM_HOME}/${tpmrm} ${GW_ACCESS_TPM_HOME}/${GW_ACCESS_TPMRM}
	fi

	# Block devices
	mkdir -p ${GW_ACCESS_BLKDEV_HOME}
	declare -n GW_BLKDEV_ARR=$(gw_get_blkdev_arr)
	for blk in ${GW_BLKDEV_ARR[@]} ; do
		local blk_name=$(gw_get_blkdev_name ${blk})
		if [[ -b ${GW_BLKDEV_HOME}/${blk_name} ]]; then
			ln -s ${GW_BLKDEV_HOME}/${blk_name} ${GW_ACCESS_BLKDEV_HOME}/${blk}
		fi
	done
}

function gw_init() {
	command -v do_init_gw &>/dev/null && (do_init_gw || true) || true
}

### Main

LOG_FILE_NAME=${LOG_FILE_NAME:-${LOGS_HOME}/${IOTG}.gw.log.$(date +${TIMESTAMP_FORMAT})}
mkdir -p ${LOGS_HOME}

opt=${1:-"source"}
param=${2:-}

case ${opt} in
	"config")
		# Ad-hoc option for automated service
		gw_init
		gw_grant_access ${param} > ${LOG_FILE_NAME}
		gw_info_frontplane "Gateway Access Info:" >> ${LOG_FILE_NAME}
		;;
	"info")
		gw_init
		gw_info_frontplane "Gateway Access Info:"
		;;
	"manage")
		gw_init
		gw_grant_access
		;;
	"source")
		gw_init
		# Dummy option - applied when file is sourced by external script for further usage
		;;
	*)
		;;
esac
