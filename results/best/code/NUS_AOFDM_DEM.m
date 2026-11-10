clear %Revised at March 7, 2015.
load NUS_AOFDM_TX_parameters.mat %loading OFDM TX system paramters
figure(1);clf; plot(5,5); axis([0 10 0 10]);text(2, 5, 'RECEIVING.... DO NOT MOVE THE PHONE.'); 
%%%%%%%%%%%% Near ultrasonic sound sampling %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TX_time is one packet; the WAV contains two repeated packets.
RX_time=2*TX_time+3;
if exist('NUS_AOFDM_TX.wav','file')==2
    wav_info=audioinfo('NUS_AOFDM_TX.wav');
    RX_time=wav_info.Duration+3;
end
% Start the original WAV just before running this receiver. Frame sync below
% assumes that the recording starts during the repeated transmission.
fprintf('Recording for %.2f seconds. Play the original WAV before running this receiver.\n',RX_time);
drawnow;
% Select the Realtek microphone explicitly, independent of Windows defaults.
preferred_microphone='Microphone (Realtek(R) Audio)';
audio_devices=audiodevinfo;
mic_index=find(contains({audio_devices.input.Name},preferred_microphone,'IgnoreCase',true),1);
if isempty(mic_index)
    error('Microphone not found. Run audiodevinfo and update preferred_microphone.');
end
mic_id=audio_devices.input(mic_index).ID;
fprintf('Input device: %s (ID %d)\n',audio_devices.input(mic_index).Name,mic_id);
r = audiorecorder(fs, 16, 1,mic_id);
recordblocking(r,RX_time); y=getaudiodata(r)';
%%%%%%%%%%%% Near ultrasonic sound sampling %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clf;subplot(3,3,1);plot(1/fs*(1:length(y)),y);  xlabel('Time [sec]');grid on;
subplot(3,3,2);pwelch(y,[],[],[],fs); grid on;

%%%%%%%%%% Front end BPF stage %%%%%%%%%%%%%%%%%%%%%%%%%%%%
T=Np/fs;
B=N/T;
W=4*B;
lpf=sinc(1/fs*((-fs*2/W):(fs*2/W))*W);
bpf=cos(2*pi*(fc+B/2)/fs*(1:length(lpf))).*lpf;
bpf_out=conv(y,bpf);
%%%%%%%%%% Front end BPF stage %%%%%%%%%%%%%%%%%%%%%%%%%%%%
subplot(3,3,3);plot(1/fs*(1:length(bpf_out)),bpf_out); xlabel('Time [sec]');grid on;
subplot(3,3,4);pwelch(bpf_out,[],[],[],fs); grid on;

%%%%%%%%%%Down conversion %%%%%%%%%%%%%%%%
L=length(bpf_out);
local_carrier=exp(-j*2*pi*(fc)*(1:L)/fs);
frequency_shifted=bpf_out.*local_carrier;
cbb=conv(frequency_shifted,lpf);  % Complex baseband signal
%%%%%%%%%%Down conversion %%%%%%%%%%%%%%%%

%%%%%%%Carrier recovery (frequency offset due to sampling clock offset)%%%%
downs=1e2; %Down sampling factor
cbb_down=cbb(1:downs:end); %Downsampled complex baseband signal
fsd=fs/downs; %Sampling frequency after downsampling.
W=0.5/T;% Filter BW
lpf_cr=sinc(1/fsd*((-fsd*2/W):(fsd*2/W))*W);
filtered_pilot=conv(cbb_down,lpf_cr);
f_pilot_L=length(filtered_pilot);
xx=abs(fft(filtered_pilot)); % Alternative: xx=pwelch(filtered_pilot,[],[],[],fsd);
[A B]=max(xx);
fo_pilot=(B-1)*fsd/f_pilot_L;
if fo_pilot > fsd/2
    fo_pilot=fo_pilot-fsd;
end
fo_pilot
rcbb=cbb.*exp(-j*2*pi*(fo_pilot)*(1:length(cbb))/fs);
%%%%%%%Carrier recovery (frequency offset due to sampling clock offset)%%%%

for dummy=1:1 %For folding TX-irrelavant part
    x4pilot_spectrum=fsd/f_pilot_L*(0:(f_pilot_L-1));
    y4pilot_spectrum=abs(fft(filtered_pilot));
    x4pilot_spectrum=x4pilot_spectrum-x4pilot_spectrum(ceil(f_pilot_L/2));
    y4pilot_spectrum=circshift(y4pilot_spectrum',floor(f_pilot_L/2))';
    subplot(3,3,5);semilogy(x4pilot_spectrum , y4pilot_spectrum  );xlabel('Frequency [Hz]'); title('Filtered pilot subcarrier'); grid on
end

%%%%%%%Frame Synchronization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
DEC=N/16;
Pf_GI_dec=Pf_GI(1:DEC:end);
rcbb_dec=rcbb(1:DEC:end);
rcbb_dec=abs(conv(rcbb_dec,conj(Pf_GI_dec(end:-1:1))));
accum=zeros(1,(Np+GI)*Ns/DEC);
for k=1:floor(length(rcbb_dec)/((Np+GI)*Ns/DEC))
    accum=accum+(rcbb_dec((k-1)*((Np+GI)*Ns/DEC)+(1:((Np+GI)*Ns/DEC))));
end
[T1 T2]=max(abs(accum));
NpGI=Np+GI;
ST=T2*DEC-NpGI;
if ST<1
    ST=ST+NpGI*Ns;
end
%%%%%%%Frame Synchronization %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
subplot(3,3,6);plot(abs(accum));title('Frame Synch');grid on

%%%%%%%OFDM demodulation with Channel compensation %%%%%%%%%%%%%%%%%%%%%%%%%
Demdata=[];Dp=[];DemPixel=[];
frcnt=1;
NsT=Nf*Ns;   %Total No. of OFDM demodulations
for k=1:(NsT+1) %floor((length(rcbb)-ST)/NpGI)

    T=fft(rcbb(ST+GI+ NpGI*(k-1)+(1:Np)));
    D=T(1:N);
    
    if mod(k,Ns)==1
        ch=D./P;
        ch_tbl(frcnt,:)=ch;
        if k==(NsT+1)
            ch_tbl(frcnt,:)=ch_tbl(frcnt-1,:);
        end
        %%%% Channel Interpolation and Detection %%%
        if frcnt>1
            Pch=ch_tbl(frcnt-1,:);
            Cch=ch_tbl(frcnt,:);
            for n=1:(Ns-1)
                CH=Pch +(n)/Ns*(Cch-Pch);
                Dsym=D_buffer(n,:);
                DemD=Dsym./CH;
                Demdata=[Demdata  DemD(2:end)];
                DemPixel=[DemPixel real(DemD(2:end)) imag(DemD(2:end))];
            end
        end
        %%% Channel Interpolation and Detection %%%
        frcnt=frcnt+1;
        D_buffer=[];
    else
        D_buffer=[D_buffer ; D];
    end
end
%%%%%%%OFDM demodulation with Channel compensation %%%%%%%%%%%%%%%%%%%
subplot(3,3,7); mesh(log(abs(ch_tbl))); xlabel('Frequency:Subcarrier'); ylabel('Time:OFDM symbol'); zlabel('Channel magnitude response [dB] '); grid on;
subplot(3,3,8);mesh(unwrap(angle(ch_tbl))); xlabel('Frequency:Subcarrier'); ylabel('Time:OFDM symbol'); zlabel('Channel phase response'); grid on;

%%%%%%%%%%%%%%%%%%Image Packet  Sync%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Preamble_matched=conv(sign(DemPixel), Preamble(end:-1:1));
[A B]=max(Preamble_matched);
DemPixel=circshift(DemPixel',-B)';
%%%%%%%%%%%%%%%%%%Image Packet  Sync%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
subplot(3,3,9);plot(Preamble_matched); title('Packet Sync');T=length(Preamble_matched);axis([-T/10 T -A A]);grid on;

for dummy=1:1 %For folding TX-irrelavant part
    DemPixel=DemPixel(DILindex)/Gain;
    DemA=zeros(NN,MM,KK);
    for n=1:NN
        for m=1:MM
            for k=1:KK
                DemA(n,m,k)= DemPixel(k+KK*(m-1)+KK*MM*(n-1));
            end
        end
    end
    
    DemA=uint8(DemA*256+128);
    if KK==1
        colormap(gray)
    end
end

figure(3)
image(DemA)
figure(4); clf; axis([0 10 0 10]); text(0.5,6, 'This is Figure 4. See Figure 3. \newline If the image is not recovered in Figure 3, \newline make sure that the phone speaker volume is maximized and, \newline \newline 1. In your PC, go to [Control Panel/Sound/Recording].  \newline 2. Select the internal MIC(which should be set as the default MIC) \newline and click the button [Properties] at the bottom. \newline 3. Select the tab [Enhancements]. \newline 4. Check [Disable all sound effects]. \newline 5. Redo the experiment.')    

