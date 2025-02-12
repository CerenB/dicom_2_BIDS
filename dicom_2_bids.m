% script to import DICOM and format them into a BIDS structure
% while saving json and creating a participants.tsv file
% also creates a dataset_decription.json with empty fields

% REQUIRES
% - SPM12 7487
% - DICOM2NII (included in this repo)

% in theory a lot of the parameters can be changed in the parameters
% section at the beginning of the script

% in general make sure you have removed from your subjects source folder
% any folder that you do not want to convert (interrupted sequences for example)

% at the moment this script is not super flexible and assumes only one session
% and can only deal with anatomical functional and DWI.

% it also makes some assumption on the number of DWI, ANAT runs (only takes 1).

% the way the subject naming happens is hardcoded

% the script can remove up to 9 dummy scans (they are directly moved from the
% dicom source folder and put in a 'dummy' folder) so that dicm2nii does
% not "see" them

% the way event.tsv files are generated is very unflexible
% also the stimulus onset is not yet recalculated depending on the number
% of dummies removed

% there will still some cleaning up to do in the json files: for example
% most likely you will only want to have json files in the root folder and
% that apply to all inferior levels rather than one json file per nifti
% file (make use of the inheritance principle)

% json files created will be modified to remove any field with 'Patient' in
% it and the phase encoding direction will be re-encoded in a BIDS
% compliant way (i, j, k, i-, j-, k-)

% the participants.tsv file is created based on the header info of the
% anatomical (sex and age) so it might not be accurate

% TO DO
% - documentation !!!!!
% - extract participant weight from header and put in tsv file?
% - make sure that all parts that should be tweaked (or hard coded are in separate functions)
% - subject renaming should be more flexible
% - allow for removal of more than 9 dummy scans
% - move json file of each modality into the source folder
% - deal with sessions



clear
clc

%% Set directories
% fullpath of the spm 12 folder
% spm_path = '/home/remi-gau/Documents/SPM/spm12';

spm_path = 'D:\Dropbox\Code\MATLAB\Neuroimaging\SPM\spm12';

% fullpaths
% src_dir = '/home/remi-gau/BIDS/Olf_Blind/source/DICOM'; % source folder
% tgt_dir = '/home/remi-gau/BIDS/Olf_Blind/raw'; % target folder
% opt.onset_files_dir = '/home/remi-gau/BIDS/Olf_Blind/source/Results';

src_dir = 'D:\Dropbox\BIDS\olf_blind\source\DICOM'; % source folder
tgt_dir = 'D:\Dropbox\BIDS\olf_blind\source\raw'; % target folder
opt.onset_files_dir = 'D:\Dropbox\BIDS\olf_blind\source\Results';


%% Parameters definitions
% select what to convert and transfer
do_anat = 0;
do_func = 1;
do_dwi = 0;


opt.zip_output = 0; % 1 to zip the output into .nii.gz (not ideal for
% SPM users)
opt.delete_json = 1; % in case you have already created the json files in
% another way (or you have already put some in the root folder)
opt.do = 0; % actually convert DICOMS, can be usefull to set to false
% if only events files or something similar must be created


% DICOM folder patterns to look for
subject_dir_pattern = 'Olf_Blind_C02*';


% Details for ANAT
% target folders to convert
opt.src_anat_dir_patterns = {
    'acq-mprage_T1w', ...
    'acq-tse_t2-tse-cor-'};

% corresponding names for the output file in BIDS data set
opt.tgt_anat_dir_patterns = {
    '_T1w', ...
    '_acq-tse_T2w'};


% Details for FUNC
opt.src_func_dir_patterns = {
    'bold_run-[1-2]';...
    'bold_run-[3-4]';...
    'bold_RS'};
opt.task_name = {...
    'olfid'; ...
    'olfloc'; ...
    'rest'};
opt.get_onset = [
    1;... 
    1;...
    0];
opt.get_stim = [
    1;...
    1;...
    0];
opt.nb_folder = [;...
    2;...
    2;...
    1];
opt.stim_patterns = {...
    '^Breathing.*[Ii]den[_]?[0]?[1-2].*.txt$'; ...
    '^Breathing.*[Ll]oc[_]?[0]?[1-2].*.txt$' ;...
    ''};
opt.events_patterns = {...
    '^Results.*.txt$';...
    '^Results.*.txt$';...
    ''};
opt.events_src_file = {
    1:2;...
    3:4;...
    []};

opt.nb_dummies = 8; %9 MAX!!!!


% Details for DWI
% target folders to convert
opt.src_dwi_dir_patterns = {...
    'pa_dwi', ...
    'ap_b0'};
% corresponding names for the output file in BIDS data set
opt.tgt_dwi_dir_patterns = {
    '_dwi', ...
    '_sbref'};
% take care of eventual bval bvec values
opt.bvecval = [...
    1; ...
    0];


% option for json writing
opt.indent = '    ';


%% set path and directories
addpath(genpath(fullfile(pwd, 'subfun')))
addpath(fullfile(pwd,'dicm2nii'))

addpath(spm_path)

% check spm version
[a, b] = spm('ver');
if any(~[strcmp(a, 'SPM12') strcmp(b, '7487')])
    str = sprintf('%s\n%s', ...
        'The current version SPM version is not SPM12 7487.', ...
        'In case of problems (e.g json file related) consider updating.');
    warning(str); %#ok<*SPWRN>
end
clear a b
spm('defaults','fmri')

mkdir(tgt_dir)

% We create json files and do not save the patient code name
setpref('dicm2nii_gui_para', 'save_patientName', false);
setpref('dicm2nii_gui_para', 'save_json', true);

% Give some time to zip the files before we rename them
if opt.zip_output
    opt.pauseTime = 30; %#ok<*UNRCH>
else
    opt.pauseTime = 1;
end


%% let's do this

% create general json and data dictionary files
create_dataset_description_json(tgt_dir, opt)

% get list of subjsects
subj_ls = dir(fullfile(src_dir, subject_dir_pattern));
nb_sub = numel(subj_ls);


for iSub = 1:nb_sub % for each subject
    
    opt.iSub = iSub;
    
    % creating name of the subject ID (folder and filename)
    if strcmp(subj_ls(iSub).name(11), 'B')
        sub_id = 'sub-blnd';
    elseif strcmp(subj_ls(iSub).name(11), 'C')
        sub_id = 'sub-ctrl';
    end
    sub_id = [sub_id subj_ls(iSub).name(12:end)]; %#ok<*AGROW>
    
    % keep track of the subjects ID to create participants.tsv
    ls_sub_id{iSub} = sub_id; %#ok<*SAGROW>
    
    fprintf('\n\n\nProcessing %s\n', sub_id)
    
    % creating directories in BIDS structure
    sub_src_dir = fullfile(src_dir, subj_ls(iSub).name);
    sub_tgt_dir = fullfile(tgt_dir, sub_id);
    spm_mkdir(sub_tgt_dir, {'anat', 'func', 'dwi'});
    
    
    %% Anatomy folders
    if do_anat
        
        fprintf('\n\ndoing ANAT\n')
        
        %% do T1w
        % we set the patterns in DICOM folder names too look for in the
        % source folder
        pattern.input = opt.src_anat_dir_patterns{1};
        % we set the pattern to in the target file in the BIDS data set
        pattern.output = opt.tgt_anat_dir_patterns{1};
        % we ask to return opt because that is where the age and gender of
        % the participants is stored
        [opt, anat_tgt_dir] = convert_anat(sub_id, sub_src_dir, sub_tgt_dir, pattern, opt);
        
        
        %% do T2 olfactory bulb high-res image
        pattern.input = opt.src_anat_dir_patterns{2};
        pattern.output = opt.tgt_anat_dir_patterns{2};
        convert_anat(sub_id, sub_src_dir, sub_tgt_dir, pattern, opt);
        
        % clean up
        delete(fullfile(anat_tgt_dir, '*.mat'))
        if opt.delete_json
            delete(fullfile(anat_tgt_dir, '*.json'))
        end
        
    end
    
    
    %% BOLD series
    if do_func
        
        fprintf('\n\ndoing FUNC\n')
        
        if opt.nb_dummies > 0
            opts.indent = opt.indent;
            filename = fullfile(tgt_dir, 'discarded_dummy.json');
            content.NumberOfVolumesDiscardedByUser = opt.nb_dummies;
            spm_jsonwrite(filename, content, opts)
        end
       
        for task_idx = 1:numel(opt.task_name)
            fprintf('\n\n doing TASK: %s\n', opt.task_name{task_idx})
            create_events_json(tgt_dir, opt, task_idx)
            create_stim_json(tgt_dir, opt, task_idx)
            [func_tgt_dir] = convert_func(sub_id, subj_ls, sub_src_dir, sub_tgt_dir, opt, task_idx);
        end

        % clean up
        delete(fullfile(func_tgt_dir, '*.mat'))
        if opt.delete_json
            delete(fullfile(func_tgt_dir, '*.json'))
        end
        
    end
    
    %% deal with diffusion imaging
    if do_dwi

         fprintf('\n\ndoing DWI\n')
        
        %% do DWI
        % we set the patterns in DICOM folder names too look for in the
        % source folder
        pattern.input = opt.src_dwi_dir_patterns{1};
        % we set the pattern to in the target file in the BIDS data set
        pattern.output = opt.tgt_dwi_dir_patterns{1};

        bvecval = opt.bvecval(1);
        
        [dwi_tgt_dir] = convert_dwi(sub_id, sub_src_dir, sub_tgt_dir, bvecval, pattern, opt);

        if opt.delete_json
            delete(fullfile(dwi_tgt_dir, '*.json'))
        end
        
        %% do b_ref
        pattern.input = opt.src_dwi_dir_patterns{2};
        % we set the pattern to in the target file in the BIDS data set
        pattern.output = opt.tgt_dwi_dir_patterns{2};

        bvecval = opt.bvecval(2);
        
        convert_dwi(sub_id, sub_src_dir, sub_tgt_dir, bvecval, pattern, opt);
        

        %% clean up
        delete(fullfile(dwi_tgt_dir, '*.mat'))
        delete(fullfile(dwi_tgt_dir, '*.txt'))

        
    end
    
end


%% print participants.tsv file
if do_anat && opt.do
    create_participants_tsv(tgt_dir, ls_sub_id, opt.age, opt.gender);
end

message = 'REMEMBER TO CHECK IF YOU HAVE A VALID BIDS DATA SET BY USING THE BIDS VALIDATOR:';
bids_validator_URL = 'https://bids-standard.github.io/bids-validator/';
fprintf('\n\n%s\n\n%s\n\n', message, bids_validator_URL)
