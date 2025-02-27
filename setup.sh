#!/bin/bash
# Fast ICA Framework Setup Script
# This script helps set up dependencies for the Fast ICA Framework

echo "Fast ICA Framework Setup"
echo "======================="
echo

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for Python
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version | awk '{print $2}')
    echo "Found Python: $PYTHON_VERSION"
else
    echo "ERROR: Python 3 is required but not found."
    echo "Please install Python 3.6 or later."
    exit 1
fi

# Check for pip
if command_exists pip3; then
    PIP_VERSION=$(pip3 --version | awk '{print $2}')
    echo "Found pip: $PIP_VERSION"
else
    echo "ERROR: pip3 is required but not found."
    echo "Please install pip3."
    exit 1
fi

# Install Python dependencies
echo
echo "Installing Python dependencies..."
pip3 install -r requirements.txt

# Create required directories
echo
echo "Creating required directories..."
mkdir -p logs

# Check if MATLAB is available
echo
echo "Checking for MATLAB..."
if command_exists matlab; then
    MATLAB_VERSION=$(matlab -batch "disp(version)" 2>/dev/null | tail -n 1)
    echo "Found MATLAB: $MATLAB_VERSION"
else
    echo "WARNING: MATLAB command not found in PATH."
    echo "Make sure MATLAB is installed and update the path in config/default.yml"
fi

# Check if running in container
if [ -f "/.dockerenv" ] || [ -f "/.singularity.d/env/01-base.sh" ]; then
    echo "Detected container environment."
    echo "Make sure to update the container MATLAB path in config/default.yml"
fi

# Check for SLURM (for server environments)
if command_exists srun; then
    SLURM_VERSION=$(srun --version | head -n 1)
    echo "Found SLURM: $SLURM_VERSION"
    echo "Server environment detected. Update server MATLAB path in config/default.yml"
fi

echo
echo "Setup complete!"
echo
echo "Next steps:"
echo "1. Edit config/default.yml to set your MATLAB and EEGLAB paths"
echo "2. Run a test analysis with: ./run_ica.sh -i serial <data_directory>"
echo "3. Read the README.md for detailed usage instructions"
echo