#!/bin/bash

###############################################
# run_ica.sh - Script to run ICA analysis on individual .set files from a given directory
#
# Dependencies:
# 1. analyze_ica.m & run_analyze_ica.m
# 2. EEGLAB
# 3. AMICA plugin
# 4. MATLAB
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
MATLAB_CMD="/Applications/MATLAB_R2024a.app/bin/matlab"

# Check if the MATLAB executable exists and is executable
if [ ! -x "$MATLAB_CMD" ]; then
    echo "MATLAB executable not found or not executable at '$MATLAB_CMD'"
    exit 1
fi

# Set the path to your MATLAB scripts (directory containing run_analyze_ica.m and analyze_ica.m)
SCRIPT_DIR=$(pwd)

# Check if the scripts directory exists
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Scripts directory '$SCRIPT_DIR' does not exist."
    exit 1
fi

# Enable nullglob to handle directories with no matching files
shopt -s nullglob

# Initialize a counter to check if any files are processed
file_count=0

# Loop over all .set files in the directory
for FILE in "$DIR"/*.set; do
    if [ -f "$FILE" ]; then
        echo "Processing file: $FILE"
        file_count=$((file_count + 1))

        # Run MATLAB command for each .set file
        "$MATLAB_CMD" -nodisplay -nosplash -sd "$SCRIPT_DIR" -r "run_analyze_ica('$FILE'); exit;"
    fi
done

# Check if no .set files were found
if [ "$file_count" -eq 0 ]; then
    echo "No .set files found in directory '$DIR'."
    exit 1
fi

