# CompuLab EEPROM utility

## Download:
```
wget https://github.com/compulab-yokneam/bin/raw/refs/heads/eeprom-util/eeprom-util.d/eeprom-util_1.0+git0+f760fb3444-r0_arm64.deb
```

## Install:
```
sudo dpkg -i /path/to/eeprom-util_1.0+git0+f760fb3444-r0_arm64.deb
```

## Usage:
* Issue the command w/out parameters to get help:
```
eeprom-util
```

* IOTG-IMX8PLUS MAC update example:

|NOTE|eeprom update requires root credentials|
|:---|:---|

```
sudo -i
eeprom-util write fields 1 0x50 "1st MAC Address=ca:fe:ca:ca:be:de"
eeprom-util write fields 1 0x50 "2nd MAC Address=ca:fe:ca:ca:be:da"
eeprom-util read 1 0x50
```

* EdgeAI-ORN example:

```
sudo -i
eeprom-util read 7 0x50
eeprom-util read 7 0x51
```
