# I/O extension home
export IO_STACK_HOME=/run/${IOTG}/io_stack
## Frontplane Emulation home
export FPE_HOME=${IO_STACK_HOME}/frontplane
export IE_TYPE=type
export IE_SUBTYPE=subtype
export IE_ACCESS=access
export ACCESS_TTY=tty
export ACCESS_ADC=adc
export ACCESS_BLKDEV=blkdev
export ACCESS_EMMC=${ACCESS_BLKDEV}
export ACCESS_CAN=can
export ACCESS_MESH_NORD=${ACCESS_TTY}
export ACCESS_MESH_SILAB=${ACCESS_TTY}
export ACCESS_GPIO=gpiochip
export ACCESS_TPM=tpm
export ACCESS_TPMRM=tpmrm
export ACCESS_DI=di.map
export ACCESS_DO=do.map
export ACCESS_ACCEL=accel
export ACCESS_GYRO=gyro

## IE Types

### RS232
export IE_RS232="RS232"
### RS485
export IE_RS485="RS485"
export TTY_IE=ttyIE

### CAN
export IE_CAN="CAN"
SPBA=
[[ -d /sys/devices/platform/soc@0/30800000.bus/30800000.spba-bus ]] && SPBA="30800000.spba-bus"
export CAN_DEV_BASE=/sys/devices/platform/soc@0/30800000.bus/${SPBA}
declare -A CAN_DEV_HOME=(
		[C]=${CAN_DEV_BASE}/308c0000.can/net
		[E]=${CAN_DEV_BASE}/308d0000.can/net
)

export CAN_HOME=/sys/class/net

### DI4O4
export IE_DIO="DI4O4"
export CHIP_O="3 4 0 3"
export PIN_O="30 4 1 12"
export CHIP_I="4 4 3 3"
export PIN_I="3 0 31 29"

### ADC
export IE_ADC="ADC"
export ADC_DEV=iio:device0
export AIN_MIN=0
export AIN_MAX=3

### eMMC
export IE_EMMC="eMMC"
export EMMC_DEV=mmcblk1
export EMMC_DEV_HOME=/dev

### M.2
export IE_M2="M2"
export MESH_USB_HOME=${USB_BUS}/3-1/3-1.2
export MESH_USB_DEV=${MESH_USB_HOME}/3-1.2:1.0
export MESH_DEVID_HOME=${MESH_USB_HOME}
export IDVENDOR=idVendor
export IDPROD=idProduct
declare -a MESH_SUBTYPE=("NORD" "SILAB")
declare -A MESH_USB_IDVENDOR=(
		[NORD]="37a1"
		[SILAB]="10c4"
)
declare -A MESH_USB_IDPROD=(
		[NORD]="0101"
		[SILAB]="ea60"
)
export IMU_SUBTYPE="IMU"
export GPIO_DEV_HOME=/dev

### TPM
export IE_TPM="TPM"
export TPM_DEV_BASE=/sys/devices/platform/soc@0/30800000.bus/${SPBA}/30830000.spi/spi_master/spi1/spi1.0
export TPM_DEV_HOME=${TPM_DEV_BASE}/tpm
export TPMRM_DEV_HOME=${TPM_DEV_BASE}/tpmrm
export TPM_HOME=/sys/class/tpm
export TPMRM_HOME=/sys/class/tpmrm

## Slot stuff
### 1-st slot index: 'B' for begin
export BIDX=0
### Last slot index: 'E' for end
export EIDX=5

### Slots array: array index -> slot's index
declare -a STACK_SLOTS=("A" "B" "C" "D" "E" "X")

### Slot name-to-index translation array: name -> key, value -> index
declare -A STACK_SLOTS2IDX=(
		[A]=0
		[B]=1
		[C]=2
		[D]=3
		[E]=4
		[X]=5
)

### Unique slots
export IE_DIO_SLOT="D"
export IE_ADC_SLOT="X"

## IE detection stuff
export IE_TYPE_INV="Inval"	# Invalid
export IE_TYPE_ND="Empty"	# Not detected - the slot is aassumed to be empty

## Detected IEs
declare -a IE_DETECTED=(
		"${IE_TYPE_ND}"
		"${IE_TYPE_ND}"
		"${IE_TYPE_ND}"
		"${IE_TYPE_ND}"
		"${IE_TYPE_ND}"
		"${IE_TYPE_ND}"
)

export POD_DETECT_I2C_DEV="2-0021"
export POD_DET_GPIO_CHIP=$(readlink -e ${I2C_BUS}/${POD_DETECT_I2C_DEV}/gpiochip*)
declare -A POD_DET_GPIOS=(
		[A]="0 1 2"
		[B]="3 4 5"
		[C]="6 7 8"
		[D]="9 10 11"
)

## M.2 Add-ons
### Add on board types
declare -a M2_ADDON_LIST=(
		"${IE_EMMC}"
		"${IE_M2}"
		"${IE_ADC}"
		"${IE_TPM}"
)

## Support map IEs
export IE_SERIAL="${IE_RS232} | ${IE_RS485}"
declare -A IE_SUPPORTED=(
		[A]="${IE_SERIAL}"
		[B]="${IE_SERIAL}"
		[C]="${IE_SERIAL} | ${IE_CAN}"
		[D]="${IE_DIO}"
		[E]="${IE_CAN}"
		[X]="$(printf "| %s " ${M2_ADDON_LIST[@]} | sed "s/|//" ; printf "\n")"
)

### Detection: based on I2C slave detection
#### I2C bus
declare -A ADDON_BUS=(
		[eMMC]="4"
		[M2]="4"
		[ADC]="4"
		[TPM]="4"
)
#### I2C slave addr
declare -A ADDON_CHIP=(
		[eMMC]="0x20"
		[M2]="0x21"
		[ADC]="0x48"
		[TPM]="0x54"
)
#### Reg offset
declare -A ADDON_OFFSET=(
		[eMMC]="0"
		[M2]="0"
		[ADC]="2"
		[TPM]="0"
)

## USB Mux stuff
export MUX_CHIP=0
export MUX_SEL=15
