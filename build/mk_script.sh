#!/bin/bash
#
#  author: xindong.xu@amlogic.com
#  2020.04.15

function clean() {
	echo "Clean up ${MAIN_FOLDER}"
	cd ${MAIN_FOLDER}
	for common_dir in `ls common*/mk.sh`; do
		common_dir=`dirname ${common_dir}`
		echo "clean: ${common_dir}"
		(cd ${common_dir}; [[ -d bazel-out ]] && tools/bazel clean --async; [[ -d out ]] && rm -rf out; [[ -d out_abi ]] && rm -rf out_abi)
	done
	return
}

function build_deadpool() {
	echo "------project/askey/deadppol/build.config.meson.arm64.deadpool-----"
	cd ${MAIN_FOLDER}
	export BUILD_CONFIG=project/askey/deadpool/build.config.meson.arm64.deadpool

	. ${MAIN_FOLDER}/${BUILD_CONFIG}
	export $(sed -n -e 's/\([^=]\)=.*/\1/p' ${MAIN_FOLDER}/${BUILD_CONFIG})
	if [ $CONFIG_AB_UPDATE ]; then
		echo "=====ab update mode====="
		for aDts in ${KERNEL_DEVICETREE}; do
			sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic_ab.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
		done
	else
		echo "=====normal mode====="
		for aDts in ${KERNEL_DEVICETREE}; do
			sed -i 's/^#include \"partition_.*/#include "partition_mbox_dynamic_deadpool.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
		done
	fi

	cd ${MAIN_FOLDER}
	./project/build/build_kernel_4.9.sh
}

function build_boreal() {
	echo "------project/google/boreal/build.config.meson.arm64.trunk-----"
	cd ${MAIN_FOLDER}
	export BUILD_CONFIG=project/google/boreal/build.config.meson.arm64.trunk
	export TARGET_BUILD_KERNEL_VERSION=5.4
        export TARGET_BUILD_KERNEL_4_9=false
	. ${MAIN_FOLDER}/${BUILD_CONFIG}
	export $(sed -n -e 's/\([^=]\)=.*/\1/p' ${MAIN_FOLDER}/${BUILD_CONFIG})

	if [ $CONFIG_KERNEL_DDR_1G ]; then
		export KERNEL_DEVICETREE=${KERNEL_DEVICETREE_DDR_1G}
	fi

	echo "KERNEL_DEVICETREE: ${KERNEL_DEVICETREE}"

	echo "=====ab update & vendor boot mode====="
	for aDts in ${KERNEL_DEVICETREE}; do
		if [ $KERNEL_A32_SUPPORT ]; then
			sed -i 's/^#include \"partition_.*/#include "partition_mbox_ab.dtsi"/' ${KERNEL_DIR}/arch/arm/boot/dts/amlogic/$aDts.dts;
		else
			sed -i 's/^#include \"partition_.*/#include "partition_mbox_ab.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
		fi
	done

	echo "================================="

	cd ${MAIN_FOLDER}
	./project/build/build.sh
}
function build_anning() {
	if [ $KERNEL_A32_SUPPORT ]; then
		echo "------project/amlogic/ampere/anning/build.config.meson.arm.trunk_4.9-----"
	else
		echo "------project/amlogic/ampere/anning/build.config.meson.arm64.trunk_4.9-----"
	fi

	cd ${MAIN_FOLDER}
	if [ $KERNEL_A32_SUPPORT ]; then
		export BUILD_CONFIG=project/amlogic/ampere/anning/build.config.meson.arm.trunk_4.9
	else
		export BUILD_CONFIG=project/amlogic/ampere/anning/build.config.meson.arm64.trunk_4.9
	fi

	export TARGET_BUILD_KERNEL_VERSION=4.9
        export TARGET_BUILD_KERNEL_4_9=true
	. ${MAIN_FOLDER}/${BUILD_CONFIG}
	export $(sed -n -e 's/\([^=]\)=.*/\1/p' ${MAIN_FOLDER}/${BUILD_CONFIG})
	echo "KERNEL_DEVICETREE: ${KERNEL_DEVICETREE}"
	if [ $CONFIG_AB_UPDATE ]; then
		echo "=====ab update mode====="
		for aDts in ${KERNEL_DEVICETREE}; do
			if [ $KERNEL_A32_SUPPORT ]; then
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic_ab.dtsi"/' ${KERNEL_DIR}/arch/arm/boot/dts/amlogic/$aDts.dts;
			else
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic_ab.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
			fi
		done
	else
		echo "=====normal mode====="
		for aDts in ${KERNEL_DEVICETREE}; do
			if [ $KERNEL_A32_SUPPORT ]; then
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic.dtsi"/' ${KERNEL_DIR}/arch/arm/boot/dts/amlogic/$aDts.dts;
			else
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
			fi
		done
	fi
	echo "================================="
    echo "KERNEL_DEVICETREE === ${KERNEL_DEVICETREE}"
	cd ${MAIN_FOLDER}
	./project/build/build_kernel_4.9.sh
}

function copy_out() {
	SRC_PATH=$1
	if [ ${ANDROID_OUT_DIR} -a -d ${ANDROID_OUT_DIR} ]; then
		echo "copy kernel to incoming android out dir"
		rm -rf ${ANDROID_OUT_DIR}/*
		cp -a ${SRC_PATH}/* ${ANDROID_OUT_DIR}/
	else
		if [ "$2" = "adt4" ]; then
			ANDROID_PROJECT_PATH=device/sei/adt4-kernel
		else
			ANDROID_PROJECT_PATH=device/amlogic/$2-kernel
		fi
		if [ $KERNEL_A32_SUPPORT ]; then
			if [[ -d ${MAIN_FOLDER}/../${ANDROID_PROJECT_PATH} ]]; then
				DST_PATH=${MAIN_FOLDER}/../${ANDROID_PROJECT_PATH}/32/${KERNEL_VERSION}
			elif [[ -d ${MAIN_FOLDER}/${ANDROID_PROJECT_PATH} ]]; then
				DST_PATH=${MAIN_FOLDER}/${ANDROID_PROJECT_PATH}/32/${KERNEL_VERSION}
			fi
		else
			if [[ -d ${MAIN_FOLDER}/../${ANDROID_PROJECT_PATH} ]]; then
				DST_PATH=${MAIN_FOLDER}/../${ANDROID_PROJECT_PATH}/${KERNEL_VERSION}
			elif [[ -d ${MAIN_FOLDER}/${ANDROID_PROJECT_PATH} ]]; then
				DST_PATH=${MAIN_FOLDER}/${ANDROID_PROJECT_PATH}/${KERNEL_VERSION}
			fi

		fi
		if [[ -d ${MAIN_FOLDER}/../${ANDROID_PROJECT_PATH} || -d ${MAIN_FOLDER}/${ANDROID_PROJECT_PATH} ]]; then
			mkdir -p ${DST_PATH}
			DST_PATH=`realpath ${DST_PATH}`
			echo "copy kernel to ${DST_PATH}"
			rm -rf ${DST_PATH}/*
			pwd
			cp -a ${SRC_PATH}/* ${DST_PATH}/
		fi
	fi
}

function build_common_4.9() {
	if [ $KERNEL_A32_SUPPORT ]; then
		echo "------project/${device_project}/$1/build.config.meson.arm.trunk_4.9-----"
	else
		echo "------project/${device_project}/$1/build.config.meson.arm64.trunk_4.9-----"
	fi
	cd ${MAIN_FOLDER}
	if [ $KERNEL_A32_SUPPORT ]; then
		export BUILD_CONFIG=project/${device_project}/$1/build.config.meson.arm.trunk_4.9
	else
		export BUILD_CONFIG=project/${device_project}/$1/build.config.meson.arm64.trunk_4.9
	fi
	export TARGET_BUILD_KERNEL_VERSION=4.9
        export TARGET_BUILD_KERNEL_4_9=true

	. ${MAIN_FOLDER}/${BUILD_CONFIG}
	export $(sed -n -e 's/\([^=]\)=.*/\1/p' ${MAIN_FOLDER}/${BUILD_CONFIG})
	echo "KERNEL_DEVICETREE: ${KERNEL_DEVICETREE}"
	if [ $CONFIG_AB_UPDATE ]; then
		echo "=====ab update mode====="
		for aDts in ${KERNEL_DEVICETREE}; do
			if [ $KERNEL_A32_SUPPORT ]; then
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic_ab.dtsi"/' ${KERNEL_DIR}/arch/arm/boot/dts/amlogic/$aDts.dts;
			else
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic_ab.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
			fi
		done
	else
		echo "=====normal mode====="
		for aDts in ${KERNEL_DEVICETREE}; do
			if [ $KERNEL_A32_SUPPORT ]; then
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic.dtsi"/' ${KERNEL_DIR}/arch/arm/boot/dts/amlogic/$aDts.dts;
			else
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_normal_dynamic.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
			fi
		done
	fi
	echo "================================="

	cd ${MAIN_FOLDER}
	./project/build/build_kernel_4.9.sh
}

function build_common_5.4() {
	if [ $KERNEL_A32_SUPPORT ]; then
		echo "------project/${device_project}/$1/build.config.meson.arm.trunk-----"
	else
		echo "------project/${device_project}/$1/build.config.meson.arm64.trunk-----"
	fi

	cd ${MAIN_FOLDER}
	if [ $KERNEL_A32_SUPPORT ]; then
		export BUILD_CONFIG=project/${device_project}/$1/build.config.meson.arm.trunk
	else
		export BUILD_CONFIG=project/${device_project}/$1/build.config.meson.arm64.trunk
	fi
	export TARGET_BUILD_KERNEL_VERSION=5.4
        export TARGET_BUILD_KERNEL_4_9=false
	. ${MAIN_FOLDER}/${BUILD_CONFIG}
	export $(sed -n -e 's/\([^=]\)=.*/\1/p' ${MAIN_FOLDER}/${BUILD_CONFIG})

	if [ $CONFIG_KERNEL_DDR_1G ]; then
		export KERNEL_DEVICETREE=${KERNEL_DEVICETREE_DDR_1G}
	fi

	if [ $CONFIG_KERNEL_FCC_PIP ]; then
		export KERNEL_DEVICETREE=${KERNEL_DEVICETREE_FCC_PIP}
		export CONFIG_KERNEL_FCC_PIP=true
	fi

	echo "KERNEL_DEVICETREE: ${KERNEL_DEVICETREE}"
	if [ $CONFIG_NONGKI ]; then
		echo "=====normal mode====="
		for aDts in ${KERNEL_DEVICETREE}; do
			if [ $KERNEL_A32_SUPPORT ]; then
				sed -i 's/^#include \"partition_.*/#include "partition_mbox.dtsi"/' ${KERNEL_DIR}/arch/arm/boot/dts/amlogic/$aDts.dts;
			else
				sed -i 's/^#include \"partition_.*/#include "partition_mbox.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
			fi
		done
	else
		echo "=====ab update & vendor boot mode====="
		for aDts in ${KERNEL_DEVICETREE}; do
			if [ $KERNEL_A32_SUPPORT ]; then
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_ab.dtsi"/' ${KERNEL_DIR}/arch/arm/boot/dts/amlogic/$aDts.dts;
			else
				sed -i 's/^#include \"partition_.*/#include "partition_mbox_ab.dtsi"/' ${KERNEL_DIR}/arch/arm64/boot/dts/amlogic/$aDts.dts;
			fi
		done
	fi
	echo "================================="

	cd ${MAIN_FOLDER}
	./project/build/build.sh
}

function build_config_to_bzl() {
	[[ -f ${PROJECT_DIR}/project.bazel ]] || touch ${PROJECT_DIR}/project.bzl
	echo "# SPDX-License-Identifier: GPL-2.0" 	>  ${PROJECT_DIR}/project.bzl
	echo 						>> ${PROJECT_DIR}/project.bzl

	echo 						>> ${PROJECT_DIR}/project.bzl
	echo "EXT_MODULES_ANDROID = [" 			>> ${PROJECT_DIR}/project.bzl
	local ext_modules
	for ext_module in ${EXT_MODULES_ANDROID}; do
		if [[ "${ext_module:0:2}" == "//" ]]; then
			echo "    \"${ext_module}\","	>> ${PROJECT_DIR}/project.bzl
		else
			echo "    \"//${ext_module}\","	>> ${PROJECT_DIR}/project.bzl
		fi
	done
	echo "]" 					>> ${PROJECT_DIR}/project.bzl

	echo                                            >> ${PROJECT_DIR}/project.bzl
	echo "VENDOR_MODULES_REMOVE = [" 		>> ${PROJECT_DIR}/project.bzl
	for module in ${VENDOR_MODULES_REMOVE}; do
		echo "    \"${module}\","		>> ${PROJECT_DIR}/project.bzl
	done
	echo "]"					>> ${PROJECT_DIR}/project.bzl

	echo 						>> ${PROJECT_DIR}/project.bzl
	echo "VENDOR_MODULES_ADD = [" 			>> ${PROJECT_DIR}/project.bzl
	for module in ${VENDOR_MODULES_ADD}; do
		echo "    \"${module}\","		>> ${PROJECT_DIR}/project.bzl
	done
	echo "]"					>> ${PROJECT_DIR}/project.bzl
}

function build_config_to_build_config() {
	[[ -f ${PROJECT_DIR}/build.config.project ]] || touch ${PROJECT_DIR}/build.config.project
	echo "# SPDX-License-Identifier: GPL-2.0" 	> ${PROJECT_DIR}/build.config.project
	echo 						>> ${PROJECT_DIR}/build.config.project

	export WIFI_TRUNK_CONFIG=${MAIN_FOLDER}/${PRODUCT_DIRNAME}/wifibt.build.config.trunk.mk
	if [ -d "${MAIN_FOLDER}/common14-5.15/driver_modules/wifi_bt/wifi" ]; then
		make -f ${MAIN_FOLDER}/common14-5.15/driver_modules/wifi_bt/wifi/configs/get_module.mk TOP_DIR=$MAIN_FOLDER BOARD=$BOARD_DEVICENAME DRIVER_IN_KERNEL=true
	else
		make -f ${MAIN_FOLDER}/driver_modules/wifi_bt/wifi/configs/get_module.mk TOP_DIR=$MAIN_FOLDER BOARD=$BOARD_DEVICENAME
	fi
	echo "WIFI_TRUNK_CONFIG=${WIFI_TRUNK_CONFIG}"	>> ${PROJECT_DIR}/build.config.project
	echo "PRODUCT_DIR=${BOARD_DEVICENAME}" 		>> ${PROJECT_DIR}/build.config.project
	[[ -n ${GPU_DRV_VERSION} ]] && echo "GPU_DRV_VERSION=${GPU_DRV_VERSION}" >> ${PROJECT_DIR}/build.config.project
}

function build_config_to_modules_kconfig() {
	[[ -f ${PROJECT_DIR}/Kconfig.ext_modules ]] || touch ${PROJECT_DIR}/Kconfig.ext_modules
	echo "# SPDX-License-Identifier: GPL-2.0" 	> ${PROJECT_DIR}/Kconfig.ext_modules
	echo 						>> ${PROJECT_DIR}/Kconfig.ext_modules

	if [[ ${BAZEL} == 1 ]]; then
		echo                                            >> ${PROJECT_DIR}/project.bzl
		echo "KCONFIG_EXT_SRCS = ["               	>> ${PROJECT_DIR}/project.bzl
		echo "    \"${COMMON_DRIVERS_DIR}/Kconfig.ext\","	>> ${PROJECT_DIR}/project.bzl
		echo "    \"${COMMON_DRIVERS_DIR}/project/Kconfig.ext_modules\","	>> ${PROJECT_DIR}/project.bzl
	fi
	for kconfig in ${KCONFIG_EXT_ANDOIRD}; do
		if [[ ${BAZEL} == 1 ]]; then
			echo "    \"${kconfig}\","		>> ${PROJECT_DIR}/project.bzl
		fi
		if [[ "${kconfig:0:2}" == "//" ]]; then
			kconfig=${kconfig:2}
		fi
		kconfig_dir=${kconfig%:*}
		echo kconfig_dir=${kconfig_dir}
		echo "source \"\$(KCONFIG_EXT_MODULES_PREFIX)${kconfig_dir}/Kconfig\""	>> ${PROJECT_DIR}/Kconfig.ext_modules
	done
	if [[ ${BAZEL} == 1 ]]; then
		echo "]"					>> ${PROJECT_DIR}/project.bzl
	fi

}

function build_common_5.15() {
	export KERNEL_VERSION=${CONFIG_KERNEL_VERSION##*-}
	export TARGET_BUILD_KERNEL_VERSION=${KERNEL_VERSION}
	export TARGET_BUILD_KERNEL_4_9=false
	if [ ${CONFIG_KERNEL_VERSION} = "5.15" ]; then
		export KERNEL_REPO=common-${CONFIG_KERNEL_VERSION}
		export FULL_KERNEL_VERSION="common13-5.15"
	else
		if [ ${CONFIG_KERNEL_VERSION} == "common13-5.15" ]; then
			if [[ -d ${CONFIG_KERNEL_VERSION} ]]; then
				export KERNEL_REPO=${CONFIG_KERNEL_VERSION}
			elif [[ -d common-5.15 ]]; then
				export KERNEL_REPO="common-5.15"
			else
				echo "error -v ${CONFIG_KERNEL_VERSION}"
				exit
			fi
		else
			export KERNEL_REPO=${CONFIG_KERNEL_VERSION}
		fi
		export FULL_KERNEL_VERSION=${CONFIG_KERNEL_VERSION}
	fi
	export KERNEL_DIR=common
	export COMMON_DRIVERS_DIR=common_drivers
	export BOARD_DEVICENAME=$1
	export BOARD_MANUFACTURER=${device_project}
	export PRODUCT_DIRNAME=project/amlogic/${BOARD_DEVICENAME}

	if [ ${SKIP_MRPROPER} = "true" ]; then
		SKIP_MRPROPER=1
	fi
	cd ${MAIN_FOLDER}
	local android_version='o'
	local android_version_number=8
	local k_android_version=$(grep BRANCH= ${KERNEL_REPO}/${KERNEL_DIR}/build.config.constants)
	k_android_version=${k_android_version#*android}
	k_android_version=${k_android_version%%-*}
	local version_diff=$((${k_android_version} - ${android_version_number}))
	android_version=$(printf "%d" "'${android_version}")
	android_version=$((${android_version} + ${version_diff}))
	ANDROID_VERSION=$(echo ${android_version} | awk '{printf("%c", $1)}')
	export ANDROID_VERSION

	if [ $KERNEL_A32_SUPPORT ]; then
		BUILD_CONFIG_ANDROID=${PRODUCT_DIRNAME}/build.config.meson.arm.trunk.5.15
	else
		BUILD_CONFIG_ANDROID=${PRODUCT_DIRNAME}/build.config.meson.arm64.trunk.5.15
	fi
	. ${MAIN_FOLDER}/${BUILD_CONFIG_ANDROID}

	local prebuilt_modules_path
	local module_path
	for module_path in ${PREBUILT_MODULES_PATH}; do
		prebuilt_modules_path="${prebuilt_modules_path} ${MAIN_FOLDER}/${module_path}"
	done
	export PREBUILT_MODULES_PATH=${prebuilt_modules_path}

	export $(sed -n -e 's/\([^=]\)=.*/\1/p' ${MAIN_FOLDER}/${BUILD_CONFIG_ANDROID})

	if [ $CONFIG_KERNEL_FCC_PIP ]; then
		export KERNEL_DEVICETREE=${KERNEL_DEVICETREE_FCC_PIP}
		export CONFIG_KERNEL_FCC_PIP=true
	fi

	EXT_MODULES_ANDROID="${EXT_MODULES_ANDROID} ${EXT_MODULES_ANDROID_AUTO_LOAD}"
	local common_drivers=${KERNEL_REPO}/${KERNEL_DIR}/${COMMON_DRIVERS_DIR}
	PROJECT_DIR=${common_drivers}/project
	[[ ! -d ${common_drivers} ]] && echo "no common_drivers: ${common_drivers}" && exit
	[[ -d ${PROJECT_DIR} ]] || mkdir -p ${PROJECT_DIR}
	if [[ "${FULL_KERNEL_VERSION}" == "common13-5.15" || "${KERNEL_A32_SUPPORT}" == "true" || ${BAZEL} == 0 ]]; then
		local ext_modules
		for ext_module in ${EXT_MODULES_ANDROID}; do
			ext_module=`echo ${ext_module} | cut -d ':' -f1`
			if [[ "${ext_module:0:2}" == "//" ]]; then
				ext_module=${ext_module:2}
			fi
			ext_modules="${MAIN_FOLDER}/${KERNEL_REPO}/${ext_module} ${ext_modules}"
		done
		EXT_MODULES_ANDROID=${ext_modules}
	else
		BAZEL=1
		build_config_to_bzl
		build_config_to_build_config
	fi
	build_config_to_modules_kconfig

	if [[ -n ${EXT_MODULES_ANDROID_AUTO_LOAD} ]]; then
		local ext_modules
		for ext_module in ${EXT_MODULES_ANDROID_AUTO_LOAD}; do
			ext_module=`echo ${ext_module} | cut -d ':' -f1`
			if [[ "${ext_module:0:2}" == "//" ]]; then
				ext_module=${ext_module:2}
			fi
			ext_modules="${ext_module} ${ext_modules}"
		done
		EXT_MODULES_ANDROID_AUTO_LOAD=${ext_modules}
	fi

	[[ "${KERNEL_A32_SUPPORT}" == "true" ]] && sub_parameters="$sub_parameters --arch arm"
	if [[ -n ${UPGRADE_PROJECT} ]]; then
		ANDROID_VERSION=${UPGRADE_PROJECT}
		sub_parameters="$sub_parameters --upgrade ${ANDROID_VERSION}"
	fi
	if [[ -n ${DEV_CONFIGS} ]]; then
		sub_parameters="$sub_parameters --dev_config"
		for config in ${DEV_CONFIGS}; do
			if [[ -f ${MAIN_FOLDER}/project/amlogic/${PRODUCT_DIR}/${config} ]]; then # relative path search
				sub_parameters="$sub_parameters ${MAIN_FOLDER}/project/amlogic/${PRODUCT_DIR}/${config}"
			else
				sub_parameters="$sub_parameters ${config}"
			fi
		done
	fi
	[[ "${KASAN_ENABLED}" == "true" ]] && sub_parameters="$sub_parameters --kasan"
	sub_parameters="$sub_parameters --android_project ${BOARD_DEVICENAME}"
	echo sub_parameters=$sub_parameters

	./project/build/build_kernel_5.15.sh $sub_parameters

	copy_out ${KERNEL_REPO}/out/android/${BOARD_DEVICENAME} ${BOARD_DEVICENAME}
}

function build_common() {
	if [ "$CONFIG_KERNEL_VERSION" = "4.9" ]; then
		build_common_4.9 $@
	elif [ "$CONFIG_KERNEL_VERSION" = "5.4" ]; then
		build_common_5.4 $@
	elif [[ "$CONFIG_KERNEL_VERSION" =~ "5.15" ]]; then
		build_common_5.15 $@
	fi
}

function build() {
	# parser
	bin_path_parser $@

	export SKIP_MRPROPER=true
	unset SKIP_BUILD_KERNEL
	unset BUILD_ONE_MODULES
	unset SKIP_CP_KERNEL_HDR
	unset BUILD_KERNEL_ONLY
	unset SKIP_EXT_MODULES
	export PRODUCT_DIR=$1

	if [ "${CONFIG_KERNEL_VERSION}" == "" ]; then
		if [ "$1" = "franklin" -o "$1" = "ohm" -o "$1" = "elektra" -o "$1" = "newton" ]; then
			CONFIG_KERNEL_VERSION=4.9
			echo "CONFIG_KERNEL_VERSION: ${CONFIG_KERNEL_VERSION}"
		else
			CONFIG_KERNEL_VERSION=5.4
		fi
	fi

	if [ "${CONFIG_ONE_MODULES}" != "" ]; then
		export SKIP_BUILD_KERNEL=true
		export BUILD_ONE_MODULES=${CONFIG_ONE_MODULES}
		export SKIP_CP_KERNEL_HDR=true
	fi

	if [ "${CONFIG_KERNEL_ONLY}" != "" ]; then
		export SKIP_EXT_MODULES=true
	fi

	option="${1}"
	case ${option} in
		deadpool)
			build_deadpool
			;;
		boreal)
			build_boreal
			;;
		anning)
		    build_anning
			;;
		heavenly)
			device_project="google"
			build_common $@
			;;
		*)
			device_project="amlogic"
			build_common $@
			;;
	esac

	if [ $? -ne 0 ]; then
		echo "build kernel error"
		exit 1
	fi

	if [ "$CONFIG_KERNEL_VERSION" = "4.9" ]; then
		KERNEL_OFFSET=0x1080000
		BOOT_HEADER_VERSION=2
		if [ $CONFIG_AB_UPDATE ]; then
			BOOT_IMGSIZE=25165824
		else
			BOOT_IMGSIZE=16777216
		fi
	else
		KERNEL_OFFSET=0x2080000
		BOOT_IMGSIZE=67108864
		BOOT_HEADER_VERSION=4
	fi

	if [ "$1" = "ohm" -o "$1" = "ohmcas" -o "$1" = "oppen" \
		-o "$1" = "smith" -o "$1" = "calla" -o "$1" = "oppencas" -o "$1" = "planck" ]; then
		if [ "$CONFIG_KERNEL_VERSION" = "4.9" ]; then
			BOOT_DEVICES="androidboot.boot_devices=fe08c000.emmc"
		else
			BOOT_DEVICES="androidboot.boot_devices=soc/fe08c000.mmc"
		fi
	fi

	if [ "$1" = "galilei" -o "$1" = "newton" -o "$1" = "dalton" \
		-o "$1" = "elektra" -o "$1" = "redi" -o "$1" = "franklin" ]; then
		if [ "$CONFIG_KERNEL_VERSION" = "4.9" ]; then
			BOOT_DEVICES="androidboot.boot_devices=ffe07000.emmc"
		else
			BOOT_DEVICES="androidboot.boot_devices=soc/ffe07000.mmc"
		fi
	fi

	if [ "$1" = "ampere" ]; then
		BOOT_DEVICES="androidboot.boot_devices=d0074000.emmc"
	fi

	if [ "${CONFIG_Ramdisk}" != "" ]; then
		echo "CONFIG_Ramdisk: ${CONFIG_Ramdisk}"
		if [ $KERNEL_A32_SUPPORT ]; then
			KERNEL_FILE=project/${device_project}/$1-kernel/${CONFIG_KERNEL_VERSION}/uImage
		else
			KERNEL_FILE=project/${device_project}/$1-kernel/${CONFIG_KERNEL_VERSION}/Image.gz
		fi
		./project/build/mkbootimg --kernel ${KERNEL_FILE} \
		--ramdisk ${CONFIG_Ramdisk} \
		--os_version 12 --kernel_offset ${KERNEL_OFFSET} \
		--header_version ${BOOT_HEADER_VERSION} \
		--output out/$1_boot.img
		./project/build/avbtool add_hash_footer --image out/$1_boot.img \
		--partition_size ${BOOT_IMGSIZE} --partition_name boot  \
		--prop com.android.build.boot.os_version:12
	fi

	if [ "${CONFIG_VENDOR_Ramdisk}" != "" -a "${CONFIG_RECOVERY_Ramdisk}" != "" ]; then
		echo "CONFIG_VENDOR_Ramdisk: ${CONFIG_VENDOR_Ramdisk}"
		echo "CONFIG_RECOVERY_Ramdisk: ${CONFIG_RECOVERY_Ramdisk}"
		VENDOR_CMDLINE="androidboot.dynamic_partitions=true androidboot.dtbo_idx=0"
		VENDOR_CMDLINE="$VENDOR_CMDLINE $BOOT_DEVICES"
		VENDOR_CMDLINE="$VENDOR_CMDLINE use_uvm=1 buildvariant=userdebug"
		echo "VENDOR_CMDLINE: $VENDOR_CMDLINE"

		./project/build/mkbootimg \
		--dtb project/${device_project}/$1-kernel/${CONFIG_KERNEL_VERSION}/$1.dtb --base 0x0 \
		--vendor_cmdline "$VENDOR_CMDLINE" \
		--kernel_offset ${KERNEL_OFFSET} --header_version ${BOOT_HEADER_VERSION} \
		--vendor_ramdisk ${CONFIG_VENDOR_Ramdisk} \
		--ramdisk_type RECOVERY --ramdisk_name recovery \
		--vendor_ramdisk_fragment  ${CONFIG_RECOVERY_Ramdisk} \
		--vendor_boot out/$1_vendor_boot.img
		./project/build/avbtool add_hash_footer \
		--image out/$1_vendor_boot.img \
		--partition_size 25165824 --partition_name vendor_boot
	fi
}

function usage() {
  cat << EOF
  Usage:
    $(basename $0) --help

    kernel & modules standalone build script.

    you must use -v ** params

    command list:
    1. build kernel & modules for 5.4 GKI:
        ./$(basename $0) [config_name] -v 5.4

    2. build kernel & modules for 5.4 normal:
        ./$(basename $0) [config_name] -v 5.4 --nonGKI

    3. build kernel & modules for 4.9 normal:
        ./$(basename $0) [config_name] -v 4.9

    4. build kernel & modules for 4.9 virtual ab:
        ./$(basename $0) [config_name] -v 4.9 --ab

    5. clean
        ./$(basename $0) clean

    6. build one modules only
        ./$(basename $0) [config_name] -v 5.4 --modules module_path

    7. build kernel only
        ./$(basename $0) [config_name] -v 5.4 --kernel_only

    8. build kernel with different config
        ./$(basename $0) [config_name] -t [userdebug|user|eng]

    you can use different params at the same time

    Example:
    1) ./mk newton -v 5.4 //5.4 GKI

    2) ./mk newton -v 5.4 --nonGKI   //5.4 nonGKI

    2) ./mk franklin -v 4.9   //4.9 normal

    3) ./mk clean

    4) ./mk newton -v 5.4 -t user   //5.4 GKI with additional meson64_a64_r_user_diffconfig

    5) ./mk franklin -v 4.9 --ab    //4.9 virtual_ab

    6) ./mk ohm -v 5.4 --modules hardware/amlogic/media_modules

    7) ./mk ohm -v 5.4 --kernel_only

EOF
  exit 1
}

function parser() {
	local i=0
	local j=0
	local argv=()
	for arg in "$@" ; do
		argv[$i]="$arg"
		i=$((i + 1))
	done
	i=0
	j=0
	while [ $i -lt $# ]; do
		arg="${argv[$i]}"
		i=$((i + 1)) # must place here
		case "$arg" in
			-h|--help|help)
				usage
				exit ;;
			-v)
				j=1 ;;
			clean|distclean|-distclean|--distclean)
				clean
				exit ;;
			*)
		esac
	done
	if [ "$j" == "0" ]; then
		usage
		exit
	fi
}

function bin_path_parser() {

	local para=$@
	local main_parameters
	if [[ $para =~ "--sp" ]]; then
		sub_parameters=${para#*--sp}
		main_parameters=${para%%--sp*}
	else
		main_parameters=$para
	fi
	sub_parameters=`echo $sub_parameters | awk '$1=$1'`
	main_parameters=`echo $main_parameters | awk '$1=$1'`

	local i=0
	local argv=()
	for arg in $main_parameters ; do
		argv[$i]="$arg"
		i=$((i + 1))
	done
	i=0

	num=${#argv[@]}
	while [ $i -lt $num ]; do
		arg="${argv[$i]}"
		i=$((i + 1)) # must pleace here
		case "$arg" in
			-t)
				CONFIG_BOOTIMAGE="${argv[$i]}"
				echo "CONFIG_BOOTIMAGE: ${CONFIG_BOOTIMAGE}"
				export CONFIG_BOOTIMAGE
				continue ;;
			-v)
				CONFIG_KERNEL_VERSION="${argv[$i]}"
				echo "CONFIG_KERNEL_VERSION: ${CONFIG_KERNEL_VERSION}"
				continue ;;
			--ab|--ab_update)
				CONFIG_AB_UPDATE=true
				continue ;;
			--fccpip)
				CONFIG_KERNEL_FCC_PIP=true
				continue ;;
			--nonGKI)
				CONFIG_NONGKI=true
				continue ;;
			--kasan)
				KASAN_ENABLED=true
				continue ;;
			--gki_image)
				[[ ${KASAN_ENABLED} != "true" ]] && export CONFIG_REPLACE_GKI_IMAGE=true
				continue ;;
			--upgrade)
				UPGRADE_PROJECT="${argv[$i]}"
				continue ;;
			--modules)
				CONFIG_ONE_MODULES="${argv[$i]}"
				continue ;;
			--kernel_only)
				CONFIG_KERNEL_ONLY=true
				continue ;;
			--kernel32)
				export KERNEL_A32_SUPPORT=true
				continue ;;
			--ramdisk)
				CONFIG_Ramdisk="${argv[$i]}"
				continue ;;
			--vendor_ramdisk)
				CONFIG_VENDOR_Ramdisk="${argv[$i]}"
				continue ;;
			--recovery_ramdisk)
				CONFIG_RECOVERY_Ramdisk="${argv[$i]}"
				continue ;;
			-o)
				ANDROID_OUT_DIR="${argv[$i]}"
				mkdir -p ${ANDROID_OUT_DIR}
				ANDROID_OUT_DIR=$(realpath ${ANDROID_OUT_DIR})
				continue ;;
			--1g)
				export CONFIG_KERNEL_DDR_1G=true
				continue ;;
			--builtin_modules)
				CONFIG_BUILTIN_MODULES=true
				echo "CONFIG_BUILTIN_MODULES: true"
				export CONFIG_BUILTIN_MODULES
				continue ;;
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

	export MAIN_FOLDER=$(realpath $(dirname $(readlink $0))/../..)
	cd ${MAIN_FOLDER}

	parser $@
	build $@
}

set -e
main $@ # parse all paras to function
set +e
