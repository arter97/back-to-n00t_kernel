#!/bin/bash
export KERNELDIR=`readlink -f .`
export RAMFS_SOURCE=`readlink -f $KERNELDIR/ramdisk`
export USE_SEC_FIPS_MODE=true

echo "kerneldir = $KERNELDIR"
echo "ramfs_source = $RAMFS_SOURCE"

RAMFS_TMP="/tmp/arter97-ramdisk"

echo "ramfs_tmp = $RAMFS_TMP"
cd $KERNELDIR

if [ "${1}" = "skip" ] ; then
	echo "Skipping Compilation"
else
	echo "Compiling kernel"
	cp defconfig .config
	scripts/configcleaner "
CONFIG_WLAN_REGION_CODE
CONFIG_TARGET_LOCALE_EUR
CONFIG_TARGET_LOCALE_USA
CONFIG_TARGET_LOCALE_KOR
CONFIG_MACH_M0_KOR_SKT
CONFIG_MACH_M0_KOR_KT
CONFIG_MACH_M0_KOR_LGT
"
	echo "
CONFIG_WLAN_REGION_CODE=201
# CONFIG_TARGET_LOCALE_EUR is not set
# CONFIG_TARGET_LOCALE_USA is not set
CONFIG_TARGET_LOCALE_KOR=y
CONFIG_MACH_M0_KOR_SKT=y
# CONFIG_MACH_M0_KOR_KT is not set
# CONFIG_MACH_M0_KOR_LGT is not set
" >> .config
	make "$@" || exit 1
fi

echo "Building new ramdisk"
#remove previous ramfs files
rm -rf '$RAMFS_TMP'*
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
#copy ramfs files to tmp directory
cp -ax $RAMFS_SOURCE $RAMFS_TMP
rm $RAMFS_TMP/sbin/cbd
cp -p m440s/cbd $RAMFS_TMP/sbin/
cd $RAMFS_TMP

find . -name "*smdk4x12*" | while read file; do mv -f "$file" "$(echo $file | sed s/smdk4x12/SHW-M440S/g)"; done
find . -name "*rc*" | while read file; do sed -i -e s/smdk4x12/SHW-M440S/g $file ; done

$KERNELDIR/ramdisk_fix_permissions.sh 2>/dev/null

#clear git repositories in ramfs
find . -name .git -exec rm -rf {} \;
find . -name EMPTY_DIRECTORY -exec rm -rf {} \;
cd $KERNELDIR
rm -rf $RAMFS_TMP/tmp/*

rm *.ko 2>/dev/null
find . -name "*.ko" -exec cp {} . \;
ls *.ko | while read file; do /home/arter97/toolchain/bin/arm-linux-gnueabihf-strip --strip-unneeded $file ; done
cp -av *.ko $RAMFS_TMP/lib/modules/
chmod 644 $RAMFS_TMP/lib/modules/*
cd $RAMFS_TMP
find . | fakeroot cpio -H newc -o | lzop -9 > $RAMFS_TMP.cpio.lzo
ls -lh $RAMFS_TMP.cpio.lzo
cd $KERNELDIR

echo "Making new boot image"
gcc -w -s -pipe -O2 -Itools/libmincrypt -o tools/mkbootimg/mkbootimg tools/libmincrypt/*.c tools/mkbootimg/mkbootimg.c
tools/mkbootimg/mkbootimg --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.lzo --board smdk4x12 --cmdline 'ttySAC2,115200 enforcing=0' --base 0x40000000 --pagesize 2048 -o $KERNELDIR/m440s.img
dd if=/dev/zero bs=$((8388608-$(stat -c %s m440s.img))) count=1 >> m440s.img

echo "done"
ls -al m440s.img
echo ""
ls -al *.ko
