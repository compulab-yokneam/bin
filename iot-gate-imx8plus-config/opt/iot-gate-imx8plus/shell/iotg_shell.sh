#!/bin/bash

IOTG_SHELL=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

bash --rcfile ${IOTG_SHELL}/iotg_shell.bashrc
