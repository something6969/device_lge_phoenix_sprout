#!/vendor/bin/sh

target=`getprop ro.board.platform`
#device=`getprop ro.product.device`
#product=`getprop ro.product.name`
#region=`getprop ro.product.locale.region`
#characteristics=`getprop ro.build.characteristics`

start() {
  # Check the available memory
  memtotal_str=$(grep 'MemTotal' /proc/meminfo)
  memtotal_tmp=${memtotal_str#MemTotal:}
  memtotal_kb=${memtotal_tmp%kB}

  echo MemTotal is $memtotal_kb kB

  #check built-in zram devices
  nr_builtin_zram=$(ls /dev/block/zram* | grep -c zram)

  if [ "$nr_builtin_zram" -ne "0" ] ; then
    #use the built-in zram devices
    nr_zramdev=${nr_builtin_zram}
    use_mod=0
  else
    use_mod=1
    # Detect the number of cores
    nr_cores=$(grep -c ^processor /proc/cpuinfo)

    # Evaluate the number of zram devices based on the number of cores.
    nr_zramdev=${nr_cores/#0/1}
    echo The number of cores is $nr_cores
  fi
  echo zramdev $nr_zramdev

  # Evaluate the zram size for swap
  # C/Y need to increase zram size 450Mb
  # aka jagn b2ln need to increase zram size to 450Mb (only korea device)
  #if [ "$region" -eq "KR" ] ; then
  #  case $device in
  #    "aka" | "jagn" | "b2ln" | "e8lte")
  #      characteristics="increase"
  #    ;;
  #  esac
  #fi

  # Add zram tunable parameters
  # you can set "compr_zram=lzo" or "compr_zram=lz4"
  # but when you set "zram=lz4", you must set "CONFIG_ZRAM_LZ4_COMPRESS=y"
  compr_zram=lzo
  nr_multi_zram=1
  sz_zram0=0
  zram_async=0

  case $target in
    "msm8916")
      sz_zram=$((((memtotal_kb/4) / ${nr_zramdev}) * 1024))
      compr_zram=lz4
      nr_multi_zram=1

      #case $product in
      #    "g4stylusn_global_com" | "g4stylusds_global_com" | "g4stylusdsn_global_com")
      #      sz_zram=$((((memtotal_kb/2) / ${nr_zramdev}) * 1024))
      #      compr_zram=lzo
      #      nr_multi_zram=1
      #  ;;
      #esac

      #case $product in
      #    "c90_global_com" | "c90n_global_com" | "c70_global_com" | "c70n_global_com" | "c70ds_global_com")
      #      sz_zram=$((((memtotal_kb/2) / ${nr_zramdev}) * 1024))
      #      compr_zram=lzo
      #      nr_multi_zram=1
      #  ;;
      #esac

      #case $product in
      #    "altev2_vzw" )
      #     sz_zram=$((((memtotal_kb/3) / ${nr_zramdev}) * 1024))
      #     compr_zram=lzo
      #     nr_multi_zram=1
      #  ;;
      #esac
    ;;
    "msm8226")
        #case $characteristics in
        #  "increase")
        #    sz_zram=$((((memtotal_kb/2) / ${nr_zramdev}) * 1024))
        #  ;;
        #  "tablet")
        #    sz_zram=$((((memtotal_kb/3) / ${nr_zramdev}) * 1024))
        #  ;;
        #  *)
            sz_zram=$((((memtotal_kb/4) / ${nr_zramdev}) * 1024))
        #  ;;
        #esac
    ;;
    "msm8996" | "msm8952")
        sz_zram=$((((memtotal_kb/4) / ${nr_zramdev}) * 1024))
        compr_zram=lz4
        nr_multi_zram=4
    ;;
    "msm8998")
        sz_zram=$(((memtotal_kb/4) * 1024))
        sz_zram0=$(((memtotal_kb/4) * 1024))
        compr_zram=lz4
        nr_multi_zram=4
        zram_async=1
        max_write_threads=4
    ;;
    *)
      sz_zram=$((((memtotal_kb/4) / ${nr_zramdev}) * 1024))
    ;;
  esac
  echo sz_zram size is ${sz_zram}

  # load kernel module for zram
  if [ "$use_mod" -eq "1"  ] ; then
    modpath=/system/lib/modules/zram.ko
    modargs="num_devices=${nr_zramdev}"
    echo zram.ko is $modargs

    if [ -f $modpath ] ; then
      insmod $modpath $modargs && (echo "zram module loaded") || (echo "module loading failed and exiting(${?})" ; exit $?)
    else
      echo "zram module not exist(${?})"
      exit $?
    fi
  fi

  # initialize and configure the zram devices as a swap partition
  zramdev_num=0
  if [ "$sz_zram0" -e "0" ] ; then
    sz_zram0=$((${sz_zram} * ${nr_zramdev}))
  fi
  swap_prio=5
  while [[ $zramdev_num -lt $nr_zramdev ]]; do
    modpath_comp_streams=/sys/block/zram${zramdev_num}/max_comp_streams
    modpath_comp_algorithm=/sys/block/zram${zramdev_num}/comp_algorithm
    # If compr_zram is not available, then use default zram comp_algorithm
    available_comp_algorithm="$(cat $modpath_comp_algorithm | grep $compr_zram)"
    if [ "$available_comp_algorithm" ]; then
      if [ -f $modpath_comp_streams ] ; then
        echo $nr_multi_zram > /sys/block/zram${zramdev_num}/max_comp_streams
      fi
      if [ -f $modpath_comp_algorithm ] ; then
        echo $compr_zram > /sys/block/zram${zramdev_num}/comp_algorithm
      fi
    fi
    if [ "$zramdev_num" -ne "0" ] ; then
      echo $sz_zram > /sys/block/zram${zramdev_num}/disksize
    else
      if [ "$zram_async" -ne "0" ] ; then
        echo $zram_async > /sys/block/zram${zramdev_num}/async
        echo $max_write_threads > /sys/block/zram${zramdev_num}/max_write_threads
      fi
      echo $sz_zram0 > /sys/block/zram${zramdev_num}/disksize
    fi
    mkswap /dev/block/zram${zramdev_num} && (echo "mkswap ${zramdev_num}") || (echo "mkswap ${zramdev_num} failed and exiting(${?})" ; exit $?)
    swapon -p $swap_prio /dev/block/zram${zramdev_num} && (echo "swapon ${zramdev_num}") || (echo "swapon ${zramdev_num} failed and exiting(${?})" ; exit $?)
    ((zramdev_num++))
    ((swap_prio++))
  done

  # tweak VM parameters considering zram/swap

  #deny_minfree_change=`getprop ro.lge.deny.minfree.change`

  #case $product in
  #  "c90_global_com" | "c90n_global_com" | "c70_global_com" | "c70n_global_com" | "c70ds_global_com")
  #    swappiness_new=100
  #  ;;
  #  *)
      swappiness_new=80
  #  ;;
  #esac

  overcommit_memory=1
  page_cluster=0
  #if [ "$deny_minfree_change" -ne "1" ] ; then
  #     let min_free_kbytes=$(cat /proc/sys/vm/min_free_kbytes)*2
  #fi
  laptop_mode=0

  echo $swappiness_new > /proc/sys/vm/swappiness
  echo $overcommit_memory > /proc/sys/vm/overcommit_memory
  echo $page_cluster > /proc/sys/vm/page-cluster
  #if [ "$deny_minfree_change" -ne "1" ] ; then
  #     echo $min_free_kbytes > /proc/sys/vm/min_free_kbytes
  #fi
  echo $laptop_mode > /proc/sys/vm/laptop_mode
}

stop() {
  swaps=$(grep zram /proc/swaps)
  swaps=${swaps%%partition*}
  if [ $swaps ] ; then
    for i in $swaps; do
     swapoff $i
    done
    for j in $(ls /sys/block | grep zram); do
      echo 1 ${j}/reset
    done
    if [ $(lsmod | grep -c zram) -ne "0" ] ; then
      rmmod zram && (echo "zram unloaded") || (echo "zram unload fail(${?})" ; exit $?)
    fi
  fi
}

cmd=${1-start}

case $cmd in
  "start") start
  ;;
  "stop") stop
  ;;
  *) echo "Undefined command!"
  ;;
esac
