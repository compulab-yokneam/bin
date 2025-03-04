# Definitions

# Slot stuff
## Dummy slot (aka Main Module) index: 'Z' for zero
export ZIDX=0
## 1-st slot index: 'B' for begin
export BIDX=1
## Last slot index: 'E' for end
export EIDX=8

## Slots array: array index -> slot's index
declare -a STACK_SLOTS=("0" "A" "B" "C" "D" "E" "F" "G" "H")

## Slot name-to-index translation array: name -> key, value -> index
declare -A STACK_SLOTS2IDX=(
		[A]=1
		[B]=2
		[C]=3
		[D]=4
		[E]=5
		[F]=6
		[G]=7
		[H]=8
)

# W1 stuff
export W1_BUS=/sys/bus/w1/devices
export W1_EEPROM_WILDCARD="2d-0000"
declare -a STACK_W1_EEPROM=()

# EEPROM stuff
export EEPROM_FILE=/tmp/eeprom.w1
export EEPROM_CHECK=/tmp/eeprom.w1.check

# STACK stuff
## Detected IFMs
declare -a STACK_IFM=(
		"${IFM_TYPE_ND}"
		"${IFM_TYPE_ND}"
		"${IFM_TYPE_ND}"
		"${IFM_TYPE_ND}"
		"${IFM_TYPE_ND}"
		"${IFM_TYPE_ND}"
		"${IFM_TYPE_ND}"
		"${IFM_TYPE_ND}"
		"${IFM_TYPE_ND}"
)

## Stack home 
export STACK_HOME=/run/${IOTDIN}/stack
### Backplane Emulation home
export BPE_HOME=${STACK_HOME}/backplane
export BPE_W1=w1_bus
export BPE_W1_BM=master
export BPE_W1_EEPROM=eeprom
export BPE_W1_EEPROM_SHADOW=eeprom.raw
export BPE_IFM=type

### Frontplane Emulation home
export FPE_HOME=${STACK_HOME}/frontplane
export FPE_IFM=${BPE_IFM}
export FPE_ACCESS=access
export ACCESS_TTY=tty
export ACCESS_ADC=adc
export ACCESS_WLAN=wlan
export ACCESS_BT=bluetooth
export ACCESS_GPIO=gpiochip
export ACCESS_DI=di.map
export ACCESS_DO=do.map
export ACCESS_BLKDEV=blkdev
export ACCESS_NVME=${ACCESS_BLKDEV}
export ACCESS_NETX100=uio
export ACCESS_MESH=hci
export ACCESS_CAN=can
export PIN_IB=0
export PIN_IE=7
export PIN_OB=8
export PIN_OE=15

# Genaral stuff
export DUMMY_PATH=/dev/null
export I2C_BUS=/sys/bus/i2c/devices
export IIO_BUS=/sys/bus/iio/devices
export USB_BUS=/sys/bus/usb/devices
export TTY_DEV_HOME=/dev
export TTY_DEV_PTRN=ttyIFM_RSx
export STACK_USB_HOME=${USB_BUS}/3-1.1
export USB_DEV_PREFIX=${USB_BUS}/3-1.
export GPIO_DEV_HOME=/dev
export DIxOx_GPIOCHIP_BUS=4
export DIxOx_GPIOCHIP_BASEADDR=20
export DI8O8_INUM=8
export DI8O8_ONUM=8
export CAN_DI4O4_INUM=4
export CAN_DI4O4_ONUM=4
export IER=a
export REIR=10
export FEIR=12
export IRQ_EN=1
export IRQ_DIS=0
export WIFI_HOME=/sys/class/net
export WIFI_DEV_HOME=/sys/bus/pci/devices/0000:01:00.0/net
export BT_HOME=/sys/class/bluetooth
export BT_DEV_HOME=${STACK_USB_HOME}/3-1.1:1.0/bluetooth
export BT_DEVID_HOME=${STACK_USB_HOME}
export IDVENDOR=idVendor
export IDPROD=idProduct
export BT_USB_IDVENDOR="8087"
export BT_USB_IDPROD="0032"
export NVME_DEV=nvme0n1
export NVME_DEV_HOME=/dev
export UIO_HOME=/sys/class/uio
export NETX100_DEV_HOME=/sys/bus/pci/devices/0000:02:00.0/uio
export MESH_DEVID_HOME=${STACK_USB_HOME}
export MESH_USB_IDVENDOR="37a1"
export MESH_USB_IDPROD="0101"
export MESH_BT_USB_IDPROD="1000"
export MESH_DEV_PREFIX=${USB_DEV_PREFIX}
export MESH_BT_DEV_SUFFIX=:1.0/bluetooth
export MESH_BT_HOME=/sys/class/bluetooth
SPBA=
[[ -d /sys/devices/platform/soc@0/30800000.bus/30800000.spba-bus ]] && SPBA="30800000.spba-bus"
export CAN_DEV_PREFIX=/sys/devices/platform/soc@0/30800000.bus/${SPBA}/30830000.spi/spi_master/spi1/spi1.
export CAN_DEV_SUFFIX=/net/
export CAN_HOME=/sys/class/net

# Return Values and Error Codes
export SLOT_EMPTY=0
export SLOT_NONEMPTY=1
export RET_OK=0
export ERR_SLOT_NUM=1
export ERR_PCIE_SLOT=2
export ERR_LIMIT_RES=3
export ERR_INVAL=4
