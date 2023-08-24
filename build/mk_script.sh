#!/bin/bash
#
#  author: wanwei.jiang@amlogic.com
#  2023.08.24

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

function copy_out() {
	SRC_PATH=${KERNEL_REPO}/out/android/${BOARD_DEVICENAME}
	if [ ${ANDROID_OUT_DIR} -a -d ${ANDROID_OUT_DIR} ]; then
		echo "copy kernel to incoming android out dir"
		rm -rf ${ANDROID_OUT_DIR}/*
		cp -a ${SRC_PATH}/* ${ANDROID_OUT_DIR}/
	else
		ANDROID_PROJECT_PATH=device/${BOARD_MANUFACTURER}/${BOARD_DEVICENAME}-kernel
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
	echo "MODULES_OUT_REMOVE = ["	 		>> ${PROJECT_DIR}/project.bzl
	for module in ${MODULES_OUT_REMOVE}; do
		echo "    \"${module}\","		>> ${PROJECT_DIR}/project.bzl
	done
	echo "]"					>> ${PROJECT_DIR}/project.bzl

	echo 						>> ${PROJECT_DIR}/project.bzl
	echo "MODULES_OUT_ADD = [" 			>> ${PROJECT_DIR}/project.bzl
	for module in ${MODULES_OUT_ADD}; do
		echo "    \"${module}\","		>> ${PROJECT_DIR}/project.bzl
	done
	echo "]"					>> ${PROJECT_DIR}/project.bzl
}

function build_config_to_build_config() {
	[[ -f ${PROJECT_DIR}/build.config.project ]] || touch ${PROJECT_DIR}/build.config.project
	echo "# SPDX-License-Identifier: GPL-2.0" 	> ${PROJECT_DIR}/build.config.project
	echo 						>> ${PROJECT_DIR}/build.config.project

	export WIFI_TRUNK_CONFIG=${MAIN_FOLDER}/${PROJECT_CONFIG_DIR}/wifibt.build.config.trunk.mk
	echo "WIFI_TRUNK_CONFIG=${WIFI_TRUNK_CONFIG}"	>> ${PROJECT_DIR}/build.config.project
	if [ -d "${MAIN_FOLDER}/common14-5.15/driver_modules/wifi_bt/wifi" ]; then
		make -f ${MAIN_FOLDER}/common14-5.15/driver_modules/wifi_bt/wifi/configs/get_module.mk TOP_DIR=${MAIN_FOLDER} BOARD=${BOARD_DEVICENAME} MANUFACTURER=${BOARD_MANUFACTURER} DRIVER_IN_KERNEL=true
	else
		make -f ${MAIN_FOLDER}/driver_modules/wifi_bt/wifi/configs/get_module.mk TOP_DIR=${MAIN_FOLDER} BOARD=${BOARD_DEVICENAME} MANUFACTURER=${BOARD_MANUFACTURER}
	fi

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
	export PROJECT_CONFIG_DIR=project/${BOARD_MANUFACTURER}/${BOARD_DEVICENAME}

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
		ARCH=arm
		BUILD_CONFIG_ANDROID=${PROJECT_CONFIG_DIR}/build.config.meson.arm.trunk.5.15
	else
		ARCH=arm64
		BUILD_CONFIG_ANDROID=${PROJECT_CONFIG_DIR}/build.config.meson.arm64.trunk.5.15
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

	if [[ -n ${DEV_CONFIGS} ]]; then
		local dev_configs
		local copy_dev_configs
		for config in ${DEV_CONFIGS}; do
			if [[ -f ${MAIN_FOLDER}/${PROJECT_CONFIG_DIR}/${config} ]]; then
				if [[ ${BAZEL} == 1 ]]; then
					cp ${MAIN_FOLDER}/${PROJECT_CONFIG_DIR}/${config} ${common_drivers}/arch/${ARCH}/configs
					copy_dev_configs="${copy_dev_configs} ${config}"
					dev_configs="${dev_configs} ${config}"
				else
					dev_configs="${dev_configs} ${MAIN_FOLDER}/${PROJECT_CONFIG_DIR}/${config}"
				fi
			else
				dev_configs="${dev_configs} ${config}"
			fi
		done
		DEV_CONFIGS=`echo ${dev_configs} | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'`
		export COPY_DEV_CONFIGS=`echo ${copy_dev_configs} | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g'`
	fi

	if [[ -n ${MODULES_SEQUENCE_LIST} ]]; then
		if [[ -f ${MAIN_FOLDER}/${PROJECT_CONFIG_DIR}/${MODULES_SEQUENCE_LIST} ]]; then
			MODULES_SEQUENCE_LIST="${MAIN_FOLDER}/${PROJECT_CONFIG_DIR}/${MODULES_SEQUENCE_LIST}"
		fi
	fi

	[[ "${KERNEL_A32_SUPPORT}" == "true" ]] && sub_parameters="$sub_parameters --arch arm"
	if [[ -n ${UPGRADE_PROJECT} ]]; then
		ANDROID_VERSION=${UPGRADE_PROJECT}
		sub_parameters="$sub_parameters --upgrade ${ANDROID_VERSION}"
	fi
	[[ "${KASAN_ENABLED}" == "true" ]] && sub_parameters="$sub_parameters --kasan"
	sub_parameters="$sub_parameters --android_project ${BOARD_DEVICENAME}"
	echo sub_parameters=$sub_parameters

	./project/build/build_kernel_5.15.sh $sub_parameters

	copy_out
}

function build_common() {
	if [[ "$CONFIG_KERNEL_VERSION" =~ "5.15" ]]; then
		build_common_5.15 $@
	fi
}

function build() {
	# parser
	bin_path_parser $@

	export PRODUCT_DIR=$1

	device_project=`find project -name ${1}`
	if [[ -n ${device_project} ]]; then
		device_project=`echo ${device_project} | cut -d '/' -f 2`
	else
		echo "can't find the project"
		exit
	fi

	build_common $@

	if [ $? -ne 0 ]; then
		echo "build kernel error"
		exit 1
	fi
}

function usage() {
  cat << EOF
  Usage:
    $(basename $0) --help

    kernel standalone build script.

    you must use -v ** params

    command list:
    1. build kernel for 5.15:
        ./$(basename $0) [config_name] -v common14-5.15

    2. clean
        ./$(basename $0) clean

    you can use different params at the same time, example:
    1) ./mk ohm -v common14-5.15 --gki_image	//using gki and gki modules

    2) ./mk ohm -v common14-5.15 -o out_dir	//compilation result directory
						//out_dir: absolute directory or relative "common" directory
						//default: device/amlogic/ohm-kernel/5.15 device/amlogic/ohm-kernel/32/5.15

    3) ./mk ohm -v common14-5.15 -t user	//only for androidR+kernel5.15

    4) ./mk ohm -v common14-5.15 --kasan	//build with kasan

    4) ./mk planck -v common14-5.15 --kernel32	//compile 32-bit kernel, default to 64-bit kernel

    5) ./mk ohm -v common14-5.15 --sp xxx	//parameters(xxx) after --sp is used for script ./mk.sh

    6) ./mk ohmcas -v common14-5.15 --fccpip    //for fccpip project

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
			--fccpip)
				CONFIG_KERNEL_FCC_PIP=true
				continue ;;
			--kasan)
				KASAN_ENABLED=true
				continue ;;
			--gki_image)
				if [[ ${KASAN_ENABLED} != "true" && ! ${sub_parameters} =~ "--use_prebuilt_gki" ]]; then
					export CONFIG_REPLACE_GKI_IMAGE=true
				fi
				continue ;;
			--kernel32)
				export KERNEL_A32_SUPPORT=true
				continue ;;
			-o)
				ANDROID_OUT_DIR="${argv[$i]}"
				mkdir -p ${ANDROID_OUT_DIR}
				ANDROID_OUT_DIR=$(realpath ${ANDROID_OUT_DIR})
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
