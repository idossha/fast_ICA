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

## Dependencies

- MATLAB (R2020a or newer recommended)
- EEGLAB (latest version recommended)
- AMICA plugin for EEGLAB
- Parallel Computing Toolbox (for parallel and strengthen implementations)

## Usage Instructions

### 1. Parallel-ICA (Best for powerful workstations)

```bash
cd parallel-ICA
./run_ica.sh /path/to/your/data/directory
```

- Automatically processes files in parallel using available cores
- Maximum 64 parallel jobs, limited to half the available cores
- Requires Parallel Computing Toolbox

### 2. Serial-ICA (Best for limited computing resources)

```bash
cd serial-ICA
./run_ica.sh /path/to/your/data/directory
```

- Processes files sequentially
- Attempts to use 2 threads by default, falling back to 1 if needed
- More memory efficient than parallel approach

### 3. Strengthen-ICA (Best for complex projects)

```bash
cd strengthen-ICA
./ica.sh /path/to/project_directory
```

- Edit `run_analyze_ica.m` to configure:
  - Subject list
  - Night list
  - File template pattern

## Environment Considerations

### Personal Computer

- Edit the MATLAB and EEGLAB paths in the run_ica.sh files to match your installation
- For Windows users, convert shell scripts to batch files or use WSL
- Limit parallel processing to avoid overloading your system
- Monitor memory usage when processing large datasets

### Headless Remote Server

- Make sure MATLAB is properly configured for headless operation
- Add `-nodisplay -nosplash -nodesktop` flags to MATLAB commands
- Use `nohup` or `screen`/`tmux` to run processes in the background
- Submit jobs using job schedulers like SLURM or PBS if available
- Example:
  ```bash
  nohup ./run_ica.sh /path/to/data > ica_log.txt 2>&1 &
  ```

## Utilities

The `utils/` directory contains helper scripts:
- `total_time.py`: Calculate total processing time from AMICA output files
  ```bash
  python3 utils/total_time.py /path/to/amicaout/out.txt
  ```

## Troubleshooting

- If MATLAB paths are incorrect, edit them in the respective `run_ica.sh` files
- For memory errors, reduce the number of parallel workers
- Check individual status.txt files in amicaout directories for error messages
- Ensure EEGLAB and the AMICA plugin are correctly installed and accessible

## Performance Tips

- Parallel-ICA is fastest on multi-core systems with plenty of RAM
- Serial-ICA is more stable but slower on large datasets
- Strengthen-ICA offers the best organization and error handling for production use
- Processing time scales with EEG file size and recording length
