% analyze_ica.m
% Last updated: [Feb27,2025]
% Use: Functions to perform ICA on EEG data using AMICA in parallel
% Erin Schaeffer, Ido Haber

% Make sure you have Parallel Computing Toolbox installed

classdef analyze_ica
    methods (Static)
        %% Main method to run AMICA on datasets organized by project, subjects, and nights
        function run_amica_project(experiment_path, subjects, nights, setFileTemplate)
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

            % Initialize list to hold .set file information
            fileList = struct('filepath', {}, 'filename', {});

            % Iterate over subjects and nights to build file list
            fprintf('Scanning directories for .set files...\n');
            for subjIdx = 1:length(subjects)
                for nightIdx = 1:length(nights)
                    % Define current subject and night
                    whichSubj = subjects{subjIdx};
                    whichNight = nights{nightIdx};

                    % Define file name using the setFileTemplate
                    % The template should include two '%s' placeholders for subject and night
                    name_temp = sprintf(setFileTemplate, whichSubj, whichNight);
                    % Example: 'Strength_123_N1_filt_bc_we_rmwk_noZ_rmepoch_rmbs_bc.set'

                    % Define file path
                    filepath = fullfile(experiment_path, whichSubj, whichNight);
                    fullFilePath = fullfile(filepath, name_temp);

                    % Check if file exists
                    if exist(fullFilePath, 'file')
                        % Add to fileList
                        fileList(end+1).filepath = filepath; %#ok<AGROW>
                        fileList(end).filename = name_temp;
                        fprintf('Found file: %s\n', fullFilePath);
                    else
                        warning('File not found: %s', fullFilePath);
                    end
                end
            end

            numFiles = length(fileList);

            if numFiles == 0
                error('No .set files found based on the provided project directory, subjects, nights, and set file template.');
            end

            fprintf('Total .set files to process: %d\n', numFiles);

            % Determine the number of CPU cores
            totalCores = feature('numcores');

            % Adjust numWorkers based on your requirements
            if totalCores >= 64
                numWorkers = min(floor(totalCores / 2), 64);
            else
                numWorkers = floor(totalCores / 2);
            end

            % Ensure at least one worker is used
            numWorkers = max(1, numWorkers);

            fprintf('Total CPU cores available: %d\n', totalCores);
            fprintf('Initializing parallel pool with %d workers.\n', numWorkers);

            % Start a parallel pool with the desired number of workers
            pool = gcp('nocreate'); % Get current pool without creating new one
            if isempty(pool)
                parpool('local', numWorkers);
            else
                fprintf('Using existing parallel pool with %d workers.\n', pool.NumWorkers);
            end

            % Use parfor to process files in parallel
            parfor setIdx = 1:numFiles
                try
                    % Load dataset
                    filepath = fileList(setIdx).filepath;
                    filename = fileList(setIdx).filename;
                    fprintf('Processing file %d/%d: %s\n', setIdx, numFiles, fullfile(filepath, filename));
                    EEG = pop_loadset('filename', filename, 'filepath', filepath);

                    % Check and remove 'Cz' channel if present
                    cz_ind = find(contains({EEG.chanlocs.labels}, 'Cz'));
                    if ~isempty(cz_ind)
                        fprintf('Removing Cz channel in %s\n', filename);
                        EEG = pop_select(EEG, 'nochannel', cz_ind);
                    end

                    % Define parameters for AMICA
                    numprocs = 1;         % Number of nodes (default 1)
                    max_threads = 1;      % Use only 1 thread
                    num_models = 1;       % Number of models of mixture ICA
                    max_iter = 1000;      % Max number of learning steps

                    % Extract the base name of the .set file (without extension)
                    [~, baseName, ~] = fileparts(filename);

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

                    % Define cleanup function to delete temporary files
                    cleanupObj = onCleanup(@() analyze_ica.cleanup_temp_files(outdir));

                    % Run AMICA with 1 thread
                    fprintf(txtout, 'Running runamica15 with 1 thread\n');
                    tic;

                    runamica15(EEG.data, 'num_models', num_models, 'outdir', outdir, ...
                        'numprocs', numprocs, 'max_threads', max_threads, 'max_iter', max_iter);

                    elapsedTime = toc;
                    fprintf(txtout, 'runamica15 success\n');
                    fprintf(txtout, 'Elapsed time: %.5f seconds\n', elapsedTime);

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

                    % Delete the cleanup object to prevent deletion of necessary files
                    clear cleanupObj;

                    fprintf('Successfully processed and saved: %s\n', fullfile(filepath, newFileName));

                catch ME
                    % Handle errors for this iteration
                    fprintf('Error processing %s: %s\n', fullfile(fileList(setIdx).filepath, fileList(setIdx).filename), ME.message);
                end
            end

            % Shut down the parallel pool (optional)
            pool = gcp('nocreate'); % Get current pool without creating new one
            if ~isempty(pool)
                delete(pool);
                fprintf('Parallel pool closed.\n');
            end

            fprintf('AMICA processing completed for all datasets.\n');
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
