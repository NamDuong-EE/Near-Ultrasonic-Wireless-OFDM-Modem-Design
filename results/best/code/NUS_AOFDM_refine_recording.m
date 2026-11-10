function [recovered, report] = NUS_AOFDM_refine_recording(recording_file)
% Replay a saved recording and try later starts to avoid microphone startup.
% Candidate selection uses only the transmitted preamble, not the source image.
root_dir = fileparts(mfilename('fullpath'));
if nargin < 1
    recording_file = fullfile(root_dir,'NUS_AOFDM_RX_debug.mat');
end
recording = load(recording_file,'y','fs');
p = load(fullfile(root_dir,'NUS_AOFDM_TX_parameters.mat'));
assert(recording.fs == p.fs,'Recording and transmitter sample rates differ.');
y = recording.y(:).';
assert(all(isfinite(y)),'Recording contains nonfinite samples.');

candidate_seconds = [0 0.25 0.5 1:8];
minimum_samples = (p.Nf*p.Ns+2)*(p.Np+p.GI);
best_score = -Inf;
trials = struct('skipSeconds',{},'packetPeak',{},'packetScore',{});
for skip_seconds = candidate_seconds
    first_sample = 1+round(skip_seconds*p.fs);
    if numel(y)-first_sample+1 < minimum_samples
        continue;
    end
    [candidate, details] = decode_samples(y(first_sample:end),p);
    details.skipSeconds = skip_seconds;
    trials(end+1) = struct('skipSeconds',skip_seconds, ...
        'packetPeak',details.packetPeak,'packetScore',details.packetScore); %#ok<AGROW>
    fprintf('Skip %4.2f s: preamble %.2f / %.2f\n', ...
        skip_seconds,details.packetPeak,numel(p.Preamble)*sqrt(2));
    if details.packetScore > best_score
        best_score = details.packetScore;
        recovered = candidate;
        report = details;
    end
end
assert(best_score > -Inf,'Recording is too short for a complete image packet.');
report.trials = trials;
report.recordingFile = recording_file;
report.outputFile = fullfile(root_dir,'NUS_AOFDM_RX_refined.png');
imwrite(recovered,report.outputFile);
save(fullfile(root_dir,'NUS_AOFDM_RX_refinement.mat'),'report','recovered');
figure(3); image(recovered); axis image;
title(sprintf('Skip %.2f s; preamble %.2f / %.2f', ...
    report.skipSeconds,report.packetPeak,numel(p.Preamble)*sqrt(2)));
fprintf('Selected skip %.2f s. Image saved to %s\n', ...
    report.skipSeconds,report.outputFile);
end

function [recovered, details] = decode_samples(y,p)
% Original receiver processing, with capture and plotting removed.
T = p.Np/p.fs;
B = p.N/T;
W = 4*B;
lpf = sinc(1/p.fs*((-p.fs*2/W):(p.fs*2/W))*W);
bpf = cos(2*pi*(p.fc+B/2)/p.fs*(1:length(lpf))).*lpf;
bpf_out = conv(y,bpf);
frequency_shifted = bpf_out.*exp(-1i*2*pi*p.fc*(1:length(bpf_out))/p.fs);
cbb = conv(frequency_shifted,lpf);

downs = 100;
fsd = p.fs/downs;
W = 0.5/T;
lpf_cr = sinc(1/fsd*((-fsd*2/W):(fsd*2/W))*W);
filtered_pilot = conv(cbb(1:downs:end),lpf_cr);
[~,peak_bin] = max(abs(fft(filtered_pilot)));
fo_pilot = (peak_bin-1)*fsd/length(filtered_pilot);
if fo_pilot > fsd/2
    fo_pilot = fo_pilot-fsd;
end
rcbb = cbb.*exp(-1i*2*pi*fo_pilot*(1:length(cbb))/p.fs);

DEC = p.N/16;
Pf_GI_dec = p.Pf_GI(1:DEC:end);
matched = abs(conv(rcbb(1:DEC:end),conj(Pf_GI_dec(end:-1:1))));
frame_samples = (p.Np+p.GI)*p.Ns/DEC;
accum = zeros(1,frame_samples);
for k = 1:floor(length(matched)/frame_samples)
    accum = accum+matched((k-1)*frame_samples+(1:frame_samples));
end
[~,peak_sample] = max(accum);
NpGI = p.Np+p.GI;
ST = peak_sample*DEC-NpGI;
if ST < 1
    ST = ST+NpGI*p.Ns;
end

DemPixel = [];
previous_channel = [];
D_buffer = [];
NsT = p.Nf*p.Ns;
for k = 1:(NsT+1)
    samples = ST+p.GI+NpGI*(k-1)+(1:p.Np);
    assert(samples(end)<=length(rcbb),'Not enough samples after frame synchronization.');
    spectrum = fft(rcbb(samples));
    D = spectrum(1:p.N);
    if mod(k,p.Ns)==1
        current_channel = D./p.P;
        if k==(NsT+1)
            current_channel = previous_channel;
        end
        if ~isempty(previous_channel)
            for n = 1:(p.Ns-1)
                channel = previous_channel+n/p.Ns*(current_channel-previous_channel);
                DemD = D_buffer(n,:)./channel;
                DemPixel = [DemPixel real(DemD(2:end)) imag(DemD(2:end))]; %#ok<AGROW>
            end
        end
        previous_channel = current_channel;
        D_buffer = [];
    else
        D_buffer = [D_buffer; D]; %#ok<AGROW>
    end
end

Preamble_matched = conv(sign(DemPixel),p.Preamble(end:-1:1));
[packet_peak,packet_index] = max(Preamble_matched);
DemPixel = circshift(DemPixel.',-packet_index).';
pixels = DemPixel(p.DILindex)/p.Gain;
recovered = uint8(permute(reshape(pixels,[p.KK p.MM p.NN]),[3 2 1])*256+128);
details = struct('packetPeak',packet_peak, ...
    'packetScore',packet_peak/(numel(p.Preamble)*sqrt(2)), ...
    'frequencyOffsetHz',fo_pilot,'frameStartSample',ST);
end
