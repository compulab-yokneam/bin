# cl-som-imx7 u-boot update procedure

* Download the firmware file to the tftp export folder:
```
cd /path/to/tftp-export
wget -O - https://github.com/compulab-yokneam/bin/raw/refs/heads/cl-som-imx7/firmware/u-boot.pad.bz2 | bzip2 -dc | sudo tee u-boot.pad >/dev/null
```
* Issue md5sum validation:
```
md5sum u-boot.pad
c8431e228a559fe9c3810d387cf7b178  u-boot.pad
```

* Issue the u-boot update procedure:
  * Turn off the device;
  * Get connected to the device serial console;
  * Turn on the device and stop in U-Boot;
  * Issue these commands:
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
  * Done.
