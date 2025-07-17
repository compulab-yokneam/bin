#! /bin/bash

[[ -z ${IOTG_LIB_HOME} ]] && export IOTG_LIB_HOME=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

# Includes
. ${IOTG_LIB_HOME}/common.inc
. ${IOTG_LIB_HOME}/gw.inc

function gw_info_frontplane() {
	[[ -n ${1} ]] && echo "${1}"
	echo ""
	LC_CTYPE=C tree --noreport ${GW_ACCESS}
	echo ""
}

#############################################################################
# Grant access: populate the Gateway access directory
#############################################################################
function gw_grant_access() {
	# Make GW access homedir
	local access_home=${GW_ACCESS}
	rm -rf ${access_home}
	mkdir -p ${access_home}

	# Connectivity/Network
	mkdir -p ${GW_ACCESS_NET}
	## WiFi/BT
	modprobe iwlwifi > /dev/null 2>&1
	modprobe btusb > /dev/null 2>&1
	sleep 1
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
	## User LEDs
	mkdir -p ${GW_ACCESS_LED_HOME}
	for led in ${GW_LED_FIRST} ${GW_LED_LAST} ; do
		for color in ${GW_LED_RED} ${GW_LED_GREEN} ; do
			[[ -L ${LED_HOME}/${color^}"_"${led} ]]  && ln -s ${LED_HOME}/${color^}"_"${led} ${GW_ACCESS_LED_HOME}/${color}"_"${led,,}
		done
	done
	## Power LED
	[[ -L ${LED_HOME}/${GW_PWR_LED} ]]  && ln -s ${LED_HOME}/${GW_PWR_LED} ${GW_ACCESS_LED_HOME}/${GW_PWR_LED,,}
}

### Main

LOG_FILE_NAME=${LOG_FILE_NAME:-${LOGS_HOME}/${IOTG}.gw.log.$(date +${TIMESTAMP_FORMAT})}
mkdir -p ${LOGS_HOME}

opt=${1:-"source"}
param=${2:-}

case ${opt} in
	"config")
		# Ad-hoc option for automated service
		gw_grant_access ${param} > ${LOG_FILE_NAME}
		gw_info_frontplane "Gateway Access Info:" >> ${LOG_FILE_NAME}
		;;
	"info")
		gw_info_frontplane "Gateway Access Info:"
		;;
	"source")
		# Dummy option - applied when file is sourced by external script for further usage
		;;
	*)
		;;
esac
