% analyze_ica.m
% v.0.0.1 - (ELS 10/11/23) - name setname after filename before saving
% last (ELS) - v.0.0.0 - initial commit
% use - functions to perform ica on EEG data

classdef analyze_ica
    methods(Static)
        % given _readyForICA.set file, run amica to perform ICA
        function run_amica(path)
            % loop over .set files and run amica
            allSets = dir(path);
            for setIdx = 1:length(allSets)

                % load dataset
                filepath = allSets(setIdx).folder;
                filename = allSets(setIdx).name;
                EEG = pop_loadset(filename, filepath);

                % check to see if 'Cz' chan is in file (typically last index)
                % remove if present (causes eeg_checkset error)
                cz_ind = find(contains({EEG.chanlocs(:).labels}, 'Cz'));
                if cz_ind
                    fprintf('Removing Cz channel \n')
                    EEG = pop_select(EEG, 'nochannel', cz_ind);
                end

                % define parameters
                numprocs = 1;       % # of nodes (1-4: default 1)
                max_threads = 2;    % max # of threads to try to run
                num_models = 1;     % # of models of mixture ICA
                max_iter = 1000;    % max number of learning steps orig 1000 changed to 2000

                % define outputs
                outdir = [filepath,'/amicaout/'];
                if ~exist(outdir)
                    mkdir(outdir)
                end
                txtout = fopen(fullfile(outdir, 'status.txt'), 'w');

                % attempt to execute runamica15 from max_threads # backwards to 1 (eg., 3 will try 3,2,1)
                % NOTE: amicaout folder must be EMPTY before starting this loop (else it thinks any thread works)
                for iThread=max_threads:-1:1
                    try
                        fprintf(txtout, '\n');
                        fprintf(txtout, 'trying to runamica15 with %g threads \n', iThread);
                        tic

                        runamica15(EEG.data, 'num_models',num_models, 'outdir',outdir,'numprocs', numprocs, 'max_threads', iThread, 'max_iter',max_iter);

                        break

                    catch ME
                        fprintf(txtout, 'runamica15 failed: %s \n', ME.message);
                        continue;
                    end
                end %iThread

                % assume successful run
                fprintf(txtout, 'runamica15 success \n');
                fprintf(txtout, 'elapsed time: %.5f \n', toc);
                fprintf(txtout, '\n');

                % add amica info to EEG struct
                EEG.etc.amica  = loadmodout15(outdir);
                %EEG.etc.amica.S = EEG.etc.amica.S(1:EEG.etc.amica.num_pcs, :); % Weirdly, I saw size(S,1) be larger than rank. This process does not hurt anyway.
                EEG.icaweights = EEG.etc.amica.W; % unmixing weights
                EEG.icasphere  = EEG.etc.amica.S; % sphering matrix
                EEG.icawinv = EEG.etc.amica.A; % model component matrices
                EEG = eeg_checkset(EEG, 'ica'); % update EEG.icaact

                % rename set
                fileName = fullfile(EEG.filepath, [EEG.filename(1:end-4) '_wcomps.set']);
                EEG.filename = fileName;
                EEG.setname = fileName;

                % save EEG data
                EEG = pop_saveset(EEG,fileName);

            end %setIdx
        end %function

    end %methods
end %classdef
