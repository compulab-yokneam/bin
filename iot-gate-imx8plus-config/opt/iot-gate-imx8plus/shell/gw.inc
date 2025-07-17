# GW home 
export GW_HOME=/run/${IOTG}/gateway
export GW_ACCESS=${GW_HOME}/access

## Connectivity/Network
export GW_ACCESS_NET=${GW_ACCESS}/network
### WiFI/BT
export GW_ACCESS_WLAN=wlan
export GW_ACCESS_BT=bluetooth
export GW_WIFI_HOME=/sys/class/net
export GW_WIFI_DEV_HOME=/sys/bus/pci/devices/0000:01:00.0/net
export GW_BT_HOME=/sys/class/bluetooth
export GW_BT_DEV_HOME=${USB_BUS}/3-1.4/3-1.4:1.0/bluetooth
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
export GW_LED_FIRST=1
export GW_LED_LAST=2
export GW_LED_RED=red
export GW_LED_GREEN=green
export GW_PWR_LED=PowerLED_Red
