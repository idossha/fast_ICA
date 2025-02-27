% analyze_ica.m
% v.1.0.0 - Enhanced with configuration system
% Last updated: [Feb27,2025]
% Use: Functions to perform ICA on EEG data using AMICA in serial mode
% Erin Schaeffer, Ido Haber

classdef analyze_ica
    methods(Static)
        % Given a single .set file, run AMICA to perform ICA
        function run_amica(path, config_file)
            % Configure logging
            log_dir = fullfile(fileparts(path), 'logs');
            if ~exist(log_dir, 'dir')
                mkdir(log_dir);
            end
            
            % Create log file for this run
            [~, file_base, ~] = fileparts(path);
            log_file = fullfile(log_dir, sprintf('serial_ica_%s_%s.log', file_base, datestr(now, 'yyyymmdd_HHMMSS')));
            log_fid = fopen(log_file, 'w');
            
            if log_fid == -1
                warning('Cannot open log file: %s. Using console output only.', log_file);
            else
                fprintf(log_fid, 'Processing file: %s\n', path);
            end
            
            try
                % Load configuration if provided
                if nargin < 2
                    % Default configuration
                    max_threads = 2;
                    fallback_threads = 1;
                    num_models = 1;
                    max_iter = 1000;
                    remove_cz = true;
                else
                    % Load from config file
                    try
                        config = jsondecode(fileread(config_file));
                        
                        % Get implementation parameters
                        impl_config = config.implementation;
                        max_threads = getConfigParam(impl_config, 'max_threads', 2);
                        fallback_threads = getConfigParam(impl_config, 'fallback_threads', 1);
                        
                        % Get AMICA parameters
                        amica_config = config.amica;
                        num_models = getConfigParam(amica_config, 'num_models', 1);
                        max_iter = getConfigParam(amica_config, 'max_iter', 1000);
                        remove_cz = getConfigParam(amica_config, 'remove_cz', true);
                        
                        fprintf('Loaded configuration from %s\n', config_file);
                        if log_fid ~= -1
                            fprintf(log_fid, 'Loaded configuration from %s\n', config_file);
                        end
                    catch ME
                        fprintf('Error loading config file: %s\nUsing default parameters.\n', ME.message);
                        if log_fid ~= -1
                            fprintf(log_fid, 'Error loading config file: %s\nUsing default parameters.\n', ME.message);
                        end
                        % Default configuration if loading fails
                        max_threads = 2;
                        fallback_threads = 1;
                        num_models = 1;
                        max_iter = 1000;
                        remove_cz = true;
                    end
                end
                
                % Load dataset
                [filepath, filename, ext] = fileparts(path);
                filename = [filename ext]; % Reconstruct full filename with extension
                
                fprintf('Loading dataset: %s\n', filename);
                if log_fid ~= -1
                    fprintf(log_fid, 'Loading dataset: %s\n', filename);
                end
                
                EEG = pop_loadset(filename, filepath);
                
                % Check and remove 'Cz' channel if configured and present
                if remove_cz
                    cz_ind = find(contains({EEG.chanlocs.labels}, 'Cz'));
                    if ~isempty(cz_ind)
                        fprintf('Removing Cz channel in %s\n', filename);
                        if log_fid ~= -1
                            fprintf(log_fid, 'Removing Cz channel\n');
                        end
                        EEG = pop_select(EEG, 'nochannel', cz_ind);
                    end
                end
                
                % Define base parameters
                numprocs = 1;  % Number of nodes (default 1)
                
                % Define outputs
                outdir = fullfile(filepath, 'amicaout', filename(1:end-4));
                if ~exist(outdir, 'dir')
                    mkdir(outdir);
                end
                
                statusFile = fullfile(outdir, 'status.txt');
                txtout = fopen(statusFile, 'w');
                if txtout == -1
                    error('Cannot open status file: %s', statusFile);
                end
                
                % Attempt to execute runamica15 from max_threads to fallback_threads
                success = false;
                
                for iThread = max_threads:-1:fallback_threads
                    try
                        fprintf(txtout, '\n');
                        fprintf(txtout, 'Trying runamica15 with %d thread(s)\n', iThread);
                        if log_fid ~= -1
                            fprintf(log_fid, 'Trying runamica15 with %d thread(s)\n', iThread);
                        end
                        
                        tic;
                        runamica15(EEG.data, 'num_models', num_models, 'outdir', outdir, ...
                            'numprocs', numprocs, 'max_threads', iThread, 'max_iter', max_iter);
                        
                        success = true;
                        break;
                    catch ME
                        fprintf(txtout, 'runamica15 failed with %d thread(s): %s\n', iThread, ME.message);
                        if log_fid ~= -1
                            fprintf(log_fid, 'runamica15 failed with %d thread(s): %s\n', iThread, ME.message);
                        end
                        continue;
                    end
                end
                
                if ~success
                    error('runamica15 failed with all thread configurations');
                end
                
                % Log success
                elapsedTime = toc;
                fprintf(txtout, 'runamica15 success\n');
                fprintf(txtout, 'Elapsed time: %.5f seconds\n', elapsedTime);
                
                if log_fid ~= -1
                    fprintf(log_fid, 'runamica15 success\n');
                    fprintf(log_fid, 'Elapsed time: %.5f seconds\n', elapsedTime);
                end
                
                fclose(txtout);
                
                % Add AMICA info to EEG struct
                fprintf('Loading AMICA results\n');
                if log_fid ~= -1
                    fprintf(log_fid, 'Loading AMICA results\n');
                end
                
                EEG.etc.amica = loadmodout15(outdir);
                EEG.icaweights = EEG.etc.amica.W;  % Unmixing weights
                EEG.icasphere = EEG.etc.amica.S;   % Sphering matrix
                EEG.icawinv = EEG.etc.amica.A;     % Model component matrices
                EEG = eeg_checkset(EEG, 'ica');    % Update EEG.icaact
                
                % Rename set
                newFileName = [filename(1:end-4) '_wcomps.set'];
                EEG.setname = newFileName;
                
                % Save EEG data
                fprintf('Saving dataset with ICA components: %s\n', newFileName);
                if log_fid ~= -1
                    fprintf(log_fid, 'Saving dataset with ICA components: %s\n', newFileName);
                end
                
                EEG = pop_saveset(EEG, 'filename', newFileName, 'filepath', filepath);
                
                % Final success message
                fprintf('Processing complete for %s\n', filename);
                if log_fid ~= -1
                    fprintf(log_fid, 'Processing complete for %s\n', filename);
                    fclose(log_fid);
                end
                
            catch ME
                % Handle errors
                fprintf('Error processing %s: %s\n', path, ME.message);
                
                if log_fid ~= -1
                    fprintf(log_fid, 'ERROR: %s\n', ME.message);
                    fprintf(log_fid, 'Stack trace:\n');
                    for k = 1:length(ME.stack)
                        fprintf(log_fid, '  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
                    end
                    fclose(log_fid);
                end
                
                % Re-throw error
                rethrow(ME);
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
