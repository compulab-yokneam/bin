#/bin/bash -x

root=$(findmnt / --output SOURCE --noheadings)
boot=${root:0:-1}1

src=$(mktemp --directory)

umoun -l ${boot} 2>/dev/null || true
mount ${boot} /boot

tar_file=linux-bluetooth.tar.bz2
linux_bluetooth=https://github.com/compulab-yokneam/bin/raw/linux-bluetooth/${tar_file}

wget --directory-prefix ${src} ${linux_bluetooth}
tar -C / -xf ${src}/${tar_file}
systemctl enable bt-start

cat << eof
DONE: Please reboot the system
eof
