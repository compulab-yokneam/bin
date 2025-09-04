get_device() {
	[[ -d /sys/devices/soc0 ]] && device=$(udevadm info -ap /sys/devices/soc0 | awk -F"\"" '(/machine/)&&($0=$2)' | cut -d" " -f2 | tr '[:upper:]' '[:lower:]') || device=iotdin
	echo ${device}
}

IOTDIN=$(get_device)

IOTDIN_SHELL_HOME=/opt/${IOTDIN}/shell
STACK_LIB=${IOTDIN_SHELL_HOME}/stack.sh

do_iotdin() {
	${STACK_LIB} $@
}

fast_reboot() {
	for cmd in s u b;do echo ${cmd} > /proc/sysrq-trigger ; done
}

usage () {
cat << eof
~~~~ EEPROM
[Dd] - Dump IFM's EEPROM
~~~~ Misc
[Bb] - Fast reboot
[Qq] - Quit Expert shell
eof
}

PS1='$(usage)\n\nExpert IOTDIN shell ( device: $(get_device) ) > '
set -m

alias d='do_iotdin slot dump'
alias D='do_iotdin slot dump'
alias q='exit'
alias Q='exit'
alias exit='exit'
alias quit='exit'
alias b='fast_reboot'
alias B='fast_reboot'
