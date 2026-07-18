#!/bin/bash

board_name="/proc/device-tree/som.info/board.name"
name="iotdin-imx8p"

# Get the device tree board.name value provided by the board bootloader.
# Return true if exists && equal; else false
[[ -f ${board_name} ]] && [[ ${name} = $(cat ${board_name}) ]]
