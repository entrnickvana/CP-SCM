#!/usr/bin/python
# -*- coding: UTF-8 -*-
from argparse import ArgumentParser
from optparse import OptionParser
import copy
import numpy as np
from numpy import matlib
import scipy.io as sio
import time
import iris_py
from iris_py import *
import matplotlib.pyplot as plt

class MIMODriver:
    def __init__(self, hub_serial, bs_serials, ue_serials, rate,
            tx_freq, rx_freq, tx_gain, rx_gain, bs_channels='A', ue_channels='A', beamsweep=False):
        # Init Radios
        #bs_serials_str = ""
        #for c in bs_serials:
        #    bs_serials_str += c
        #ue_serials_str = ""
        #for c in ue_serials:
        #    ue_serials_str += c
        #bs_serials_list = bs_serials.split(",")
        #ue_serials_list = ue_serials.split(",")
        print("HUB: {}".format(hub_serial))
        print("BS NODES: {}".format(bs_serials))
        print("UE NODES: {}".format(ue_serials))
        self.bs_obj = [Iris_py(sdr, tx_freq, rx_freq, tx_gain, rx_gain, None, rate, None, bs_channels) for sdr in bs_serials]
        self.ue_obj = [Iris_py(sdr, tx_freq, rx_freq, tx_gain, rx_gain, None, rate, None, ue_channels) for sdr in ue_serials]
        self.hub = None
        if len(hub_serial) != 0:
            self.hub = Hub_py(hub_serial)

        # Setup Radios and Streams
        if self.hub is not None:
            self.hub.sync_delays()
        else:
            self.bs_obj[0].sync_delays()

        [ue.config_gain_ctrl() for ue in self.ue_obj]

        [ue.setup_stream_rx() for ue in self.ue_obj]
        [bs.setup_stream_rx() for bs in self.bs_obj]

        if beamsweep == True:
            [bs.burn_beacon() for bs in self.bs_obj]
            # also write beamweights
        else:
            self.bs_obj[0].burn_beacon()

        self.n_bs_chan = len(bs_channels)
        self.n_ue_chan = len(ue_channels)

        self.n_users = len(ue_serials) * self.n_ue_chan
        self.n_bs_antenna = len(bs_serials) * self.n_bs_chan
        self.n_bs_sdrs = len(bs_serials)

    def bs_trigger(self):
        if self.hub is not None:
            self.hub.set_trigger()
        else:
            self.bs_obj[0].set_trigger()

    def reset_frame(self):
        [ue.reset_hw_time() for ue in self.ue_obj]
        [bs.reset_hw_time() for bs in self.bs_obj]

    def close(self):
        [ue.close() for ue in self.ue_obj]
        [bs.close() for bs in self.bs_obj]

    def nf(self, n_frames, n_samps):
        bs_sched='GRRG'
        [bs.config_sdr_tdd() for i, bs in enumerate(self.bs_obj)] #just guard band - no tx or rx
        [bs.activate_stream_rx() for bs in self.bs_obj]
        rx_data = np.empty((n_frames, self.n_bs_antenna, n_samps), dtype=np.complex64)

        self.bs_trigger()
        rx_data_frame = [bs.recv_stream_tdd() for bs in self.bs_obj]  # Returns dimensions (num bs nodes, num channels, num samples)
        rx_data_frame_arr = np.array(rx_data_frame)
        ant_cnt = 0
        # for j in range(self.n_bs_sdrs):
        #     for k in range(self.n_bs_chan):
        #         # Dimensions of rx_data: (self.n_bs_antenna, n_samps)
        #         rx_data[ant_cnt, :] = rx_data_frame_arr[j][k]
        #         ant_cnt = ant_cnt + 1
        ## rx_data
        for sdr in enumerate(rx_data_frame_arr):
            for chan in enumerate(sdr):
                for sample_idx in enumerate(chan):
                    rx_data[ant_cnt,sample_idx] = chan[sample_idx]
                ant_cnt += 1
        self.reset_frame()

        ## NF rms
        rx_data_mean = np.mean(rx_data_frame_arr**2)
        rx_data_rms = np.sqrt(rx_data_mean)

        ## NF power (dB)
        rx_data_pwr = np.real(rx_data_rms)**2
        rx_data_pwr_dB = 10*np.log10(rx_data_pwr)

        return rx_data , rx_data_pwr_dB

#########################################
#                  Main                 #
#########################################
def main():
    parser = OptionParser()
    parser.add_option("--hub", type="string", dest="hub", help="serial number of the hub device", default='FH4B000003')
    parser.add_option("--bs-serials", type="string", dest="bs_serials", help="serial numbers of the BS devices", default='RF3E000698,RF3E000731,RF3E000747,RF3E000734')
    parser.add_option("--ue-serials", type="string", dest="ue_serials", help="serial numbers of the UE devices", default=[])
    parser.add_option("--rate", type="float", dest="rate", help="Tx sample rate", default=5e6)
    parser.add_option("--freq", type="float", dest="freq", help="Tx freq (Hz). POWDER users must set to 3.6e9", default=3.547e9)
    parser.add_option("--tx-gain", type="float", dest="tx_gain", help="Optional Tx gain (dB)", default=0)
    parser.add_option("--rx-gain", type="float", dest="rx_gain", help="Optional Rx gain (dB)", default=60.0)
    (options, args) = parser.parse_args()
    mimo = MIMODriver(
        hub_serial=options.hub,
        bs_serials=options.bs_serials.split(','),
        ue_serials=options.ue_serials.split(','),
        rate=options.rate,
        tx_freq=options.freq,
        rx_freq=options.freq,
        tx_gain=options.tx_gain,
        rx_gain=options.rx_gain
    )

    test_nf = True
    if test_nf:
        rx_vec_iris, nf_pwr_dB = mimo.nf(1, 4096)
        print("rx_vec_iris.shape: {}, nf_pwr_dB: {}".format(rx_vec_iris.shape, nf_pwr_dB))

    mimo.close()

if __name__ == '__main__':
    main()
