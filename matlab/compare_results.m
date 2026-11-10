% Compare the saved live run with the previous baseline and refined images.
root_dir=fileparts(fileparts(mfilename('fullpath')));
comparison_dir=fullfile(root_dir,'results','comparison');
run_dir=fullfile(root_dir,'results','best');
current=load(fullfile(run_dir,'results','decoding_workspace.mat'));
previous=load(fullfile(root_dir,'data','recordings','previous_RX_debug.mat'));
refined=load(fullfile(root_dir,'results','previous','NUS_AOFDM_RX_refinement.mat'));
old_params=load(fullfile(comparison_dir,'previous_TX_parameters.mat'));
new_params=load(fullfile(run_dir,'config','session_TX_parameters.mat'));

source=imread(fullfile(run_dir,'config','myphoto.jpg'));
ds=floor(max(size(source,1),size(source,2))/100);
reference=double(source(1:ds:end,1:ds:end,:));
for c=1:size(reference,3)
    plane=reference(:,:,c);
    reference(:,:,c)=256*plane/max(plane(:));
end
reference=uint8(reference);
old_image=imread(fullfile(root_dir,'results','previous','NUS_AOFDM_RX_baseline.png'));
refined_image=imread(fullfile(root_dir,'results','previous','NUS_AOFDM_RX_refined.png'));
new_image=imread(fullfile(run_dir,'results','recovered_image.png'));
assert(isequal(new_image,current.DemA),'Displayed and workspace images differ.');
assert(isequal(refined_image,refined.recovered),'Previous refined image and MAT differ.');

names={'Previous original RX','Previous refined RX','Run 20261110_162941_128'};
images={old_image,refined_image,new_image};
peaks=[max(previous.Preamble_matched),refined.report.packetPeak,max(current.Preamble_matched)];
offsets=[previous.fo_pilot,refined.report.frequencyOffsetHz,current.fo_pilot];
metrics=struct([]);
for k=1:3
    assert(isequal(size(images{k}),size(reference)),'Image dimensions differ.');
    difference=double(images{k})-double(reference);
    mse=mean(difference(:).^2);
    metrics(k).name=names{k};
    metrics(k).psnrDB=10*log10(255^2/mse);
    metrics(k).rmse=sqrt(mse);
    metrics(k).mae=mean(abs(difference(:)));
    metrics(k).packetPeak=peaks(k);
    metrics(k).packetScore=peaks(k)/(numel(current.Preamble)*sqrt(2));
    metrics(k).frequencyOffsetHz=offsets(k);
end
disp(struct2table(metrics));

parameter_changes={};
fields=fieldnames(old_params);
for k=1:numel(fields)
    key=fields{k};
    if ~isfield(new_params,key) || ~isequaln(old_params.(key),new_params.(key))
        parameter_changes{end+1}=key; %#ok<SAGROW>
    end
end
fprintf('Changed transmitter parameter fields: %s\n',strjoin(parameter_changes,', '));
fprintf('Same raw recording: %d\n',isequal(previous.y,current.y));

recordings={previous.y,current.y};
signal_metrics=struct([]);
for k=1:2
    v=recordings{k}(:);
    stable=v(2*current.fs+1:end);
    [power,f]=pwelch(stable,hann(8192),4096,8192,current.fs);
    mask=f>=18200 & f<=21000;
    signal_metrics(k).durationSeconds=numel(v)/current.fs;
    signal_metrics(k).rmsAfter2Seconds=sqrt(mean(stable.^2));
    signal_metrics(k).ofdmBandPowerDBFS=10*log10(sum(power(mask))*(f(2)-f(1)));
    signal_metrics(k).peakFirst2Seconds=max(abs(v(1:2*current.fs)));
    signal_metrics(k).peakAfter2Seconds=max(abs(stable));
end
disp(struct2table(signal_metrics));

f=figure('Visible','off','Color','w','Position',[100 100 1300 1000]);
layout=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
all_images=[{reference},images];
for k=1:4
    ax=nexttile(layout);
    image(ax,all_images{k});
    axis(ax,'image'); axis(ax,'off');
    if k==1
        label='Reference image sent by modem';
    else
        label=sprintf('%s | PSNR %.2f dB',names{k-1},metrics(k-1).psnrDB);
    end
    title(ax,label,'Color','k','FontSize',15,'Interpreter','none');
end
exportgraphics(f,fullfile(comparison_dir,'image_comparison.png'),'Resolution',150);
close(f);

summary=struct('runID','20261110_162941_128', ...
    'previousSnapshotTime','2026-11-10 01:37-01:40 Asia/Bangkok', ...
    'currentSnapshotTime','2026-11-10 16:29:47 Asia/Bangkok', ...
    'metrics',metrics,'recordings',signal_metrics, ...
    'changedTransmitterParameterFields',{parameter_changes}, ...
    'reference','Modem input: original image downsampled and normalized per channel.', ...
    'caution','Preamble score is correlation normalized by its ideal peak, not pixel accuracy.');
fid=fopen(fullfile(comparison_dir,'comparison.json'),'w','n','UTF-8');
assert(fid~=-1); fprintf(fid,'%s\n',jsonencode(summary,'PrettyPrint',true)); fclose(fid);
fid=fopen(fullfile(comparison_dir,'comparison.md'),'w','n','UTF-8');
assert(fid~=-1);
fprintf(fid,'Comparison of run 20261110_162941_128\n\n');
fprintf(fid,'Previous artifacts are dated 2026-11-10 01:37-01:40; current run was saved at 16:29:47, Asia/Bangkok. No separate Nov 9 decode snapshot was found.\n\n');
fprintf(fid,'| Result | PSNR (dB) | MAE (0-255) | Preamble peak | Preamble score | Frequency offset (Hz) |\n');
fprintf(fid,'|---|---:|---:|---:|---:|---:|\n');
for k=1:3
    fprintf(fid,'| %s | %.3f | %.3f | %.3f | %.3f | %.6f |\n', ...
        metrics(k).name,metrics(k).psnrDB,metrics(k).mae,metrics(k).packetPeak, ...
        metrics(k).packetScore,metrics(k).frequencyOffsetHz);
end
fprintf(fid,'\nThe reference follows transmitter downsampling and per-channel normalization. Preamble score is not pixel accuracy. Images are from stored artifacts; no new decoding or recording was performed.\n');
fprintf(fid,'\nChanged transmitter parameter fields: %s\n',strjoin(parameter_changes,', '));
fclose(fid);
