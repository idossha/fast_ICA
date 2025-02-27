#!/bin/bash
# Strengthen-ICA shell script wrapper
# This script runs the strengthen-ICA implementation with configuration
# Last updated: [Feb27,2025]
# Erin Schaeffer, Ido Haber

if [ $# -lt 1 ]; then
    echo "Usage: $0 <project_directory> [config_file]"
    echo "Example: $0 /path/to/project_dir"
    echo "Example with config: $0 /path/to/project_dir /path/to/config.yml"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get project root directory
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Get project directory
PROJECT_DIR="$1"

# Get config file if provided
CONFIG_FILE=""
if [ $# -ge 2 ]; then
    CONFIG_FILE="$2"
else
    # Use default config if it exists
    if [ -f "$ROOT_DIR/config/default.yml" ]; then
        CONFIG_FILE="$ROOT_DIR/config/default.yml"
    fi
fi

# Set environment variable for configuration
if [ -n "$CONFIG_FILE" ]; then
    export FAST_ICA_CONFIG="$CONFIG_FILE"
    echo "Using configuration: $CONFIG_FILE"
fi

# Get MATLAB path from config or use default
if [ -n "$CONFIG_FILE" ] && [ -f "$ROOT_DIR/utils/config_parser/config.py" ]; then
    cd "$ROOT_DIR"
    MATLAB_PATH=$(python3 -m utils.config_parser.config --config "$CONFIG_FILE" | grep -A1 "matlab:" | grep -E "container|server|local" | head -1 | awk '{print $2}')
    MATLAB_OPTIONS=$(python3 -m utils.config_parser.config --config "$CONFIG_FILE" | grep -A2 "eeglab:" | grep "startup_options" | cut -d: -f2- | tr -d '"')
else
    # Default paths
    MATLAB_PATH="/usr/local/share/apptainer/bin/matlab-r2024a"
    MATLAB_OPTIONS="-nodisplay -nosplash -nodesktop"
fi

# Check if MATLAB exists
if [ ! -f "$MATLAB_PATH" ]; then
    echo "MATLAB command '$MATLAB_PATH' not found (or not accessible)."
    exit 1
fi

echo "Using MATLAB: $MATLAB_PATH"
echo "Using options: $MATLAB_OPTIONS"

# Create config argument for MATLAB
CONFIG_ARG=""
if [ -n "$CONFIG_FILE" ] && [ -f "$ROOT_DIR/utils/config_parser/config.py" ]; then
    # Export configuration for MATLAB
    cd "$ROOT_DIR"
    MATLAB_CONFIG=$(python3 -m utils.config_parser.config --config "$CONFIG_FILE" --implementation "strengthen" --export-matlab)
    MATLAB_CONFIG_PATH=$(echo "$MATLAB_CONFIG" | awk '{print $NF}')
    CONFIG_ARG=",'$MATLAB_CONFIG_PATH'"
fi

# Create logs directory if it doesn't exist
mkdir -p "$ROOT_DIR/logs"

# Run MATLAB script
echo "Running strengthen-ICA on project: $PROJECT_DIR"
LOG_FILE="$ROOT_DIR/logs/strengthen_ica_$(date +%Y%m%d_%H%M%S).log"
$MATLAB_PATH $MATLAB_OPTIONS -r "addpath('$ROOT_DIR'); addpath('$SCRIPT_DIR'); run_analyze_ica('$PROJECT_DIR'$CONFIG_ARG); exit;" > "$LOG_FILE" 2>&1

echo "Log file: $LOG_FILE"

# Clean up temporary config file
if [ -n "$MATLAB_CONFIG_PATH" ]; then
    rm -f "$MATLAB_CONFIG_PATH"
fi

echo "Strengthen-ICA processing complete."

