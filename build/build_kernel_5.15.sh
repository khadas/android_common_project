#!/bin/bash

set -e
export KERNEL_BUILD_VAR_FILE=`mktemp /tmp/kernel.XXXXXXXXXXXX`

echo
echo "========================================================"
echo "enter kernel build: $@"
pushd ${KERNEL_REPO}
./mk.sh $@
popd

[[ "$@" =~ "--patch" ]] && echo "Finish patch" &&  exit

echo "========================================================"
echo "exit kernel build"
echo "========================================================"
echo

echo
echo "========================================================"
echo "copy files to android project"
source ${KERNEL_BUILD_VAR_FILE}

DEVICE_KERNEL_DIR=${KERNEL_REPO}/out/android/${BOARD_DEVICENAME}

echo "copy symbols"
rm -rf ${DEVICE_KERNEL_DIR}
mkdir -p ${DEVICE_KERNEL_DIR}
cp -rf ${OUT_AMLOGIC_DIR}/symbols ${DEVICE_KERNEL_DIR}/symbols

echo "copy ramdisk module ko"
mkdir -p ${DEVICE_KERNEL_DIR}/ramdisk/lib/modules/
cp ${OUT_AMLOGIC_DIR}/modules/ramdisk/*.ko ${DEVICE_KERNEL_DIR}/ramdisk/lib/modules/

if [ -s ${OUT_AMLOGIC_DIR}/modules/recovery/recovery_modules.order ]; then
	cp ${OUT_AMLOGIC_DIR}/modules/recovery/*.ko ${DEVICE_KERNEL_DIR}/ramdisk/lib/modules/
fi

echo "copy vendor_dlkm module ko"
mkdir -p ${DEVICE_KERNEL_DIR}/lib/modules/
if [[ -d ${COMMON_OUT_DIR}/vendor_lib ]]; then
	cp -a ${COMMON_OUT_DIR}/vendor_lib/* ${DEVICE_KERNEL_DIR}/lib/
fi
if [[ "${BAZEL}" == "1" ]]; then
	cp -a ${OUT_AMLOGIC_DIR}/ext_modules/*.ko ${DEVICE_KERNEL_DIR}/lib/modules/

	for src_dst in ${FILES_COPY}; do
		src=`echo ${src_dst} | cut -d '+' -f 1`
		dst=`echo ${src_dst} | cut -d '+' -f 2`
		mkdir -p ${DEVICE_KERNEL_DIR}/lib/${dst}
		cp -a ${src} ${DEVICE_KERNEL_DIR}/lib/${dst}
	done
fi
cp ${OUT_AMLOGIC_DIR}/modules/vendor/*.ko ${DEVICE_KERNEL_DIR}/lib/modules/

echo "copy service_module ko"
res=`ls ${OUT_AMLOGIC_DIR}/modules/service_module`
if [[ -n ${res} ]]; then
	cp ${OUT_AMLOGIC_DIR}/modules/service_module/*.ko ${DEVICE_KERNEL_DIR}/lib/modules/
fi

echo "copy modules.load"
cp ${OUT_AMLOGIC_DIR}/modules/ramdisk/ramdisk_modules.order ${DEVICE_KERNEL_DIR}/vendor_boot.modules.load
cp ${OUT_AMLOGIC_DIR}/modules/ramdisk/ramdisk_modules.order ${DEVICE_KERNEL_DIR}/vendor_recovery.modules.load
cat ${OUT_AMLOGIC_DIR}/modules/recovery/recovery_modules.order >> ${DEVICE_KERNEL_DIR}/vendor_recovery.modules.load
cp ${OUT_AMLOGIC_DIR}/modules/vendor/vendor_modules.order ${DEVICE_KERNEL_DIR}/vendor_dlkm.modules.load

echo "copy ext modules ko"
if [[ -n ${LOAD_EXT_MODULES_IN_SECOND_STAGE} ]]; then
	cp ${OUT_AMLOGIC_DIR}/ext_modules/*.ko ${DEVICE_KERNEL_DIR}/lib/modules/
	cat ${OUT_AMLOGIC_DIR}/ext_modules/ext_modules.order >> ${DEVICE_KERNEL_DIR}/vendor_dlkm.modules.load
fi

if [[ ${FULL_KERNEL_VERSION} == "common13-5.15" ]]; then
	if [[ ${CONFIG_REPLACE_GKI_IMAGE} ]]; then
		echo "copy gki image"
		gki_dir=${KERNEL_REPO}/gki_image
		cp ${gki_dir}/Image* ${DEVICE_KERNEL_DIR}
		cp ${gki_dir}/vmlinux ${DEVICE_KERNEL_DIR}/symbols
		while read gki_module; do
			gki_module=${gki_module##*/}
			gki_module_dst=`find ${DEVICE_KERNEL_DIR}/ -name ${gki_module} -not -path "${DEVICE_KERNEL_DIR}/symbols/*"`
			cp ${gki_dir}/${gki_module} ${gki_module_dst}
		done < ${KERNEL_REPO}/${KERNEL_DIR}/android/gki_system_dlkm_modules
	else
		echo "copy image"
		if [ ${KERNEL_A32_SUPPORT} ]; then
			cp ${DIST_DIR}/uImage ${DEVICE_KERNEL_DIR}/
		else
			cp ${DIST_DIR}/Image* ${DEVICE_KERNEL_DIR}/
		fi
	fi
else
	if [ ${KERNEL_A32_SUPPORT} ]; then
		cp ${DIST_DIR}/uImage ${DEVICE_KERNEL_DIR}/
	elif [[ -n ${EXT_MODULES} && "${BAZEL}" != "1" ]]; then
		cp ${DIST_DIR}/Image* ${DEVICE_KERNEL_DIR}/
	else
		DIST_GKI_DIR=${DIST_GKI_DIR:-${DIST_DIR}}
		touch ${DEVICE_KERNEL_DIR}/system_dlkm.modules.load
        	cat ${DEVICE_KERNEL_DIR}/vendor_dlkm.modules.load | while read gki_module; do
			awk "/\/${gki_module}/" ${DIST_GKI_DIR}/system_dlkm.modules.load >> ${DEVICE_KERNEL_DIR}/system_dlkm.modules.load
		done
		cat ${DEVICE_KERNEL_DIR}/system_dlkm.modules.load  | while read gki_module; do
			gki_module=${gki_module##*/}
			sed -i "/^${gki_module}/d" ${DEVICE_KERNEL_DIR}/vendor_dlkm.modules.load
			rm ${DEVICE_KERNEL_DIR}/lib/modules/${gki_module}
		done
		mkdir ${DEVICE_KERNEL_DIR}/gki
		if [[ ${CONFIG_REPLACE_GKI_IMAGE} ]]; then
			gki_dir=${KERNEL_REPO}/gki_image
		else
			gki_dir=${DIST_GKI_DIR}
		fi
		cp ${gki_dir}/Image* ${DEVICE_KERNEL_DIR}/gki
		cp ${gki_dir}/boot* ${DEVICE_KERNEL_DIR}/gki
		cp ${gki_dir}/system_dlkm* ${DEVICE_KERNEL_DIR}/gki
		cp ${gki_dir}/vmlinux ${DEVICE_KERNEL_DIR}/gki

		if [ -f ${DEVICE_KERNEL_DIR}/gki/system_dlkm_staging_archive.tar.gz ]; then
			(cd ${DEVICE_KERNEL_DIR}/gki; tar -zxf system_dlkm_staging_archive.tar.gz)
			for module in `find ${DEVICE_KERNEL_DIR}/gki -name *.ko`; do
				module_name=${module##*/}
				find_module=
				for white_module in ${GKI_MODULES_LOAD_WHITE_LIST}; do
					if [[ "${module_name}" == "${white_module}" ]]; then
						find_module=1
						break;
					fi
				done
				[[ -z ${find_module} ]] && rm -f ${module}
			done
		fi
	fi
fi

echo "copy dtb"
cp ${DIST_DIR}/dtbo.img ${DEVICE_KERNEL_DIR}/

if [ $CONFIG_KERNEL_FCC_PIP ]; then
	export KERNEL_DEVICETREE=${KERNEL_DEVICETREE_FCC_PIP}
fi

DTBTOOL_DIR=project/build
dtb_files_count=0
mkdir -p ${OUT_AMLOGIC_DIR}/dtb
for dtb_file in ${KERNEL_DEVICETREE}; do
	cp ${DIST_DIR}/${dtb_file}.dtb ${OUT_AMLOGIC_DIR}/dtb/
	dtb_files_count=`expr ${dtb_files_count} + 1`
done
if [[ ${dtb_files_count} == 1 ]]; then
	if [ $CONFIG_KERNEL_FCC_PIP ]; then
		if [[ ${PRODUCT_DIRNAME} == *"ohm"* ]]; then
			cp -f ${DIST_DIR}/${KERNEL_DEVICETREE}.dtb ${DEVICE_KERNEL_DIR}/ohm_mxl258c.dtb
		elif [[ ${PRODUCT_DIRNAME} == *"oppencas"* ]]; then
			cp -f ${DIST_DIR}/${KERNEL_DEVICETREE}.dtb ${DEVICE_KERNEL_DIR}/oppencas_mxl258c.dtb
		elif [[ ${PRODUCT_DIRNAME} == *"oppen"* ]]; then
			cp -f ${DIST_DIR}/${KERNEL_DEVICETREE}.dtb ${DEVICE_KERNEL_DIR}/oppen_mxl258c.dtb
		else
			cp -f ${DIST_DIR}/${KERNEL_DEVICETREE}.dtb ${DEVICE_KERNEL_DIR}/${BOARD_DEVICENAME}.dtb
		fi
	else
		if [[ ${KERNEL_DEVICETREE} == "adt4_1k_ui" ]]; then
			cp ${DIST_DIR}/${KERNEL_DEVICETREE}.dtb ${DEVICE_KERNEL_DIR}/${KERNEL_DEVICETREE}.dtb
		else
			cp ${DIST_DIR}/${KERNEL_DEVICETREE}.dtb ${DEVICE_KERNEL_DIR}/${BOARD_DEVICENAME}.dtb
		fi
	fi
else
	${DTBTOOL_DIR}/dtbTool -o ${DEVICE_KERNEL_DIR}/${BOARD_DEVICENAME}.dtb -p ${DTBTOOL_DIR}/ ${OUT_AMLOGIC_DIR}/dtb/
fi

rm -f ${KERNEL_BUILD_VAR_FILE}
echo "========================================================"
echo "build end"
echo "========================================================"
echo
set +e
