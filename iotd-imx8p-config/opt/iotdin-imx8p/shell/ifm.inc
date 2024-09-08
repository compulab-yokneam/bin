# Resource Map (RMAP) stuff
export RMAP_PCIE_OFF=0
export RMAP_USB1_OFF=1
export RMAP_USB2_OFF=2
export RMAP_USB3_OFF=3
export RMAP_USB_MASK=$((1 << RMAP_USB1_OFF | 1 << RMAP_USB2_OFF | 1 << RMAP_USB3_OFF))

export RMAP_SPI2_OFF=4
export RMAP_I2C5_OFF=5
export RMAP_I2C6_OFF=6
export RMAP_I2C_ADDR_OFF=7
export RMAP_GPIO_GR1_P1_OFF=8
export RMAP_GPIO_GR1_P2_OFF=9
export RMAP_GPIO_GR1_P3_OFF=10
export RMAP_GPIO_GR1_P4_OFF=11
export RMAP_GPIO_GR1_MASK=$((1 << RMAP_GPIO_GR1_P1_OFF | 1 << RMAP_GPIO_GR1_P2_OFF | 1 << RMAP_GPIO_GR1_P3_OFF | 1 << RMAP_GPIO_GR1_P4_OFF))

export RMAP_GPIO_GR2_P1_OFF=12
export RMAP_GPIO_GR2_P2_OFF=13
export RMAP_GPIO_GR2_MASK=$((1 << RMAP_GPIO_GR2_P1_OFF | 1 << RMAP_GPIO_GR2_P2_OFF))

export RMAP_GPIO_GR3_P1_OFF=14
export RMAP_GPIO_GR3_P2_OFF=15
export RMAP_GPIO_GR3_P3_OFF=16
export RMAP_GPIO_GR3_P4_OFF=17
export RMAP_GPIO_GR3_MASK=$((1 << RMAP_GPIO_GR3_P1_OFF | 1 << RMAP_GPIO_GR3_P2_OFF | 1 << RMAP_GPIO_GR3_P3_OFF | 1 << RMAP_GPIO_GR3_P4_OFF))

export RMAP_RS485=$((1 << RMAP_USB1_OFF))
export RMAP_RS232=$((1 << RMAP_USB1_OFF))
export RMAP_DI8O8=$((1 << RMAP_I2C5_OFF | 1 << RMAP_I2C_ADDR_OFF | 1 << RMAP_GPIO_GR1_P1_OFF))
export RMAP_ADC8=$((1 << RMAP_I2C6_OFF | 1 << RMAP_GPIO_GR2_P1_OFF | 1 << RMAP_GPIO_GR2_P2_OFF))
export RMAP_WB=$((1 << RMAP_USB1_OFF | 1 << RMAP_PCIE_OFF))

# IFM ID/type stuff
## Known IDs
export IFM_ID_RS485=16#a
export IFM_ID_RS232=16#b
export IFM_ID_DI8O8=16#c
export IFM_ID_ADC8=16#d
export IFM_ID_WB=16#e

export IFM_ID_FIRST=${IFM_ID_RS485}
export IFM_ID_LAST=${IFM_ID_WB}

## Known types
declare -a IFM_TYPE=(
		"RS485"
		"RS232"
		"DI8O8"
		"ADC8"
		"WB"
)
## Additional pseudo-types
export IFM_TYPE_INV="Inval"	# Invalid - W1 eeprom found, but does not contain a valid IFM ID
export IFM_TYPE_ND="Empty"	# Not detected - W1 eeprom found - the slot is aassumed to be empty

##  IFM ID-to-type translation array 
declare -A IFM_ID2TYPE=(
		[a]="RS485"
		[b]="RS232"
		[c]="DI8O8"
		[d]="ADC8"
		[e]="WB"
)

##  IFM type-to-ID translation array
declare -A IFM_TYPE2ID=(
		[RS485]="a"
		[RS232]="b"
		[DI8O8]="c"
		[ADC8]="d"
		[WB]="e"
)
