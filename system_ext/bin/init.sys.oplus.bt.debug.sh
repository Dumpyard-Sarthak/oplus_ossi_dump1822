#! /system/bin/sh
#***********************************************************
#** Copyright (C), 2008-2020, OPLUS Mobile Comm Corp., Ltd.
#** OPLUS_FEATURE_BT_HCI_LOG
#**
#** Version: 1.0
#** Date : 2020/06/06
#** Author: Laixin@CONNECTIVITY.BT.BASIC.LOG.70745, 2020/06/06
#** Add for: cached bt hci log and feedback
#**
#** ---------------------Revision History: ---------------------
#**  <author>    <data>       <version >       <desc>
#**  Laixin    2020/06/06     1.0        build this module
#**  YangQiang 2020/11/20     2.0        add for auto capture switch log
#****************************************************************/

config="$1"

function countCachedHciLog() {
    # cached file under CsLog_xxx
    hciLogCachedPath=`getprop persist.sys.oplus.bt.cache_hcilog_path`
    if [ "w$hciLogCachedPath" = "w" ];then
        hciLogCachedPath="/data/misc/bluetooth/cached_hci/"
    fi
    enPath="/data/persist_log/DCS/en/network_logs/bt_hci_log/"
    dePath="/data/persist_log/DCS/de/network_logs/bt_hci_log/"

    # list out all CsLog under hciLogCachedPath
    allCsLogDir=`ls -A ${hciLogCachedPath} | grep CsLog`
    fullsize=0
    for singleDir in ${allCsLogDir};
    do
        dirSize=`ls -Al ${hciLogCachedPath}/${singleDir} | grep BT_HCI | awk 'BEGIN{sum7=0}{sum7+=$5}END{print sum7}'`
        let fullsize+=${dirSize}
    done
    threadshold=`getprop persist.sys.oplus.bt.cache_hcilog_fsThreshold_bytes`
    if [ ${fullsize} -gt ${threadshold} ];then
        deleteCachedHciLogMtk ${hciLogCachedPath}
    fi
    enAndDeFileLimitNum=2
    deHciLogCnt=`ls -A $dePath`
    deList=($deHciLogCnt)
    deCnt=${#deList[@]}
    if [ ${deCnt} -gt ${enAndDeFileLimitNum} ];then
        deleteCachedHciLog ${dePath} 2
    fi

    enHciLogCnt=`ls -A $enPath`
    enList=($enHciLogCnt)
    enCnt=${#enList[@]}
    if [ ${enCnt} -gt ${enAndDeFileLimitNum} ];then
        deleteCachedHciLog ${enPath} 2
    fi

    #count logcat
    # a logcat file would be 10 MB, keep five files
    cachedLogcatLogNumCnt=`ls -l ${hciLogCachedPath}  | grep "android" | wc -l`
    if [ ${cachedLogcatLogNumCnt} -gt 5 ];then
        deleteSnoopLogcat ${hciLogCachedPath} "android" 5
    fi
    #

    #count event log
    cachedEventLogNumCnt=`ls -l ${hciLogCachedPath}  | grep "event_record" | wc -l`
    if [ ${cachedEventLogNumCnt} -gt 10 ];then
        deleteSnoopLogcat ${hciLogCachedPath} "event_record" 10
    fi
    #

    setprop sys.oplus.bt.count_cache_hcilog 0
}

function uploadCachedHciLog() {
    hciLogCachedPath=`getprop persist.sys.oplus.bt.cache_hcilog_path`
    if [ "w$hciLogCachedPath" = "w" ];then
        hciLogCachedPath="/data/misc/bluetooth/cached_hci/"
    fi
    dePath="/data/persist_log/DCS/de/network_logs/bt_hci_log"

    otaVersion=`getprop ro.build.version.ota`

    uuid=`uuidgen | sed 's/-//g'`
    echo "uuid: ${uuid}"
    uploadReason=`getprop sys.oplus.bt.cache_hcilog_upload_reason`
    if [ "w${uploadReason}" = "w" ];then
        uploadReason="rus_trigger_upload"
    fi

    fileName="bt_hci_log@${uuid:0:16}@${otaVersion}@${uploadReason}.tar.gz"
    # filter out posted file
    excludePosted=`ls -A ${hciLogCachedPath} | grep -v posted_`
    #echo ".... ${excludePosted}  ...."
    #excludePosted=($excludePosted)
    #echo "numbers: ${#excludePosted[@]}"
    num=${#excludePosted[@]}
    if [ num -eq 0 ];then
        setprop sys.oplus.bt.cache_hcilog_rus_upload 0
        return
    fi

    tar -czvf ${dePath}/${fileName} -C $hciLogCachedPath --exclude=posted_* $hciLogCachedPath
    chown -R system:system ${dePath}/${fileName}
    chmod -R 777 ${dePath}/${fileName}

    # for file that not in use, mark it as posted
    #files=${excludePosted}
    #echo "file all $files"
    #for var in ${files};
    #do
    #    if [[ ! ${var} == posted_* ]];then
    #        status=`lsof ${hciLogCachedPath}/${var}`
    #        echo "status of  ${var} : $status"
    #        if [ "w${status}" = "w" ];then
    #            mv ${hciLogCachedPath}/${var} ${hciLogCachedPath}/posted_${var}
    #        fi
    #    fi
    #done

    setprop sys.oplus.bt.cache_hcilog_rus_upload 0
}

function deleteCachedHciLog() {
    logPath=$1
    aim=$2

    # sort file by time 
    filelist=`ls -Atr $logPath`
    filelist=($filelist)
    totalFile=${#filelist[@]}

    th=`getprop persist.sys.oplus.bt.cache_hcilog_fsThreshold_cnt`
    #echo "filelist: ${filelist},, totalFile: ${totalFile},, th: ${th}"
    loop=`expr ${totalFile} - ${aim}`
    while [ ${loop} -gt 0 ];do
        index=`expr $loop - 1`
        if [ "w${logPath}" != "w" ];then
            rm ${logPath}/${filelist[$index]}
        fi
        let loop-=1
    done
}

function deleteCachedHciLogMtk() {
    logPath=$1
    #
    allCsLogDir=`ls -Atr ${hciLogCachedPath} | grep CsLog`
    CsDirList=($allCsLogDir)
    sizeOfCsDir=${#CsDirList[@]}
    loop=`expr ${sizeOfCsDir} - 10`
    if [ $loop -lt 1 ];then
        loop=1; # delete one dir at least
    fi
    while [ ${loop} -gt 0 ];do
        index=`expr $loop - 1`
        if [ "w${logPath}" != "w" ];then
            rm -rf ${logPath}/${CsDirList[$index]}
        fi
        let loop-=1
    done
}

function collectSnoopLogcat() {
    cachedHciLogPath=`getprop persist.sys.oplus.bt.cache_hcilog_path`
    if [ "w${cachedHciLogPath}" == "w" ];then
        cachedHciLogPath="/data/misc/bluetooth/cached_hci/"
    fi

    #if bluetooth keep on, and no new snoop cfa created, keep dumping android log may cause bt
    #occupy too much storage, add these to avoid this situation
    deleteSnoopLogcat ${cachedHciLogPath} "android" 5

    #
    current=`date +%Y%m%d%H%M%S`
    /system/bin/logcat -b main,system,events -f ${cachedHciLogPath}/android_${current}.txt -d -t 15000 -v threadtime *:V
    chown bluetooth:system ${cachedHciLogPath}/android_${current}.txt
    chmod 666 ${cachedHciLogPath}/android_${current}.txt
    # set prop to be false
    setprop sys.oplus.bt.collect_snoop_logcat 0
}

function deleteSnoopLogcat() {
    logPath=$1
    pattern=$2
    # sort file by time
    filelist=`ls -Atr $logPath | grep ${pattern}`
    filelist=($filelist)
    totalFile=${#filelist[@]}

    th=$3
    #echo "filelist: ${filelist},, totalFile: ${totalFile},, th: ${th}"
    loop=`expr ${totalFile} - ${th}`
    while [ ${loop} -gt 0 ];do
        index=`expr $loop - 1`
        if [ "w${logPath}" != "w" ];then
            rm ${logPath}/${filelist[$index]}
        fi
        let loop-=1
    done
}

function collectSSRDumpLogcat() {
    crashReason=`getprop persist.bluetooth.oplus.ssr.reason`
    if [ "w${crashReason}" == "w" ];then
        return
    fi
    DCS_BT_FW_LOG_PATH=/data/persist_log/DCS/de/network_logs/bt_fw_dump
    /system/bin/logcat -b main -b system -b events -f ${DCS_BT_FW_LOG_PATH}/android.log -d -v threadtime *:V
}

function uploadBtSSRDump() {
    DCS_BT_LOG_PATH=/data/persist_log/DCS/de/network_logs/bt_fw_dump
    if [ ! -d ${DCS_BT_LOG_PATH} ];then
        mkdir -p ${DCS_BT_LOG_PATH}
    fi

    #this only provide uuid
    uuidssr=`getprop persist.sys.bluetooth.dump.zip.name`
    otassr=`getprop ro.build.version.ota`
    date_time=`date +%Y-%m-%d_%H-%M-%S`
    zip_name="bt_ssr_dump@${uuidssr}@${otassr}@${date_time}"

    chmod 777 ${DCS_BT_LOG_PATH}/*
    debtssrdumpcount=`ls -l /data/persist_log/DCS/de/network_logs/bt_fw_dump  | grep "bt_ssr_dump" | wc -l`
    enbtssrdumpcount=`ls -l /data/persist_log/DCS/en/network_logs/bt_fw_dump  | grep "bt_ssr_dump" | wc -l`
    dump_count_limit=`getprop persist.sys.bt.ssrdump.limit`
    if [ "x$dump_count_limit" == 'x' ];then
        dump_count_limit=10
    fi
    if [ $debtssrdumpcount -ge ${dump_count_limit} ];then
        # remove the oldest compressed file
        filelist=`ls -Atr $DCS_BT_LOG_PATH | grep bt_ssr_dump`
        filelist=($filelist)
        rm ${DCS_BT_LOG_PATH}/${filelist[0]}
    fi
    # remove op would be failed, double check to avoid file increase
    debtssrdumpcount=`ls -l /data/persist_log/DCS/de/network_logs/bt_fw_dump  | grep "bt_ssr_dump" | wc -l`
    enbtssrdumpcount=`ls -l /data/persist_log/DCS/en/network_logs/bt_fw_dump  | grep "bt_ssr_dump" | wc -l`
    if [ $debtssrdumpcount -lt ${dump_count_limit} ] && [ $enbtssrdumpcount -lt ${dump_count_limit} ];then
        dmesg > ${DCS_BT_LOG_PATH}/kernel_${date_time}.txt
        tar -czvf  ${DCS_BT_LOG_PATH}/${zip_name}.tar.gz --exclude=*.tar.gz -C ${DCS_BT_LOG_PATH} ${DCS_BT_LOG_PATH}
    fi
    #sleep 5
    if [ "w${DCS_BT_LOG_PATH}" != "w" ];then
        rm ${DCS_BT_LOG_PATH}/*.log
        rm ${DCS_BT_LOG_PATH}/*.cfa
        rm ${DCS_BT_LOG_PATH}/*.bin
        rm ${DCS_BT_LOG_PATH}/*.txt
        rm ${DCS_BT_LOG_PATH}/combo_t32*
    fi

    chown system:system ${DCS_BT_LOG_PATH}/${zip_name}.tar.gz
    chmod 777 ${DCS_BT_LOG_PATH}/${zip_name}.tar.gz

    setprop sys.oplus.bt.collect_bt_ssrdump 0
}

#ifdef OPLUS_FEATURE_BT_SWITCH_LOG
#YangQiang@CONNECTIVITY.BT.Basic.Log.490661, 2020/11/20, add for auto capture switch log
function collectBtSwitchLog() {
    boot_completed=`getprop sys.boot_completed`
    logReason=`getprop sys.oplus.bt.switch.log.reason`
    logDate=`date +%Y_%m_%d_%H_%M_%S`
    while [ x${boot_completed} != x"1" ];do
        sleep 2
        boot_completed=`getprop sys.boot_completed`
    done

    btSwitchLogPath="/data/misc/bluetooth/bt_switch_log"
    if [ ! -e  ${btSwitchLogPath} ];then
        mkdir -p ${btSwitchLogPath}
    fi

    dmesg > ${btSwitchLogPath}/dmesg@${logReason}@${logDate}.txt
    /system/bin/logcat -b main -b system -b events -f ${btSwitchLogPath}/android@${logReason}@${logDate}.txt -v threadtime *:V
}

function packBtSwitchLog() {
    btSwitchLogPath="/data/misc/bluetooth/bt_switch_log"
    btLogPath="/data/misc/bluetooth/"
    btSwitchFile="bt_switch_log"
    DCS_BT_LOG_PATH="/data/persist_log/DCS/de/network_logs/bt_switch_log"
    logReason=`getprop sys.oplus.bt.switch.log.reason`
    logFid=`getprop sys.oplus.bt.switch.log.fid`
    version=`getprop ro.build.version.ota`
    logDate=`date +%Y_%m_%d_%H_%M_%S`
    if [ "w${logReason}" == "w" ];then
        return
    fi

    if [ ! -d ${DCS_BT_LOG_PATH} ];then
        mkdir -p ${DCS_BT_LOG_PATH}
        chown system:system ${DCS_BT_LOG_PATH}
        chmod -R 777 ${DCS_BT_LOG_PATH}
    fi

    if [ ! -d ${btSwitchLogPath} ];then
        return
    fi

    tar -czvf  ${DCS_BT_LOG_PATH}/${logReason}.tar.gz -C ${btLogPath} ${btSwitchFile}
    abs_file=${DCS_BT_LOG_PATH}/${logReason}.tar.gz

    fileName="bt_turn_on_failed_${logReason}@${logFid}@${version}@${logDate}.tar.gz"
    mv ${abs_file} ${DCS_BT_LOG_PATH}/${fileName}
    chown system:system ${DCS_BT_LOG_PATH}/${fileName}
    chmod 777 ${DCS_BT_LOG_PATH}/${fileName}
    #rm -rf ${btSwitchLogPath}
    rm -rf ${btSwitchLogPath}/*

    setprop sys.oplus.bt.switch.log.ctl "0"
}
#endif /* OPLUS_FEATURE_BT_SWITCH_LOG */


case "$config" in
        "collectBTCoredumpLog")
        collectBTCoredumpLog
    ;;
        "countCachedHciLog")
        countCachedHciLog
    ;;
        "uploadCachedHciLog")
        uploadCachedHciLog
    ;;
        "uploadBtSSRDump")
        uploadBtSSRDump
    ;;
        "collectSnoopLogcat")
        collectSnoopLogcat
    ;;
        "collectSSRDumpLogcat")
        collectSSRDumpLogcat
    ;;
    #ifdef OPLUS_FEATURE_BT_SWITCH_LOG
    #YangQiang@CONNECTIVITY.BT.Basic.Log.490661, 2020/11/20, add for auto capture switch log
        "collectBtSwitchLog")
        collectBtSwitchLog
    ;;
        "packBtSwitchLog")
        packBtSwitchLog
    ;;
    #endif /* OPLUS_FEATURE_BT_SWITCH_LOG */
esac
