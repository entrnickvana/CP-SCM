%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%	Author(s): Todd Renner: u1169633@utah.edu
%
%
%---------------------------------------------------------------------
% This code characterizes the noise floor at a given center Frequency
% for an array of Iris BS antennas. This is meant to run in parallel
% with data collection scripts to provide information regarding changes
% in the noise floor value.
% ---------------------------------------------------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
close all;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERIZE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Iris params:
TX_FRQ            = 3.55e9;
RX_FRQ            = TX_FRQ;
ANT_BS            = 'AB';         % Options: {A, AB}. To use both antennas per board, set to 'AB'
TX_GN             = 70;
RX_GN             = 50;
SMPL_RT           = 5e6;
n_samp            = 4096;
N_FRM             = 1;
bs_ids = string.empty();
bs_sched = string.empty();

% Rx processing params
FFT_OFFSET        = 16;          % Number of CP samples to use in FFT (on average)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INITIALIZE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize BS Hub
hub_id = "FH4B000003";

bs_ids = [ "RF3E000698", "RF3E000731", "RF3E000747", "RF3E000734", ...
    "RF3E000654", "RF3E000458", "RF3E000463", "RF3E000424", ...
    "RF3E000053", "RF3E000177", "RF3E000192", "RF3E000117", ...
    "RF3E000257", "RF3E000430", "RF3E000311", "RF3E000565", ...
    "RF3E000686", "RF3E000574", "RF3E000595", "RF3E000585", ...
    "RF3E000722", "RF3E000494", "RF3E000592", "RF3E000333", ...
    "RF3E000748", "RF3E000567", "RF3E000492", "RF3E000688", ...
    "RF3E000708", "RF3E000526", "RF3E000437", "RF3E000090" ]; % updated for MEB rooftop

bs_sched        = ["RRRR"];  % All BS schedule, Ref Schedule
N_BS_NODE       = length(bs_ids);   % Number of nodes/antennas at the BS
N_BS_ANT        = length(bs_ids) * length(ANT_BS);  % Number of antennas at the BS
N_BS            = N_BS_NODE - 1;

payload_rx = zeros(N_BS_NODE, data_len);
rx_fft = zeros(N_BS, N_SC);
rx_fft_ref = zeros(N_BS, N_SC);
cal_mat = zeros(N_BS, N_SC);

printf('Initializing Iris SDRs... ');

% Iris nodes' parameters
bs_sdr_params = struct(...
    'bs_id', bs_ids, ...
    'bs_ant', ANT_BS, ...
    'txfreq', TX_FRQ, ...
    'rxfreq', RX_FRQ, ...
    'txgain', TX_GN, ...
    'rxgain', RX_GN, ...
    'sample_rate', SMPL_RT);   
    % %Original driver
    % 'id', bs_ids, ...
    % 'n_sdrs', N_BS_NODE, ...
    % 'txfreq', TX_FRQ, ...
    % 'rxfreq', RX_FRQ, ...
    % 'txgain', TX_GN, ...
    % 'rxgain', RX_GN, ...
    % 'sample_rate', SMPL_RT, ...
    % 'n_samp', n_samp, ...          % number of samples per frame time.
    % 'n_frame', 1, ...
    % 'tdd_sched', bs_sched, ...     % number of zero-paddes samples
    % 'n_zpad_samp', N_ZPAD_PRE ...
    % );
    % Updated MIMO driver

% Initialize BS SDRs
%node_bs = iris_py(bs_sdr_params,hub_id);
node_bs = mimo_driver(bs_sdr_params);
node_bs.sdrsync();                 % synchronize delays only for BS
node_bs.sdrrxsetup();
tdd_sched_index = 1;               % ***UNSURE ABOUT THIS***
node_bs.set_tddconfig(1, bs_sdr_params.tdd_sched(tdd_sched_index)); % configure the BS: schedule etc.
printf('SUCCESS \n ');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RX DATA STREAM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
printf('Reading Rx data... ');
node_bs.sdr_activate_rx();                        % activate reading stream
[rx_vec_iris, data0_len] = node_bs.sdrrx(n_samp); % read data
printf('SUCCESS \n ');

% Close Stream
node_bs.sdr_close();


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RX DATA PROCESSING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Remove DC component ***Necessary?***
for i = 1:length(rx_vec_iris)
  rx_vec_iris(i) = rx_vec_iris(i) - mean(rx_vec_iris);
end

% Time Domain Power
nf_td_rms = sqrt(mean(rx_vec_iris.*conj(rx_vec_iris)));
nf_td_pwr = real(nf_td_rms).^2;
nf_td_pwr_dB = 10*log10(nf_td_pwr);
nf_td_pwr_dBm = 10*log10(nf_td_pwr./(1e-3));
printf('######## NF Power (Time Domain) ########\n');
fprintf('RMS: %d \n', nf_td_rms);
fprintf('Power(dB): %d \n', nf_td_pwr_dB);
fprintf('Power(dBm): %d \n', nf_td_pwr_dBm);

% Frequency Domain Power


for ibs = 1:N_BS_NODE
    nf_vec(ibs,:) = nf_avg_tmp;
    nf_avg_tmp = 0;

end

node_bs.sdr_close();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Optional: PLOTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
