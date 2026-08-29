#!/bin/bash

echo $(cat /etc/hostname) localhost | tee >/dev/null /var/run/hosts
