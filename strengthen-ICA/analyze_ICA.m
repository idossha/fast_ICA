% analyze_ICA.m
% v.1.0.0 - Enhanced with configuration system
% Last updated: [Feb27,2025]
% Use: Functions to perform ICA on EEG data using AMICA in parallel with project structure
% Erin Schaeffer, Ido Haber

% Make sure you have Parallel Computing Toolbox installed

classdef analyze_ica
    methods (Static)
        %% Main method to run AMICA on datasets organized by project, subjects, and nights
        function run_amica_project(experiment_path, subjects, nights, setFileTemplate, config_file)
            % Validate inputs
            if ~isfolder(experiment_path)
                error('The specified experiment path does not exist: %s', experiment_path);
            end
            if ~iscell(subjects) || isempty(subjects)
                error('Subjects must be a non-empty cell array of strings.');
            end
            if ~iscell(nights) || isempty(nights)
                error('Nights must be a non-empty cell array of strings.');
            end
            if ~ischar(setFileTemplate) || isempty(setFileTemplate)
                error('Set file template must be a non-empty string.');
            end
            
            % Set up logging directory
            log_dir = fullfile(experiment_path, 'logs');
            if ~exist(log_dir, 'dir')
                mkdir(log_dir);
            end
            
            % Create main log file
            main_log = fullfile(log_dir, sprintf('strengthen_ica_%s.log', datestr(now, 'yyyymmdd_HHMMSS')));
            log_fid = fopen(main_log, 'w');
            if log_fid == -1
                error('Cannot open main log file: %s', main_log);
            end
            
            % Log execution parameters
            fprintf(log_fid, 'Processing experiment: %s\n', experiment_path);
            fprintf(log_fid, 'Subjects: %s\n', strjoin(subjects, ', '));
            fprintf(log_fid, 'Nights: %s\n', strjoin(nights, ', '));
            fprintf(log_fid, 'File template: %s\n', setFileTemplate);
            
            % Load configuration if provided
            if nargin < 5 || isempty(config_file)
                % Default configuration
                max_workers = 32;
                threads_per_worker = 1;
                num_models = 1;
                max_iter = 1000;
                remove_cz = true;
                cleanup_temp_files = true;
                
                fprintf(log_fid, 'Using default configuration\n');
            else
                % Load from config file
                try
                    config = jsondecode(fileread(config_file));
                    
                    % Get implementation parameters
                    impl_config = config.implementation;
                    max_workers = getConfigParam(impl_config, 'max_workers', 32);
                    threads_per_worker = getConfigParam(impl_config, 'threads_per_worker', 1);
                    cleanup_temp_files = getConfigParam(impl_config, 'cleanup_temp_files', true);
                    
                    % Get AMICA parameters
                    amica_config = config.amica;
                    num_models = getConfigParam(amica_config, 'num_models', 1);
                    max_iter = getConfigParam(amica_config, 'max_iter', 1000);
                    remove_cz = getConfigParam(amica_config, 'remove_cz', true);
                    
                    fprintf(log_fid, 'Loaded configuration from %s\n', config_file);
                    fprintf('Loaded configuration from %s\n', config_file);
                catch ME
                    fprintf(log_fid, 'Error loading config file: %s\nUsing default parameters.\n', ME.message);
                    fprintf('Error loading config file: %s\nUsing default parameters.\n', ME.message);
                    
                    % Default configuration if loading fails
                    max_workers = 32;
                    threads_per_worker = 1;
                    num_models = 1;
                    max_iter = 1000;
                    remove_cz = true;
                    cleanup_temp_files = true;
                end
            end
            
            % Initialize list to hold .set file information
            fileList = struct('filepath', {}, 'filename', {});

            % Iterate over subjects and nights to build file list
            fprintf('Scanning directories for .set files...\n');
            fprintf(log_fid, 'Scanning directories for .set files...\n');
            
            for subjIdx = 1:length(subjects)
                for nightIdx = 1:length(nights)
                    % Define current subject and night
                    whichSubj = subjects{subjIdx};
                    whichNight = nights{nightIdx};

                    % Define file name using the setFileTemplate
                    % The template should include two '%s' placeholders for subject and night
                    if isempty(whichNight)
                        % If nights is {''}
                        name_temp = sprintf(setFileTemplate, whichSubj);
                    else
                        name_temp = sprintf(setFileTemplate, whichSubj, whichNight);
                    end
                    
                    % Define file path
                    if isempty(whichNight)
                        filepath = fullfile(experiment_path, whichSubj);
                    else
                        filepath = fullfile(experiment_path, whichSubj, whichNight);
                    end
                    
                    fullFilePath = fullfile(filepath, name_temp);

                    % Check if file exists
                    if exist(fullFilePath, 'file')
                        % Add to fileList
                        fileList(end+1).filepath = filepath; %#ok<AGROW>
                        fileList(end).filename = name_temp;
                        fprintf('Found file: %s\n', fullFilePath);
                        fprintf(log_fid, 'Found file: %s\n', fullFilePath);
                    else
                        warning('File not found: %s', fullFilePath);
                        fprintf(log_fid, 'WARNING: File not found: %s\n', fullFilePath);
                    end
                end
            end

            numFiles = length(fileList);

            if numFiles == 0
                error_msg = 'No .set files found based on the provided project directory, subjects, nights, and set file template.';
                fprintf(log_fid, 'ERROR: %s\n', error_msg);
                fclose(log_fid);
                error(error_msg);
            end

            fprintf('Total .set files to process: %d\n', numFiles);
            fprintf(log_fid, 'Total .set files to process: %d\n', numFiles);

            % Determine the number of CPU cores
            totalCores = feature('numcores');

            % Calculate number of workers based on configuration
            numWorkers = min(max_workers, floor(totalCores / 2));

            % Ensure at least one worker is used
            numWorkers = max(1, numWorkers);

            fprintf('Total CPU cores available: %d\n', totalCores);
            fprintf('Initializing parallel pool with %d workers.\n', numWorkers);
            
            fprintf(log_fid, 'Total CPU cores available: %d\n', totalCores);
            fprintf(log_fid, 'Initializing parallel pool with %d workers.\n', numWorkers);
            fprintf(log_fid, 'Threads per worker: %d\n', threads_per_worker);

            % Start a parallel pool with the desired number of workers
            pool = gcp('nocreate'); % Get current pool without creating new one
            if isempty(pool)
                parpool('local', numWorkers);
            else
                fprintf('Using existing parallel pool with %d workers.\n', pool.NumWorkers);
                fprintf(log_fid, 'Using existing parallel pool with %d workers.\n', pool.NumWorkers);
            end
            
            % Create a copy of parameters for parfor
            p_threads_per_worker = threads_per_worker;
            p_num_models = num_models;
            p_max_iter = max_iter;
            p_remove_cz = remove_cz;
            p_cleanup_temp_files = cleanup_temp_files;

            % Use parfor to process files in parallel
            parfor setIdx = 1:numFiles
                try
                    % Load dataset
                    filepath = fileList(setIdx).filepath;
                    filename = fileList(setIdx).filename;
                    
                    % File-specific log
                    [~, baseName, ~] = fileparts(filename);
                    file_log = fullfile(log_dir, sprintf('%s_%s.log', baseName, datestr(now, 'yyyymmdd_HHMMSS')));
                    file_fid = fopen(file_log, 'w');
                    
                    if file_fid == -1
                        warning('Cannot open file log: %s. Using console output only.', file_log);
                    else
                        fprintf(file_fid, 'Processing file: %s\n', fullfile(filepath, filename));
                    end
                    
                    fprintf('Processing file %d/%d: %s\n', setIdx, numFiles, fullfile(filepath, filename));
                    EEG = pop_loadset('filename', filename, 'filepath', filepath);

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

                    % Define parameters for AMICA
                    numprocs = 1;  % Number of nodes (default 1)
                    max_threads = p_threads_per_worker;  % Use configured threads per worker

                    % Define outputs
                    outdir = fullfile(filepath, 'amicaout', baseName);
                    if ~exist(outdir, 'dir')
                        mkdir(outdir);
                    end
                    
                    statusFile = fullfile(outdir, 'status.txt');
                    txtout = fopen(statusFile, 'w');
                    if txtout == -1
                        error('Cannot open status file: %s', statusFile);
                    end

                    % Define cleanup function to delete temporary files if configured
                    if p_cleanup_temp_files
                        cleanupObj = onCleanup(@() analyze_ica.cleanup_temp_files(outdir));
                    end

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
                    if p_cleanup_temp_files
                        clear cleanupObj;
                    end

                    fprintf('Successfully processed and saved: %s\n', fullfile(filepath, newFileName));

                catch ME
                    % Handle errors for this iteration
                    fprintf('Error processing %s: %s\n', fullfile(fileList(setIdx).filepath, fileList(setIdx).filename), ME.message);
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

            % Shut down the parallel pool (optional)
            pool = gcp('nocreate'); % Get current pool without creating new one
            if ~isempty(pool)
                delete(pool);
                fprintf('Parallel pool closed.\n');
            end

            fprintf('AMICA processing completed for all datasets.\n');
            fprintf('Log files saved to: %s\n', log_dir);
        end

        %% Cleanup function to delete temporary files
        function cleanup_temp_files(outdir)
            % Delete temporary files in the output directory
            tempFiles = dir(fullfile(outdir, 'tmpdata*.fdt'));
            for k = 1:length(tempFiles)
                tempFilePath = fullfile(tempFiles(k).folder, tempFiles(k).name);
                if exist(tempFilePath, 'file')
                    delete(tempFilePath);
                    fprintf('Deleted temporary file: %s\n', tempFilePath);
                end
            end
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
