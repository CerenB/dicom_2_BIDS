function create_participants_tsv(tgt_dir, ls_sub_id, age, gender)

    filename = fullfile(tgt_dir, 'participants.json');

    headers = {'participant_id' 'age' 'sex'};
    opts.indent = '    ';
    
    nb_sub = numel(ls_sub_id);
    
    DestName = fullfile(tgt_dir, 'participants.tsv');
    OFilefID = fopen (DestName, 'w');
    
    fprintf(OFilefID, '%s\t%s\t%s\n', headers{1}, headers{2}, headers{3} );
    
    for iSub = 1:nb_sub
        fprintf (OFilefID, '%s\t%i\t%s\n', ...
            ls_sub_id{iSub}, ...
            age(iSub), ...
            gender(iSub));
    end
    
    fclose (OFilefID);
    
    % create corresponding data dictionary
    content.participant_id = struct(...
        'LongName', 'participant ID', ...
        'Description', ' ', ...
        'Levels', struct(), ...
        'Units', ' ',...
        'TermURL', ' ');
    content.age = struct(...
        'LongName', 'age', ...
        'Description', ' ', ...
        'Levels', struct(), ...
        'Units', 'years from birth',...
        'TermURL', ' ');
    content.sex = struct(...
        'LongName', 'gender', ...
        'Description', ' ', ...
        'Levels', struct('M', 'male', 'F', 'female'), ...
        'Units', ' ',...
        'TermURL', ' ');
    
    spm_jsonwrite(filename, content, opts)
    
end

