# Imports

import pandas as pd
from io import StringIO
from pathlib import Path
import sys
import getopt
from scipy import stats
from scipy.stats.mstats import gmean
import matplotlib.pyplot as plt
import numpy as np

# Constants

this_dir = Path().absolute()

# This designates the throughput test in the microbenchmark file
benchmark_type = 'REQUEST_PROCESSING_MICROBENCHMARK'

# names of benchmark applications
benchmark_names = [
    'RISC-V-Generic_main_modbus-nocheri-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-purecap-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-nocheri-net-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-purecap-net-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-purecap-obj-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-purecap-obj-net-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-nocheri-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-purecap-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-nocheri-net-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-purecap-net-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-purecap-obj-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-purecap-obj-net-micro-execperiod_100'
]

benchmark_names_no_network_caps_20ms = [
    'RISC-V-Generic_main_modbus-nocheri-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-purecap-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-purecap-obj-micro-execperiod_20',
]

benchmark_names_no_network_caps_100ms = [
    'RISC-V-Generic_main_modbus-nocheri-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-purecap-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-purecap-obj-micro-execperiod_100',
]

benchmark_names_network_caps_20ms = [
    'RISC-V-Generic_main_modbus-nocheri-net-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-purecap-net-micro-execperiod_20',
    'RISC-V-Generic_main_modbus-purecap-obj-net-micro-execperiod_20',
]

benchmark_names_network_caps_100ms = [
    'RISC-V-Generic_main_modbus-nocheri-net-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-purecap-net-micro-execperiod_100',
    'RISC-V-Generic_main_modbus-purecap-obj-net-micro-execperiod_100',
]

# dict of modbus functions and pretty-print names (for plotting)
modbus_function_names = {
    'MODBUS_FC_READ_SINGLE_COIL': 'read single coil',
    'MODBUS_FC_READ_MULTIPLE_COILS': 'read multiple coils',

    'MODBUS_FC_WRITE_SINGLE_COIL': 'write single coil',
    'MODBUS_FC_WRITE_MULTIPLE_COILS': 'write multiple coils',

    'MODBUS_FC_READ_MULTIPLE_DISCRETE_INPUTS': 'read discrete inputs',

    'MODBUS_FC_READ_SINGLE_HOLDING_REGISTER': 'read single holding register',
    'MODBUS_FC_READ_MULTIPLE_HOLDING_REGISTERS': 'read multiple holding registers',
    'MODBUS_FC_WRITE_SINGLE_REGISTER': 'write single holding register',
    'MODBUS_FC_WRITE_MULTIPLE_REGISTERS': 'write multiple holding registers',

    'MODBUS_FC_WRITE_AND_READ_REGISTERS': 'write and read holding registers',
    'MODBUS_FC_MASK_WRITE_REGISTER': 'mask write holding register',

    'MODBUS_FC_READ_INPUT_REGISTERS': 'read input register',

    'MODBUS_FC_READ_STRING': 'read string',
    'MODBUS_FC_WRITE_STRING': 'write string',

    'MODBUS_FC_ALL': 'unit test'
}

def main(argv):
    try:
        opts, args = getopt.getopt(argv,"hd:",["input_dir="])
    except getopt.GetoptError:
        print('modbus_microbenchmark.py -d <input_dir>')
        sys.exit(2)

    for opt, arg in opts:
        if opt == '-d':
            input_dir = Path(arg)
        else:
            print('modbus_microbenchmark.py -d <inputdir>')
            sys.exit(2)

    benchmark_data = extract_benchmark_data(input_dir, benchmark_names)
    print()
    print("Processing: base | base + CHERI | base + CHERI + obj")
    print("20ms execution period")
    display_data(benchmark_type, benchmark_data, benchmark_names_no_network_caps_20ms)

    print()
    print("Processing: base | base + CHERI | base + CHERI + obj")
    print("100ms execution period")
    display_data(benchmark_type, benchmark_data, benchmark_names_no_network_caps_100ms)

    print()
    print("Processing: base + net | base + CHERI + net | base + CHERI + obj + net")
    print("20ms execution period")
    display_data(benchmark_type, benchmark_data, benchmark_names_network_caps_20ms)

    print()
    print("Processing: base + net | base + CHERI + net | base + CHERI + obj + net")
    print("100ms execution period")
    display_data(benchmark_type, benchmark_data, benchmark_names_network_caps_100ms)

def display_data(benchmark_type, benchmark_data, benchmark_names):
    '''
    This is a display wrapper for get_gms_and_overheads
    '''
    (gms, overheads) = get_gms_and_overheads(benchmark_type, benchmark_data,
                                             benchmark_names)
    if gms is None:
        print('\nNo data\n')
        return

    print()
    print(gms['mean'])
    print()
    print(overheads['mean'])

def extract_benchmark_data(input_dir, benchmark_names):
    '''
    Extract all data from all benchmark files in input_dir to dataframes in a dict
    '''
    # dictionary to hold DataFrames for each benchmark application
    benchmark_data = {}

    # extract benchmark data from the output of the benchmark applications
    # process as csv data and store to a DataFrame
    # add the DataFrame to the dictionary
    for benchmark_name in benchmark_names:
        benchmark_data[benchmark_name] = pd.DataFrame()
        for benchmark_output_file in list(input_dir.glob(benchmark_name + '_*.txt')):
            print(benchmark_output_file.name)
            df = benchmark_data[benchmark_name].append(benchmark_output_file_to_df(benchmark_output_file), ignore_index = True)

            # store the dataframe in the dict of benchmark data
            benchmark_data[benchmark_name] = df

    return benchmark_data

# Extract printed statistics from the output of each run
# - The header starts with 'benchmark_type'
# - Each stat line starts with [BENCHMARK_TYPE]
# - Exclude the occassional line where 'NetworkInterface' is thrown in the middle of data
def benchmark_output_file_to_df(file):
    csv = ''
    with open(file) as fin:
        for line in fin:
            # sanitise some serial junk leading the first actual output line
            if "benchmark_type" in line:
                pos = line.find("benchmark_type")
                line = line[pos:]

            if line.startswith('REQUEST_PROCESSING_MICROBENCHMARK') or \
            line.startswith('SPARE_PROCESSING_MICROBENCHMARK') or \
            line.startswith('MAX_PROCESSING_MACROBENCHMARK') or \
            line.startswith('benchmark_type'):
                csv += line.replace(', ', ',') # remove any spaces after commas in the csv

        if len(csv) == 0:
            return None

        df = pd.read_csv(StringIO(csv))
        df['file'] = file.name

        # drop rows with missing values
        df = df.dropna()

        return df


def extract_function_time_diff(df, benchmark_type, modbus_function_name = "ALL"):
    '''
    Extract the 'time_diff' column for a given Modbus function

    The time_diff could be time time to process a Modbus request (REQUEST_PROCESSING)
    or the spare processing time after processing the request (SPARE_PROCESSING)

    params
    ------
    df                   : pd.DataFrame with 'modbus_function_name' and 'time_diff' columns
    modbus_function_name : function for which times will be computed (default: do not distinguish)

    returns
    -------
    runtimes             : pd.Series of individual function runtimes
    '''

    # if the df has both SPARE_PROCESSING and REQUEST_PROCESSING data
    if 'benchmark_type' in df.columns:
        df = df[df['benchmark_type'] == benchmark_type]

    # extract the rows for the given function
    if modbus_function_name != "ALL":
        temp = df[df['modbus_function_name'] == modbus_function_name]
    else:
        temp = df

    # extract the time_diff column
    temp = temp['time_diff']

    entries_start = len(temp)

    # we expect our data to be tight, and outliers are the result of initial data runs,
    # so we'll use IQR to remove these outliers (same alg as boxplot):
    # https://towardsdatascience.com/ways-to-detect-and-remove-the-outliers-404d16608dba
    Q1 = temp.quantile(0.25)
    Q3 = temp.quantile(0.75)
    IQR = Q3 - Q1
    outliers_low = temp < (Q1 - 1.5 * IQR)
    outliers_high = temp > (Q3 + 1.5 * IQR)

    temp = temp[~(outliers_low | outliers_high)]

    entries_end = len(temp)
    entries_removed = entries_start - entries_end

    # print a warning if > 20% are outliers
    if entries_removed > 0.2*entries_start:
        print("Removed {} of {} for {}".format(entries_removed, entries_start, modbus_function_name))

    # assert that < 50% are outliers
    assert entries_removed < 0.5*entries_start, \
    "Removed {} of {} for {}".format(entries_removed, entries_start, modbus_function_name)

    # return a series of the time_diff column for the given Modbus function
    return temp

def get_gms_and_overheads(benchmark_type, benchmark_data, benchmark_names):
    '''
    computes geometric means and overheads for all benchmarks against a baseline

    params
    ------
    benchmark_type : string designating which benchmark to process
                   : assumes element 0 is the baseline benchmark
    benchmark_data : dict of dataframes with data from each benchmark run
    benchmark_names: string list of benchmark names to process

    returns
    -------
    df : DataFrame of geometric means and overheads, indexed by benchmark name
    '''
    # dicts to store geometric means and overheads for each benchmark
    gms = {}
    overheads = {}

    # iterate through each benchmark and store the gm
    for benchmark_name in benchmark_names:
        gms[benchmark_name] = {}
        overheads[benchmark_name] = {}

        df = benchmark_data[benchmark_name]

        if len(df) == 0:
            continue

        for modbus_function_name in df.modbus_function_name.value_counts().index:
            # print("Processing: {} in {}".format(modbus_function_name, benchmark_name))
            s = extract_function_time_diff(df, benchmark_type, modbus_function_name)

            gm = gmean(s)
            if benchmark_name == benchmark_names[0]:
                overhead = 0
            else:
                baseline_gm = gms[benchmark_names[0]][modbus_function_name]
                overhead = ((gm - baseline_gm) / baseline_gm) * 100
            gms[benchmark_name][modbus_function_name] = gm
            overheads[benchmark_name][modbus_function_name] = overhead

    gms_df = pd.DataFrame(gms).transpose()
    gms_df['mean'] = gms_df.mean(axis = 1)

    overheads_df = pd.DataFrame(overheads).transpose()
    overheads_df['mean'] = overheads_df.mean(axis = 1)

    return (gms_df, overheads_df)

if __name__ == "__main__":
    main(sys.argv[1:])
