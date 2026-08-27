export UBOOT_ENV_FDTO=fdtofile
export FDTO_PREFIX=iotg-imx8pv2
export FDTO_EXT=dtbo

#############################################################################
# Apply user defined configuration by putting appropriate lines into config.txt
# Additionally, put the Industrial I/O configuration (IE) into cl-config.txt
#############################################################################
function do_apply_config() {
set -x
	local fdto_a=
	local fdto_b=
	local fdto_c=
	local fdtofile=$(fw_printenv ${UBOOT_ENV_FDTO} | cut -d"=" -f 2-)
	## Prepare C-Lab IOTG-IMX8PV2 config
	: > ${NEW_CL_CONFIG}
	init_stack_config ${NEW_CL_CONFIG}

	### Apply IE slots configuration: for each slot generate a line to be written into config.txt
	local slot_list=$(seq ${BIDX} ${EIDX})
	for slot in ${slot_list}; do
		local sslot=${STACK_SLOTS[${slot}],,}
		SLOT_CL_CFG_STR=
		SLOT_CL_CFG_KEY="${IE_SLOT_CFG}${sslot}"
		declare -n fdto_slot=fdto_${sslot}
		if [[ "${sslot^^}" == "${IE_DIO_SLOT}" ]] ; then
			[[ "${IE_CONFIG[${slot}]}" == "${IE_DIO}" ]] || continue ; # probably never happens...
			#### Enable DIO
			# cl_config.txt: set DIO configuration
			SLOT_CL_CFG_STR="dio"
			local dio_list=$(seq ${BDIO} ${EDIO})
			for p in ${dio_list} ; do
				if [[ ${DO_UMAP[${p}]} -eq ${DIO_VAL} ]] ; then
					SLOT_CL_CFG_STR+=",o${p}"
					fdto_slot=${fdto_slot}" "${FDTO_PREFIX}-do${p}.${FDTO_EXT}
				fi
			done
			# fdtofile:
			## remove the previous config
			fdtofile=$(echo ${fdtofile} | sed -E "s/\s*${FDTO_PREFIX}-do[0-3]\.${FDTO_EXT}\s*/ /g" | sed -E 's/^\s+|\s+$//g')
			## add the new one
			[[ -z ${fdto_slot} ]] || fdtofile=${fdtofile}" "${fdto_slot}
		else
			case ${IE_CONFIG[${slot}]} in
			"${IE_CAN}")
				#### Enable CAN
				# cl_config.txt: slot ${slot}: enable CAN interface
				SLOT_CL_CFG_STR="can"
				fdto_slot=${FDTO_PREFIX}-${SLOT_CL_CFG_STR}-${sslot}.${FDTO_EXT}
				;;
			"${IE_RS485}")
				#### Enable RS485
				# cl_config.txt: slot ${slot}: enable RS485 interface
				SLOT_CL_CFG_STR="rs485"
				fdto_slot=${FDTO_PREFIX}-${SLOT_CL_CFG_STR}-${sslot}.${FDTO_EXT}
				;;
			"${IE_TYPE_ND}")
				#### Do nothing 
				SLOT_CL_CFG_STR=
				;;
			*)
				# Probably never happens...
				continue
				;;
			esac
			# fdtofile:
			## remove the previous config
			fdtofile=$(echo ${fdtofile} | sed -E "s/\s*${FDTO_PREFIX}-(can|rs485)-${sslot}\.${FDTO_EXT}\s*/ /g" | sed -E 's/^\s+|\s+$//g')
			## add the new one
			[[ -z ${fdto_slot} ]] || fdtofile=${fdtofile}" "${fdto_slot}
		fi
		# Push the new configuration to the cl_config.txt
		[[ -z ${SLOT_CL_CFG_STR} ]] || set_config_var ${SLOT_CL_CFG_KEY} ${SLOT_CL_CFG_STR} ${NEW_CL_CONFIG}
	done

	### Unconditional peripherals: add below if needed

	### Backup the previous cl_config.txt
	cp ${CL_CONFIG} ${CL_CONFIG_BAK}
	### Put the new cl_config.txt to its home directory
	tee ${CL_CONFIG} ${CL_CONFIG_NEXT} > /dev/null < ${NEW_CL_CONFIG}
	rm ${NEW_CL_CONFIG}
	# Store the new value of the fdtofile
	fdtofile=$(echo ${fdtofile} | sed -E 's/^\s+|\s+$//g')
	fw_setenv ${UBOOT_ENV_FDTO} "${fdtofile}"

	ASK_TO_REBOOT=1
set +x
}
