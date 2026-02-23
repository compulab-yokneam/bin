#!/bin/bash -x

BASE_MAC=${BASE_MAC:-"0x0001c03c1122"}

PROG_DIR=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

function net_iface_mac_update() {
    for _d in $(${PROG_DIR}/i226/eeupdateaarch64 | awk '(/8086-125D/)&&($0=$1)');
    do
        mac=$(printf 0x%.10x $((${BASE_MAC} + $_d - 1)))
        NIC=${_d} MAC=${mac} ${PROG_DIR}/i226/flash_command.sh
        ${PROG_DIR}/i226/eeupdateaarch64 /NIC=${_d} /ADAPTERRESET
    done
    return 0
}

function net_iface_fw_update() {
    local done_func="true"
    for _d in $(${PROG_DIR}/i226/eeupdateaarch64 | awk '(/8086-125F/)&&($0=$1)');
    do
        NIC=${_d} ${PROG_DIR}/i226/flash_command.sh
        ${PROG_DIR}/i226/eeupdateaarch64 /NIC=${_d} /ADAPTERRESET
        done_func="fu_after_func"
    done
    ${done_func}
    return 0
}

function net_iface_list() {
    ${PROG_DIR}/i226/eeupdateaarch64
    return 0
}

fu_after_func() {
cat << eof

- FW Update Complete -
1) Issue the device power cycle.
2) Run the script again for the mac address update.

eof
exit 0
}

net_iface_list
net_iface_fw_update
net_iface_mac_update
