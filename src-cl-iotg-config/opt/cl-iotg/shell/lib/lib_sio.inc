# CAN stuff
export IE_CAN="CAN"

# RS485 stuff
export IE_RS485="RS485"

# DIO stuff
export IE_DIO="DIO"
export D_IN="Input"
export D_OUT="Output"
export DIO_VAL=0
export DIO_INV=-1
## 1-st DIO pin index: 'B' for begin
export BDIO=0
## Last DIO pin index: 'E' for end
export EDIO=3

declare -A DIO_VALUE_PRINT=(
		[${DIO_VAL}]="*"
		[${DIO_INV}]=" "
)

## IE detection stuff
export IE_TYPE_INV="Inval"	# Invalid
export IE_TYPE_ND="IDLE"	# Not detected - the slot is assumed to be idle

## Detected IEs
declare -a IE_DETECTED=(
		"${IE_TYPE_ND}"
		"${IE_TYPE_ND}"
		"${IE_DIO}"
)

## IE user cfg stuff
export IE_CONF_DEF="${IE_TYPE_ND}"

## User defined IEs configuration
declare -a IE_CONFIG=(
		"${IE_CONF_DEF}"
		"${IE_CONF_DEF}"
		"${IE_DIO}"
)

## Slot stuff
### 1-st slot index: 'B' for begin
export BIDX=0
### Last slot index: 'E' for end
export EIDX=2

### Slots array: array index -> slot's index
declare -a STACK_SLOTS=("A" "B" "C")

### Slot name-to-index translation array: name -> key, value -> index
declare -A STACK_SLOTS2IDX=(
		[A]=0
		[B]=1
		[C]=2
)

### Unique slots
export IE_DIO_SLOT="C"

## DI / DO maps
export DIO_VAL=0
export DIO_INV=-1
declare -a DI_CMAP=(${DIO_VAL} ${DIO_VAL} ${DIO_VAL} ${DIO_VAL})
declare -a DO_CMAP=(${DIO_INV} ${DIO_INV} ${DIO_INV} ${DIO_INV})

declare -a DI_UMAP=(${DIO_VAL} ${DIO_VAL} ${DIO_VAL} ${DIO_VAL})
declare -a DO_UMAP=(${DIO_INV} ${DIO_INV} ${DIO_INV} ${DIO_INV})

declare -A DIO_VALUE_PRINT=(
		[${DIO_VAL}]="*"
		[${DIO_INV}]=" "
)

## Support map IEs
export IE_COMBO="COMBO"
declare -A IE_SUPPORTED=(
		[A]="${IE_RS485} | ${IE_CAN} | ${IE_COMBO}"
		[B]="${IE_RS485} | ${IE_CAN} | ${IE_COMBO}"
		[C]="${IE_DIO}"
)

declare -A CFG_DSCR=(
		[${IE_CAN}]="CAN FD interface"
		[${IE_RS485}]="RS-485 interface (half-duplex)"
		[${IE_DIO}]="4x Digital Signals (inputs or outputs)"
		[${IE_TYPE_ND}]="No interface is enabled"
		[${D_IN}]="Read-only access enabled"
		[${D_OUT}]="Write-only access enabled"
)
