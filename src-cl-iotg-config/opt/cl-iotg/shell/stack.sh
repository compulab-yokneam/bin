#! /bin/bash

[[ -z ${IOTG_LIB_HOME} ]] && export IOTG_LIB_HOME=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

# Includes
## Common lib
. ${IOTG_LIB_HOME}/common.inc
# Device specific Stack Lib
[[ -e ${IOTG_LIB_HOME}/${IOTG}/stack_lib.sh ]] && . ${IOTG_LIB_HOME}/${IOTG}/stack_lib.sh

function do_dummy() {
	echo "$(basename ${0}): $@: command not found"
}

function do_stack() {
	command -v stack_${1} &>/dev/null && (stack_${1} || true) || do_dummy "stack_${1}"
}

function do_init() {
	command -v do_init_stack &>/dev/null && (do_init_stack || true) || true
}

### Main

# redirect console log to file
LOG_FILE_NAME=${LOG_FILE_NAME:-${LOGS_HOME}/${IOTG}.stack.log.$(date +${TIMESTAMP_FORMAT})}
mkdir -p ${LOGS_HOME}

opt=${1:-"source"}
param=${2:-}

case ${opt} in
	"stack")
		do_init
		do_stack ${param}
		;;
	"slot")
		do_init
		do_slot ${param}
		;;
	"config")
		# Ad-hoc option for automated service
		do_init
		do_config ${param}
		;;
	"source")
		# Dummy option - applied when file is sourced by external script for further usage
		do_init
		;;
	*)
		do_dummy $@
		;;
esac
