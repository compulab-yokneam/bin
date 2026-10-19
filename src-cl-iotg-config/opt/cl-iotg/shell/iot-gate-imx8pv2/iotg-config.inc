. ${IOTG_LIB_HOME}/${IOTG}/gw.inc

export UBOOT_ENV_FDTO=fdtofile
export FDTO_PREFIX=iotg-imx8pv2
export FDTO_EXT=dtbo

# GW Peripherals
export WIFI=WIFI
export NVME=NVME
export WIFI_SDIO=WIFI-SDIO
export CMD_BTN=CMD
export PD_EN=ON
export PD_DIS=OFF
declare -A PERIPHERAL_DEVS=(
		[WIFI]=${PD_EN}
		[NVME]=${PD_DIS}
		[WIFI-SDIO]=${PD_DIS}
		[CMD]=${PD_DIS}
)

declare -A PERIPHERAL_CFG=(
		[WIFI]=${PD_EN}
		[NVME]=${PD_DIS}
		[WIFI-SDIO]=${PD_DIS}
		[CMD]=${PD_DIS}
)

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
	## Prepare C-Lab IOTG-IMX8PV2 config files
	### Stack config file
	: > ${NEW_CL_CONFIG_STK}
	init_stack_config ${NEW_CL_CONFIG_STK}
	### GW config file
	: > ${NEW_CL_CONFIG_GW}
	init_gw_config ${NEW_CL_CONFIG_GW}

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
			# cl_config.stack.txt: set DIO configuration
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
				# cl_config.stack.txt: slot ${slot}: enable CAN interface
				SLOT_CL_CFG_STR="can"
				fdto_slot=${FDTO_PREFIX}-${SLOT_CL_CFG_STR}-${sslot}.${FDTO_EXT}
				;;
			"${IE_RS485}")
				#### Enable RS485
				# cl_config.stack.txt: slot ${slot}: enable RS485 interface
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
		# Push the new configuration to the cl_config.stack.txt
		[[ -z ${SLOT_CL_CFG_STR} ]] || set_config_var ${SLOT_CL_CFG_KEY} ${SLOT_CL_CFG_STR} ${NEW_CL_CONFIG_STK}
	done

	### Peripherals
declare -A pd_fdtptrn=(
		[WIFI]=${WIFI,,}
		[NVME]=${NVME,,}
		[WIFI-SDIO]=${WIFI_SDIO,,}
		[CMD]=cmd-button
)

	for key in "${!PERIPHERAL_CFG[@]}"; do
		PD_CL_CFG_STR=
		PD_CL_CFG_KEY="${key,,}"
		local fdto_pd=

		## Remove the previous config from fdtofile
		fdto_pd=${FDTO_PREFIX}-${pd_fdtptrn[${key}]}
		fdtofile=$(echo ${fdtofile} | sed -E "s/\s*${fdto_pd}\.${FDTO_EXT}\s*/ /g" | sed -E 's/^\s+|\s+$//g')

		if [[ ${PERIPHERAL_CFG[${key}]} == ${PD_EN} ]] ; then
			case ${key} in
				"${WIFI}")
					clear_config_var ${NVME,,} ${NEW_CL_CONFIG_GW}
					;;
				"${NVME}")
					clear_config_var ${WIFI,,} ${NEW_CL_CONFIG_GW}
					;;
			esac
			set_config_var ${PD_CL_CFG_KEY} ${PD_EN,,} ${NEW_CL_CONFIG_GW}
			[[ -z ${fdto_pd} ]] || fdtofile=${fdtofile}" "${fdto_pd}.${FDTO_EXT}
		fi
	done

	### Backup the previous cl_config
	cp ${CL_CONFIG_STK} ${CL_CONFIG_STK_BAK}
	### Put new cl_config.*.txt to their home directory
	tee ${CL_CONFIG_STK} ${CL_CONFIG_STK_NEXT} > /dev/null < ${NEW_CL_CONFIG_STK}
	rm ${NEW_CL_CONFIG_STK}
	tee ${CL_CONFIG_GW} ${CL_CONFIG_GW_NEXT} > /dev/null < ${NEW_CL_CONFIG_GW}
	rm ${NEW_CL_CONFIG_GW}
	# Store the new value of the fdtofile
	fdtofile=$(echo ${fdtofile} | sed -E 's/^\s+|\s+$//g')
	fw_setenv ${UBOOT_ENV_FDTO} "${fdtofile}"

	ASK_TO_REBOOT=1
set +x
}

declare -A PD_CFG_DSCR=(
		[WIFI]="WiFi Interface (PCIe)"
		[NVME]="NVME Storage / HAILO AI"
		[WIFI-SDIO]="WiFi Interface (SDIO)"
		[CMD]="CMD Button"
		[ON]="Enabled"
		[OFF]="Disabled"
)

#############################################################################
# Probe GW peripheral devices
#############################################################################
function gw_pd_probe() {
	# Handle all but PCIe devices
	declare -a pd_list=(${WIFI_SDIO} ${CMD_BTN})
	for key in "${pd_list[@]}"; do
		local pd_key=${key,,}
		local key_cfg=$(grep -E "^[[:space:]]*${pd_key}=on([[:space:]]*#|$)" "${CL_CONFIG_GW}" | sed 's/.*=//; s/,.*//')
		if [[ ${key_cfg^^} == ${PD_EN} ]] ; then
			PERIPHERAL_DEVS[${key}]=${PD_EN}
		fi
		PERIPHERAL_CFG[${key}]="${PERIPHERAL_DEVS[${key}]}"
	done
	# Handle PCIe devices
	## WIFI firts
	key_cfg=$(grep -E "^[[:space:]]*${WIFI,,}=on([[:space:]]*#|$)" "${CL_CONFIG_GW}" | sed 's/.*=//; s/,.*//')
	if [[ ${key_cfg^^} == ${PD_EN} ]] ; then
		PERIPHERAL_DEVS[${WIFI}]=${PD_EN}
		PERIPHERAL_CFG[${WIFI}]=${PD_EN}
		PERIPHERAL_DEVS[${NVME}]=${PD_DIS}
		PERIPHERAL_CFG[${NVME}]=${PD_DIS}
		return 0
	fi
	## NVME if WIFI not configured explicitly
	key_cfg=$(grep -E "^[[:space:]]*${NVME,,}=on([[:space:]]*#|$)" "${CL_CONFIG_GW}" | sed 's/.*=//; s/,.*//')
	if [[ ${key_cfg^^} == ${PD_EN} ]] ; then
		PERIPHERAL_DEVS[${NVME}]=${PD_EN}
		PERIPHERAL_CFG[${NVME}]=${PD_EN}
		PERIPHERAL_DEVS[${WIFI}]=${PD_DIS}
		PERIPHERAL_CFG[${WIFI}]=${PD_DIS}
	fi
	return 0
}

#############################################################################
# Peripheral devices configuration menu
#############################################################################
do_peripherals_cfg_misc () {
	selected_dev_descr=$(whiptail --title "Configure Misc Peripherals" --separate-output --checklist "" 20 80 11 \
	"${CMD_BTN}" "Enable/Disable ${PD_CFG_DSCR[${CMD_BTN}]}" ${PERIPHERAL_CFG[${CMD_BTN}]} \
	"${NVME}" "Enable/Disable ${PD_CFG_DSCR[${NVME}]}" ${PERIPHERAL_CFG[${NVME}]} \
	3>&1 1>&2 2>&3)
	mapfile -t selected_dev_list <<< "$selected_dev_descr"

	for key in "${!PERIPHERAL_CFG[@]}"; do
		PERIPHERAL_CFG[${key}]=${PD_DIS}
	done
	for key in "${selected_dev_list[@]}" ; do
		[[ ! -z "$key" ]] || continue
		PERIPHERAL_CFG[${key}]=${PD_EN}
	done

	return 0
}

#############################################################################
# PCIe configuration menu
#############################################################################
do_pcie_config () {
	new_pcie_conf=$(whiptail --title "Configure PCI Express Devices" --separate-output --radiolist "" 20 80 11 \
	"${WIFI}" "${PD_CFG_DSCR["${WIFI}"]}" ${PERIPHERAL_CFG[${WIFI}]} \
	"${NVME}" "${PD_CFG_DSCR["${NVME}"]}" ${PERIPHERAL_CFG[${NVME}]} \
	3>&1 1>&2 2>&3)
	RET=$?
	if [ ${RET} -eq 1 ] || [ ${RET} -eq 255 ]; then
		return 0
	fi

declare -A pcie_buddy=(
	[WIFI]=${NVME}
	[NVME]=${WIFI}
)

	# Set slot new value
	PERIPHERAL_CFG[${new_pcie_conf}]=${PD_EN}
	PERIPHERAL_CFG[${pcie_buddy[${new_pcie_conf}]}]=${PD_DIS}
	return 0
}

#############################################################################
# Misc devices configuration menu
#############################################################################
do_misc_config () {
	selected_dev_descr=$(whiptail --title "Configure Misc Peripherals" --separate-output --checklist "" 20 80 11 \
	"${CMD_BTN}" "Enable/Disable ${PD_CFG_DSCR[${CMD_BTN}]}" ${PERIPHERAL_CFG[${CMD_BTN}]} \
	3>&1 1>&2 2>&3)
	RET=$?
	if [ ${RET} -eq 1 ] || [ ${RET} -eq 255 ]; then
		return 0
	fi
	mapfile -t selected_dev_list <<< "$selected_dev_descr"

	PERIPHERAL_CFG[${CMD_BTN}]=${PD_DIS}
	for key in "${selected_dev_list[@]}" ; do
		[[ ! -z "$key" ]] || continue
		PERIPHERAL_CFG[${key}]=${PD_EN}
	done

	return 0
}

#############################################################################
# Wireless devices configuration menu
#############################################################################
do_wireless_config () {
	selected_dev_descr=$(whiptail --title "Configure Alternative Wireless Devices" --separate-output --checklist "" 20 80 11 \
	"${WIFI_SDIO}" "Enable/Disable ${PD_CFG_DSCR[${WIFI_SDIO}]}" ${PERIPHERAL_CFG[${WIFI_SDIO}]} \
	3>&1 1>&2 2>&3)
	RET=$?
	if [ ${RET} -eq 1 ] || [ ${RET} -eq 255 ]; then
		return 0
	fi
	mapfile -t selected_dev_list <<< "$selected_dev_descr"

	PERIPHERAL_CFG[${WIFI_SDIO}]=${PD_DIS}
	for key in "${selected_dev_list[@]}" ; do
		[[ ! -z "$key" ]] || continue
		PERIPHERAL_CFG[${key}]=${PD_EN}
	done

	return 0
}

#############################################################################
# Peripheral devices configuration menu
#############################################################################
do_peripherals_cfg_menu () {
	while true; do
		FUN=$(whiptail --title "Configure Peripherals" --menu "" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
		"C1 PCIe      " "Configure PCI Express Devices" \
		"C2 Wireless  " "Configure Alternative Wireless Devices" \
		"C3 Misc      " "Configure Miscellaneous Devices" \
		3>&1 1>&2 2>&3)
		RET=$?
		if [ $RET -eq 1 ]; then
			return 0
		elif [ $RET -eq 0 ]; then
			case "$FUN" in
			C1\ *) do_pcie_config ;;
			C2\ *) do_wireless_config ;;
			C3\ *) do_misc_config ;;
			*) whiptail --msgbox "${UNRECOGNIZED_ERR}" 20 60 1 ;;
			esac || whiptail --msgbox "${RUNNING_ERR} $FUN" 20 60 1
		fi
	done
}

#############################################################################
# Display current GW configuration
#############################################################################
do_pd_show () {
	# Detect
	gw_grant_access
	# Show
	whiptail --title "Peripherals: running configuration" --msgbox "\
	PCI Express:
	  ${PD_CFG_DSCR[${WIFI}]}:    [${PERIPHERAL_DEVS[${WIFI}]}] - ${PD_CFG_DSCR[${PERIPHERAL_DEVS[${WIFI}]}]}
	  ${PD_CFG_DSCR[${NVME}]}:  [${PERIPHERAL_DEVS[${NVME}]}] - ${PD_CFG_DSCR[${PERIPHERAL_DEVS[${NVME}]}]}

	Alternative Wireless Connectivity:
	  ${PD_CFG_DSCR[${WIFI_SDIO}]}:    [${PERIPHERAL_DEVS[${WIFI_SDIO}]}] - ${PD_CFG_DSCR[${PERIPHERAL_DEVS[${WIFI_SDIO}]}]}

	Miscellaneous:
	  ${PD_CFG_DSCR[${CMD_BTN}]}:               [${PERIPHERAL_DEVS[${CMD_BTN}]}] - ${PD_CFG_DSCR[${PERIPHERAL_DEVS[${CMD_BTN}]}]}" \
	20 70 1

	return 0
}

#############################################################################
# Display user defined GW configuration
#############################################################################
do_pd_config_show () {
	# Show
	whiptail --title "Peripherals: user configuration" --msgbox "\
	PCI Express:
	  ${PD_CFG_DSCR[${WIFI}]}:    [${PERIPHERAL_CFG[${WIFI}]}] - ${PD_CFG_DSCR[${PERIPHERAL_CFG[${WIFI}]}]}
	  ${PD_CFG_DSCR[${NVME}]}:  [${PERIPHERAL_CFG[${NVME}]}] - ${PD_CFG_DSCR[${PERIPHERAL_CFG[${NVME}]}]}

	Alternative Wireless Connectivity:
	  ${PD_CFG_DSCR[${WIFI_SDIO}]}:    [${PERIPHERAL_CFG[${WIFI_SDIO}]}] - ${PD_CFG_DSCR[${PERIPHERAL_CFG[${WIFI_SDIO}]}]}

	Miscellaneous:
	  ${PD_CFG_DSCR[${CMD_BTN}]}:               [${PERIPHERAL_CFG[${CMD_BTN}]}] - ${PD_CFG_DSCR[${PERIPHERAL_CFG[${CMD_BTN}]}]}" \
	20 70 1

	return 0
}

#############################################################################
# Show GW menu
#############################################################################
do_peripherals_show_menu () {
	while true; do
		FUN=$(whiptail --title "Show Peripherals Configuration" --menu "" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
		"P1 Show User Configured         " "Show user defined configuration" \
		"P2 Show Current Configuration   " "Show currently run configuration" \
		3>&1 1>&2 2>&3)
		RET=$?
		if [ $RET -eq 1 ]; then
			return 0
		elif [ $RET -eq 0 ]; then
			case "$FUN" in
			P1\ *) do_pd_config_show ;;
			P2\ *) do_pd_show ;;
			*) whiptail --msgbox "${UNRECOGNIZED_ERR}" 20 60 1 ;;
			esac || whiptail --msgbox "${RUNNING_ERR} $FUN" 20 60 1
		fi
	done
}

## Probe GW peripherals
gw_pd_probe
for key in "${!PERIPHERAL_DEVS[@]}"; do
	PERIPHERAL_CFG[${key}]="${PERIPHERAL_DEVS[${key}]}"
done
