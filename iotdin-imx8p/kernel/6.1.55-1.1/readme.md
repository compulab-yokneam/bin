# How to

```
sudo -i
wget -qO - https://github.com/compulab-yokneam/bin/raw/refs/heads/etc/iotdin-imx8p/kernel/6.1.55-1.1/kernel-module-slcan-6.1.55-1.1.tar.bz2 | tar -C / -xjvf -
depmod -a 6.1.55-1.1
modprobe slcan
```
