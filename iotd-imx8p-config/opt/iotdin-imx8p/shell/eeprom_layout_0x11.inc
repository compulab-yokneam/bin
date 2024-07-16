#! /bin/bash

############################################################################
# Misc usefull values
############################################################################
export EEPROM_SIZE=128
export EEPROM_LAYOUT_VERSION=17 # -> 0x11

############################################################################
# Table of offsets for layout version 0x11
############################################################################
export EEPROM_REVISION_OFFSET=0
export EEPROM_RESOURCE_MAP_OFFSET=2
export EEPROM_RESOURCE_MAP_LEN=4
export EEPROM_IFM_ID_OFFSET=6
export EEPROM_IFM_ID_LEN=4
export EEPROM_PADDING_OFFSET=10
export EEPROM_PROD_DATE_OFFSET=16
export EEPROM_SERIAL_NUM_OFFSET=20
export EEPROM_FIRST_MAC_OFFSET=32
export EEPROM_SECOND_MAC_OFFSET=38
export EEPROM_LAYOUT_VER_OFFSET=44
export EEPROM_COMPULAB_ID_OFFSET=45
export EEPROM_RESERVED_BIN_OFFSET=48
export EEPROM_PROD_NAME_OFFSET=64
export EEPROM_PROD_OPTS1_OFFSET=80
export EEPROM_PROD_OPTS_LAST_OFFSET=80
export EEPROM_RESERVED_ASCII_OFFSET=96
