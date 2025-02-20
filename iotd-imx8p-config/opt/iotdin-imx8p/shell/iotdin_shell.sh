IOTDIN_SHELL=$(dirname $(readlink -e ${BASH_SOURCE[0]}))

bash --rcfile ${IOTDIN_SHELL}/iotdin_shell.bashrc
