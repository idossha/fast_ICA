% analyze_ica.m
% v.1.0.0 - Enhanced with configuration system
% Last updated: [Feb27,2025]
% Use: Functions to perform ICA on EEG data using AMICA in parallel
% Erin Schaeffer, Ido Haber

classdef analyze_ica
    methods(Static)
        % Given a directory path, run AMICA on all .set files in the directory
        function run_amica(path, config_file)
            % Get list of .set files
            allSets = dir(fullfile(path, '*.set'));
            numFiles = length(allSets);

            if numFiles == 0
                error('No .set files found in the specified directory.');
            end
            
            % Load configuration if provided
            if nargin < 2
                % Default configuration
                max_workers = 32;
                worker_limit_factor = 0.5;
                max_jobs = 64;
                threads_per_worker = 1;
                num_models = 1;
                max_iter = 1000;
                remove_cz = true;
            else
                % Load from config file
                try
                    config = jsondecode(fileread(config_file));
                    
                    % Get implementation parameters
                    impl_config = config.implementation;
                    max_workers = getConfigParam(impl_config, 'max_workers', 32);
                    worker_limit_factor = getConfigParam(impl_config, 'worker_limit_factor', 0.5);
                    max_jobs = getConfigParam(impl_config, 'max_jobs', 64);
                    threads_per_worker = getConfigParam(impl_config, 'threads_per_worker', 1);
                    
                    % Get AMICA parameters
                    amica_config = config.amica;
                    num_models = getConfigParam(amica_config, 'num_models', 1);
                    max_iter = getConfigParam(amica_config, 'max_iter', 1000);
                    remove_cz = getConfigParam(amica_config, 'remove_cz', true);
                    
                    fprintf('Loaded configuration from %s\n', config_file);
                catch ME
                    fprintf('Error loading config file: %s\nUsing default parameters.\n', ME.message);
                    % Default configuration if loading fails
                    max_workers = 32;
                    worker_limit_factor = 0.5;
                    max_jobs = 64;
                    threads_per_worker = 1;
                    num_models = 1;
                    max_iter = 1000;
                    remove_cz = true;
                end
            end
            
            % Set up logging directory
            log_dir = fullfile(path, 'logs');
            if ~exist(log_dir, 'dir')
                mkdir(log_dir);
            end
            
            % Create main log file
            main_log = fullfile(log_dir, sprintf('parallel_ica_%s.log', datestr(now, 'yyyymmdd_HHMMSS')));
            log_fid = fopen(main_log, 'w');
            if log_fid == -1
                error('Cannot open main log file: %s', main_log);
            end
            
            % Determine the number of CPU cores
            totalCores = feature('numcores');

            % Calculate number of workers based on configuration
            numWorkers = min(floor(totalCores * worker_limit_factor), max_workers);
            numWorkers = min(numWorkers, max_jobs);

            % Ensure at least one worker is used
            numWorkers = max(1, numWorkers);

            fprintf(log_fid, 'Total CPU cores: %d\n', totalCores);
            fprintf(log_fid, 'Using %d parallel workers with %d threads per worker.\n', numWorkers, threads_per_worker);
            fprintf(log_fid, 'Processing %d files.\n', numFiles);
            
            % Display the same information to console
            fprintf('Total CPU cores: %d\n', totalCores);
            fprintf('Using %d parallel workers with %d threads per worker.\n', numWorkers, threads_per_worker);
            fprintf('Processing %d files.\n', numFiles);

            % Start a parallel pool with the desired number of workers
            if isempty(gcp('nocreate'))
                parpool('local', numWorkers);
            end
            
            % Create a copy of parameters for parfor
            p_threads_per_worker = threads_per_worker;
            p_num_models = num_models;
            p_max_iter = max_iter;
            p_remove_cz = remove_cz;

            % Use parfor to process files in parallel
            parfor setIdx = 1:numFiles
                try
                    % Load dataset
                    filepath = allSets(setIdx).folder;
                    filename = allSets(setIdx).name;
                    EEG = pop_loadset(filename, filepath);
                    
                    % File-specific log
                    [~, baseName, ~] = fileparts(filename);
                    file_log = fullfile(log_dir, sprintf('%s_%s.log', baseName, datestr(now, 'yyyymmdd_HHMMSS')));
                    file_fid = fopen(file_log, 'w');
                    
                    if file_fid == -1
                        warning('Cannot open file log: %s. Using console output only.', file_log);
                    else
                        fprintf(file_fid, 'Processing file: %s\n', filename);
                    end

                    % Check and remove 'Cz' channel if configured and present
                    if p_remove_cz
                        cz_ind = find(contains({EEG.chanlocs.labels}, 'Cz'));
                        if ~isempty(cz_ind)
                            fprintf('Removing Cz channel in %s\n', filename);
                            if file_fid ~= -1
                                fprintf(file_fid, 'Removing Cz channel\n');
                            end
                            EEG = pop_select(EEG, 'nochannel', cz_ind);
                        end
                    end

                    % Define parameters
                    numprocs = 1;                         % Number of nodes (default 1)
                    max_threads = p_threads_per_worker;   % Use configured threads per worker

                    % Define outputs
                    outdir = fullfile(filepath, 'amicaout', baseName);
                    if ~exist(outdir, 'dir')
                        mkdir(outdir);
                    end
                    
                    % Status file in output directory
                    statusFile = fullfile(outdir, 'status.txt');
                    txtout = fopen(statusFile, 'w');
                    if txtout == -1
                        error('Cannot open status file: %s', statusFile);
                    end

                    % Define cleanup function to delete temporary files
                    cleanupObj = onCleanup(@() cleanup_temp_files(outdir, pwd));

                    % Run AMICA with configured threads
                    fprintf(txtout, 'Running runamica15 with %d thread(s)\n', max_threads);
                    if file_fid ~= -1
                        fprintf(file_fid, 'Running runamica15 with %d thread(s)\n', max_threads);
                    end
                    
                    tic;
                    runamica15(EEG.data, 'num_models', p_num_models, 'outdir', outdir, ...
                        'numprocs', numprocs, 'max_threads', max_threads, 'max_iter', p_max_iter);

                    elapsedTime = toc;
                    fprintf(txtout, 'runamica15 success\n');
                    fprintf(txtout, 'Elapsed time: %.5f seconds\n', elapsedTime);
                    
                    if file_fid ~= -1
                        fprintf(file_fid, 'runamica15 success\n');
                        fprintf(file_fid, 'Elapsed time: %.5f seconds\n', elapsedTime);
                    end

                    fclose(txtout);

                    % Add AMICA info to EEG struct
                    EEG.etc.amica = loadmodout15(outdir);
                    EEG.icaweights = EEG.etc.amica.W;  % Unmixing weights
                    EEG.icasphere = EEG.etc.amica.S;   % Sphering matrix
                    EEG.icawinv = EEG.etc.amica.A;     % Model component matrices
                    EEG = eeg_checkset(EEG, 'ica');    % Update EEG.icaact

                    % Rename set
                    newFileName = [baseName '_wcomps.set'];
                    EEG.setname = newFileName;

                    % Save EEG data
                    EEG = pop_saveset(EEG, 'filename', newFileName, 'filepath', filepath);
                    
                    if file_fid ~= -1
                        fprintf(file_fid, 'Saved ICA components to %s\n', newFileName);
                        fclose(file_fid);
                    end

                    % Delete the cleanup object to prevent deletion of necessary files
                    clear cleanupObj;

                catch ME
                    % Handle errors for this iteration
                    fprintf('Error processing %s: %s\n', filename, ME.message);
                    if exist('file_fid', 'var') && file_fid ~= -1
                        fprintf(file_fid, 'ERROR: %s\n', ME.message);
                        fprintf(file_fid, 'Stack trace:\n');
                        for k = 1:length(ME.stack)
                            fprintf(file_fid, '  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
                        end
                        fclose(file_fid);
                    end
                end
            end
            
            % Log completion
            fprintf(log_fid, 'Processing complete. %d files processed.\n', numFiles);
            fclose(log_fid);

            % Display completion message
            fprintf('Processing complete. %d files processed.\n', numFiles);
            fprintf('Log files saved to: %s\n', log_dir);
        end
    end
end

% Helper function to get config parameter with default value
function value = getConfigParam(config, field, default)
    if isfield(config, field)
        value = config.(field);
    else
        value = default;
    end
end

% Function to clean up temporary files
function cleanup_temp_files(outdir, current_dir)
    % Delete temporary files in the output directory
    tempFiles = dir(fullfile(outdir, 'tmpdata*.fdt'));
    for k = 1:length(tempFiles)
        tempFilePath = fullfile(tempFiles(k).folder, tempFiles(k).name);
        if exist(tempFilePath, 'file')
            delete(tempFilePath);
            fprintf('Deleted temporary file: %s\n', tempFilePath);
        end
    end
    
    % Also clean up any temporary files in the current directory
    tempFilesWD = dir(fullfile(current_dir, 'tmpdata*.fdt'));
    for k = 1:length(tempFilesWD)
        tempFilePath = fullfile(tempFilesWD(k).folder, tempFilesWD(k).name);
        if exist(tempFilePath, 'file')
            delete(tempFilePath);
            fprintf('Deleted working directory temporary file: %s\n', tempFilePath);
        end
    end
    
    % Also try to clean up in the MATLAB startup directory
    try
        startup_dir = pwd;
        tempFilesSD = dir(fullfile(startup_dir, 'tmpdata*.fdt'));
        for k = 1:length(tempFilesSD)
            tempFilePath = fullfile(tempFilesSD(k).folder, tempFilesSD(k).name);
            if exist(tempFilePath, 'file')
                delete(tempFilePath);
                fprintf('Deleted startup directory temporary file: %s\n', tempFilePath);
            end
        end
    catch
        % Ignore errors in this part
    end
end
