get_device() {
	[[ -d /sys/devices/soc0 ]] && device=$(udevadm info -ap /sys/devices/soc0 | awk -F"\"" '(/machine/)&&($0=$2)' | cut -d" " -f2 | tr '[:upper:]' '[:lower:]') || device=iotdin
	echo ${device}
}

export IOTDIN=$(get_device)

IOTDIN_SHELL_HOME=/opt/${IOTDIN}/shell
STACK_LIB=${IOTDIN_SHELL_HOME}/stack.sh

do_iotdin() {
	${STACK_LIB} $@
}

GW_LIB=${IOTDIN_SHELL_HOME}/gw.sh

do_gateway() {
	${GW_LIB} $@
}

do_extra() {
	bash --rcfile ${IOTDIN_SHELL_HOME}/iotdin_expert_shell.bashrc
}

usage () {
cat << eof
~~~~ Explore and Manage
[Ss] - Explore Stack: probe and display (all slots)
[Vv] - Explore Slot: probe and display (specific slot)
[Mm] - Manage Stack: validate configuration and grant access (all slots)
[Ww] - Manage Gateway: validate configuration and grant access
~~~~ Show Info
[Ii] - Show Stack Info
[Gg] - Show Gateway Info
~~~~ Misc
[Xx] - Extra functionality (experts only)
[Qq] - Quit IOTDIN shell
eof
}

PS1='$(usage)\n\nIOTDIN shell ( device: ${IOTDIN} ) > '
set -m

alias s='do_iotdin stack probe'
alias S='do_iotdin stack probe'
alias v='do_iotdin slot probe'
alias V='do_iotdin slot probe'
alias m='do_iotdin stack manage'
alias M='do_iotdin stack manage'
alias i='do_iotdin stack info'
alias I='do_iotdin stack info'
alias w='do_gateway manage'
alias W='do_gateway manage'
alias g='do_gateway info'
alias G='do_gateway info'
alias x='do_extra'
alias X='do_extra'
alias q='exit'
alias Q='exit'
alias exit='exit'
alias quit='exit'
