% run_analyze_ica.m

function run_analyze_ica(inputPath, config_file)
    % RUN_ANALYZE_ICA - Run serial ICA analysis on a single .set file
    %
    % Syntax:
    %   run_analyze_ica(inputPath, config_file)
    %
    % Inputs:
    %   inputPath - Path to a .set file
    %   config_file - Path to JSON configuration file (optional)

    % Add paths
    if nargin < 2
        % Default path if no config provided
        eeglab_path = '~/eeglab';
    else
        eeglab_path = getConfigValue(config_file, 'eeglab_path', '~/eeglab');
    end
    
    addpath(eeglab_path);

    % Start EEGLAB without GUI
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
    eeglab nogui;

    % Call analyze_ica function to process the data
    if nargin < 2
        analyze_ica.run_amica(inputPath);
    else
        analyze_ica.run_amica(inputPath, config_file);
    end
end

function value = getConfigValue(config_file, key, default_value)
    % Get value from config file or use default

    if ~exist('config_file', 'var') || isempty(config_file) || ~exist(config_file, 'file')
        value = default_value;
        return;
    end

    try
        config = jsondecode(fileread(config_file));
        
        % Parse key path (e.g., 'implementation.max_workers')
        key_parts = strsplit(key, '.');
        current = config;
        
        for i = 1:length(key_parts)
            if isfield(current, key_parts{i})
                current = current.(key_parts{i});
            else
                current = [];
                break;
            end
        end
        
        if ~isempty(current)
            value = current;
        else
            value = default_value;
        end
    catch
        fprintf('Error reading config file: %s\n', config_file);
        value = default_value;
    end
end

