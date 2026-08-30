#!/bin/bash

set -Eeuo pipefail

readonly hosts_file=/run/hosts
temporary_file=

die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

cleanup() {
	if [[ -n $temporary_file ]]; then
		rm -f -- "$temporary_file"
	fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

[[ $EUID -eq 0 ]] || die 'update-hosts must be run as root'
[[ -r /etc/hostname ]] || die '/etc/hostname is not readable'

hostname=$(</etc/hostname)
[[ -n $hostname ]] || die '/etc/hostname is empty'
[[ $hostname != *[[:space:]]* ]] ||
	die '/etc/hostname contains whitespace'

umask 022
temporary_file=$(mktemp /run/update-hosts.XXXXXX)
printf '%s localhost\n' "$hostname" >"$temporary_file"
chmod 0644 "$temporary_file"
mv -f -- "$temporary_file" "$hosts_file"
temporary_file=
