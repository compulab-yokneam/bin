#! /bin/bash

# Stack Lib
. ${IOTDIN_LIB_HOME}/ifm.inc
. ${IOTDIN_LIB_HOME}/stack_lib.inc
. ${IOTDIN_LIB_HOME}/resources.inc

export LIMITED_RES=
function ifm_check_limit() {
	# Slot index
	local ifm_res_type=${1}

	LIMITED_RES=
	[[ "${!IFM_RES_LIMIT[@]}" =~ "${ifm_res_type}" ]] || return ${ERR_INVAL}

	declare -n ifm_arr=IFM_ARR_${ifm_res_type}
	local ifm_limit=${IFM_RES_LIMIT[${ifm_res_type}]}
	local ifm_num=${#ifm_arr[@]}

	if [[ ${ifm_num} -lt ${ifm_limit}  ]]; then
		return ${RET_OK}
	fi

	#return ${err_limit}
	LIMITED_RES=${ifm_res_type}
	return ${ERR_LIMIT_RES}
}

function is_ifm_accessable_PCIE() {
	# Slot index
	local slot=${1}

	# PCIe based IFM-<WB|NVME|...> is accessable only when installed into the 1-st slot
	if [[ ${slot} -ne ${BIDX} ]] ; then
		return ${ERR_PCIE_SLOT}
	fi

	# Check PCIE resources although not a necessary
	ifm_check_limit PCIE
	return $?
}

function is_ifm_accessable_USB() {
	ifm_check_limit USB
	return $?
}

function is_ifm_accessable_I2C5_META() {
	ifm_check_limit I2C5_META
	return $?
}

function is_ifm_accessable_I2C6() {
	ifm_check_limit I2C6
	return $?
}

function is_ifm_accessable_GPIO_GR2() {
	ifm_check_limit GPIO_GR2
	return $?
}

function is_ifm_accessable_SPI() {
	ifm_check_limit SPI
	return $?
}

function is_ifm_accessable() {
	# Slot index
	local slot=${1}
	local ret=${RET_OK}
	# Validate slot index
	if [[ ${slot} -gt ${EIDX} || ${slot} -lt ${BIDX} ]]; then
		return ${ERR_SLOT_NUM}
	fi

	local ifm_type=${STACK_IFM[${slot}]}
	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# recalculate resources and decide
		declare -n res_arr=IFM_RES_${ifm_type}
		for r in ${res_arr[@]} ; do
			is_ifm_accessable_${r} ${slot}
			ret=$?
			[[ ${ret} -eq ${RET_OK} ]] || return ${ret}
		done
		return ${ret}
	fi

	return ${ERR_INVAL}
}

function ifm_cleanup() {
	# Slot index
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return ${ERR_SLOT_NUM}

	local ifm_home=${FPE_HOME}/${STACK_SLOTS[${slot}]}
	rm -rf ${ifm_home}
}

function ifm_accounting_reset() {
	for r in ${!IFM_RES_LIMIT[@]} ; do
		declare -n ifm_arr=IFM_ARR_${r}
		#echo "${r}: ifm_arr='${ifm_arr[@]}'"
		unset ifm_arr
	done
}

function ifm_accounting_inc() {
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return ${ERR_SLOT_NUM}

	local ifm_type=${STACK_IFM[${slot}]}
	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# recalculate resources and decide
		declare -n res_arr=IFM_RES_${ifm_type}
		for r in ${res_arr[@]} ; do
			declare -n ifm_arr=IFM_ARR_${r}
			local ifm_limit=${IFM_RES_LIMIT[${r}]}
			local idx=${#ifm_arr[@]}
			if [[ ${idx} -ge ${ifm_limit}  ]]; then
				declare -n err_limit=ERR_LIMIT_${r}
				return ${err_limit}
			fi
			ifm_arr[${idx}]=${slot}
		done
	fi
	return ${RET_OK}
}

function ifm_dio_irq_set() {
	local bus=${1}
	local addr=${2}
	local state=${3:-${IRQ_EN}}
	local regval=ff

	[[ -d ${I2C_BUS}/${bus}-00${addr}  ]] || return ${RET_OK} # I2C device not found
	if [[ ${state} -eq ${IRQ_DIS} ]] ; then
		regval=0
	fi
	command -v i2cset &>/dev/null || return ${RET_OK} # i2cset utility not found
	for reg in ${IER} ${REIR} ${FEIR} ; do
		 i2cset -f -y 0x${bus} 0x${addr} 0x${reg} 0x${regval} &>/dev/null && true || true
	done
}

function ifm_grant_access_DIxOx() {
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return ${ERR_SLOT_NUM};

	local ifm_type=${STACK_IFM[${slot}]}
	if [[ "${IFM_RES_I2C5_META[@]}" =~ "${ifm_type}" ]]; then
		# Because of USB bus shifting
		for (( i=0 ; i<${#IFM_ARR_I2C5_META[@]} ; i++ )) ; do
			if [[ "${IFM_ARR_I2C5_META[${i}]}" -eq "${slot}" ]] ; then
				local access_home=${FPE_HOME}/${STACK_SLOTS[${slot}]}/${FPE_ACCESS}
				# Determine a number on IN and OUT pins
				local p_ib=${PIN_IB}
				local p_ie=0
				local p_ob=${PIN_OB}
				local p_oe=0
				case ${ifm_type} in
					"DI8O8")
						p_ie=$((p_ib + ${DI8O8_INUM} - 1))
						p_oe=$((p_ob + ${DI8O8_ONUM} - 1))
						;;
					"CAN")
						p_ie=$((p_ib + ${CAN_DI4O4_INUM} - 1))
						p_oe=$((p_ob + ${CAN_DI4O4_ONUM} - 1))
						;;
					*)
						;;
				esac
				local addr=$((DIxOx_GPIOCHIP_BASEADDR + i))
				local bus=${DIxOx_GPIOCHIP_BUS}
				local chip=$(basename ${I2C_BUS}/${bus}-00${addr}/gpiochip*)
				[[ -c ${GPIO_DEV_HOME}/${chip} ]] || return ${RET_OK} ;
				ln -s ${GPIO_DEV_HOME}/${chip} ${access_home}/${ACCESS_GPIO}
				local chipnum=${chip#"gpiochip"}
				touch ${access_home}/${ACCESS_DI}
				if [[ ${p_ib} -le ${p_ie} ]] ; then
					printf "${chipnum}%.0s " $(seq ${p_ib} ${p_ie}) | xargs > ${access_home}/${ACCESS_DI}
					printf "%s " $(seq ${p_ib} ${p_ie}) | xargs >> ${access_home}/${ACCESS_DI}
				fi
				touch ${access_home}/${ACCESS_DO}
				if [[ ${p_ob} -le ${p_oe} ]] ; then				
					printf "${chipnum}%.0s " $(seq ${p_ob} ${p_oe}) | xargs > ${access_home}/${ACCESS_DO}
					printf "%s " $(seq ${p_ob} ${p_oe}) | xargs >> ${access_home}/${ACCESS_DO}
				fi
				ifm_dio_irq_set ${bus} ${addr}
			fi
		done
	fi
	return ${RET_OK}
}

function ifm_grant_access() {
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return ${ERR_SLOT_NUM}

	local ifm_type=${STACK_IFM[${slot}]}

	# Known IFM type
	if [[ "${IFM_TYPE[@]}" =~ "${ifm_type}" ]]; then
		# Create access files for populated slots
		local access_home=${FPE_HOME}/${STACK_SLOTS[${slot}]}/${FPE_ACCESS}
		case ${ifm_type} in
			"RS232"|"RS485")
				# Create access files for 4x TTY devices
				for (( i=0 ; i<${#IFM_ARR_USB[@]} ; i++ )) ; do
					if [[ "${IFM_ARR_USB[${i}]}" -eq "${slot}" ]] ; then
						for p in {0..3}; do
							t=${TTY_DEV_HOME}/${TTY_DEV_RSx_PTRN}_${i}_${p}
							if [[ -L ${t} && -c $(readlink -f ${t}) ]]; then
								ln -s ${t} ${access_home}/${ACCESS_TTY}${p}
							fi
						done
						break
					fi
				done
				;;
			"DI8O8")
				# Create access files for DI8O8
				ifm_grant_access_DIxOx ${slot}
				;;
			"CAN")
				# Create access files for 2x CAN interfaces
				modprobe mcp251xfd > /dev/null 2>&1
				sleep 1
				# Create two symbolic links to can interfaces
				for i in {0..1} ; do
					local dev_home=${CAN_DEV_PREFIX}${i}${CAN_DEV_SUFFIX}
					if [[ -d ${dev_home} ]]; then
						local can=$(ls ${dev_home})
						[[ -L ${CAN_HOME}/${can} ]] && ln -s ${CAN_HOME}/${can} ${access_home}/${ACCESS_CAN}${i}
					fi
				done
				# Create access files for DI4O4 sybsystem
				ifm_grant_access_DIxOx ${slot}
				;;
			"ADC8")
				# Create access files for 2x IIO devices
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
				# Create access files for WLAN and BT devices
				modprobe iwlwifi > /dev/null 2>&1
				modprobe btusb > /dev/null 2>&1
				sleep 1
				if [[ -d ${WIFI_DEV_HOME} ]]; then
					local wlan=$(ls ${WIFI_DEV_HOME})
					[[ -L ${WIFI_HOME}/${wlan} ]] && ln -s ${WIFI_HOME}/${wlan} ${access_home}/${ACCESS_WLAN}
				fi
				if [[ -d ${BT_DEV_HOME} ]]; then
					local idvendor=$(cat ${BT_DEVID_HOME}/${IDVENDOR})
					local idprod=$(cat ${BT_DEVID_HOME}/${IDPROD})
					if [[ "${idvendor,,}" == "${BT_USB_IDVENDOR,,}" && "${idprod,,}" == "${BT_USB_IDPROD,,}" ]] ; then
						local bt=$(ls ${BT_DEV_HOME})
						[[ -L ${BT_HOME}/${bt} ]] && ln -s ${BT_HOME}/${bt} ${access_home}/${ACCESS_BT}
					fi
				fi
				;;
			"NVME")
				# Create access files for block device (storage)
				local nvme=${NVME_DEV_HOME}/${NVME_DEV}
				if [[ -b ${nvme} ]]; then
					ln -s ${nvme} ${access_home}/${ACCESS_NVME}
				fi
				;;
			"NETX100")
				# Create access files for UIO device
				modprobe uio_netx > /dev/null 2>&1
				sleep 1
				if [[ -d ${NETX100_DEV_HOME} ]]; then
					local uio=$(ls ${NETX100_DEV_HOME})
					[[ -L ${UIO_HOME}/${uio} ]] && ln -s ${UIO_HOME}/${uio} ${access_home}/${ACCESS_UIO}
				fi
				;;
			"MESH")
				for (( i=0 ; i<${#IFM_ARR_USB[@]} ; i++ )) ; do
					if [[ "${IFM_ARR_USB[${i}]}" -eq "${slot}" ]] ; then
						# Get idVendor & idProduct
						local devid_home=${MESH_DEV_PREFIX}$((i+1))
						local idvendor=$(cat ${devid_home}/${IDVENDOR})
						local idprod=$(cat ${devid_home}/${IDPROD})
						# Detect MESH subtype (e.g. NORD, SILAB, etc.)
						EEPROM_DEV="$(_slot_get_eeprom ${slot})"
						local IFM_CFG=$(eeprom_print_prod_opts ${EEPROM_DEV})
						[[ -n ${IFM_CFG} ]] || continue
						local mtype=${IFM_CFG#W}
						rm ${access_home}/${FPE_IFM_SUBTYPE}.* > /dev/null 2>&1
						case "${mtype}" in
							"NORD")
								# Create access files for BT devices
								modprobe btusb > /dev/null 2>&1
								sleep 1
								touch ${access_home}/${FPE_IFM_SUBTYPE}.${mtype}
								[[ "${idvendor,,}" == "${MESH_USB_IDVENDOR_NORD,,}" ]] || break
								if  [[ "${idprod,,}" == "${MESH_USB_IDPROD_NORD_BT,,}" ]] ; then
									# BT device
									local dev_home=${devid_home}${MESH_BT_DEV_SUFFIX}
									if [[ -d ${dev_home} ]]; then
										local mesh=$(ls ${dev_home})
										[[ -L ${MESH_BT_HOME}/${mesh} ]] && ln -s ${MESH_BT_HOME}/${mesh} ${access_home}/${ACCESS_MESH_NORD_BT}
									fi
									break
								fi
								if  [[ "${idprod,,}" == "${MESH_USB_IDPROD_NORD,,}" ]] ; then
									# TTY device
									local tty=${TTY_DEV_HOME}/${TTY_DEV_MESH_PTRN}_${i}
									if [[ -L ${tty} && -c $(readlink -f ${tty}) ]] ; then
										ln -s ${tty} ${access_home}/${ACCESS_MESH_NORD}
									else
										# Alternative way
										local dev_home=$(readlink -e ${devid_home}${MESH_TTY_DEV_SUFFIX})
										if [[ -d ${dev_home} ]]; then
											tty=${TTY_DEV_HOME}/$(ls ${dev_home})
											[[ -c ${tty} ]] && ln -s ${tty} ${access_home}/${ACCESS_MESH_NORD}
										fi
									fi
									break
								fi
								;;
							"SILAB")
								# Create access files for tty device
								modprobe cp210x > /dev/null 2>&1
								sleep 1
								touch ${access_home}/${FPE_IFM_SUBTYPE}.${mtype}
								if [[ "${idvendor,,}" == "${MESH_USB_IDVENDOR_SILAB,,}" && "${idprod,,}" == "${MESH_USB_IDPROD_SILAB,,}" ]] ; then
									local tty=${TTY_DEV_HOME}/${TTY_DEV_MESH_PTRN}_${i}
									if [[ -L ${tty} && -c $(readlink -f ${tty}) ]]; then
										ln -s ${tty} ${access_home}/${ACCESS_MESH_SILAB}
									else
										# Alternative way
										local dev_home=$(readlink -e ${devid_home}${MESH_TTYUSB_DEV_SUFFIX})
										if [[ -d ${dev_home} ]]; then
											tty=${TTY_DEV_HOME}/$(basename ${dev_home})
											[[ -c ${tty} ]] && ln -s ${tty} ${access_home}/${ACCESS_MESH_SILAB}
										fi
									fi
									# Create access files for gpio chip
									local dev_home=$(readlink -e ${MESH_DEV_PREFIX}$((i+1))${MESH_GPIO_DEV_SUFFIX})
									local chip=${GPIO_DEV_HOME}/$(basename ${dev_home})
									if [[ -c ${chip} ]] ; then
										ln -s ${chip} ${access_home}/${ACCESS_GPIO}
									fi
								fi
								;;
							*)
								;;
						esac
						break
					fi
				done
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
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return ${ERR_SLOT_NUM};
	is_ifm_accessable ${slot} && ret=$? || ret=$?
	if [[ ${ret} -ne ${RET_OK} ]]; then
		# remove all slots starting from this one
		for s in $(seq ${slot} ${EIDX}) ; do
			ifm_cleanup ${s}
		done
		return 1
	fi
	local ifm_type=${STACK_IFM[${slot}]}

	ifm_accounting_inc ${slot}
	
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
	ifm_grant_access ${slot}
}

function _slot_get_eeprom() {
	local slot=${1}
	local EEPROM_DEV="${DUMMY_PATH}"

	if [[ ${slot} -le ${EIDX} && ${slot} -ge ${BIDX} ]]; then
		EEPROM_DEV=$(readlink -f ${BPE_HOME}/${STACK_SLOTS[${slot}]}/${BPE_W1}/${BPE_W1_EEPROM})
	fi
	echo "${EEPROM_DEV}"
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
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return ${ERR_SLOT_NUM};

	local slot_home=${BPE_HOME}/${STACK_SLOTS[${slot}]}
	rm -rf ${slot_home}
	mkdir -p ${slot_home}
}

function slot_add() {
	# Slot index
	local slot=${1}
	# Validate slot index
	[[ ${slot} -lt ${EIDX} || ${slot} -gt ${BIDX} ]] || return ${ERR_SLOT_NUM};

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
	local slot_list=$(seq ${fslot} ${tslot})
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
	local slot_list=$(seq ${fslot} ${tslot})
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
	local slot_list=$(seq ${fslot} ${tslot})
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
	local slot_list=$(seq ${fslot} ${tslot})
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
				for s in $(seq ${i} ${EIDX}) ; do
					ifm_cleanup ${s}
				done
				break
			else
				# Either invalid or non-manageable IFM is found in the current slot
				for s in $(seq ${BIDX} ${EIDX}) ; do
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
						"${ERR_INVAL}")
							echo "Populate the IFM Stack with well-defined IFMs only!"
							echo "Refer to the Stacking Rules for more info."
							;;
						"${ERR_LIMIT_RES}")
							res_type=${LIMITED_RES}
							if [[ "${!IFM_RES_LIMIT[@]}" =~ "${ifm_res_type}" ]] ; then
								declare -n res_arr=IFM_RES_${res_type}
								printf -v list "%s|" ${res_arr[@]}
								echo "IFM-${ifm_type}: there can be up-to ${IFM_RES_LIMIT[${res_type}]} (in total) module(s) of type(s) IFM-<${list%?}>"
							else
								echo "Unexpected error: refer to the Stacking Rules, and double check the Stack. Try again later..."
							fi
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
