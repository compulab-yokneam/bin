#!/bin/bash -x

# Device Node:		/sys/devices/platform/bus@0/140c0000.pcie/pci0009:00/0009:00:00.0/0009:01:00.0
# Device VID:PID:	/sys/devices/platform/bus@0/140c0000.pcie/pci0009:00/0009:00:00.0/0009:01:00.0/{vendor,device}

WORK_DIR=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

NIC=${NIC:-""}
MAC=${MAC:-""}

[[ -n "${NIC}" ]] || exit 2
[[ -n "${MAC}" ]] && CMD="/MAC ${MAC}" || CMD="/D ${WORK_DIR}/FXVL_125D_IT_1MB_2.32.bin"

${WORK_DIR}/eeupdateaarch64 /NIC=${NIC} ${CMD}
