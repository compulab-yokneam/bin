#! /bin/bash

# Stack Lib
. ${IOTDIN_LIB_HOME}/ifm.inc
. ${IOTDIN_LIB_HOME}/stack_lib.inc
. ${IOTDIN_LIB_HOME}/resources.inc

function is_ifm_accessable() {
	# Slot index
	local slot=${1}
	local ret=
	# Validate slot index
	if [[ ${slot} -gt ${EIDX} || ${slot} -lt ${BIDX} ]]; then
		return ${ERR_SLOT_NUM}
	fi

	local ifm_type=${STACK_IFM[${slot}]}
	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# recalculate resources and decide
		## Is it PCIe device?
		if [[ "${IFM_RES_PCIE[@]}" =~ "${ifm_type}" ]] ; then
			# PCIe based IFM-<WB|NVME|...> is accessable only when installed into the 1-st slot
			if [[ ${slot} -ne ${BIDX} ]] ; then
				return ${ERR_PCIE_SLOT}
			fi
			[[ "${IFM_RES_USB[@]}" =~ "${ifm_type}" ]] || return ${RET_OK}
		fi

		## Is it USB device?
		if [[ "${IFM_RES_USB[@]}" =~ "${ifm_type}" ]] ; then
			ifm_type="USB"
		fi
		## USB or other type
		declare -n ifm_arr=IFM_ARR_${ifm_type}
		declare -n ifm_limit=IFM_LIMIT_${ifm_type}
		local ifm_num=${#ifm_arr[@]}
		
		if [[ ${ifm_num} -lt ${ifm_limit}  ]]; then
			return ${RET_OK}
		fi
		[[ "${ifm_type}" -eq "USB" ]] && ret=${ERR_LIMIT_USB} || ret=${ERR_LIMIT}
		return ${ret}
	fi

	return ${ERR_INVAL}
}

function ifm_cleanup() {
	# Slot index
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;

	local ifm_home=${FPE_HOME}/${STACK_SLOTS[${slot}]}
	rm -rf ${ifm_home}
}

function ifm_accounting_reset() {
	for t in ${IFM_TYPE[@]} ; do
		[[ "${IFM_RES_PCIE[@]}" =~ "${t}" ]] && continue
		[[ "${IFM_RES_USB[@]}" =~ "${t}" ]] && continue

		declare -n ifm_arr=IFM_ARR_${t}
		#echo "${t}: ifm_arr='${ifm_arr[@]}'"
		unset ifm_arr
	done
	unset IFM_ARR_PCIE
	unset IFM_ARR_USB
}

function ifm_accounting_inc() {
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;

	local ifm_type=${STACK_IFM[${slot}]}
	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# recalculate resources and decide
		if [[ "${IFM_RES_PCIE[@]}" =~ "${ifm_type}" ]] ; then
			idx=${#IFM_ARR_PCIE[@]}
			if [[ ${idx} -ge ${IFM_LIMIT_PCIE} ]] ; then
				return 1
			fi
			IFM_ARR_PCIE[${idx}]=${slot}
			[[ "${IFM_RES_USB[@]}" =~ "${ifm_type}" ]] || return 0
		fi
		if [[ "${IFM_RES_USB[@]}" =~ "${ifm_type}" ]] ; then
			idx=${#IFM_ARR_USB[@]}
			if [[ ${idx} -ge ${IFM_LIMIT_USB} ]] ; then
				return 1
			fi
			IFM_ARR_USB[${idx}]=${slot}
			return 0
		fi

		declare -n ifm_arr=IFM_ARR_${ifm_type}
		declare -n ifm_limit=IFM_LIMIT_${ifm_type}
		local idx=${#ifm_arr[@]}
		if [[ ${idx} -ge ${ifm_limit}  ]]; then
			return 1
		fi
		ifm_arr[${idx}]=${slot}
	fi

	return 0
}

function ifm_grant_access() {
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;

	local ifm_type=${STACK_IFM[${slot}]}

	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# recalculate resources and decide
		declare -n ifm_arr=IFM_ARR_${ifm_type}
		local ifm_num=${#ifm_arr[@]}
		local access_home=${FPE_HOME}/${STACK_SLOTS[${slot}]}/${FPE_ACCESS}

		case ${ifm_type} in
			"RS232"|"RS485")
				# Because of USB bus shifting
				for (( i=0 ; i<${#IFM_ARR_USB[@]} ; i++ )) ; do
					if [[ "${IFM_ARR_USB[${i}]}" -eq "${slot}" ]] ; then
						for p in {0..3}; do
							t=${TTY_DEV_HOME}/${TTY_DEV_PTRN}_${i}_${p}
							if [[ -L ${t} && -c $(readlink -f ${t}) ]]; then
								ln -s ${t} ${access_home}/${ACCESS_TTY}${p}
							fi
						done
						break
					fi
				done
				;;
			"DI8O8")
				local addr=$((ifm_num - 1 + DI8O8_GPIOCHIP_BASEADDR))
				local bus=${DI8O8_GPIOCHIP_BUS}
				for f in ${I2C_BUS}/${bus}-00${addr}/* ; do
					if [[ "$(basename ${f})" == "gpiochip"* && -c ${GPIO_DEV_HOME}/$(basename ${f}) ]]; then
						local chip=$(basename ${f})
						ln -s ${GPIO_DEV_HOME}/${chip} ${access_home}/${ACCESS_GPIO}
						local chipnum=${chip#"gpiochip"}
						printf "${chipnum}%.0s " $(seq ${PIN_IB} ${PIN_IE}) | xargs > ${access_home}/${ACCESS_DI}
						printf "%s " $(seq ${PIN_IB} ${PIN_IE} | xargs -x) | xargs >> ${access_home}/${ACCESS_DI}
						printf "${chipnum}%.0s " $(seq ${PIN_OB} ${PIN_OE}) | xargs > ${access_home}/${ACCESS_DO}
						printf "%s " $(seq ${PIN_OB} ${PIN_OE} | xargs -x) | xargs >> ${access_home}/${ACCESS_DO}
						break
					fi
				done
				;;		
			"ADC8")
				modprobe ti_ads1015 > /dev/null 2>&1
				sleep 1
				# Create two symbolic links to iio devices
				for i in {0..1} ; do
					if [[ -d ${IIO_BUS}/iio:device${i} ]]; then
						ln -s ${IIO_BUS}/iio:device${i} ${access_home}/${ACCESS_ADC}${i}
					fi
				done
				;;
			"WB")
				modprobe iwlwifi > /dev/null 2>&1
				modprobe btusb > /dev/null 2>&1
				sleep 1
				if [[ -d ${WIFI_DEV_HOME} ]]; then
					local wlan=$(ls ${WIFI_DEV_HOME})
					[[ -L ${WIFI_HOME}/${wlan} ]] && ln -s ${WIFI_HOME}/${wlan} ${access_home}/${ACCESS_WLAN}
				fi
				if [[ -d ${BT_DEV_HOME} ]]; then
					local bt=$(ls ${BT_DEV_HOME})
					[[ -L ${BT_HOME}/${bt} ]] && ln -s ${BT_HOME}/${bt} ${access_home}/${ACCESS_BT}
				fi
				;;
			"NVME")
				local nvme=${NVME_DEV_HOME}/${NVME_DEV}
				if [[ -b ${nvme} ]]; then
					ln -s ${nvme} ${access_home}/${ACCESS_NVME}
				fi
				;;
			"NETX100")
				modprobe uio_netx > /dev/null 2>&1
				sleep 1
				if [[ -d ${NETX100_DEV_HOME} ]]; then
					local uio=$(ls ${NETX100_DEV_HOME})
					[[ -L ${UIO_HOME}/${uio} ]] && ln -s ${uio} ${access_home}/${ACCESS_UIO}
				fi
				;;
			*)
				;;
		esac
	fi

	return 0
}

function ifm_add() {
	# Slot index
	local slot=${1}
	local ret
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;
	is_ifm_accessable ${slot} && ret=$? || ret=$?
	if [[ ${ret} -ne ${RET_OK} ]]; then
		# remove all slots starting from this one
		for s in $(seq ${slot} ${EIDX} | xargs -x) ; do
			ifm_cleanup ${s}
		done
		return 1
	fi
	local ifm_type=${STACK_IFM[${slot}]}

	ifm_accounting_inc ${slot} #|| return 1
	
	# Create IFM home directory
	local ifm_home=${FPE_HOME}/${STACK_SLOTS[${slot}]}
	rm -rf ${ifm_home} # Check if somewhat needed
	mkdir -p ${ifm_home}
	# Get slot home directory
	local slot_home=${BPE_HOME}/${STACK_SLOTS[${slot}]}

	## Specify detected IFM type 
	rm -rf ${ifm_home}/${FPE_IFM}.*
	touch ${ifm_home}/${FPE_IFM}.${ifm_type}
	## put link to backplane dir
	#ln -s ${slot_home} ${ifm_home}/$(basename ${BPE_HOME})
	# create access subdir
	mkdir -p ${ifm_home}/${FPE_ACCESS}
	# populate with access info according to IFM type
	ifm_grant_access ${slot} #|| return 1
}

function is_slot_empty() {
	# Slot index
	local slot=${1}
	# Validate slot index
	if [[ ${slot} -gt ${EIDX} || ${slot} -lt ${BIDX} ]]; then
		return ${SLOT_EMPTY};
	fi

	# Probe the slot once again - for being...
	slot_probe ${slot} ${slot} 0 # Do not be verbose

	local ifm_type=${STACK_IFM[${slot}]}
	# Known IFM type
	if [[ "${IFM_TYPE_ND}" == "${ifm_type}" ]]; then
		return ${SLOT_EMPTY}
	else
		return ${SLOT_NONEMPTY}
	fi
}

function slot_cleanup() {
	# Slot index
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;

	local slot_home=${BPE_HOME}/${STACK_SLOTS[${slot}]}
	rm -rf ${slot_home}
	mkdir -p ${slot_home}
}

function slot_add() {
	# Slot index
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;

	# IFM type
	local ifm_type=${2:-${STACK_IFM[${slot}]}}
	[[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]] || [[ "${ifm_type}" == "${IFM_TYPE_ND}" ]] || [[ "${ifm_type}" == "${IFM_TYPE_INV}" ]] || return 1;

	# Create slot home directory
	local slot_home=${BPE_HOME}/${STACK_SLOTS[${slot}]}
	rm -rf ${slot_home} # Check if somewhat needed
	mkdir -p ${slot_home}

	## Specify detected IFM type 
	rm -rf ${slot_home}/${BPE_IFM}.*
	touch ${slot_home}/${BPE_IFM}.${ifm_type}
	
	## Create and populate w1 info
	local w1_dir=${slot_home}/${BPE_W1}
	rm -rf {w1_dir}
	mkdir -p ${w1_dir}
	if [[ "${ifm_type}" == "${IFM_TYPE_ND}" ]]; then
		### w1 eeprom stub
		ln -s ${DUMMY_PATH} ${w1_dir}/${BPE_W1_EEPROM}
	else
		### w1 eeprom
		ln -s ${W1_BUS}/w1_bus_master${slot}/${STACK_W1_EEPROM[${slot}]}/eeprom ${w1_dir}/${BPE_W1_EEPROM}
	fi
}

function slot_probe() {
	local fslot=${1:-${BIDX}}	# From slot
	local tslot=${2:-${EIDX}}	# To slot
	local slot_list=$(seq ${fslot} ${tslot} | xargs -x)
	local verbose=${3:-1}
	local EEPROM_DEV=""
	local IFM_ID=""			# IFM ID ASCII string
	declare -i IFM=0		# IFM ID Hexadecimal value

	# Loop over all requested slots
	for i in ${slot_list}; do
		# Check if any slave found
		local slave_cnt=$(cat ${W1_BUS}/w1_bus_master${i}/w1_master_slave_count)
		if [[ ${slave_cnt} -eq 0 ]]; then
			# No IFM detected
			STACK_IFM[${i}]="${IFM_TYPE_ND}"
			slot_add "${i}" "${IFM_TYPE_ND}"
			continue
		fi

		# Try to detect W1 eeprom on a corresponding W1 Master bus
		local f=$(ls ${W1_BUS}/w1_bus_master${i} | grep "${W1_EEPROM_WILDCARD}")

		# Not found ...
		if [[ -z "${f}" ]]; then
			STACK_IFM[${i}]="${IFM_TYPE_ND}"
			slot_add "${i}" "${IFM_TYPE_ND}"
			continue
		fi
		
		EEPROM_DEV=${W1_BUS}/w1_bus_master${i}/${f}/eeprom
		# Detected ...
		if [[ -f ${EEPROM_DEV} ]]; then
			# Save W1 slave ID
			STACK_W1_EEPROM[${i}]="${f}"
			# Try to read IFM_ID string (may contain leading 0's)
			IFM_ID=$(eeprom_print_ifm_id 1 ${EEPROM_DEV})
			# IFM_ID field is empty => invalid IFM
			if [[ -z ${IFM_ID} ]]; then
				STACK_IFM[${i}]="${IFM_TYPE_INV}"
				slot_add "${i}" "${IFM_TYPE_INV}"
				continue
			fi
			# Convert to hexadecimal
			IFM=16#${IFM_ID}
			if [[ ${IFM} -ge ${IFM_ID_FIRST} && ${IFM} -le ${IFM_ID_LAST} ]]; then
				# Converto to ASCII w/o leading 0's
				IFM_ID=$(printf "%x" ${IFM})
				# Put into STACK array
				STACK_IFM[${i}]=${IFM_ID2TYPE[${IFM_ID}]}
				slot_add "${i}"
				continue
			else
				# IFM ID is unknown => invalid IFM
				STACK_IFM[${i}]=${IFM_TYPE_INV}
				slot_add "${i}" "${IFM_TYPE_INV}"
				continue
			fi
		fi
	done

	if [[ ${verbose} -eq 1 ]]; then
		# Display stack
		slot_show ${fslot} ${tslot} 
	fi
}

function stack_walkthru_backplane() {
	local fslot=${BIDX}	# From slot
	local tslot=${EIDX}	# To slot
	local slot_list=$(seq ${fslot} ${tslot} | xargs -x)
	local ifm_type=${IFM_TYPE_ND}

	for i in ${slot_list}; do
		local slot_home=${BPE_HOME}/${STACK_SLOTS[${i}]}
		if [[ ! -d ${slot_home} ]]; then
			slot_probe ${i} ${i} 0 # Do not be verbose
		fi
		ifm_type=$(ls ${slot_home} | grep "${BPE_IFM}\.")
		if [[ "${ifm_type##*.}" == "${IFM_TYPE_INV}" ]] ; then
			slot_probe ${i} ${i} 0 # Do not be verbose
			ifm_type=$(ls ${slot_home} | grep "${BPE_IFM}\.")
		fi
		STACK_IFM[${i}]="${ifm_type##*.}"
	done
}

#############################################################################
# Grant access
#############################################################################
function stack_manage_access() {
	local fslot=${BIDX}	# From slot
	local tslot=${EIDX}	# To slot
	local slot_list=$(seq ${fslot} ${tslot} | xargs -x)
	local ifm_type=${IFM_TYPE_ND}
	local ret=0

	for i in ${slot_list}; do
		local slot_home=${BPE_HOME}/${STACK_SLOTS[${i}]}
		if [[ ! -d ${slot_home} ]]; then
			slot_probe ${i} ${i} 0 # Do not be verbose
		fi
		ifm_type=$(ls ${slot_home} | grep "${BPE_IFM}\.")
		STACK_IFM[${i}]="${ifm_type##*.}"
		ifm_add ${i} ; ret=$?
		[[ ${ret} -eq 0 ]] || break
	done
}

#############################################################################
# Validate stack, return 0 if contains a valid and fully accessable set
# or 1 otherwise
#############################################################################
function stack_manage_config() {
	local local verbose=${1:-1}
	local fslot=${BIDX}	# From slot
	local tslot=${EIDX}	# To slot
	local slot_list=$(seq ${fslot} ${tslot} | xargs -x)
	local ifm_type=${IFM_TYPE_ND}
	local last_valid=${EIDX}
	local ret=

	for i in ${slot_list}; do
		local slot_home=${BPE_HOME}/${STACK_SLOTS[${i}]}
		if [[ ! -d ${slot_home} ]]; then
			slot_probe ${i} ${i} 0 # Do not be verbose
		fi
		ifm_type=$(ls ${slot_home} | grep "${BPE_IFM}\.")
		STACK_IFM[${i}]="${ifm_type##*.}"
		is_ifm_accessable ${i} && ret=$? || ret=$?
		if [[ ${ret} -eq ${RET_OK} ]]; then
			ifm_accounting_inc ${i}
		else
			local empty=
			is_slot_empty ${i} && empty=$? || empty=$?
			if [[ ${empty} -eq ${SLOT_EMPTY} ]]; then
				# So far stack configuration is valid (stack_manageable)
				# And the current slot is empty: valid configuration
				last_valid=$((i-1))
				for s in $(seq ${i} ${EIDX} | xargs -x) ; do
					ifm_cleanup ${s}
				done
				break
			else
				# Either invalid or non-manageable IFM is found in the current slot
				for s in $(seq ${BIDX} ${EIDX} | xargs -x) ; do
					ifm_cleanup ${s}
				done
				if [[ ${verbose} -eq 1 ]]; then
					local cutline="###############################################################"
					ifm_type=${STACK_IFM[${i}]}
					printf "\n%s\n" ${cutline}
					echo "IFM Stack misconfiguration detected!!!"
					echo "Virtual slot '${STACK_SLOTS[${i}]}' :: IFM type '${ifm_type}'"
					case ${ret} in
						"${ERR_PCIE_SLOT}")
							echo "IFM-${STACK_IFM[${i}]}: can only be installed in virtual slot ${STACK_SLOTS[${BIDX}]}"
							;;
						"${ERR_LIMIT}")
							if [[ "${IFM_RES_USB[@]}" =~ "${ifm_type}" ]] ; then
								echo "IFM-${ifm_type}: there can be up-to ${ifm_limit} module(s)"

							fi
							;;
						"${ERR_LIMIT_USB}")
							printf -v list "%s|" ${IFM_RES_USB[@]}
							echo "IFM-${ifm_type}: there can be up-to ${IFM_LIMIT_USB} (in total) modules of types IFM-<${list%?}>"
							;;
						"${ERR_INVAL}")
							echo "Populate the IFM Stack with well-defined IFMs only!"
							echo "Refer to the Stacking Rules for more info."
							;;
						*)
							echo "Unexpected error: refer to the Stacking Rules, and double check the Stack. Try again later..."
							;;
					esac
					printf "%s\n\n" ${cutline}
				fi
				return 1
			fi
		fi
	done
	if [[ ${verbose} -eq 1 ]]; then
		echo "A valid and fully accessable IFM Stack is detected"
		slot_show ${BIDX} ${last_valid}
		printf "\n"
	fi
	return 0
}

#############################################################################
# Probe and display all slots
#############################################################################
function stack_probe() {
	slot_probe
}
