#! /system/bin/sh
##################################################################################
### Copyright (C), 2008-2021, OPLUS Mobile Comm Corp., Ltd.
### Description: XXXXXXXXXXXXXXXXXXXXX.
### Author: <Yongpei.Yao>
###
### ---------------------Revision History: ---------------------
###  <author>        <data>      <version>       <desc>
###  <Yongpei.Yao>   2021/09/14      1.0         build this module
##################################################################################

config="$1"

function logOn() {
    # set log on command
    if [[ `getprop ro.hardware` == mt* ]]; then
        setprop vendor.streamin.pcm.dump 1
        setprop vendor.streamin.dsp.dump 1
        setprop vendor.streamout.pcm.dump 1
        setprop vendor.streamout.dsp.dump 1
        setprop persist.vendor.audiohal.aurisys.pcm_dump_on 1
        setprop vendor.streamin.epl.dump 1
        echo "mtk audio log on"
    else
        echo "qcom audio log on"
    fi
    log -p d -t Debuglog "audio log on"
}

function logOff() {
    # set log off command
    if [[ `getprop ro.hardware` == mt* ]]; then
        setprop vendor.streamin.pcm.dump 0
        setprop vendor.streamin.dsp.dump 0
        setprop vendor.streamout.pcm.dump 0
        setprop vendor.streamout.dsp.dump 0
        setprop persist.vendor.audiohal.aurisys.pcm_dump_on 0
        setprop vendor.streamin.epl.dump 0
        echo "mtk audio log on"
    else
        echo "qcom audio log on"
    fi
    log -p d -t Debuglog "audio log off"
}

case "$config" in
    "logon")
        logOn
        ;;
    "logoff")
        logOff
        ;;
    *)
        ;;
esac
