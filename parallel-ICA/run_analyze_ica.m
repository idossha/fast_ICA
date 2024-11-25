% run_analyze_ica.m

function run_analyze_ica(inputPath)
    % This function runs analyze_ica.run_amica on the specified path

    % Add EEGLAB to the MATLAB path
    addpath('/Users/idohaber/Documents/MATLAB/eeglab2024.0/');  % Replace with the actual path to your EEGLAB folder

    % Start EEGLAB without GUI
    eeglab nogui;

    % Call your analyze_ica class
    analyze_ica.run_amica(inputPath);
end

