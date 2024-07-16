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
export BPE_RES=resources
export BPE_RES_ACQ=acquired
export BPE_RES_IN=incoming
export BPE_RES_OUT=outgoiug
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
export PIN_IB=0
export PIN_IE=7
export PIN_OB=8
export PIN_OE=15

# Genaral stuff
export DUMMY_PATH=/dev/null
export I2C_BUS=/sys/bus/i2c/devices
export IIO_BUS=/sys/bus/iio/devices
export TTY_DEV_HOME=/dev
export TTY_DEV_PTRN=ttyIFM_RSx
export GPIO_DEV_HOME=/dev
export DI8O8_GPIOCHIP_BUS=4
export DI8O8_GPIOCHIP_BASEADDR=20
export WIFI_HOME=/sys/class/net
export WIFI_DEV_HOME=/sys/bus/pci/devices/0000:01:00.0/net
export BT_HOME=/sys/class/bluetooth
export BT_DEV_HOME=/sys/bus/usb/devices/3-1.1/3-1.1:1.0/bluetooth

