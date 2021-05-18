#!/bin/bash

###########################################################################
# Script to build FreeRTOS Modbus FETT demo targets with cheribuild and waf
#
# Starts by building the appropriate compiler-rt
#
# Parameterises and builds several FreeRTOS Modbus demos
###########################################################################
set -e
set -u

PROG_BASE=main_modbus
CHERIBUILD_DIR=$3
CHERI_OUTPUT_DIR=$4
FREERTOS_TARGET=freertos-baremetal-riscv64
COMPILER_RT_TARGET=compiler-rt-builtins-baremetal-riscv64
# EXEC_PERIOD=(100)
EXEC_PERIOD=(20 100)
# NETWORK_DELAY=(0)
NETWORK_DELAY=(0 10)

if [[ $# != 4 ]]; then
    echo "usage: $0.sh <nocheri | purecap> <qemu_virt | fett> <path_to_cheribuild> <path_to_output_dir>"
    exit 1
fi

CHERI=$1
PLATFORM=$2
PROG_BASE=${PROG_BASE}-${CHERI}

# Identify the directory where cheribuild installs binaries
if [[ ${CHERI} == "nocheri" ]]; then
    BIN_DIR=${CHERI_OUTPUT_DIR}/sdk/baremetal/baremetal-riscv64/riscv64-unknown-elf/FreeRTOS/Demo/bin
elif [[ ${CHERI} == "purecap" ]]; then
    BIN_DIR=${CHERI_OUTPUT_DIR}/sdk/baremetal/baremetal-riscv64-purecap/riscv64-unknown-elf/FreeRTOS/Demo/bin
    COMPILER_RT_TARGET=${COMPILER_RT_TARGET}-purecap
    FREERTOS_TARGET=${FREERTOS_TARGET}-purecap
else
    echo "usage: $0.sh <nocheri | purecap> <qemu_virt | fett> <path_to_cheribuild> <path_to_output_dir>"
    exit 1
fi

# build compiler_rt
#${CHERIBUILD_DIR}/cheribuild.py ${COMPILER_RT_TARGET} --clean

# building an elf
# $1 = program name
build () {
    ${CHERIBUILD_DIR}/cheribuild.py ${FREERTOS_TARGET} \
        --freertos/prog $1 \
        --freertos/platform ${PLATFORM} \
        --skip-update --clean
}

# build the freertos modbus demo applications

# basic demo
PROG=${PROG_BASE}
build ${PROG}

# basic network capability demo
PROG=${PROG_BASE}-net
build ${PROG}

# create microbenchmarks with different execution periods
for exec_period in "${EXEC_PERIOD[@]}"; do
    # basic demo with microbenchmarking
    PROG=${PROG_BASE}-micro-execperiod_${exec_period}
    build ${PROG}

    # network capability demo with microbenchmarking
    PROG=${PROG_BASE}-net-micro-execperiod_${exec_period}
    build ${PROG}
done

# create macrobenchmark with different simulated network delays
for network_delay in "${NETWORK_DELAY[@]}"; do
    # basic demo with macrobenchmarking
    PROG=${PROG_BASE}-macro-netdelay_${network_delay}
    build ${PROG}

    # network capability demo with macrobenchmarking
    PROG=${PROG_BASE}-net-macro-netdelay_${network_delay}
    build ${PROG}
done

if [[ ${CHERI} == "purecap" ]]; then
    # object capability demo
    PROG=${PROG_BASE}-obj
    build ${PROG}

    # object and network capability demo
    PROG=${PROG_BASE}-obj-net
    build ${PROG}

    # create microbenchmarks with different execution periods
    for exec_period in "${EXEC_PERIOD[@]}"; do
        # object capability demo with microbenchmarking
        PROG=${PROG_BASE}-obj-micro-execperiod_${exec_period}
        build ${PROG}

        # object and network capability demo with microbenchmarking
        PROG=${PROG_BASE}-obj-net-micro-execperiod_${exec_period}
        build ${PROG}
    done

    # create macrobenchmark with different simulated network delays
    for network_delay in "${NETWORK_DELAY[@]}"; do
        # object capability demo with macrobenchmarking
        PROG=${PROG_BASE}-obj-macro-netdelay_${network_delay}
        build ${PROG}

        # object and network capability demo with macrobenchmarking
        PROG=${PROG_BASE}-obj-net-macro-netdelay_${network_delay}
        build ${PROG}
    done
fi
