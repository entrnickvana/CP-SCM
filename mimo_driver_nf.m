classdef mimo_driver_nf < handle
    % This class serves as an interface between matlab and
    % iris python driver. Matlab calls the methods here and iris_class calls
    % iris' python functions.

    properties
        sdr_params;
        % pyhton object array. This array decribes 1 Iris board or
        % a collection of Iris boards that belong to the same entity.E.g., a BS.
        mimo_obj;

        bs_serial_ids;
        ue_serial_ids;
        n_bs_ant = 0;
        n_ue_ant = 0;
        bs_channels = 'A';
        ue_channels = 'A';
        hub_serial='';
        sample_rate = 0;
        tx_freq = 0;
        rx_freq = 0;
        tx_gain = 0;
        rx_gain = 0;
    end

    methods
        function obj = mimo_driver_nf(sdr_params)
            if nargin > 0
                obj.sdr_params = sdr_params;

                obj.bs_serial_ids = sdr_params.bs_id;
                obj.ue_serial_ids = sdr_params.ue_id;
                if isfield(sdr_params, 'hub_id')
                    obj.hub_serial = sdr_params.hub_id;
                end
                obj.sample_rate = sdr_params.sample_rate;
                obj.tx_freq = sdr_params.txfreq;
                obj.rx_freq = sdr_params.rxfreq;
                obj.tx_gain = sdr_params.txgain;
                obj.rx_gain = sdr_params.rxgain;

                n_bs_sdrs = length(obj.bs_serial_ids);
                n_ue_sdrs = length(obj.ue_serial_ids);

                obj.n_bs_ant = n_bs_sdrs * length(sdr_params.bs_ant);
                obj.n_ue_ant = n_ue_sdrs * length(sdr_params.ue_ant);
                obj.bs_channels = sdr_params.bs_ant;
                obj.ue_channels = sdr_params.ue_ant;

                bs_id_str = cell(1, n_bs_sdrs);
                for i = 1:n_bs_sdrs
                    bs_id_str(1, i) = {convertStringsToChars(obj.bs_serial_ids(i))};
                end
                bs_id_list = py.list(bs_id_str);

                ue_id_str = cell(1, n_ue_sdrs);
                for i = 1:n_ue_sdrs
                    ue_id_str(1, i) = {convertStringsToChars(obj.ue_serial_ids(i))};
                end
                ue_id_list = py.list(ue_id_str);

                hub_id_str = convertStringsToChars(obj.hub_serial);
                obj.mimo_obj = py.mimo_driver_nf.MIMODriver( pyargs( ...
                    'hub_serial', hub_id_str, ...
                        'bs_serials', bs_id_list, ...
                        'ue_serials', ue_id_list, ...
                        'rate', obj.sample_rate, ...
                        'tx_freq', obj.tx_freq, 'rx_freq', obj.rx_freq, ...
                        'tx_gain', obj.tx_gain, 'rx_gain', obj.rx_gain, ...
                        'bs_channels', obj.bs_channels , 'ue_channels', obj.ue_channels ) );

            end
        end

        function [data, nf_pwr] = mimo_nf(obj, n_frames, n_samps)
            [data, nf_pwr] = obj.mimo_obj.nf(py.int(n_frames), py.int(n_samps));
        end

        function mimo_close(obj)
            obj.mimo_obj.close();
        end
    end
end
