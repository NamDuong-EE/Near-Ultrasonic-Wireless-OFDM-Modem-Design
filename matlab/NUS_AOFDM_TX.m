clc  %Revised at March 7, 2015.
clear
root_dir=fileparts(fileparts(mfilename('fullpath')));
tx_dir=fullfile(root_dir,'output','tx');
if ~exist(tx_dir,'dir'), mkdir(tx_dir); end
%%%%%%% Image pixel stream generation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
A=imread(fullfile(root_dir,'data','input','myphoto.jpg'));
for dummy=1:1  %For folding the OFDM-irrelavent part.
    [NN MM KK]=size(A);
    PixelsPerWidth=100;
    DS=floor(max([NN MM])/PixelsPerWidth);
    A=A(1:DS:end,1:DS:end,:);
    A=double(A);
    [NN MM KK]=size(A);
    for kk=1:KK
        A(:,:,kk)=(A(:,:,kk)-0*mean(mean(A(:,:,kk))))/max(max(A(:,:,kk)))-0.5;% Convert to double in [-0.5 0.5]
    end
    % Converting matrix to a vector
    Pixel=[];
    for n=1:NN
        for m=1:MM
            for k=1:KK
                Pixel=[Pixel A(n,m,k)];
            end
        end
    end
    %Power scale
    Gain=sqrt(2)/sqrt(var(Pixel));
    Pixel=Gain*Pixel;
end
%Interleaving
[A ILindex]=sort(rand(1,length(Pixel))); [B DILindex]=sort(ILindex);
Pixel=Pixel(ILindex);
%Preample prefix
Preamble_size=50; Preamble=sqrt(2)*sign(rand(1,Preamble_size)-0.5);
Pixel=[Preamble Pixel];
Nsyms=length(Pixel);
%%%%%%% Image pixel stream  generation%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%% OFDM signal parameters%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs=44100; %Sampling frequency for the wave file of OFDM singal.
fc=18.2e3;%Carrier frequency at near ultrasonic band
N=64;  % No. of subcarrier (IFFT size for OFDM symbol generation)
Np=16*N;  % No of samples per OFDM symbol (prior to guard interval insertion)
GI=ceil(Np*1/8); %No of samples in Guard interval.
Ns=5; %No of OFDM symbols per frame
Nf=ceil(Nsyms/(Ns-1)/(N-1)/2); %No of frames for the image data packet
pilot_boost=8;  %(Pilot carrier)/(Data carrier)  power ratio
signature_boost=1;  % (Pilot OFDM symbol)/(Data OFDM symbol) power ratio
P=[sqrt(2)*pilot_boost  (sign(rand(1,N-1)-0.5)+j*sign(rand(1,N-1)-0.5))*signature_boost]; %Pilot symbol vector
Pf=ifft([P zeros(1,Np-N)]);  % Pilot OFDM symbol
Pf_GI=[Pf((Np-GI+1):Np) Pf]; % Cyclic prefix inserted pilot OFDM symbol
%%%%%%%%%%%%%%%%%% OFDM signal parameters%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Postamble: Null insertion to  the last OFDM frame to fill the packet.
Nnull=Nf*(Ns-1)*(N-1)*2-Nsyms;
Pixel=[Pixel zeros(1,Nnull)];

%%%%%%%% OFDM modulated image data packet generation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
x=[];
data=[];
D=[sqrt(2)*pilot_boost zeros(1,N-1)]; %Intial setting of data vector in one OFDM symbol
Nd=N-1;
ofdmcnt=0;
for k=1:Nf
    x=[x Pf_GI];
    for kk=1:(Ns-1)
        rdata=Pixel(ofdmcnt*Nd+(1:Nd));
        idata=Pixel((ofdmcnt+1)*Nd+(1:Nd));
        ofdmcnt=ofdmcnt+2;
        
        D(2:end)=rdata+j*idata;
        T=ifft([D zeros(1, Np-N)]);
        T_GI=[T((Np-GI+1):Np) T];
        x=[x T_GI];
        data=[data D(2:end)];
    end
end
%%%%%%%% OFDM modulated image data packet generation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%% Up conversion %%%%%%%%%%%%%%%%%%%%%%%%%%%%
L=length(x);
carrier=exp(j*2*pi*(fc)*(1:L)/fs);
tx=real(x.*carrier);
%%%%%% Up conversion %%%%%%%%%%%%%%%%%%%%%%%%%%%%

T=Np/fs;B=N/T;W=1.25*B;lpf=sinc(1/fs*((-fs*2/W):(fs*2/W))*W);
bpf=cos(2*pi*(fc+B/2)/fs*(1:length(lpf))).*lpf;
%%%%%%%%% Packet repetition and Sidelobe suppression %%%%%%%%
tx=[tx tx];% tx tx];
tx=conv(tx,bpf);
%%%%%%%%% Packet repetition and Sidelobe suppression %%%%%%%%
TX_time=length(x)/fs

save(fullfile(tx_dir,'NUS_AOFDM_TX_parameters.mat'), ...
    'Pf_GI','GI','P','Np','Nf','Ns','N','fc','fs','MM','NN','KK', ...
    'TX_time','Preamble','DILindex','Gain');
save(fullfile(tx_dir,'NUS_AOFDM_TX_tx.mat'),'tx');
audiowrite(fullfile(tx_dir,'NUS_AOFDM_TX.wav'),tx,fs);
fprintf('TX files saved in %s\n',tx_dir);

figure(2)
subplot(2,1,1); pwelch(tx,[],[],[],fs);
subplot(2,1,2); plot(1/fs*(1:length(tx)),tx); xlabel('Time [sec]');grid on;
