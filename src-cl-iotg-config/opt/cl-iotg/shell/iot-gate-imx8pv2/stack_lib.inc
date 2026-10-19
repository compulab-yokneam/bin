# I/O extension home
export IO_STACK_HOME=/run/${IOTG}/io_stack
## Frontplane Emulation home
export FPE_HOME=${IO_STACK_HOME}/frontplane
export IE_TYPE=type
export IE_SUBTYPE=subtype
export IE_ACCESS=access
export ACCESS_TTY=tty
export ACCESS_CAN=can
export ACCESS_GPIO=gpiochip
export ACCESS_DI=di.map
export ACCESS_DO=do.map

## IE Types

### RS485
export TTY_IE=ttyRS485_

### CAN
export CAN_HOME=/sys/class/net
SPBA=
[[ -d /sys/devices/platform/soc@0/30800000.bus/30800000.spba-bus ]] && SPBA="30800000.spba-bus"
export CAN_DEV_BASE=/sys/devices/platform/soc@0/30800000.bus/${SPBA}
declare -A CAN_DEV_HOME=(
		[A]=${CAN_DEV_BASE}/308d0000.can/net
		[B]=${CAN_DEV_BASE}/308c0000.can/net
)

### DIO
declare -a CHIP_O=(5 5 5 5)
declare -a PIN_O=(4 5 6 7)
declare -a CHIP_I=(2 2 2 1)
declare -a PIN_I=(19 20 21 10)

## Configuration
export CONFIG_STK_HOME=/run/${IOTG}/config
export CONFIG_STK_SRC_HOME=${BOARDS_HOME}/${IOTG}/config

### Stack config
export CL_CONFIG_STK_PTRN=cl-config.stack
export CL_CONFIG_STK_FILE=${CL_CONFIG_STK_PTRN}.txt
export CL_CONFIG_STK=${CONFIG_STK_HOME}/${CL_CONFIG_STK_FILE}
export CL_CONFIG_STK_NEXT=${CONFIG_STK_SRC_HOME}/${CL_CONFIG_STK_FILE}
export CL_CONFIG_STK_TMPL=${CONFIG_STK_SRC_HOME}/${CL_CONFIG_STK_PTRN}.tmpl
export CL_CONFIG_STK_BAK=${CL_CONFIG_STK}.prev
export IE_SLOT_CFG="ie_"
export NEW_CL_CONFIG_STK=$(mktemp --dry-run -p /tmp ${CL_CONFIG_STK_PTRN}.XXX)
