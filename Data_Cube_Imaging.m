%% Get Range, Velocity, Spacial location of the given data cube
function [TargetNum TargetInformation] = Data_Cube_Imaging(DataCube,...
                                nfft_r,...
                                nfft_d,...
                                fc,...
                                fs,...
                                SweepTime,...
                                SweepBandwidth,...
                                Nt,...
                                Nr,...
                                RD_Th)
%Input definition
%   DataCube        : Data matrix with dimension of range-channel-chirp.
%   nfft_r          : FFT points on range dimension 
%   nfft_d          : FFT points on doppler dimension
%   fc              : Carrier frequency
%   fs              : Sample rate
%   SweepTime       : Chirp-up time
%   SweepBandwidth  : Chirp bandwidth
%   Nt              : Number of Tx antennas
%   Nr              : Number of Rx antennas
%   RD_Th           : Threat relative dB on range-doppler map
%   Detailed explanation goes here

%% Virtual antennas definition
c = 3e8;
dt = c/fc/2;
v_ant_pos = [0 0  0    0    0    0    0    0    0    0    0    0   ;...
             0 dt 2*dt 3*dt 4*dt 5*dt 3*dt 4*dt 5*dt 6*dt 7*dt 8*dt;...
             0 0  0    0    0    0    dt   dt   dt   dt   dt   dt ];
v_array = phased.ConformalArray('ElementPosition',v_ant_pos);

%%  Range-Doppler detection
rngdop = phased.RangeDopplerResponse('PropagationSpeed',c,...
    'DopplerOutput','Speed','OperatingFrequency',fc,'SampleRate',fs,...
    'RangeMethod','FFT','PRFSource','Property',...
    'RangeWindow','Hann','PRF',1/(Nt*SweepTime),...
    'SweepSlope',SweepBandwidth/SweepTime,...
    'RangeFFTLengthSource','Property','RangeFFTLength',nfft_r,...
    'DopplerFFTLengthSource','Property','DopplerFFTLength',nfft_d,...
    'DopplerWindow','Hann');
[RangeDoppler,RangeGrid,DopplerGrid] = rngdop(DataCube);

%% Range-Doppler peaks found
RangeDopplerMap = squeeze(mag2db(abs(RangeDoppler(:,1,:))));
RangeDopplerMap = RangeDopplerMap-max(RangeDopplerMap(:));                     % Normalize map
peakmat = findpeaks2D(RangeDopplerMap,0,RD_Th);   
[RangeIndex,DopplerIndex] = ind2sub(size(RangeDopplerMap),find(peakmat));

%% Velocity compensation
TargetNum = length(RangeIndex);
AngleData = zeros(TargetNum,Nt*Nr);
for i=1:TargetNum
    AngleData(i,:) = RangeDoppler(RangeIndex(i),:,DopplerIndex(i));
end
% for i=2:Nt
%     AngleData(:,((i-1)*Nr+1):i*Nr) = AngleData(:,((i-1)*Nr+1):i*Nr).*exp(1i*2*pi*2*fc*DopplerGrid(DopplerIndex)*(i-1)*SweepTime/3e8);
% end

%% Angle detection
AngleIndex = zeros(2,TargetNum);
doa = phased.BeamscanEstimator2D('SensorArray',v_array,'OperatingFrequency',fc, ...
    'DOAOutputPort',true,'NumSignals',1,'AzimuthScanAngles',-50:50,'ElevationScanAngles',-30:30);
for i = 1:TargetNum
    [Pdoav,AngleIndex(:,i)] = doa(AngleData(i,:));
end
disp(AngleIndex);
TargetInformation = zeros(4,TargetNum);
TargetInformation(3,:) = -RangeGrid(RangeIndex);
TargetInformation(1:2,:) = -AngleIndex;
TargetInformation(4,:) = -DopplerGrid(DopplerIndex);

AngleData_FFT = zeros(2,6);
AngleData_FFT(1,:) = AngleData(1,1:6).';
AngleData_FFT(2,:) = AngleData(1,7:12).';

AngleDataResult = fft2(AngleData_FFT,61,111);
figure(1);
mesh(fftshift(abs(AngleDataResult)));
figure(2);
mesh(Pdoav);

end

