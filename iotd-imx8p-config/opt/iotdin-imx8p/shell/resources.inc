declare -a IFM_RES_PCIE=(
		"WB"
		"NVME"
		"NETX100"
		"5G"
)
declare -a IFM_ARR_PCIE=()

declare -a IFM_RES_USB=(
		"RS485"
		"RS232"
		"WB"
		"MESH"
)
declare -a IFM_ARR_USB=()

###################################################
# Let's aggregate tree quasi-independent resources
# I2C5 + I2C_ADDR + GPIO_GR1 into a single
# meta-resource I2C5_META
declare -a IFM_RES_I2C5_META=(
		"DI8O8"
		"CAN"
)
declare -a IFM_ARR_I2C5_META=()
###################################################

declare -a IFM_RES_I2C6=(
		"ADC8"
)
declare -a IFM_ARR_I2C6=()

declare -a IFM_RES_GPIO_GR2=(
		"ADC8"
		"CAN"
)
declare -a IFM_ARR_GPIO_GR2=()

declare -a IFM_RES_SPI=(
		"CAN"
)
declare -a IFM_ARR_SPI=()

declare -A IFM_RES_LIMIT=(
		[PCIE]=1
		[USB]=3
		[I2C5_META]=4
		[I2C6]=1
		[GPIO_GR2]=1
		[SPI]=1
)

declare -a IFM_RES_ADC8=(
		"I2C6"
		"GPIO_GR2"
)

declare -a IFM_RES_CAN=(
		"SPI"
		"I2C5_META"
		"GPIO_GR2"
)

declare -a IFM_RES_DI8O8=(
		"I2C5_META"
)

declare -a IFM_RES_MESH=(
		"USB"
)

declare -a IFM_RES_NETX100=(
		"PCIE"
)

declare -a IFM_RES_NVME=(
		"PCIE"
)

declare -a IFM_RES_RS232=(
		"USB"
)

declare -a IFM_RES_RS485=(
		"USB"
)

declare -a IFM_RES_WB=(
		"PCIE"
		"USB"
)

declare -a IFM_RES_5G=(
		"PCIE"
)
