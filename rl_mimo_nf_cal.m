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

DUAL_CHAN = 1;                % 0: Single, 1: Dual

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PARAMETERIZE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% SDR Params
TX_FRQ            = 3.47e9;
RX_FRQ            = TX_FRQ;
ANT_BS            = 'AB';         % Options: {A, AB}. To use both antennas per board, set to 'AB'
TX_GN             = 0;
RX_GN             = 50;
SMPL_RT           = 5e6;
N_SAMP            = 4096;
N_FRM             = 1;           % 4096 samples/frame
N_ZPAD_PRE        = 0;
bs_sched        = ["RRRRRRRRRRRRRRRR","RRRRRRRRRRRRRRRR"];  % All BS schedule, Ref Schedule

% BS HUB ID
hub_id = "FH4B000003";

% NOTE: *567/688/526 Iris nodes were removed due to SoapySDR init errors
bs_ids = [ "RF3E000698", "RF3E000731", "RF3E000747", "RF3E000734", ...
    "RF3E000654", "RF3E000458", "RF3E000463", "RF3E000424", ...
    "RF3E000053", "RF3E000177", "RF3E000192", "RF3E000117", ...
    "RF3E000257", "RF3E000430", "RF3E000311", "RF3E000565", ...
    "RF3E000686", "RF3E000574", "RF3E000595", "RF3E000585", ...
    "RF3E000722", "RF3E000494", "RF3E000592", "RF3E000333", ...
    "RF3E000748", ..."RF3E000567",
    "RF3E000492", ..."RF3E000688", ...
    "RF3E000708", ..."RF3E000526",
    "RF3E000437", "RF3E000090" ]; % updated for MEB rooftop

N_BS_NODE               = length(bs_ids);           % Number of nodes/antennas at the BS
N_BS_ANT                = length(bs_ids) * length(ANT_BS);  % Number of antennas at the BS

% Rx processing params
FFT_OFFSET        = 16;          % Number of CP samples to use in FFT (on average)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INITIALIZE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Initializing Iris SDRs... ');

% Iris nodes parameters
bs_sdr_params_mimo = struct(...      % MIMO_driver
  'bs_id', bs_ids, ...
  'ue_id', [], ...           % not interested in UL
  'bs_ant', ANT_BS, ...
  'ue_ant', [], ...
  'hub_id', hub_id, ...
  'txfreq', TX_FRQ, ...
  'rxfreq', RX_FRQ, ...
  'txgain', TX_GN, ...
  'rxgain', RX_GN, ...
  'sample_rate', SMPL_RT);

bs_sdr_params = struct(...           % Iris_py driver
     'id', bs_ids, ...
     'n_sdrs', N_BS_NODE, ...
     'txfreq', TX_FRQ, ...
     'rxfreq', RX_FRQ, ...
     'txgain', TX_GN, ...
     'rxgain', RX_GN, ...
     'sample_rate', SMPL_RT, ...
     'n_samp', n_samp, ...          % number of samples per frame time.
     'n_frame', 1, ...
     'tdd_sched', bs_sched, ...
     'n_zpad_samp', N_ZPAD_PRE);

% Initialize BS SDRs
if(DUAL_CHAN)
  disp('Using Dual Channel...');
  node_bs = mimo_driver_nf(bs_sdr_params_mimo);
else
  disp('Using Single Channel...');
  node_bs = iris_py(bs_sdr_params,hub_id);
end
disp('SUCCESS');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RX DATA STREAM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Reading Rx data... ');
if(DUAL_CHAN)
  rx_vec_iris = node_bs.mimo_nf(N_FRM, N_SAMP);
  node_bs.mimo_close();
else
  disp('Using Single Channel...');
  node_bs = iris_py(bs_sdr_params,hub_id);
  node_bs.sdrsync();                 % synchronize delays only for BS
  node_bs.sdrrxsetup();
  tdd_sched_index = 1;               % ***UNSURE ABOUT THIS***
  node_bs.set_tddconfig(1, bs_sdr_params.tdd_sched(tdd_sched_index)); % configure the BS: schedule etc.
  node_bs.sdr_activate_rx();                        % activate reading stream
  [rx_vec_iris, data0_len] = node_bs.sdrrx(n_samp); % read data
  disp('SUCCESS');
  node_bs.sdr_close();
end

if isempty(rx_vec_iris)
    disp("Driver returned empty array. No good data received by base station");
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RX DATA PROCESSING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Time Domain Power
nf_td_rms = rms(rx_vec_iris,'all'); %sqrt(mean(rx_vec_iris.*conj(rx_vec_iris)));
nf_td_pwr = real(nf_td_rms).^2;
nf_td_pwr_dB = db(nf_td_pwr);
nf_td_pwr_dBm = nf_td_pwr_dB + 30;
disp('######## NF Power (Time Domain) ########');
fprintf('RMS: %d \n', nf_td_rms);
fprintf('Power(dB): %.3f \n', nf_td_pwr_dB);
fprintf('Power(dBm): %.3f \n', nf_td_pwr_dBm);

% Frequency Domain Power


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Optional: PLOTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
