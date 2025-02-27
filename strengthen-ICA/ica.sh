#!/bin/bash
# Ido Haber, February 2025
# run_ica.sh
# A minimal script that launches "run_analyze_ica.m" in batch mode.

# Set the full path to the MATLAB executable
MATLAB_CMD="/usr/local/share/apptainer/bin/matlab-r2024a"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Optional: check if it exists.
if [ ! -f "$MATLAB_CMD" ]; then
    echo "MATLAB command '$MATLAB_CMD' not found (or not accessible)."
    exit 1
fi

# Now just run your run_analyze_ica.m file
"$MATLAB_CMD" -nodisplay -nosplash -sd "$SCRIPT_DIR" -r "run_analyze_ica; exit;"

# -nodsiplay  : starts MATLAB without initiating any graphical display components.
# -nosplash   : suppresses the MATLAB splash screen during startup
# -sd         : Sets the current working directory when MATLAB starts.
# -r          :  Executes specified MATLAB commands or scripts immediately after MATLAB starts

