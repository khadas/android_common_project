#!/bin/bash
#
#  author: xindong.xu@amlogic.com
#  2020.04.15

function clean() {
	echo "Clean up"
	CUR_DIR=$(pwd)
	cd $CUR_DIR
	rm -rf out_android out_tmp
	return
}

function build() {
	TARGET_ZIP=$1
	TOOLS_ZIP=$2
	KERNEL_DIR=$3
	BOARD_NAME=$4
	CUR_DIR=$(pwd)

	rm -rf out_android/*
	cd $CUR_DIR
	unzip -o -q $TOOLS_ZIP -d $CUR_DIR/out_android

	chmod +x $CUR_DIR/out_android/prebuilts/jdk/jdk17/linux-x86/bin/*
	export PATH=$CUR_DIR/:$CUR_DIR/out_android/:$CUR_DIR/out_android/bin/:$CUR_DIR/out_android/prebuilts/jdk/jdk17/linux-x86/bin/:$PATH
	export LD_LIBRARY_PATH=$CUR_DIR/out_android/lib64:$LD_LIBRARY_PATH

	echo $PATH
	echo $LD_LIBRARY_PATH

	rm -rf out_android/normal_target
	echo "unzip $TARGET_ZIP"
	unzip -o -q $TARGET_ZIP -d $CUR_DIR/out_android/normal_target

	if [[ "$BOARD_NAME" = "ohm" ]]; then
		BOARD_AML_SOC_TYPE=S905X4
	elif [[ "$BOARD_NAME" = "adt4" ]]; then
		BOARD_AML_SOC_TYPE=S905X4
	elif [[ "$BOARD_NAME" = "calla" ]]; then
		BOARD_AML_SOC_TYPE=T963D4
	elif [[ "$BOARD_NAME" = "ohmcas" ]]; then
		BOARD_AML_SOC_TYPE=S905C2
	elif [[ "$BOARD_NAME" = "ohmcas2" ]]; then
		BOARD_AML_SOC_TYPE=S905C2L
	elif [[ "$BOARD_NAME" = "planck" ]]; then
		BOARD_AML_SOC_TYPE=S805X2
	elif [[ "$BOARD_NAME" = "oppencas" ]]; then
		BOARD_AML_SOC_TYPE=S905C3
	elif [[ "$BOARD_NAME" = "tyson" ]]; then
		BOARD_AML_SOC_TYPE=S928X
	elif [[ "$BOARD_NAME" = "oppen" ]]; then
		BOARD_AML_SOC_TYPE=S905Y4
	elif [[ "$BOARD_NAME" = "boreal" ]]; then
		BOARD_AML_SOC_TYPE=S805X2G
	fi

	cd $CUR_DIR/out_android/normal_target/IMAGES/
	rm -rf boot.img dtbo.img system_dlkm.* vendor_boot.img vendor_dlkm.*

	cd $CUR_DIR/out_android/normal_target/PREBUILT_IMAGES/
	rm -rf boot.img dtbo.img

	cd $CUR_DIR

	cp -a $KERNEL_DIR/gki/boot-gz.img $CUR_DIR/out_android/normal_target/PREBUILT_IMAGES/boot.img
	cp -a $KERNEL_DIR/dtbo.img $CUR_DIR/out_android/normal_target/PREBUILT_IMAGES/dtbo.img

	echo "copy $CUR_DIR/out_android/normal_target/SYSTEM_DLKM"
	rm -rf $CUR_DIR/out_android/normal_target/SYSTEM_DLKM/lib/modules/*
	cp -a $KERNEL_DIR/gki/lib/modules/* $CUR_DIR/out_android/normal_target/SYSTEM_DLKM/lib/modules/
	cp -a $KERNEL_DIR/system_dlkm.modules.load $CUR_DIR/out_android/normal_target/SYSTEM_DLKM/lib/modules/
	cp -a $KERNEL_DIR/system_dlkm.modules.load $CUR_DIR/out_android/normal_target/VENDOR_DLKM/lib/modules/

	echo "copy $CUR_DIR/out_android/normal_target/VENDOR_BOOT"
	rm -rf $CUR_DIR/out_android/normal_target/VENDOR_BOOT/RAMDISK/lib/modules/*.ko
	cp -a $KERNEL_DIR/ramdisk/lib/modules/* $CUR_DIR/out_android/normal_target/VENDOR_BOOT/RAMDISK/lib/modules/
	cp -a $KERNEL_DIR/vendor_boot.modules.load $CUR_DIR/out_android/normal_target/VENDOR_BOOT/RAMDISK/lib/modules/modules.load
	cp -a $KERNEL_DIR/vendor_recovery.modules.load $CUR_DIR/out_android/normal_target/VENDOR_BOOT/RAMDISK/lib/modules/modules.load.recovery
	cp -a $KERNEL_DIR/$BOARD_NAME.dtb $CUR_DIR/out_android/normal_target/VENDOR_BOOT/dtb
	cp -a $KERNEL_DIR/dtbo.img $CUR_DIR/out_android/normal_target/VENDOR_BOOT/recovery_dtbo

	rm -rf $CUR_DIR/out_tmp/depmod_vendor_intermediates
	mkdir -p $CUR_DIR/out_tmp/depmod_vendor_intermediates/lib/modules/0.0/lib/modules
	cp -a $CUR_DIR/out_android/normal_target/VENDOR_BOOT/RAMDISK/lib/modules/*.ko $CUR_DIR/out_tmp/depmod_vendor_intermediates/lib/modules/0.0/lib/modules/
	./common/common14-5.15/prebuilts/kernel-build-tools/linux-x86/bin/depmod -b $CUR_DIR/out_tmp/depmod_vendor_intermediates 0.0
	sed -e 's/\(.*modules.*\):/\/\1:/g' -e 's/ \([^ ]*modules[^ ]*\)/ \/\1/g' $CUR_DIR/out_tmp/depmod_vendor_intermediates/lib/modules/0.0/modules.dep > $CUR_DIR/out_android/normal_target/VENDOR_BOOT/RAMDISK/lib/modules/modules.dep
	cp $CUR_DIR/out_tmp/depmod_vendor_intermediates/lib/modules/0.0/modules.alias $CUR_DIR/out_android/normal_target/VENDOR_BOOT/RAMDISK/lib/modules/
	rm -rf $CUR_DIR/out_tmp/depmod_vendor_intermediates

	echo "copy $CUR_DIR/out_android/normal_target/VENDOR_DLKM"
	cp -a $KERNEL_DIR/lib/modules/* $CUR_DIR/out_android/normal_target/VENDOR_DLKM/lib/modules/
	cp -a $KERNEL_DIR/vendor_dlkm.modules.load $CUR_DIR/out_android/normal_target/VENDOR_DLKM/lib/modules/modules.load

	mkdir -p $CUR_DIR/out_tmp/depmod_vendor_intermediates/lib/modules/0.0/vendor/lib/modules
	cp -a $CUR_DIR/out_android/normal_target/VENDOR_DLKM/lib/modules/*.ko $CUR_DIR/out_tmp/depmod_vendor_intermediates/lib/modules/0.0/vendor/lib/modules/
	./common/common14-5.15/prebuilts/kernel-build-tools/linux-x86/bin/depmod -b $CUR_DIR/out_tmp/depmod_vendor_intermediates 0.0
	sed -e 's/\(.*modules.*\):/\/\1:/g' -e 's/ \([^ ]*modules[^ ]*\)/ \/\1/g' $CUR_DIR/out_tmp/depmod_vendor_intermediates/lib/modules/0.0/modules.dep > $CUR_DIR/out_android/normal_target/VENDOR_DLKM/lib/modules/modules.dep
	cp $CUR_DIR/out_tmp/depmod_vendor_intermediates/lib/modules/0.0/modules.alias $CUR_DIR/out_android/normal_target/VENDOR_DLKM/lib/modules/
	rm -rf $CUR_DIR/out_tmp/depmod_vendor_intermediates

	echo "copy $CUR_DIR/out_android/normal_target/VENDOR"
	rm -rf $CUR_DIR/out_android/normal_target/VENDOR/lib/firmware/video/*
	cp -a $KERNEL_DIR/lib/firmware/video/checkmsg $CUR_DIR/out_android/normal_target/VENDOR/lib/firmware/video/
	if [ "$BOARD_AML_SOC_TYPE" = "false" ]; then
		cp -a $KERNEL_DIR/lib/firmware/video/*.bin $CUR_DIR/out_android/normal_target/VENDOR/lib/firmware/video/
	else
		cp -a $KERNEL_DIR/lib/firmware/video/$BOARD_AML_SOC_TYPE/*.bin $CUR_DIR/out_android/normal_target/VENDOR/lib/firmware/video/
	fi

	cd $CUR_DIR/out_android/

	(cd  normal_target/VENDOR; find . -type d | sed 's,$,/,'; find . \! -type d) | cut -c 3- | sort | sed 's,^,vendor/,' | bin/fs_config -C -D  normal_target/SYSTEM -S  normal_target/META/file_contexts.bin -R vendor/ >  normal_target/META/vendor_filesystem_config.txt

	(cd  normal_target/VENDOR_BOOT/RAMDISK; find . -type d | sed 's,$,/,'; find . \! -type d) | cut -c 3- | sort | sed 's,^,,' | bin/fs_config -C -D  normal_target/SYSTEM -S  normal_target/META/file_contexts.bin -R '' >  normal_target/META/vendor_boot_filesystem_config.txt

	(cd  normal_target/VENDOR_DLKM; find . -type d | sed 's,$,/,'; find . \! -type d) | cut -c 3- | sort | sed 's,^,vendor_dlkm/,' | bin/fs_config -C -D  normal_target/SYSTEM -S  normal_target/META/file_contexts.bin -R vendor_dlkm/ >  normal_target/META/vendor_dlkm_filesystem_config.txt

	(cd  normal_target/SYSTEM_DLKM; find . -type d | sed 's,$,/,'; find . \! -type d) | cut -c 3- | sort | sed 's,^,system_dlkm/,' | bin/fs_config -C -D  normal_target/SYSTEM -S  normal_target/META/file_contexts.bin -R system_dlkm/ >  normal_target/META/system_dlkm_filesystem_config.txt

	echo "mkbootimg..."
	MKBOOTIMG=bin/mkbootimg ./bin/add_img_to_target_files -a -r -v normal_target

	if [ $? -ne 0 ]; then
		echo "build img ERROR"
		exit 1
	fi
	echo "build img OK"

	cd $CUR_DIR
	rm -rf out_tmp

	exit 0
}

function usage() {
	cat << EOF
Usage:
$(basename $0) --help

command list:
./common/project/build/generata_imgs.sh clean   ### clean intermediate file
./common/project/build/generata_imgs.sh target.zip otatools.zip common/common14-5.15/out/android/ohm ohm

EOF
	exit 1
}

function show_version() {
cat << EOF
20230531.01

EOF
	exit 1
}

function parser() {
	local i=0
	local argv=()
	for arg in "$@" ; do
		argv[$i]="$arg"
		i=$((i + 1))
	done
	i=0
	while [ $i -lt $# ]; do
		arg="${argv[$i]}"
		i=$((i + 1)) # must place here
		case "$arg" in
			-h|--help|help)
				usage
				exit ;;
			-v)
				show_version
				exit ;;
			clean|distclean|-distclean|--distclean)
				clean
				exit ;;
			*)
		esac
	done
}

function main() {
	if [ -z $1 ]
	then
		usage
		return
	fi

	parser $@
	build $@
}

main $@ # parse all paras to function
