declare -a IFM_ARR_DI8O8=()
declare -i IFM_LIMIT_DI8O8=4

declare -a IFM_ARR_ADC8=()
declare -i IFM_LIMIT_ADC8=1

declare -a IFM_RES_USB=(
		"RS485"
		"RS232"
		"WB"
		"MESH"
)
declare -a IFM_ARR_USB=()
declare -i IFM_LIMIT_USB=3

declare -a IFM_RES_PCIE=(
		"WB"
		"NVME"
		"NETX100"
		"5G"
)
declare -a IFM_ARR_PCIE=()
declare -i IFM_LIMIT_PCIE=1
