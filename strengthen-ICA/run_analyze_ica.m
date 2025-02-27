% run_analyze_ica.m
% Ido Haber, February 2025
% A single MATLAB script to set all parameters and calls `analyze_ica.m`

clear; clc; close all;

% -------------------------------------------------------
% 1) Add your necessary paths (EEGLAB, utility functions, etc.)
% -------------------------------------------------------
% Replace these with real folder paths on your system/HPC:
addpath('/home/ihaber@ad.wisc.edu/eeglab2024.2');  % Tononi-1
addpath('utils');  % if you have a local "utils" folder

% -------------------------------------------------------
% 2) Initialize EEGLAB in nogui mode
% -------------------------------------------------------
eeglab nogui;

% -------------------------------------------------------
% 3) Set your data location and subject details
% -------------------------------------------------------
% Path to your dataset
experiment_path = '/Volumes/nccam_scratch/NCCAM_scratch/Ido/TI_SourceLocalization/Data';

% Define subjects and nights (hard-coded here)
subjects = {'103','106','108','109','111','112','114','117','118','120','122','124','129','131','132','133','134'};
nights   = {'N1'};  % or add more: {'N1','N2','N3'}


% -------------------------------------------------------
% 4) Define the .set file template for the run_amica call
% -------------------------------------------------------
setFileTemplate = 'Strength_%s_%s_forICA.set';
% or whatever you need:
% setFileTemplate = 'Strength_%s_%s_filt_bc_we_rmwk_noZ_rmepoch_rmbs_bc.set';

% -------------------------------------------------------
% 5) Call your main ICA routine
% -------------------------------------------------------
analyze_ica.run_amica_project( ...
    experiment_path, ...
    subjects, ...
    nights, ...
    setFileTemplate ...
);

% Done.
disp('ICA analysis completed successfully!');
