#!/bin/bash

# Fast ICA Framework - Unified runner script
# This script runs any of the ICA implementations with configuration

set -e  # Exit on error

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Default values
IMPLEMENTATION="serial"
DATA_DIR=""
CONFIG_FILE="$SCRIPT_DIR/config/default.yml"
ENV=""

# Functions
print_usage() {
    echo "Usage: $0 [options] <data_directory>"
    echo ""
    echo "Options:"
    echo "  -i, --implementation IMPL   Specify ICA implementation to use"
    echo "                              (parallel, serial, strengthen)"
    echo "  -c, --config CONFIG_FILE    Path to custom config file"
    echo "  -e, --env ENVIRONMENT       Specify environment (local, server, container)"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -i parallel /path/to/data"
    echo "  $0 -i strengthen -c my_config.yml /path/to/project"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--implementation)
            IMPLEMENTATION="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -e|--env)
            ENV="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [[ -z "$DATA_DIR" ]]; then
                DATA_DIR="$1"
            else
                echo "Error: Unexpected argument: $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate implementation
if [[ "$IMPLEMENTATION" != "parallel" && "$IMPLEMENTATION" != "serial" && "$IMPLEMENTATION" != "strengthen" ]]; then
    echo "Error: Invalid implementation: $IMPLEMENTATION"
    print_usage
    exit 1
fi

# Validate data directory for parallel and serial implementations
if [[ "$IMPLEMENTATION" != "strengthen" && -z "$DATA_DIR" ]]; then
    echo "Error: Data directory is required for $IMPLEMENTATION implementation"
    print_usage
    exit 1
fi

# Ensure data directory exists
if [[ -n "$DATA_DIR" && ! -d "$DATA_DIR" ]]; then
    echo "Error: Data directory does not exist: $DATA_DIR"
    exit 1
fi

# Ensure config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file does not exist: $CONFIG_FILE"
    exit 1
fi

# Get configuration
ENV_ARGS=""
if [[ -n "$ENV" ]]; then
    ENV_ARGS="--env $ENV"
fi

# Export configuration for MATLAB
MATLAB_CONFIG=$(python3 -m utils.config_parser.config --implementation "$IMPLEMENTATION" --config "$CONFIG_FILE" $ENV_ARGS --export-matlab)
MATLAB_CONFIG_PATH=$(echo "$MATLAB_CONFIG" | awk '{print $NF}')

# Get MATLAB path from config
MATLAB_PATH=$(python3 -m utils.config_parser.config --implementation "$IMPLEMENTATION" --config "$CONFIG_FILE" $ENV_ARGS | grep -A1 "matlab:" | grep "$ENV\|local" | awk '{print $2}')
MATLAB_OPTIONS=$(python3 -m utils.config_parser.config --implementation "$IMPLEMENTATION" --config "$CONFIG_FILE" $ENV_ARGS | grep -A2 "eeglab:" | grep "startup_options" | cut -d: -f2- | tr -d '"')

echo "Running $IMPLEMENTATION ICA implementation..."
echo "Configuration: $CONFIG_FILE"
echo "MATLAB: $MATLAB_PATH"

# Create logs directory
mkdir -p logs

# Check if MATLAB_PATH is empty and provide fallback
if [ -z "$MATLAB_PATH" ]; then
    # Try to find MATLAB in the PATH
    if command -v matlab &> /dev/null; then
        MATLAB_PATH="matlab"
        echo "Using default MATLAB path from PATH: $MATLAB_PATH"
    else
        # Look for common MATLAB installations
        for possible_path in "/Applications/MATLAB_R2023b.app/bin/matlab" "/Applications/MATLAB_R2024a.app/bin/matlab" "/Applications/MATLAB.app/bin/matlab" "/usr/local/bin/matlab" "/opt/matlab/bin/matlab"; do
            if [ -f "$possible_path" ]; then
                MATLAB_PATH="$possible_path"
                echo "Found MATLAB at: $MATLAB_PATH"
                break
            fi
        done
        
        if [ -z "$MATLAB_PATH" ]; then
            echo "ERROR: Could not find MATLAB. Please specify the correct path in your config file."
            echo "Edit config/default.yml to set the correct path for your environment."
            exit 1
        fi
    fi
fi

if [ -z "$MATLAB_OPTIONS" ]; then
    MATLAB_OPTIONS="-nodisplay -nosplash -nodesktop"
    echo "Using default MATLAB options: $MATLAB_OPTIONS"
fi

# Run implementation-specific MATLAB script
LOG_DATE=$(date +%Y%m%d_%H%M%S)
case "$IMPLEMENTATION" in
    parallel)
        echo "Running parallel ICA on data directory: $DATA_DIR"
        LOG_FILE="logs/parallel_ica_${LOG_DATE}.log"
        echo "Running: $MATLAB_PATH $MATLAB_OPTIONS -r \"addpath('$SCRIPT_DIR'); addpath('$SCRIPT_DIR/parallel-ICA'); run_analyze_ica('$DATA_DIR', '$MATLAB_CONFIG_PATH'); exit;\""
        $MATLAB_PATH $MATLAB_OPTIONS -r "addpath('$SCRIPT_DIR'); addpath('$SCRIPT_DIR/parallel-ICA'); run_analyze_ica('$DATA_DIR', '$MATLAB_CONFIG_PATH'); exit;" > "$LOG_FILE" 2>&1
        echo "Log file: $LOG_FILE"
        ;;
    serial)
        echo "Running serial ICA on data directory: $DATA_DIR"
        for file in "$DATA_DIR"/*.set; do
            if [[ -f "$file" ]]; then
                echo "Processing file: $file"
                LOG_FILE="logs/serial_ica_$(basename "$file")_${LOG_DATE}.log"
                echo "Running: $MATLAB_PATH $MATLAB_OPTIONS -r \"addpath('$SCRIPT_DIR'); addpath('$SCRIPT_DIR/serial-ICA'); run_analyze_ica('$file', '$MATLAB_CONFIG_PATH'); exit;\""
                $MATLAB_PATH $MATLAB_OPTIONS -r "addpath('$SCRIPT_DIR'); addpath('$SCRIPT_DIR/serial-ICA'); run_analyze_ica('$file', '$MATLAB_CONFIG_PATH'); exit;" > "$LOG_FILE" 2>&1
                echo "Log file: $LOG_FILE"
            fi
        done
        ;;
    strengthen)
        echo "Running strengthen ICA on project directory: $DATA_DIR"
        LOG_FILE="logs/strengthen_ica_${LOG_DATE}.log"
        echo "Running: $MATLAB_PATH $MATLAB_OPTIONS -r \"addpath('$SCRIPT_DIR'); addpath('$SCRIPT_DIR/strengthen-ICA'); run_analyze_ica('$DATA_DIR', '$MATLAB_CONFIG_PATH'); exit;\""
        $MATLAB_PATH $MATLAB_OPTIONS -r "addpath('$SCRIPT_DIR'); addpath('$SCRIPT_DIR/strengthen-ICA'); run_analyze_ica('$DATA_DIR', '$MATLAB_CONFIG_PATH'); exit;" > "$LOG_FILE" 2>&1
        echo "Log file: $LOG_FILE"
        ;;
esac

echo "ICA processing complete. Check logs directory for output."

# Cleanup temporary config file
rm -f "$MATLAB_CONFIG_PATH"