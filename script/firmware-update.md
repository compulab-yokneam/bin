# cl-som-imx7 u-boot update procedure

* From tftp server
```
setenv firmware_file u-boot.pad
setenv ubootsize 0xa8000
mw.b $loadaddr 0 $ubootsize

dhcp
tftpboot $loadaddr ${serverip}:${firmware_file}

sf probe
sf erase 0 $ubootsize
sf write $loadaddr 0 $ubootsize
reset
```
