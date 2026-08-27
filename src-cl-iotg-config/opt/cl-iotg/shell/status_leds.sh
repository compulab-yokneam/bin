#! /bin/bash

[[ -z ${IOTG_LIB_HOME} ]] && export IOTG_LIB_HOME=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

# Includes
## Common lib
. ${IOTG_LIB_HOME}/common.inc
## Device specific Gateway lib
[[ -e ${IOTG_LIB_HOME}/${IOTG}/gw.inc ]] && . ${IOTG_LIB_HOME}/${IOTG}/gw.inc

export PATTERN_OK="1 270 0 90 1 270 0 90 1 270 0 290 1 270 0 90 1 90 0 90 1 270 0 1260"
export PATTERN_SOS="1 90 0 90 1 90 0 90 1 90 0 270 1 270 0 90 1 270 0 90 1 270 0 270 1 90 0 90 1 90 0 90 1 90 0 1260"

export LEDS_HOME=/sys/class/leds
export LED_OK=$(command -v gw_get_sled &>/dev/null && gw_get_sled OK || true)
export LED_SOS=$(command -v gw_get_sled &>/dev/null && gw_get_sled SOS || true)
[[ -e ${LEDS_HOME}/${LED_OK} ]] || exit 1
[[ -e ${LEDS_HOME}/${LED_SOS} ]] || exit 1

function set_led() {
	local code=${1}
	local led=${2:-''}

	case ${code} in
		"off")
			[[ -n ${led} && -e ${LEDS_HOME}/${led} ]] || return 1
			echo none > ${LEDS_HOME}/${led}/trigger
			return 0
			;;
		"ok")
			led=${LED_OK}
			;;
		"sos")
			led=${LED_SOS}
			;;
		*)
			return 1
			;;
	esac
        
	declare -n PATTERN="PATTERN_"${code^^}

	[[ -n ${led} && -e ${LEDS_HOME}/${led} ]] || return 1
	echo pattern > ${LEDS_HOME}/${led}/trigger
	sleep 0.1
	echo "${PATTERN}" > ${LEDS_HOME}/${led}/pattern
	sleep 0.1
}

function cmd_ok() {
	set_led off ${LED_SOS}
	set_led ok
}

function cmd_sos() {
	set_led off ${LED_OK}
	set_led sos
}
