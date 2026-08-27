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
