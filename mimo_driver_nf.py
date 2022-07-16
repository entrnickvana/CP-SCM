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
        bs_sched="R"
        [bs.config_sdr_tdd() for i, bs in enumerate(self.bs_obj)] #just guard band - no tx or rx
        [bs.activate_stream_rx() for bs in self.bs_obj]
        rx_data = np.empty((n_frames, self.n_bs_antenna, n_samps), dtype=np.complex64)

        self.bs_trigger()
        rx_data_frame = [bs.recv_stream_tdd() for bs in self.bs_obj]  # Returns dimensions (num bs nodes, num channels, num samples)
        rx_data_frame_arr = np.array(rx_data_frame)
        self.reset_frame()


        return rx_data_frame_arr

#########################################
#                  Main                 #
#########################################
def main():
    parser = OptionParser()
    parser.add_option("--hub", type="string", dest="hub", help="serial number of the hub device", default="FH4B000019")
    parser.add_option("--bs-serials", type="string", dest="bs_serials", help="serial numbers of the BS devices", default='RF3E000146,RF3E000356,RF3E000546')
    parser.add_option("--ue-serials", type="string", dest="ue_serials", help="serial numbers of the UE devices", default='RF3D000016')
    parser.add_option("--rate", type="float", dest="rate", help="Tx sample rate", default=5e6)
    parser.add_option("--freq", type="float", dest="freq", help="Tx freq (Hz). POWDER users must set to 3.6e9", default=3.6e9)
    parser.add_option("--tx-gain", type="float", dest="tx_gain", help="Optional Tx gain (dB)", default=81.0)
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
    nsamps = 1024
    nsamps_pad = 82
    n_sym_samp = nsamps + 2*nsamps_pad - 14

    ltsSym, lts_f = gen_lts(cp=32, upsample=1)

    # to comprensate for front-end group delay
    pad1 = np.zeros((nsamps_pad), np.complex64)
    # to comprensate for rf path delay
    pad2 = np.zeros((nsamps_pad-14), np.complex64)

    wb_pilot = np.tile(ltsSym, nsamps//len(ltsSym)).astype(np.complex64)*.5
    wbz = np.zeros((n_sym_samp), dtype=np.complex64)
    wb_pilot1 = np.concatenate([pad1, wb_pilot, pad2])
    wb_pilot1 = np.transpose(np.matlib.repmat(wb_pilot1, len(options.ue_serials.split(',')), 1))
    wb_pilot2 = wbz  # wb_pilot1 if both_channels else wbz

    test_uplink = True
    if test_uplink:
        ul_rx_data, n_ul_good, numRxSyms = mimo.txrx_uplink(np.real(wb_pilot1), np.imag(wb_pilot1), 5, len(pad2))
        print("Uplink Rx Num {}, ShapeRxData: {}, NumRsyms: {}".format(n_ul_good, ul_rx_data.shape, numRxSyms))

    test_downlink = False
    if test_downlink:
        dl_rx_data, n_dl_good, numRxSyms = mimo.txrx_downlink(np.real(wb_pilot1), np.imag(wb_pilot1), 1, len(pad2))
        print("Downlink Rx Num {}".format(n_dl_good))

    test_sounding = False
    if test_sounding:
        snd_rx_data, n_snd_good, numRxSyms = mimo.txrx_dl_sound(np.real(wb_pilot1), np.imag(wb_pilot1), 1, len(pad2))
        print("Sounding (Downlink) Rx Num {}".format(n_snd_good))

    # 10 frames
    #[txg, rxg, max_val, is_valid] = mimo.set_opt_gains(10)
    #print("BEST GAIN COMBO: TX {} / RX {} with MAX # BEACONS: {}".format(txg,rxg,max_val))
    # Test gain change
    #mimo.update_sdr_params('txgain', 30)
    #mimo.update_sdr_params('rxgain', 30)
    mimo.close()

if __name__ == '__main__':
    main()
