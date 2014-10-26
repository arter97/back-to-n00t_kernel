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
	make "$@" || exit 1
fi

echo "Building new ramdisk"
#remove previous ramfs files
rm -rf '$RAMFS_TMP'*
rm -rf $RAMFS_TMP
rm -rf $RAMFS_TMP.cpio
#copy ramfs files to tmp directory
cp -ax $RAMFS_SOURCE $RAMFS_TMP
cd $RAMFS_TMP

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
tools/mkbootimg/mkbootimg --kernel $KERNELDIR/arch/arm/boot/zImage --ramdisk $RAMFS_TMP.cpio.lzo --board smdk4x12 --cmdline 'ttySAC2,115200 enforcing=0' --base 0x40000000 --pagesize 2048 -o $KERNELDIR/i9300.img
dd if=/dev/zero bs=$((8388608-$(stat -c %s i9300.img))) count=1 >> i9300.img

echo "done"
ls -al i9300.img
echo ""
ls -al *.ko
