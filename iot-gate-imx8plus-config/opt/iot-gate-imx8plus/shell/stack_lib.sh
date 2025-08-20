#! /bin/bash

# Stack Lib
. ${IOTG_LIB_HOME}/stack_lib.inc


LIBGPIOD_OPT=
#############################################################################
# void set_libgpiod_options() - determines libgpiod version and sets additional
# option for gpioset/gpioget utilities if required
# @gpioutil - thetarget utility (gpioset by default)
# Options are set in the LIBGPIOD_OPT
#############################################################################
function set_libgpiod_options() {
	local gpioutil=${1:-"gpioget"}
	libgpiod_version=$(${gpioutil} -v 2>/dev/null | awk '/ \(libgpiod\) v/ {print $NF}')
	if [[ ${libgpiod_version} =~ v(2\.[0-9]+\.[0-9]+) ]] ; then
		if [[ "${gpioutil}" == "gpioget" ]] ; then
			GPIOGET_OPT="--numeric" # old style output (value only)
			LIBGPIOD_OPT=${GPIOGET_OPT}
		else
			GPIOSET_OPT="--toggle 0" # return immediately
			LIBGPIOD_OPT=${GPIOSET_OPT}
		fi
		LIBGPIOD_OPT=${LIBGPIOD_OPT}" --chip"
	fi
}



function _set_usb_mux_sel() {
	local sel=${1}
	set_libgpiod_options "gpioset"
	gpioset ${LIBGPIOD_OPT} ${MUX_CHIP} ${MUX_SEL}=${sel}
	sleep 0.5
}

function usb_mux_set() {
	_set_usb_mux_sel 1
}
function usb_mux_reset() {
	_set_usb_mux_sel 0
}


#############################################################################
# int detect_m2_type() - determines EXP board type in M.2 slot
# @slot - slot name x
# A detected EXP type is set in the IE_DETECTED[x] array
#############################################################################
function detect_m2_type() {
	local slot=${1:-}
	[[ ! -z ${slot} ]] || return 1;
	local idx=${STACK_SLOTS2IDX[${slot}]}
	case ${slot} in
	"X")
		;;
	*)
		return 1;
		;;
	esac

	# Detect add-on board in M.2 connector by access a corresponding slave on I2C bus:
	# - TPM add-on board:  i2c bus 4, slave address 0x54-0x58 (24C08 EEPROM)
	# - eMMC add-on board: i2c bus 4, slave address 0x20 (PCA955 GPIO expander)
	# - M2 add-on board: i2c bus 4, slave address 0x21 (PCA955 GPIO expander)
	# - ADC add-on board:  i2c bus 4, slave address 0x48 (ADS1015 ADC)
	local m2_type="${IE_TYPE_ND}"
	for type in ${M2_ADDON_LIST[@]} ; do
		bus=${ADDON_BUS[${type}]}
		addr=${ADDON_CHIP[${type}]}
		reg=${ADDON_OFFSET[${type}]}
		local ret=
		ret=$(i2cget -f -y ${bus} ${addr} ${reg} 2> /dev/null)
		if [[ -n ${ret} ]]; then
			m2_type="${type}"
			if [ "${type}" == "${IE_EMMC}" ]; then
				# Calculate eMMC size
				local size=$(((ret & 0xf) << 4))
				export IE_EMMC_SIZE=${size}G
			fi
			break;
		fi
	done

	IE_DETECTED[${idx}]=${m2_type}
	return 0
}

#############################################################################
# int detect_ie_type() - determines IE board type for a pod with a given index
# @slot - slot name A, B, C, D, E
# A detected IE type is set in the IE_DETECTED[] array
#############################################################################
function detect_ie_type() {
	local slot=${1:-}
	[[ ! -z ${slot} ]] || return 1;
	local idx=${STACK_SLOTS2IDX[${slot}]}
	# Determine GPIO chip
	[[ -n ${POD_DET_GPIO_CHIP} ]] && POD_DET_GPIO_CHIP=$(basename ${POD_DET_GPIO_CHIP})
	[[ -c /dev/${POD_DET_GPIO_CHIP} ]] || return 1;
	# Determine GPIOs
	case ${slot} in
	"A" | "B" | "C" | "D")
		pod_det_gpios=${POD_DET_GPIOS[${slot}]}
		;;
	"E")
		# The permanent CAN interface can be treated as a slot that is always populated with the IE-CAN module
		IE_DETECTED[${idx}]="CAN"
		return 0;
		;;
	*)
		return 1;
		;;
	esac
	# Check libgpiod version and set additional options if required
	set_libgpiod_options "gpioget"
	# Read GPIOs
	local ie_cfg=$(gpioget ${LIBGPIOD_OPT} ${POD_DET_GPIO_CHIP} ${pod_det_gpios})

	# Determine IE type
	local ie_type="${IE_TYPE_INV}"
	case $ie_cfg in
	"0 0 0")
		ie_type="${IE_TYPE_ND}"
		;;
	"0 1 0")
		ie_type="RS485"
		;;
	"0 1 1")
		ie_type="RS232"
		;;
	"1 0 0")
		ie_type="DI4O4"
		;;
	"1 1 1")
		ie_type="CAN"
		;;
	*)
		ie_type="${IE_TYPE_INV}"
		;;
	esac
	IE_DETECTED[${idx}]=${ie_type}
	return 0
}

#############################################################################
# int get_ie_type() - determines IE board type for a pod with a given index
# @slot - slot name A, B, C, D , E, X
# A detected IE type is set in the IE_DETECTED[] array
#############################################################################
function get_ie_type() {
	local slot=${1:-}
	[[ ! -z ${slot} ]] || return 1;
	case ${slot} in
	"A" | "B" | "C" | "D" | "E")
		detect_ie_type ${slot}
		return $?;
		;;
	"X" )
		detect_m2_type ${slot}
		return $?;
		;;
	*)
		return 1;
		;;
	esac
}

function slot_probe() {
	local fslot=${1:-${BIDX}}	# From slot
	local tslot=${2:-${EIDX}}	# To slot
	local slot_list=$(seq ${fslot} ${tslot})
	local verbose=${3:-1}

	# Loop over all requested slots
	for i in ${slot_list}; do
		s=${STACK_SLOTS[${i}]^^}
		get_ie_type ${s}
	done

	if [[ ${verbose} -eq 1 ]]; then
		# Display stack
		slot_show ${fslot} ${tslot} 
	fi
}

function grant_access_m2() {
	# Slot index
	local idx=${1}	
	# Validate slot index
	[[ ${idx} -lt ${EIDX} || ${idx} -gt ${BIDX} ]] || return 1;
	local slot=${STACK_SLOTS[${idx}]}
	local ie_type=${IE_DETECTED[${idx}]}
	local ie_subtype=${IMU_SUBTYPE} # Default subtype
	local ie_home=${FPE_HOME}/${STACK_SLOTS[${idx}]}/${IE_ACCESS}

	# Switch USB Mux
	usb_mux_set ; sleep 5
	# Grant access to IMU: should be accessible by all subtypes
	for iio in $(ls ${IIO_BUS}) ; do
		local imu=$(cat ${IIO_BUS}/${iio}/name)
		[[ -n ${imu} ]] || continue
		[[ "${imu}" =~ "${ACCESS_GYRO}" ]] && ln -s ${IIO_BUS}/${iio} ${ie_home}/${ACCESS_IMU_PREFIX}:${ACCESS_GYRO}
		[[ "${imu}" =~ "${ACCESS_ACCEL}" ]] && ln -s ${IIO_BUS}/${iio} ${ie_home}/${ACCESS_IMU_PREFIX}:${ACCESS_ACCEL}
	done

	# Detect MESH card
	local tty=$(readlink -e /dev/${TTY_IE}${slot})
	# Grant access if detected
	if [[ -n ${tty} ]] ; then
		ln -s ${tty} ${ie_home}/${ACCESS_TTY}
		# Detect and set subtype
		local idvendor=$(cat ${MESH_DEVID_HOME}/${IDVENDOR})
		local idprod=$(cat ${MESH_DEVID_HOME}/${IDPROD})
		for s in ${MESH_SUBTYPE[@]} ; do
			if [[ "${idvendor,,}" == ${MESH_USB_IDVENDOR[${s}]} ]] ; then
				if [[ "${idprod,,}" == ${MESH_USB_IDPROD[${s}]} ]] ; then
					# Set subtype: NORD or SILAB
					touch ${ie_home}/${IE_SUBTYPE}.${s}
					# SILAB MESH features 
					# Grant access to GPIO chip if found 
					local gpiochip_dev_home=$(readlink -e ${MESH_USB_DEV}/gpiochip*)
					[[ -n ${gpiochip_dev_home} ]] || return
					local gpiochip=${GPIO_DEV_HOME}/$(basename ${gpiochip_dev_home})
					[[ -c ${gpiochip} ]] && ln -s ${gpiochip} ${ie_home}/${ACCESS_GPIO}
					return
				fi
			fi
		done
	fi
	
	# Switch USB Mux back othervise (no MESH card detected)
	usb_mux_reset
	# Set default subtype: IMU
	touch ${ie_home}/${IE_SUBTYPE}.${ie_subtype}
}

function grant_access_tpm() {
	# Slot index
	local idx=${1}	
	# Validate slot index
	[[ ${idx} -lt ${EIDX} || ${idx} -gt ${BIDX} ]] || return 1;
	local slot=${STACK_SLOTS[${idx}]}
	local ie_type=${IE_DETECTED[${idx}]}
	local ie_home=${FPE_HOME}/${STACK_SLOTS[${idx}]}/${IE_ACCESS}

	if [[ -d ${TPM_DEV_HOME} ]]; then
		local tpm=$(ls ${TPM_DEV_HOME})
		[[ -L ${TPM_HOME}/${tpm} ]] && ln -s ${TPM_HOME}/${tpm} ${ie_home}/${ACCESS_TPM}
	fi
	if [[ -d ${TPMRM_DEV_HOME} ]]; then
		local tpmrm=$(ls ${TPMRM_DEV_HOME})
		[[ -L ${TPMRM_HOME}/${tpmrm} ]] && ln -s ${TPMRM_HOME}/${tpmrm} ${ie_home}/${ACCESS_TPMRM}
	fi
}

function ie_grant_access() {
	# Slot index
	local idx=${1}	
	# Validate slot index
	[[ ${idx} -lt ${EIDX} || ${idx} -gt ${BIDX} ]] || return 1;
	local slot=${STACK_SLOTS[${idx}]}
	local ie_type=${IE_DETECTED[${idx}]}
	local ie_home=${FPE_HOME}/${STACK_SLOTS[${idx}]}/${IE_ACCESS}
	# create access subdir
	rm -rf ${ie_home} ; mkdir -p ${ie_home}

	case ${ie_type} in
		"${IE_TYPE_INV}"|"${IE_TYPE_ND}")
			# Nothing to do
			rm -rf ${ie_home}
			return 0
			;;
		"${IE_RS232}"|"${IE_RS485}")
			local tty=$(readlink -e /dev/${TTY_IE}${slot})
			[[ -n ${tty} ]] && ln -s ${tty} ${ie_home}/${ACCESS_TTY}
			;;
		"${IE_CAN}")
			local can_dev_home=${CAN_DEV_HOME[${slot}]}
			if [[ -d ${can_dev_home} ]]; then
				local can=$(ls ${can_dev_home})
				[[ -L ${CAN_HOME}/${can} ]] && ln -s ${CAN_HOME}/${can} ${ie_home}/${ACCESS_CAN}
			fi
			;;
		"${IE_DIO}")
			echo ${CHIP_I} > ${ie_home}/${ACCESS_DI}
			echo ${PIN_I} >> ${ie_home}/${ACCESS_DI}
			echo ${CHIP_O} > ${ie_home}/${ACCESS_DO}
			echo ${PIN_O} >> ${ie_home}/${ACCESS_DO}
			;;
		"${IE_EMMC}")
			# Create access files for block device (storage)
			local emmc=${EMMC_DEV_HOME}/${EMMC_DEV}
			if [[ -b ${emmc} ]]; then
				ln -s ${emmc} ${ie_home}/${ACCESS_EMMC}
			fi
			grant_access_tpm ${idx}
			;;
		"${IE_ADC}")
			if [[ -d ${IIO_BUS}/${ADC_DEV} ]]; then
				ln -s ${IIO_BUS}/${ADC_DEV} ${ie_home}/${ACCESS_ADC}
			fi
			grant_access_tpm ${idx}
			;;
		"${IE_M2}")
			grant_access_m2 ${idx}
			grant_access_tpm ${idx}
			;;
		"${IE_TPM}")
			grant_access_tpm ${idx}
			;;
		*)
			return 0
			;;
	esac

}

function ie_add() {
	# Slot index
	local idx=${1}	
	# Validate slot index
	[[ ${idx} -lt ${EIDX} || ${idx} -gt ${BIDX} ]] || return 1;
	local ie_type=${IE_DETECTED[${idx}]}

	# Create IFM home directory
	local ie_home=${FPE_HOME}/${STACK_SLOTS[${idx}]}
	rm -rf ${ie_home} # Check if somewhat needed
	mkdir -p ${ie_home}

	## Specify detected IFM type 
	rm -rf ${ie_home}/${IE_TYPE}.*
	touch ${ie_home}/${IE_TYPE}.${ie_type}
	# populate with access info according to IE type
	ie_grant_access ${idx}
}


#############################################################################
# Grant access: populate the Stack frotnplane access directory
#############################################################################
function stack_manage_access() {
	local fslot=${BIDX}	# From slot
	local tslot=${EIDX}	# To slot
	local slot_list=$(seq ${fslot} ${tslot})
	local ret=

	for i in ${slot_list}; do
		ie_add ${i} ; (( ret |= 1 ))
	done
	return ${ret}
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
	aslot=() # Accessible slots
	islot=() # Invalid slots
	eslot=() # Empty slots
	local ret=

	for i in ${slot_list}; do
		s=${STACK_SLOTS[${i}]}
		if [[ "${IE_DETECTED[${i}]}" == "${IE_TYPE_ND}" ]] ; then
			# No IE module was detected - the slot is considered empty
			eslot+=("${s}")
			# Remove unused ttyIEx symlink
			[[ -L /dev/${TTY_IE}${s} ]] && rm /dev/${TTY_IE}${s}
			continue
		fi
		if [[ "${IE_DETECTED[${i}]}" ==  "${IE_TYPE_INV}" ]] ; then
			# Unknown IE type
			islot+=("${s}")
			# Remove unused ttyIEx symlink
			[[ -L /dev/${TTY_IE}${s} ]] && rm /dev/${TTY_IE}${s}
			continue
		fi
		if [[ "${IE_SUPPORTED[${s}]}" =~ "${IE_DETECTED[${i}]}" ]] ; then
			# The detected IE module is compatible with the current slot
			aslot+=("${s}")
			# Remove unused ttyIEx symlink
			[[ "${IE_SERIAL}" =~ "${IE_DETECTED[${i}]}" ]] || ([[ -L /dev/${TTY_IE}${s} ]] && rm /dev/${TTY_IE}${s})
			continue
		else
			# The detected IE module is incompatible with the current slot
			islot+=("${s}")
			IE_DETECTED[${i}]=${IE_TYPE_INV}
			# Remove unused ttyIEx symlink
			[[ -L /dev/${TTY_IE}${s} ]] && rm /dev/${TTY_IE}${s}
			continue
		fi
	done

	local cutline="###############################################################"
	printf "\n%s\n" ${cutline}
	printf "Valid and accessable slots: " ; [[ ${#aslot[@]} == 0 ]] || printf "[%s] " ${aslot[@]}
	printf "\nInaccessable slots:\n"
	printf "  Invalid: " ; [[ ${#islot[@]} == 0 ]] || printf "{%s} " ${islot[@]}
	printf "\n  Empty:   " ; [[ ${#eslot[@]} == 0 ]] || printf "(%s) " ${eslot[@]}
	printf "\n%s\n" ${cutline}
	return 0
}

#############################################################################
# Probe and display all slots
#############################################################################
function stack_probe() {
	slot_probe
}

function stack_probe_silent() {
	slot_probe ${BIDX} ${EIDX} 0
}
