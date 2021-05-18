#!/bin/bash

###########################################################################
# Script to scp all FreeRTOS Modbus FETT demos to AWS F1
###########################################################################

set -e
set -u

USERNAME=ubuntu
ELF_SUFFIX=.elf

if [[ $# != 4 ]]; then
    echo "usage: $0.sh <nocheri | purecap> <prog> <path_to_output_dir> <server ip>"
    exit 1
fi

CHERI=$1
PROG=$2
CHERI_DIR=$3
SERVER_IP=$4

# Identify the directory where cheribuild installs binaries
if [[ ${CHERI} == "nocheri" ]]; then
    BIN_DIR=${CHERI_DIR}/output/sdk/baremetal/baremetal-riscv64/riscv64-unknown-elf/FreeRTOS/Demo/bin
elif [[ ${CHERI} == "purecap" ]]; then
    BIN_DIR=${CHERI_DIR}/output/sdk/baremetal/baremetal-riscv64-purecap/riscv64-unknown-elf/FreeRTOS/Demo/bin
else
    echo "usage: $0.sh <nocheri | purecap> <prog> <path_to_output_dir> <server ip>"
    exit 1
fi

scp ${BIN_DIR}/${PROG}*${ELF_SUFFIX} ${USERNAME}@${SERVER_IP}:~
