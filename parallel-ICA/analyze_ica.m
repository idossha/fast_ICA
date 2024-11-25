% analyze_ica.m
% v.0.0.5 - Adjusted numWorkers based on the number of CPU cores
% Last updated: [Nov23,2024]
% Use: Functions to perform ICA on EEG data using AMICA in parallel
% Erin Schaeffer, Ido Haber

classdef analyze_ica
    methods(Static)
        % Given a directory path, run AMICA on all .set files in the directory
        function run_amica(path)
            % Get list of .set files
            allSets = dir(fullfile(path, '*.set'));
            numFiles = length(allSets);

            if numFiles == 0
                error('No .set files found in the specified directory.');
            end

            % Determine the number of CPU cores
            totalCores = feature('numcores');

            % Adjust numWorkers based on your requirements
            if totalCores >= 64
                numWorkers = min(floor(totalCores / 2), 64);
            else
                numWorkers = min(floor(totalCores / 2));
            end

            % Ensure at least one worker is used
            numWorkers = max(1, numWorkers);

            fprintf('Total CPU cores: %d\n', totalCores);
            fprintf('Using %d parallel workers.\n', numWorkers);

            % Start a parallel pool with the desired number of workers
            if isempty(gcp('nocreate'))
                parpool('local', numWorkers);
            end

            % Use parfor to process files in parallel
            parfor setIdx = 1:numFiles
                try
                    % Load dataset
                    filepath = allSets(setIdx).folder;
                    filename = allSets(setIdx).name;
                    EEG = pop_loadset(filename, filepath);

                    % Check and remove 'Cz' channel if present
                    cz_ind = find(contains({EEG.chanlocs.labels}, 'Cz'));
                    if ~isempty(cz_ind)
                        fprintf('Removing Cz channel in %s\n', filename);
                        EEG = pop_select(EEG, 'nochannel', cz_ind);
                    end

                    % Define parameters
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
                    cleanupObj = onCleanup(@() cleanup_temp_files(outdir));

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

                catch ME
                    % Handle errors for this iteration
                    fprintf('Error processing %s: %s\n', filename, ME.message);
                end
            end

            % Shut down the parallel pool (optional)
            % delete(gcp('nocreate'));
        end
    end
end


% % Function to clean up temporary files
% function cleanup_temp_files(outdir)
%     % Delete temporary files in the output directory
%     tempFiles = dir(fullfile(outdir, 'tmpdata*.fdt'));
%     for k = 1:length(tempFiles)
%         tempFilePath = fullfile(tempFiles(k).folder, tempFiles(k).name);
%         if exist(tempFilePath, 'file')
%             delete(tempFilePath);
%             fprintf('Deleted temporary file: %s\n', tempFilePath);
%         end
%     end
% end
%
