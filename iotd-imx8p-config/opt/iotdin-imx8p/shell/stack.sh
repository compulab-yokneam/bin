#! /bin/bash

[[ -z ${IOTDIN_LIB_HOME} ]] && export IOTDIN_LIB_HOME=$(dirname ${0})

# Common lib
. ${IOTDIN_LIB_HOME}/common.inc
# EEPROM Lib
. ${IOTDIN_LIB_HOME}/eeprom_lib.sh
# Status LEDs Lib
. ${IOTDIN_LIB_HOME}/status_leds.sh
# Stack Lib
. ${IOTDIN_LIB_HOME}/stack_lib.sh


function ebegin() {
	echo "$@"
}

function eend() {
	:
}

function bad_msg() {
	echo "ERROR: $@"
}

function info_msg() {
	echo "INFO: $@"
}

function warn_msg() {
	echo "WARNING: $@"
}

function do_dummy() {
	echo "$(basename ${0}): $@: command not found"
}

export DELIM_LINE="+-------"

function slot_show() {
	local fslot=${1:-${BIDX}}								# 1-st slot
	local tslot=${2:-${EIDX}}								# Last slot
	local cslot=$((${tslot} - ${fslot} + 1))				# Number of slots
	local slot_list=$(seq ${fslot} ${tslot} | xargs -x)		# Slot list
	
	# Output stack state as a table
	printf "\n"
	# Header - delimiter
	printf "${DELIM_LINE}" ; printf -- "${DELIM_LINE}%.0s" ${STACK_SLOTS[@]:${fslot}:${cslot}} ; printf "+\n";
	# Header - data - slot indexes
	printf "| %-6s" "Slot" ; printf "|   %-4s"  ${STACK_SLOTS[@]:${fslot}:${cslot}} ; printf  "|\n";
	# Intermediate - delimiter
	printf "${DELIM_LINE}" ; printf -- "${DELIM_LINE}%.0s" ${STACK_SLOTS[@]:${fslot}:${cslot}} ; printf "+\n";
	# Intermediate - data
	printf "| %-6s" "IFM" ; printf "| %-6s" ${STACK_IFM[@]:${fslot}:${cslot}} ; printf "|\n";
	# Footer - delimiter
	printf "${DELIM_LINE}" ; printf -- "${DELIM_LINE}%.0s" ${STACK_SLOTS[@]:${fslot}:${cslot}} ; printf "+\n";
	printf "\n"
}

function stack_show() {
	slot_show ${BIDX} ${EIDX}
}

function stack_show_nonepmty() {
	local fslot=${BIDX}	# From slot
	local tslot=${EIDX}	# To slot
	local slot_list=$(seq ${fslot} ${tslot} | xargs -x)
	local ifm_type=${IFM_TYPE_ND}
	local last=${EIDX}
	local ret

	stack_walkthru_backplane
	for i in ${slot_list}; do
		is_slot_empty ${i} && ret=$? || ret=$?
		if [[ ${ret} -eq 1 ]]; then
			# So far stack configuration is valid (stack_manageable)
			# And the current slot is empty: valid configuration
			last=$((i-1))
			break
		fi
	done
	[[ ${last} -ge ${BIDX} ]] || return
	slot_show ${BIDX} ${last}
}

function _slot_get_eeprom() {
	local slot=${1}
	local EEPROM_DEV="${DUMMY_PATH}"

	if [[ ${slot} -le ${EIDX} && ${slot} -ge ${BIDX} ]]; then
		EEPROM_DEV=$(readlink -f ${BPE_HOME}/${STACK_SLOTS[${slot}]}/${BPE_W1}/${BPE_W1_EEPROM})
	fi
	echo "${EEPROM_DEV}"
}

function slot_dump() {
	local fslot=${1:-${BIDX}}	# From slot
	local tslot=${2:-${EIDX}}	# To slot
	local slot_list=$(seq ${fslot} ${tslot} | xargs -x)
	local EEPROM_DEV=

	slot_probe ${fslot} ${tslot} 0 # Do not be verbose

	for i in ${slot_list}; do
		EEPROM_DEV="$(_slot_get_eeprom ${i})"
		if [[ "${DUMMY_PATH}" == "${EEPROM_DEV}" || ! -f ${EEPROM_DEV} ]]; then
			# Empty slot
			printf "\n"
			echo "Virtual Slot ${STACK_SLOTS[${i}]} is not populated (empty)"
			printf "\n\n"
			continue
		fi
		# Populated slot, dump EEPROM
		printf "\n"
		echo "Virtual Slot ${STACK_SLOTS[${i}]}: EEPROM raw data:"
		printf "\n"
		hexdump -C ${EEPROM_DEV}
		printf "\n"
		echo "EEPROM Info:"
		echo " Layout Version       0x$(eeprom_get_layout_version ${EEPROM_DEV})"
		echo "Product Info:"
		echo " Revision:            $(eeprom_print_board_revision ${EEPROM_DEV})"
		echo " Resource Map:        0x$(eeprom_print_res_map 1 ${EEPROM_DEV})"
		echo " IFM ID:              0x$(eeprom_print_ifm_id 1 ${EEPROM_DEV})"
		EEPROM_SERIAL=""; eeprom_get_serial_number ${DEFAULT_PAGE_NUM} ${EEPROM_DEV}
		echo " Serial Number:       ${EEPROM_SERIAL}"
		if [[ "${STACK_IFM[${i}]}" == "WB" ]] ; then
			eeprom_get_mac_address "first" ${EEPROM_DEV} ${DEFAULT_PAGE_NUM}
			echo " 1st MAC:             ${ETH_MAC}"
			eeprom_get_mac_address "second" ${EEPROM_DEV} ${DEFAULT_PAGE_NUM}
			echo " 2nd MAC:             ${ETH_MAC}"
		fi
		echo " Product Name:        $(eeprom_print_board_name ${EEPROM_DEV})"
		echo " Product Options:     $(eeprom_print_prod_opts ${EEPROM_DEV})"
		printf "\n\n"
	done
}

function do_slot() {
	local SLOT=
	if [[ ${1} != "probe" ]] ; then
		stack_walkthru_backplane
		slot_show
	fi
	PS3="Select Virtual Slot: "
	select s in ${STACK_SLOTS[@]:${BIDX}:${EIDX}} "<-"; do
		case ${s} in
		"<-")
			return 0
			;;
		'')
			echo Select a correct Slot from the list >&2
			continue
			;;
		*)
			SLOT=${STACK_SLOTS2IDX[${s}]}
			break
			;;
		esac
	done
	command -v slot_${1} &>/dev/null && (slot_${1} ${SLOT} ${SLOT} || true) || do_dummy "slot_${1}"
}

function stack_info_backplane() {
	echo ""
	LC_CTYPE=C tree --noreport ${BPE_HOME}
	echo ""
}

function stack_info_frontplane() {
	[[ -n ${1} ]] && echo "${1}"
	echo ""
	LC_CTYPE=C tree --noreport ${FPE_HOME}
	echo ""
}

function stack_info() {
	local info=
	PS3="Select Info to be shown: "
	select t in "backplane" "frontplane" "<-"; do
		case ${t} in
		"<-")
			return 0
			;;
		'')
			echo Select a correct IFM Type from the list >&2
			continue
			;;
		*)
			info="${t}"
			break
			;;
		esac
	done
	command -v stack_info_${info} &>/dev/null && (stack_info_${info} || true) || do_dummy "stack_info_${info}"
}

#############################################################################
# stack_manage sub-menu wrapper
#############################################################################
function stack_manage() {
	PS3="Select Action: "
	select t in "Validate Configuration" "Grant Access" "<-"; do
		case ${t} in
		"<-")
			return 0
			;;
		'')
			echo Select a correct Action from the list >&2
			continue
			;;
		"Validate Configuration")
			stack_manage_config
			if [[ $? -eq 0 ]] ; then
				cmd_ok
				echo "Use 'Manage Stack -> Grant Access' Menu for getting access"
			else
				cmd_sos
				return 1
			fi
			break
			;;
		"Grant Access")
			stack_manage_access
			break
			;;
		esac
	done
}

#############################################################################
# Wrapper for "stack" cmd's
#############################################################################
function do_stack() {
	command -v stack_${1} &>/dev/null && (stack_${1} || true) || do_dummy "stack_${1}"
}

### Main

# redirect console log to file
LOG_FILE_NAME=${LOG_FILE_NAME:-${LOGS_HOME}/${IOTDIN}.stack.log.$(date +${TIMESTAMP_FORMAT})}
mkdir -p ${LOGS_HOME}
#exec &> >( tee  ${LOG_FILE_NAME} )

opt=${1:-"source"}
param=${2:-}

case ${opt} in
	"stack")
		do_stack ${param}
		;;
	"slot")
		do_slot ${param}
		;;
	"config")
		# Ad-hoc option for automated service
		stack_walkthru_backplane > ${LOG_FILE_NAME}
		stack_manage_config ${param} >> ${LOG_FILE_NAME}
		if [[ $? -eq 0 ]] ; then
			cmd_ok
			ifm_accounting_reset
			stack_manage_access >> ${LOG_FILE_NAME}
			stack_info_frontplane "Stack Access Info:" >> ${LOG_FILE_NAME}
		else
			cmd_sos
			exit 1
		fi
		;;
	"source")
		# Dummy option - applied when file is sourced by external script for further usage
		;;
	*)
		do_dummy $@
		;;
esac
