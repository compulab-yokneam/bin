#!/bin/bash

[[ -z ${IOTG_LIB_HOME} ]] && export IOTG_LIB_HOME=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

. ${IOTG_LIB_HOME}/common.inc

[[ ${IOTG} != ${prod_name_default} ]] || true #flase?

[[ -n ${BOARDS_HOME} ]] || BOARDS_HOME=/usr/share/cl-iotg-config/boards

# 1. Get the device tree board name
if [[ ! -d ${BOARDS_HOME}/${IOTG} ]] ; then
	exit 1
fi

# 2. Install the udev rules into /run/udev/rules.d
RULES_SRC=${BOARDS_HOME}/${IOTG}/udev/rules.d
RULES_DST=/run/udev/rules.d
[[ -d ${RULES_DST} ]] || mkdir -p ${RULES_DST}
## 2.1. Copy rules
#echo "${IOTG}: Find board specific rules in the ${RULES_SRC} and copy to the ${RULES_DST}"
find "${RULES_SRC}" -maxdepth 1 -name "*.rules" -exec cp -f {} "${RULES_DST}/" \;
#ls  -al ${RULES_DST}
## 2.2. Reload udev and re-trigger events to apply the new rules to existing hardware
udevadm control --reload-rules && udevadm trigger

# 3. Install services into /run/systemd/system/
SERVICE_SRC=${BOARDS_HOME}/${IOTG}/systemd/system
SERVICE_DST=/run/systemd/system
[[ -d ${SERVICE_DST} ]] || mkdir -p ${SERVICE_DST}
## 3.1. Copy services
#echo "${IOTG}: Find board specific services in the ${SERVICE_SRC} and copy to the ${SERVICE_DST}"
find "${SERVICE_SRC}" -maxdepth 1 -name "*.service" -exec cp -f {} "${SERVICE_DST}/" \;
#ls  -al ${SERVICE_DST}
## 3.2. Reload systemd daemon to pick up the new runtime services
systemctl daemon-reload 
for s in $(ls ${SERVICE_SRC}) ; do
	systemctl start ${s}
#	echo "${IOTG}: systemctl start ${s}"
done

# 4. Return success
true
