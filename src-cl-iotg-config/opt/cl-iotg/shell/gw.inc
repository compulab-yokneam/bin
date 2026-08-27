# GW home 
export GW_HOME=/run/${IOTG}/gateway
export GW_ACCESS=${GW_HOME}/access

## Connectivity/Network
export GW_ACCESS_NET=${GW_ACCESS}/network
### WiFI/BT
export GW_ACCESS_WLAN=wlan
export GW_ACCESS_BT=bluetooth
export GW_WIFI_HOME=/sys/class/net
export GW_BT_HOME=/sys/class/bluetooth
### Modem
export GW_ACCESS_MODEM_HOME=${GW_ACCESS_NET}/modem
export GW_MODEM_TTY=ttyModem
export GW_MODEM_AT1=at1
export GW_MODEM_AT2=at2
export GW_MODEM_QCDM=qcdm
export GW_MODEM_GPS=gps

## LEDs
export GW_ACCESS_LED_HOME=${GW_ACCESS}/leds
export LED_HOME=/sys/class/leds
export LED_TRG_PTRN_MOD=ledtrig_pattern

## CMD button
export GW_ACCESS_CMD_BTN_HOME=${GW_ACCESS}/cmd_button
export GW_ACCESS_CMD_BTN=event
export GW_CMD_BTN_DEV=/dev/input/by-path/platform-gpio-keys-event

## TPM
export GW_ACCESS_TPM_HOME=${GW_ACCESS}/tpm
export GW_ACCESS_TPM=tpm
export GW_ACCESS_TPMRM=tpmrm
export TPM_HOME=/sys/class/tpm
export TPMRM_HOME=/sys/class/tpmrm

## Block devices
export GW_ACCESS_BLKDEV_HOME=${GW_ACCESS}/blkdev
export GW_BLKDEV_HOME=/dev

## NULL devices
export GW_NULL_DEV=null
