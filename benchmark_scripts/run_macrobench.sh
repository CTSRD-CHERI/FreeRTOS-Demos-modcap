#!/bin/bash
set -e
set -u

ELF_DIR=${HOME}
SSITH_DIR=${HOME}/ssith-aws-fpga
CLIENT_DIR=${HOME}/modcap

# number of times to loop through all Modbus clients
ITERATIONS=1

# number of runs to perform for each Modbus client run
DISCARD_RUNS=1
BENCHMARK_RUNS=1

# set up the tap0 interface
sudo ifup tap0

# reset the fpga
fpga_reset () {
    (! lsmod | grep -q '^portalmem\>') || sudo rmmod portalmem
    (! lsmod | grep -q '^pcieportal\>') || sudo rmmod pcieportal

    # image with performance counter support
    fpga-load-local-image -F -S 0 -I agfi-034e55ea770c34eb6

    # image without performance counter support
    # fpga-load-local-image -F -S 0 -I agfi-026d853003d6c433a

    sudo insmod ${SSITH_DIR}/hw/connectal/drivers/pcieportal/pcieportal.ko
    sudo insmod ${SSITH_DIR}/hw/connectal/drivers/portalmem/portalmem.ko
}

# run a modbus server on the fpga
# $1 = the modbus server elf. also the file to which stdout is redirected.
fpga_run () {
    # we append to the file because it may get cleared between discarded
    # and saved runs
    ${SSITH_DIR}/build/ssith_aws_fpga --tun tap0 --elf ${ELF_DIR}/$1.elf > /dev/null
}

# start a modbus client on the host
# $1 = the modbus client
# $2 = the number of runs to perform (sent to the client application)
# $3 = filename to direct output
client_run () {
    ${CLIENT_DIR}/build/$1 fett $2 >> $3
}

# start a modbus client and server together
# $1 = the modbus server elf
# $2 = the modbus client
combined_run () {
    # establish the output filename
    date=`date +"%Y-%m-%d_%T"`
    filename=${1}_${date}.txt

    # reset the fpga
    echo "Resetting the FPGA"
    fpga_reset

    # run the modbus server on the fpga
    echo "Starting the fpga"
    fpga_run ${1} &

    # let the modbus server finish initialising
    sleep 5

    # run the modbus client on the host
    # these runs warm up the cache and the output will be discarded
    echo "Starting client for discard runs"
    client_run ${2} ${DISCARD_RUNS} /dev/null

    # sleep for a few seconds to let the server close its socket
    # and print benchmarking data
    sleep 5

    # clear the output file used for the discarded runs
    > ${filename}

    # output details of this test run to the file
    echo "${filename}" >> ${filename}
    echo "Iterations: ${ITERATIONS}" >> ${filename}
    echo "Discarded runs: ${DISCARD_RUNS}" >> ${filename}
    echo "Benchmark runs: ${BENCHMARK_RUNS}" >> ${filename}

    # run the modbus client on the host
    echo "Starting client for benchmark runs"
    sync
    free -m
    client_run ${2} ${BENCHMARK_RUNS} ${filename}

    # sleep for a few seconds to let the server close its socket
    # and print benchmarking data
    sleep 5

    echo "Killing the FPGA"
    fpga_kill

    stty sane
}

fpga_kill () {
    kill $( ps -a | grep ssith_aws_fpga | xargs | cut -d' ' -f1 )
}

# modbus server elfs that don't use network capabilities
modbus_servers_no_network_caps=(
    # "RISC-V-Generic_main_modbus-nocheri-macro-netdelay_0"
    # "RISC-V-Generic_main_modbus-nocheri-macro-netdelay_10"
    # "RISC-V-Generic_main_modbus-purecap-macro-netdelay_0"
    # "RISC-V-Generic_main_modbus-purecap-macro-netdelay_10"
    # "RISC-V-Generic_main_modbus-purecap-obj-macro-netdelay_0"
    # "RISC-V-Generic_main_modbus-purecap-obj-macro-netdelay_10"
)

# modbus server elfs that *do* use network capabilities
modbus_servers_network_caps=(
    "RISC-V-Generic_main_modbus-nocheri-net-macro-netdelay_0"
    # "RISC-V-Generic_main_modbus-nocheri-net-macro-netdelay_10"
    # "RISC-V-Generic_main_modbus-purecap-net-macro-netdelay_0"
    # "RISC-V-Generic_main_modbus-purecap-net-macro-netdelay_10"
    # "RISC-V-Generic_main_modbus-purecap-obj-net-macro-netdelay_0"
    # "RISC-V-Generic_main_modbus-purecap-obj-net-macro-netdelay_10"
)

# modbus client executable to communicate without network capabilities
modbus_client_no_network_caps=modbus_test_client_bench

# modbus client executable to communicate *with* network capabilities
modbus_client_network_caps=modbus_test_client_network_caps_bench

# iterate over all the Modbus clients ITERATIONS times
loop_iterations=0
while [ ${loop_iterations} -lt ${ITERATIONS} ]; do

    echo "*****************************"
    echo "*** BEGINNING ITERATION ${loop_iterations} ***"
    echo "*****************************"

    # execute modbus servers and clients without network capabilities
    # go through them in normal and then reverse order
    for (( idx=0 ; idx<${#modbus_servers_no_network_caps[@]} ; idx++ )) ; do
        echo "Testing: ${modbus_servers_no_network_caps[idx]}"
        combined_run ${modbus_servers_no_network_caps[idx]} ${modbus_client_no_network_caps}
        sleep 5
    done

    for (( idx=${#modbus_servers_no_network_caps[@]}-1 ; idx>=0 ; idx-- )) ; do
        echo "Testing: ${modbus_servers_no_network_caps[idx]}"
        combined_run ${modbus_servers_no_network_caps[idx]} ${modbus_client_no_network_caps}
        sleep 5
    done

    # execute modbus servers and clients *with* network capabilities
    # go through them in normal and then reverse order
    for (( idx=0 ; idx<${#modbus_servers_network_caps[@]} ; idx++ )) ; do
        echo "Testing: ${modbus_servers_network_caps[idx]}"
        combined_run ${modbus_servers_network_caps[idx]} ${modbus_client_network_caps}
        sleep 5
    done

    for (( idx=${#modbus_servers_network_caps[@]}-1 ; idx>=0 ; idx-- )) ; do
        echo "Testing: ${modbus_servers_network_caps[idx]}"
        combined_run ${modbus_servers_network_caps[idx]} ${modbus_client_network_caps}
        sleep 5
    done

    (( loop_iterations+=1 ))
done

# something is making the tty go wonky afterward. this fixes it.
stty sane
