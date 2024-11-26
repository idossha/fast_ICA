
#!/bin/bash

###############################################
# run_ica.sh - Script to run ICA analysis on .set files in a given directory
#
# Dependencies:
# 1. analyze_ica.m & run_analyze_ica.m
# 2. EEGLAB
# 3. AMICA plugin
# 4. MATLAB
# 5. Parallel Computing Toolbox
###############################################

# Check if the directory path is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 path_to_directory"
    exit 1
fi

# Get the directory path from the first argument
DIR="$1"

# Check if the directory exists
if [ ! -d "$DIR" ]; then
    echo "Directory '$DIR' does not exist."
    exit 1
fi

# Set the full path to the MATLAB executable
MATLAB_CMD="/opt/matlab/R2024b/bin/matlab"

# Check if the MATLAB executable exists and is executable
if [ ! -x "$MATLAB_CMD" ]; then
    echo "MATLAB executable not found or not executable at '$MATLAB_CMD'"
    exit 1
fi

# Get the directory of the script (which contains your MATLAB scripts)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check if the scripts directory exists
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Scripts directory '$SCRIPT_DIR' does not exist."
    exit 1
fi

# Run MATLAB command once with the directory path
"$MATLAB_CMD" -nodisplay -nosplash -sd "$SCRIPT_DIR" -r "run_analyze_ica('$DIR'); exit;"

