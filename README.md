# Fast ICA Processing Framework

- Last Update: February 27, 2025
- Authors: Erin Schaeffer & Ido Haber

This repository provides tools for conducting Independent Component Analysis (ICA) on EEG data using three different implementation approaches: parallel, serial, and strengthened.

## Data Organization

### Expected Input Structure

1. Your EEG data should be in `.set` format (EEGLAB format)
2. For parallel-ICA and serial-ICA:
   - Place all `.set` files in a single directory
   - Ensure files have unique names

3. For strengthen-ICA (recommended for larger projects):
   - Organize files by subject/night in a project directory structure:
   ```
   project_dir/
   ├── subject1/
   │   ├── night1/
   │   │   └── eeg_file.set
   │   └── night2/
   │       └── eeg_file.set
   ├── subject2/
   │   └── ...
   ```

### Output Structure

The scripts will create:
- `*_wcomps.set` files (EEGLAB sets with ICA components)
- `amicaout/` directories containing ICA results and status information
- `logs/` directory containing detailed processing logs

## Dependencies

- MATLAB (R2020a or newer recommended)
- EEGLAB (latest version recommended)
- AMICA plugin for EEGLAB
- Python 3.6+ (for configuration and utilities)
- PyYAML package (for configuration)
- Parallel Computing Toolbox (for parallel and strengthen implementations)

## Configuration

The framework now uses a unified configuration system:

```bash
# Use the default configuration
./run_ica.sh /path/to/data

# Specify an implementation
./run_ica.sh -i parallel /path/to/data

# Use a custom configuration file
./run_ica.sh -i strengthen -c /path/to/custom_config.yml /path/to/project
```

Configuration files use YAML format to define:
- MATLAB installation paths for different environments
- EEGLAB paths and settings
- Implementation-specific parameters
- Project structure and settings
- Logging configuration

The default configuration is stored in `config/default.yml`.

## Usage Instructions

### Unified Command

The framework now provides a unified command to run any implementation:

```bash
./run_ica.sh [options] /path/to/data
```

Options:
- `-i, --implementation`: Specify implementation (parallel, serial, strengthen)
- `-c, --config`: Path to custom configuration file
- `-e, --env`: Specify environment (local, server, container)
- `-h, --help`: Show help message

### Individual Implementation Commands

You can still use the individual implementation scripts:

#### 1. Parallel-ICA (Best for powerful workstations)

```bash
cd parallel-ICA
./run_ica.sh /path/to/your/data/directory
```

- Automatically processes files in parallel using available cores
- Maximum 64 parallel jobs, limited to half the available cores
- Requires Parallel Computing Toolbox

#### 2. Serial-ICA (Best for limited computing resources)

```bash
cd serial-ICA
./run_ica.sh /path/to/your/data/directory
```

- Processes files sequentially
- Attempts to use 2 threads by default, falling back to 1 if needed
- More memory efficient than parallel approach

#### 3. Strengthen-ICA (Best for complex projects)

```bash
cd strengthen-ICA
./ica.sh /path/to/project_directory [/path/to/config.yml]
```

- Configuration now handled through YAML files
- Automatically detects subjects and nights if not specified
- Improved logging and error handling

## Environment Considerations

### Personal Computer

- Configuration system automatically detects local environment
- Customize settings in config/default.yml
- For Windows users, convert shell scripts to batch files or use WSL
- Limit parallel processing to avoid overloading your system
- Monitor memory usage when processing large datasets

### Headless Remote Server

- Configuration system automatically detects server environment
- Add server-specific settings to config/default.yml
- Use `nohup` or `screen`/`tmux` to run processes in the background
- Submit jobs using job schedulers like SLURM or PBS if available
- Example:
  ```bash
  nohup ./run_ica.sh -i strengthen -e server /path/to/project > ica_log.txt 2>&1 &
  ```

### Container Environment

- Configuration system automatically detects container environment
- Specify container-specific MATLAB path in configuration
- Use `-e container` flag to force container environment settings

## Utilities

The `utils/` directory contains helper scripts:

- `config_parser/`: Configuration management system
  ```bash
  python3 -m utils.config_parser.config --help
  ```

- `total_time.py`: Calculate total processing time from AMICA output files
  ```bash
  python3 utils/total_time.py /path/to/amicaout/out.txt
  ```

## Troubleshooting

- Check the log files in the `logs/` directory for detailed error information
- For memory errors, reduce the number of parallel workers in the configuration
- Check individual status.txt files in amicaout directories for error messages
- Ensure EEGLAB and the AMICA plugin are correctly installed and accessible

## Performance Tips

- Parallel-ICA is fastest on multi-core systems with plenty of RAM
- Serial-ICA is more stable but slower on large datasets
- Strengthen-ICA offers the best organization and error handling for production use
- Processing time scales with EEG file size and recording length
- Use the configuration system to optimize parameters for your specific hardware
