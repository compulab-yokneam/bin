## Connectivity/Network
### WiFI/BT
export GW_WIFI_DEV_HOME=/sys/bus/pci/devices/0000:01:00.0/net
export GW_BT_DEV_HOME=${USB_BUS}/3-1/3-1.1/3-1.1:1.0/bluetooth

### Cell Modem
export CELL_USB_HOME=${USB_BUS}/3-1/3-1.2
export CELL_DEVID_HOME=${CELL_USB_HOME}
export CELL_SYSPATH=${CELL_USB_HOME}
declare -a CELL_TYPE=("T910G")
declare -A CELL_USB_IDVENDOR=(
		[T910G]="1bc7"
)
declare -A CELL_USB_IDPROD=(
		[T910G]="1031"
)

## LEDs
declare -a IOTG_ULED_ARR=("Green_A" "Red_A")
function gw_get_uled_arr() {
	echo IOTG_ULED_ARR
}
IOTG_SLED_OK="PowerLED_Blue"
IOTG_SLED_SOS="PowerLED_Amber"
function gw_get_sled() {
	local status=${1^^}

	case ${status} in
		"OK")
			echo ${IOTG_SLED_OK}
			;;
		"SOS")
			echo ${IOTG_SLED_SOS}
			;;
		*)
			return 1
			;;
	esac
}

## TPM
export TPM_DEV_BASE=/sys/bus/i2c/devices/2-002e
export TPM_DEV_HOME=${TPM_DEV_BASE}/tpm
export TPMRM_DEV_HOME=${TPM_DEV_BASE}/tpmrm

## Kernel modules
declare -a IOTG_KO_ARR=("iwlwifi" "btusb")
function gw_get_ko_arr() {
	echo IOTG_KO_ARR
}

## Block devices
declare -a IOTG_BLKDEV_ARR=(emmc nvme)
export GW_EMMC_DEV=mmcblk2
export GW_NVME_DEV=nvme0n1

function gw_get_blkdev_arr() {
	echo IOTG_BLKDEV_ARR
}

function gw_get_blkdev_name() {
	local blk=${1:-}

	[[ -n ${blk} ]] || echo ${GW_NULL_DEV}

	case ${blk} in
		"emmc")
			echo ${GW_EMMC_DEV}
			;;
		"nvme")
			echo ${GW_NVME_DEV}
			;;
		*)
			echo ${GW_NULL_DEV}
			;;
	esac
}

## Configuration
export CONFIG_GW_HOME=/run/${IOTG}/config
export CONFIG_GW_SRC_HOME=${BOARDS_HOME}/${IOTG}/config

### Gateway config
export CL_CONFIG_GW_PTRN=cl-config.gw
export CL_CONFIG_GW_FILE=${CL_CONFIG_GW_PTRN}.txt
export CL_CONFIG_GW=${CONFIG_GW_HOME}/${CL_CONFIG_GW_FILE}
export CL_CONFIG_GW_NEXT=${CONFIG_GW_SRC_HOME}/${CL_CONFIG_GW_FILE}
export CL_CONFIG_GW_TMPL=${CONFIG_GW_SRC_HOME}/${CL_CONFIG_GW_PTRN}.tmpl
export CL_CONFIG_GW_BAK=${CL_CONFIG_GW}.prev
export NEW_CL_CONFIG_GW=$(mktemp --dry-run -p /tmp ${CL_CONFIG_GW_PTRN}.XXX)

function init_gw_config () {
	local new_cfg=${1:-${CL_CONFIG_GW}}

cat  << EOF > ${new_cfg}
#### GW Peripherals
# Enable Gateway peripherals by setting their value to "on".
# Leave unset (or commented out) to disable.
#
# Supported peripherals, grouped by category:
# - Display:
# - PCIe:
#   - wifi       - PCIe WiFi module (e.g. Intel AX210) (enabled by default)
#   - nvme       - NVMe storage / Hailo AI accelerator
# - Wireless connectivity:
#   - wifi-sdio  - SDIO-based WiFi module (e.g. C-Lab EB-M2WIFI)
# - Miscellaneous:
#   - cmd        - CMD button
#
# Example: cmd=on    # <-- Enable the CMD button
wifi=on
#nvme=
#wifi-sdio=
#cmd=
EOF
}

function do_init_gw() {
	# Init GW config
	mkdir -p ${CONFIG_GW_HOME}
	## Check if cl-config.gw.txt if found
	if [[ ! -e ${CL_CONFIG_GW} ]] ; then
		if [[ -e ${CL_CONFIG_GW_NEXT} ]]; then
			# Make a copy from the last good if exists
			cp ${CL_CONFIG_GW_NEXT} ${CONFIG_GW_HOME}/
		elif [[ -e ${CL_CONFIG_GW_TMPL} ]] ; then
			# Make a copy from the template
			cp ${CL_CONFIG_GW_TMPL} ${CL_CONFIG_GW}
		else
			# Generate from the scratch
			init_gw_config ${CL_CONFIG_GW}
		fi
	fi
}
