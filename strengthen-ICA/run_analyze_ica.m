% run_analyze_ica.m
% Last updated: [Feb27,2025]
% A MATLAB script to load configuration and call `analyze_ICA.m`
% Erin Schaeffer, Ido Haber

function run_analyze_ica(data_dir, config_file)
    % RUN_ANALYZE_ICA - Run strengthen ICA analysis on a project directory structure
    %
    % Syntax:
    %   run_analyze_ica(data_dir, config_file)
    %
    % Inputs:
    %   data_dir - Base directory for the project (optional, can be specified in config)
    %   config_file - Path to JSON configuration file
    
    if nargin < 1
        data_dir = '';  % Will be loaded from config if not provided
    end
    
    % Add paths
    if nargin < 2
        % Default path if no config provided
        eeglab_path = '~/eeglab';
        
        % Default project settings
        subjects = {};
        nights = {};
        file_template = '';
        
        % Log warning about missing configuration
        warning('No configuration file provided. Using default settings.');
    else
        % Load configuration from file
        try
            config = jsondecode(fileread(config_file));
            
            % Get EEGLAB path
            eeglab_path = getConfigValue(config, 'eeglab_path', '~/eeglab');
            
            % Get project structure if provided in config
            if isfield(config, 'project')
                project_config = config.project;
                
                % If data_dir is not provided as argument, try to get from config
                if isempty(data_dir) && isfield(project_config, 'data_dir')
                    data_dir = project_config.data_dir;
                end
                
                % Get subject list
                if isfield(project_config, 'subjects')
                    subjects = project_config.subjects;
                else
                    subjects = {};
                end
                
                % Get night list
                if isfield(project_config, 'nights')
                    nights = project_config.nights;
                else
                    nights = {};
                end
                
                % Get file template
                if isfield(project_config, 'file_template')
                    file_template = project_config.file_template;
                else
                    file_template = '';
                end
            else
                % No project configuration
                subjects = {};
                nights = {};
                file_template = '';
            end
            
            fprintf('Loaded configuration from %s\n', config_file);
        catch ME
            fprintf('Error loading config file: %s\nUsing default settings.\n', ME.message);
            
            % Default paths
            eeglab_path = '~/eeglab';
            
            % Empty project settings (will prompt user)
            subjects = {};
            nights = {};
            file_template = '';
        end
    end
    
    % Validate data_dir
    if isempty(data_dir)
        error('Project directory must be specified either as an argument or in the configuration file.');
    end
    
    % Add EEGLAB to path
    addpath(eeglab_path);
    
    % Initialize EEGLAB without GUI
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
    eeglab nogui;
    
    % Check if we need to interactively ask for project settings
    if isempty(subjects)
        % No subjects specified in config, check if we have subject directories
        dirs = dir(data_dir);
        potential_subjects = {dirs([dirs.isdir]).name};
        % Remove . and .. directories
        potential_subjects = potential_subjects(~ismember(potential_subjects, {'.', '..'}));
        
        if ~isempty(potential_subjects)
            % Use directory names as subjects
            subjects = potential_subjects;
            fprintf('Using directories as subjects: %s\n', strjoin(subjects, ', '));
        else
            error('No subject directories found in %s and no subjects specified in configuration.', data_dir);
        end
    end
    
    if isempty(nights)
        % Check the first subject directory for potential night directories
        if ~isempty(subjects)
            first_subject_dir = fullfile(data_dir, subjects{1});
            if isfolder(first_subject_dir)
                dirs = dir(first_subject_dir);
                potential_nights = {dirs([dirs.isdir]).name};
                % Remove . and .. directories
                potential_nights = potential_nights(~ismember(potential_nights, {'.', '..'}));
                
                if ~isempty(potential_nights)
                    % Use directory names as nights
                    nights = potential_nights;
                    fprintf('Using directories as nights: %s\n', strjoin(nights, ', '));
                else
                    % Default to a single "night" (current directory)
                    nights = {''};
                end
            else
                % Default to a single "night" (current directory)
                nights = {''};
            end
        else
            % Default to a single "night" (current directory)
            nights = {''};
        end
    end
    
    if isempty(file_template)
        % Look for .set files in the first subject/night directory to guess the pattern
        if ~isempty(subjects) && ~isempty(nights)
            first_subject = subjects{1};
            first_night = nights{1};
            
            if isempty(first_night)
                search_dir = fullfile(data_dir, first_subject);
            else
                search_dir = fullfile(data_dir, first_subject, first_night);
            end
            
            if isfolder(search_dir)
                files = dir(fullfile(search_dir, '*.set'));
                if ~isempty(files)
                    % Use the first .set file name as template
                    template_file = files(1).name;
                    fprintf('Found .set file: %s\n', template_file);
                    
                    % Try different template guessing strategies
                    
                    % Strategy 1: Direct replacement if subject/night are in the filename
                    template1 = template_file;
                    if contains(template1, first_subject)
                        template1 = strrep(template1, first_subject, '%s');
                        
                        if ~isempty(first_night) && contains(template1, first_night)
                            template1 = strrep(template1, first_night, '%s');
                        end
                    end
                    
                    % Strategy 2: Look for common pattern Prefix_Subject_Night_Suffix
                    template2 = template_file;
                    [~, basename, ~] = fileparts(template2);
                    if contains(basename, '_')
                        parts = strsplit(basename, '_');
                        if length(parts) >= 3
                            % Common format: "Strength_101_N1_forICA.set"
                            if ~isempty(first_night)
                                template2 = [parts{1}, '_%s_%s'];
                                if length(parts) > 3
                                    template2 = [template2, '_', strjoin(parts(4:end), '_')];
                                end
                                template2 = [template2, '.set'];
                            else
                                template2 = [parts{1}, '_%s'];
                                if length(parts) > 2
                                    template2 = [template2, '_', strjoin(parts(3:end), '_')];
                                end 
                                template2 = [template2, '.set'];
                            end
                        end
                    end
                    
                    % Strategy 3: Hardcoded templates for common formats
                    templates_to_try = {'Strength_%s_%s_forICA.set', '%s_%s_forICA.set', '%s_%s.set'};
                    if isempty(first_night)
                        templates_to_try = {'Strength_%s_forICA.set', '%s_forICA.set', '%s.set'};
                    end
                    
                    % Test all templates
                    working_templates = {};
                    
                    % Test strategy 1
                    try
                        if isempty(first_night)
                            test_name = sprintf(template1, first_subject);
                        else
                            test_name = sprintf(template1, first_subject, first_night);
                        end
                        
                        if exist(fullfile(search_dir, test_name), 'file')
                            working_templates{end+1} = template1;
                        end
                    catch
                        % Template doesn't work, skip it
                    end
                    
                    % Test strategy 2
                    try
                        if isempty(first_night)
                            test_name = sprintf(template2, first_subject);
                        else
                            test_name = sprintf(template2, first_subject, first_night);
                        end
                        
                        if exist(fullfile(search_dir, test_name), 'file')
                            working_templates{end+1} = template2;
                        end
                    catch
                        % Template doesn't work, skip it
                    end
                    
                    % Test hardcoded templates
                    for i = 1:length(templates_to_try)
                        try
                            if isempty(first_night)
                                test_name = sprintf(templates_to_try{i}, first_subject);
                            else
                                test_name = sprintf(templates_to_try{i}, first_subject, first_night);
                            end
                            
                            if exist(fullfile(search_dir, test_name), 'file')
                                working_templates{end+1} = templates_to_try{i};
                            end
                        catch
                            % Template doesn't work, skip it
                        end
                    end
                    
                    % Choose the best working template
                    if ~isempty(working_templates)
                        file_template = working_templates{1};
                        fprintf('Using guessed file template: %s\n', file_template);
                    else
                        % Fallback: Just use the exact filename (will be handled specially in analyze_ica.m)
                        fprintf('WARNING: Could not guess template. Using exact filename: %s\n', template_file);
                        file_template = template_file;
                    end
                else
                    error('No .set files found in %s and no file template specified in configuration.', search_dir);
                end
            else
                error('Directory %s does not exist and no file template specified in configuration.', search_dir);
            end
        else
            error('No subjects or nights available and no file template specified in configuration.');
        end
    end
    
    % Now call analyze_ica with the loaded configuration
    if nargin < 2
        % Call without config
        analyze_ica.run_amica_project(data_dir, subjects, nights, file_template);
    else
        % Call with config
        analyze_ica.run_amica_project(data_dir, subjects, nights, file_template, config_file);
    end
    
    % Done.
    fprintf('ICA analysis completed successfully!\n');
end

function value = getConfigValue(config, field, default_value)
    % Get value from config structure with support for nested fields
    
    % Parse field path (e.g., 'project.subjects')
    fields = strsplit(field, '.');
    current = config;
    
    for i = 1:length(fields)
        if isstruct(current) && isfield(current, fields{i})
            current = current.(fields{i});
        else
            value = default_value;
            return;
        end
    end
    
    value = current;
end
