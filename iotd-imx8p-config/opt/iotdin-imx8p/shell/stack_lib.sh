#! /bin/bash

# Stack Lib
. ${IOTDIN_LIB_HOME}/ifm.inc
. ${IOTDIN_LIB_HOME}/stack_lib.inc
. ${IOTDIN_LIB_HOME}/resources.inc

function is_ifm_accessable() {
	# Slot index
	local slot=${1}
	local ret=0
	# Validate slot index
	if [[ ${slot} -gt ${EIDX} || ${slot} -lt ${BIDX} ]]; then
    	echo ${ret}
    	return 1;
	fi

	local ifm_type=${STACK_IFM[${slot}]}
	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# recalculate resources and decide
		if [[ "${ifm_type}" == "WB" ]] ; then
			# IFM-WB is accessable only when isntalled into the 1-st slot
			if [[ ${slot} -eq ${BIDX} ]] ; then
				ret=1
			fi
			echo ${ret}
			return
		fi
		
		if [[ "${ifm_type}" == "RS"* ]] ; then
			# RS232 and RS485 share same resources
			ifm_type="RSx"
		fi
		declare -n ifm_arr=IFM_ARR_${ifm_type}
		declare -n ifm_limit=IFM_LIMIT_${ifm_type}
		if [[ "${ifm_type}" == "RSx" ]] ; then
			ifm_limit=$(( ifm_limit - ${#IFM_ARR_WB[@]} ))
		fi
		local ifm_num=${#ifm_arr[@]}
		
		if [[ ${ifm_num} -lt ${ifm_limit}  ]]; then
			ret=1
		fi
	fi

	echo ${ret}
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
		if [[ "${t}" == "RS"* ]] ; then
			# RS232 and RS485 share same resources
			t="RSx"
		fi
		declare -n ifm_arr=IFM_ARR_${t}
		#echo "${t}: ifm_arr='${ifm_arr[@]}'"
		unset ifm_arr
	done
}

function ifm_accounting_inc() {
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;

	local ifm_type=${STACK_IFM[${slot}]}
	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# recalculate resources and decide
		if [[ "${ifm_type}" == "RS"* ]] ; then
			# RS232 and RS485 share same resources
			ifm_type="RSx"
		fi
		declare -n ifm_arr=IFM_ARR_${ifm_type}
		declare -n ifm_limit=IFM_LIMIT_${ifm_type}
		local idx=${#ifm_arr[@]}
		if [[ ${idx} -lt ${ifm_limit}  ]]; then
			ifm_arr[${idx}]=${slot}
			return 0
		fi
	fi

	return 1
}

function ifm_grant_access() {
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;

	local ifm_type=${STACK_IFM[${slot}]}

	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# recalculate resources and decide
		if [[ "${ifm_type}" == "RS"* ]] ; then
			# RS232 and RS485 share same resources
			ifm_type="RSx"		
		fi
		declare -n ifm_arr=IFM_ARR_${ifm_type}
		local ifm_num=${#ifm_arr[@]}
		local access_home=${FPE_HOME}/${STACK_SLOTS[${slot}]}/${FPE_ACCESS}

		case ${ifm_type} in
			"RSx")
				# Because of USB bus shifting
				ifm_num=$(( ifm_num + ${#IFM_ARR_WB[@]} ))
				for p in {0..3}; do
					t=${TTY_DEV_HOME}/${TTY_DEV_PTRN}_$((ifm_num-1))_${p}
					if [[ -L ${t} && -c $(readlink -f ${t}) ]]; then
						ln -s ${t} ${access_home}/${ACCESS_TTY}${p}
						# alternative symbolic link style:
						#ln -s ${t} ${access_home}/${ACCESS_TTY}_${STACK_SLOTS[${slot}]}_${STACK_IFM[${slot}]}_${p}
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
					wlan=$(ls ${WIFI_DEV_HOME})
					[[ -L ${WIFI_HOME}/${wlan} ]] && ln -s ${WIFI_HOME}/${wlan} ${access_home}/${ACCESS_WLAN}
				fi
				if [[ -d ${BT_DEV_HOME} ]]; then
					bt=$(ls ${BT_DEV_HOME})
					[[ -L ${BT_HOME}/${bt} ]] && ln -s ${BT_HOME}/${bt} ${access_home}/${ACCESS_BT}
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
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return 1;
	if [[ $(is_ifm_accessable ${slot}) -eq 0 ]]; then
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
	local ret=0
	# Validate slot index
	if [[ ${slot} -gt ${EIDX} || ${slot} -lt ${BIDX} ]]; then
		echo ${ret}
		return 1;
	fi

	# Probe the slot once again - for being...
	slot_probe ${slot} ${slot} 0 # Do not be verbose

	local ifm_type=${STACK_IFM[${slot}]}
	# Known IFM type
	if [[ "${IFM_TYPE_ND}" == "${ifm_type}" ]]; then
		ret=1
	fi

	echo ${ret}
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
		#ln -s ${DUMMY_PATH} ${w1_dir}/${BPE_W1_BM}
		ln -s ${DUMMY_PATH} ${w1_dir}/${BPE_W1_EEPROM}
	else
		### w1 bus master
		#ln -s ${W1_BUS}/w1_bus_master${slot} ${w1_dir}/${BPE_W1_BM}
		### w1 eeprom
		#ln -s $(readlink -f ${w1_dir}/${BPE_W1_BM})/${STACK_W1_EEPROM[${slot}]}/eeprom ${w1_dir}/${BPE_W1_EEPROM}
		ln -s ${W1_BUS}/w1_bus_master${slot}/${STACK_W1_EEPROM[${slot}]}/eeprom ${w1_dir}/${BPE_W1_EEPROM}
	fi

	## Create and populate resource info
	[[ ${STACK_ACCOUNT_RESOURCES} -eq 1 ]] || return 0
	local res_dir=${slot_home}/${BPE_RES}
	rm -rf ${res_dir}
	mkdir -p ${res_dir} #/${BPE_RES_ACQ} ${res_dir}/${BPE_RES_IN} ${res_dir}/${BPE_RES_OUT}
	touch ${res_dir}/${BPE_RES_ACQ} ${res_dir}/${BPE_RES_IN} ${res_dir}/${BPE_RES_OUT}
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

	for i in ${slot_list}; do
		local slot_home=${BPE_HOME}/${STACK_SLOTS[${i}]}
		if [[ ! -d ${slot_home} ]]; then
			slot_probe ${i} ${i} 0 # Do not be verbose
		fi
		ifm_type=$(ls ${slot_home} | grep "${BPE_IFM}\.")
		STACK_IFM[${i}]="${ifm_type##*.}"
		if [[ $(is_ifm_accessable ${i}) -eq 1 ]]; then
			ifm_accounting_inc ${i}
		elif [[ $(is_slot_empty ${i}) -eq 1 ]]; then
			# So far stack configuration is valid (stack_manageable)
			# And the current slot is empty: valid configuration
			last_valid=$((i-1))
			for s in $(seq ${i} ${EIDX} | xargs -x) ; do
				ifm_cleanup ${s}
			done
			break
		else
			#cmd_sos
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
				case ${STACK_IFM[${i}]} in
					"WB")
						echo "IFM-WB: can only be installed in virtual slot  ${STACK_SLOTS[${BIDX}]}"
						;;
					"ADC8")
						echo "IFM-${STACK_IFM[${i}]}: there can be up-to ${IFM_LIMIT_ADC8} module(s)"
						;;
					"DI8O8")
						echo "IFM-${STACK_IFM[${i}]}: there can be up-to ${IFM_LIMIT_DI8O8} module(s)"
						;;
					"RS232" | "RS485")
						echo "IFM-${STACK_IFM[${i}]}: there can be up-to ${IFM_LIMIT_RSx} (in total) modules of types IFM-<WB|RS232|RS485>"
						;;
					"${IFM_TYPE_INV}")
						echo "Populate the IFM Stack with well-defined IFMs only!"
						echo "Refer to the Stacking Rules for more info."
						;;
				esac
				printf "%s\n\n" ${cutline}
			fi
			return 1
		fi
	done
	#cmd_ok
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
