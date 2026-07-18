#!/bin/bash

board_name="/proc/device-tree/som.info/board.name"
name="iot-gate-imx8plus"

# Get the device tree board.name value provided by the board bootloader.
# Return true if exists && equal; else false
[[ -f ${board_name} ]] && [[ ${name} = $(cat ${board_name}) ]]
