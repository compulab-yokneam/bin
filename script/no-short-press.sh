#!/bin/bash

MEMTOOL=${MEMTOOL:-"/dev/null"}
[[ -x ${MEMTOOL} ]] || true

value=0x$(${MEMTOOL} 0x30370038 1 | awk '(/^0x30370038/)&&($0=$NF)')
value=$(( $(( ${value} &  $(( ~ 0x30000 )) )) | 0x30000 ))
value=0x$(printf %x $value)
${MEMTOOL} 0x30370038=${value}
