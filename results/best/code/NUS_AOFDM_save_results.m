function output_dir = NUS_AOFDM_save_results
% Save the current MATLAB decoding session without running TX or recording.
root_dir = fileparts(mfilename('fullpath'));
saved_at = datetime('now','TimeZone','Asia/Bangkok', ...
    'Format','yyyyMMdd_HHmmss_SSS');
output_dir = fullfile(root_dir,'runs',char(saved_at));
folders = {'figures','results','recording','config','code'};
for k = 1:numel(folders)
    mkdir(fullfile(output_dir,folders{k}));
end

% Copy the decoding values from the caller's live base workspace.
names = {'y','fs','fc','TX_time','RX_time','mic_id','preferred_microphone', ...
    'fo_pilot','Preamble_matched','accum','ch_tbl','DemA','DemPixel', ...
    'Demdata','ST','Pf_GI','GI','P','Np','Nf','Ns','N','MM','NN','KK', ...
    'Preamble','DILindex','Gain'};
snapshot = struct;
for k = 1:numel(names)
    name = names{k};
    if evalin('base',sprintf('exist(''%s'',''var'')',name))
        snapshot.(name) = evalin('base',name);
    end
end
save(fullfile(output_dir,'results','decoding_workspace.mat'), ...
    '-struct','snapshot','-v7.3');
if isfield(snapshot,'y') && isfield(snapshot,'fs')
    recording_fields = intersect({'y','fs','fo_pilot','Preamble_matched'}, ...
        fieldnames(snapshot),'stable');
    save(fullfile(output_dir,'recording','NUS_AOFDM_RX_debug.mat'), ...
        '-struct','snapshot',recording_fields{:});
end
parameter_names = {'Pf_GI','GI','P','Np','Nf','Ns','N','fc','fs','MM', ...
    'NN','KK','TX_time','Preamble','DILindex','Gain'};
parameter_names = intersect(parameter_names,fieldnames(snapshot),'stable');
if ~isempty(parameter_names)
    save(fullfile(output_dir,'config','session_TX_parameters.mat'), ...
        '-struct','snapshot',parameter_names{:});
end

labels = {'receiver_diagnostics','transmitter_signal', ...
    'recovered_image','receiver_instructions'};
figure_numbers = [];
for number = 1:4
    h = findall(groot,'Type','figure','Number',number);
    if isempty(h)
        continue;
    end
    stem = sprintf('Figure_%02d_%s',number,labels{number});
    savefig(h(1),fullfile(output_dir,'figures',[stem '.fig']));
    exportgraphics(h(1),fullfile(output_dir,'figures',[stem '.png']), ...
        'Resolution',200);
    figure_numbers(end+1) = number; %#ok<AGROW>
    if number == 3
        image_handles = findall(h(1),'Type','image');
        if ~isempty(image_handles)
            displayed_image = get(image_handles(1),'CData');
            imwrite(displayed_image,fullfile(output_dir,'results','recovered_image.png'));
        end
    end
end
if isfield(snapshot,'DemA')
    imwrite(snapshot.DemA, ...
        fullfile(output_dir,'results','decoded_workspace_image.png'));
end

% Keep the files on disk separately from the live session parameters above.
config_files = {'NUS_AOFDM_TX_parameters.mat','NUS_AOFDM_TX.wav', ...
    'NUS_AOFDM_TX_tx.mat','myphoto.jpg'};
for k = 1:numel(config_files)
    source = fullfile(root_dir,config_files{k});
    if exist(source,'file') == 2
        copyfile(source,fullfile(output_dir,'config',config_files{k}));
    end
end
code_files = {'NUS_AOFDM_TX.m','NUS_AOFDM_DEM.m', ...
    'NUS_AOFDM_refine_recording.m','NUS_AOFDM_save_results.m'};
for k = 1:numel(code_files)
    source = fullfile(root_dir,code_files{k});
    if exist(source,'file') == 2
        copyfile(source,fullfile(output_dir,'code',code_files{k}));
    end
end

metadata = struct('savedAt',char(datetime('now','TimeZone','Asia/Bangkok', ...
    'Format','yyyy-MM-dd HH:mm:ss Z')),'matlabVersion',version, ...
    'figureNumbers',figure_numbers,'workspaceVariables',{fieldnames(snapshot)}, ...
    'source','Existing figures and base workspace; no new recording or decoding.');
if isfield(snapshot,'fo_pilot')
    metadata.frequencyOffsetHz = snapshot.fo_pilot;
end
if isfield(snapshot,'y') && isfield(snapshot,'fs')
    metadata.recordingDurationSeconds = numel(snapshot.y)/snapshot.fs;
end
if isfield(snapshot,'Preamble_matched')
    metadata.packetPeak = max(snapshot.Preamble_matched);
end
fid = fopen(fullfile(output_dir,'manifest.json'),'w','n','UTF-8');
assert(fid ~= -1,'Could not create manifest.');
closer = onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(metadata,'PrettyPrint',true));
fprintf('SAVED_RUN_DIR=%s\n',output_dir);
fprintf('Saved %d figures as FIG and PNG, decoding data, image, and configuration.\n', ...
    numel(figure_numbers));
end
