#!/system/bin/sh
#
#ifdef OPLUS_FEATURE_ZRAM_OPT


function configure_read_ahead_kb_values() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}
	erofs_ra_kb=128

	dmpts=$(ls /sys/block/*/queue/read_ahead_kb | grep -e dm -e mmc)

	# Set 128 for <= 3GB &
	# set 512 for >= 4GB targets.
	if [ $MemTotal -le 4194304 ]; then
		ra_kb=128
	else
		ra_kb=512
	fi

	if [ -f /sys/block/mmcblk0/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0/bdi/read_ahead_kb
	fi
	if [ -f /sys/block/mmcblk0rpmb/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
	fi

	for dm in $dmpts; do
		# mtk configure dm-[0-5], so we don't need rewrite here.
		ignore=`echo $dm | grep 'dm-[0-5]/'`
		if [ ! -z "$ignore" ]; then
			continue
		fi

		dm_dev=`echo $dm |cut -d/ -f4`
		if [ "$dm_dev" = "" ]; then
			is_erofs=""
		else
			is_erofs=`mount |grep erofs |grep "${dm_dev} "`
		fi
		if [ "$is_erofs" = "" ]; then
			echo $ra_kb > $dm
		else
			echo $erofs_ra_kb > $dm
		fi
	done
}


MemTotalStr=`cat /proc/meminfo | grep MemTotal`
MemTotal=${MemTotalStr:16:8}

if [ $MemTotal -le 2097152 ]; then
  #config 1GB zram size with memory less than 2 GB
  echo lz4 > /sys/block/zram0/comp_algorithm
  echo 1342177280 > /sys/block/zram0/disksize
  echo 180 > /proc/sys/vm/swappiness
  echo 0 > /proc/sys/vm/direct_swappiness
elif [ $MemTotal -le 3145728 ]; then
  #config 1.6GB zram size with memory less than 3 GB
  echo lz4 > /sys/block/zram0/comp_algorithm
  echo 1717986918 > /sys/block/zram0/disksize
  echo 160 > /proc/sys/vm/swappiness
  echo 60 > /proc/sys/vm/direct_swappiness
elif [ $MemTotal -le 4194304 ]; then
  #config 2GB zram size with memory less than 4 GB
  echo lz4 > /sys/block/zram0/comp_algorithm
  echo 2684354560 > /sys/block/zram0/disksize
  echo 160 > /proc/sys/vm/swappiness
  echo 60 > /proc/sys/vm/direct_swappiness
elif [ $MemTotal -le 6291456 ]; then
  #config 3GB zram size with memory 6 GB
  echo lz4 > /sys/block/zram0/comp_algorithm
  echo 3221225472 > /sys/block/zram0/disksize
  echo 160 > /proc/sys/vm/swappiness
  echo 60 > /proc/sys/vm/direct_swappiness
else
  #config 4GB zram size with memory greater than 6 GB
  echo lz4 > /sys/block/zram0/comp_algorithm
  echo 4294967296 > /sys/block/zram0/disksize
  echo 160 > /proc/sys/vm/swappiness
  echo 60 > /proc/sys/vm/direct_swappiness
fi

configure_read_ahead_kb_values

mkswap /dev/block/zram0
swapon /dev/block/zram0
#endif /* OPLUS_FEATURE_ZRAM_OPT */
