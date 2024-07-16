
# GW home 
export GW_HOME=/run/${IOTDIN}/gateway
export GW_ACCESS=${GW_HOME}/access

## Modem
export GW_ACCESS_MODEM_HOME=${GW_ACCESS}/modem
export GW_MODEM_TTY=ttyModem
export GW_MODEM_AT1=at1
export GW_MODEM_AT2=at2
export GW_MODEM_QCDM=qcdm
export GW_MODEM_GPS=gps

## WiFI/BT
# TODO

## LEDs
export GW_ACCESS_LED_HOME=${GW_ACCESS}/leds
export LED_HOME=/sys/class/leds
export GW_LED_FIRST=A
export GW_LED_LAST=B
export GW_LED_RED=red
export GW_LED_GREEN=green

## Industrial I/O Connector (aka Terminal Block)
export GW_ACCESS_IO_HOME=${GW_ACCESS}/industrial_io
### RS232
export GW_ACCESS_RS232=ttyRS232
### RS485
export GW_ACCESS_RS485=ttyRS485

### CAN
export GW_ACCESS_CAN=can
export CAN_DEV_HOME=/sys/devices/platform/soc@0/30800000.bus/308d0000.can/net/
export CAN_HOME=/sys/class/net

### DI2O2
export GW_DIO="DI2O2"
export GW_ACCESS_DI=di.map
export GW_ACCESS_DO=do.map
export CHIP_O="3 4"
export PIN_O="30 4"
export CHIP_I="4 4"
export PIN_I="3 0"

