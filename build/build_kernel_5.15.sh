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
if [ -s ${OUT_AMLOGIC_DIR}/modules/ramdisk/ramdisk_modules.order ]; then
	cp ${OUT_AMLOGIC_DIR}/modules/ramdisk/*.ko ${DEVICE_KERNEL_DIR}/ramdisk/lib/modules/
fi

if [ -s ${OUT_AMLOGIC_DIR}/modules/recovery/recovery_modules.order ]; then
	cp ${OUT_AMLOGIC_DIR}/modules/recovery/*.ko ${DEVICE_KERNEL_DIR}/ramdisk/lib/modules/
fi

echo "copy firmware"
mkdir -p ${DEVICE_KERNEL_DIR}/lib/modules/
for src_dst in ${FIRMWARES_COPY_FROM_TO}; do
	src=`echo ${src_dst} | cut -d ':' -f 1`
	dst=`echo ${src_dst} | cut -d ':' -f 2`
	if [[ -d ${MAIN_FOLDER}/${src} ]]; then
		mkdir -p ${DEVICE_KERNEL_DIR}/lib/firmware/${dst}
		cp -a ${MAIN_FOLDER}/${src}/* ${DEVICE_KERNEL_DIR}/lib/firmware/${dst}
	else
		dst_dir=`dirname ${DEVICE_KERNEL_DIR}/lib/firmware/${dst}`
		mkdir -p ${dst_dir}
		cp -a ${MAIN_FOLDER}/${src} ${DEVICE_KERNEL_DIR}/lib/firmware/${dst}
	fi
done

echo "copy vendor_dlkm module ko"
cp -a ${OUT_AMLOGIC_DIR}/modules/vendor/*.ko ${DEVICE_KERNEL_DIR}/lib/modules/
cp -a ${OUT_AMLOGIC_DIR}/ext_modules/*.ko ${DEVICE_KERNEL_DIR}/lib/modules/

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
		cp ${gki_dir}/vmlinux ${DEVICE_KERNEL_DIR}/symbols

		if [ -f ${gki_dir}/unstripped_modules.tar.gz ]; then
			cp ${gki_dir}/unstripped_modules.tar.gz ${DEVICE_KERNEL_DIR}/symbols
			(cd ${DEVICE_KERNEL_DIR}/symbols; tar -zxf unstripped_modules.tar.gz)
			for white_module in ${GKI_MODULES_LOAD_WHITE_LIST}; do
				if [[ -e ${DEVICE_KERNEL_DIR}/symbols/unstripped/${white_module} ]]; then
					cp -f ${DEVICE_KERNEL_DIR}/symbols/unstripped/${white_module} ${DEVICE_KERNEL_DIR}/symbols
				fi
			done
			rm -rf ${DEVICE_KERNEL_DIR}/symbols/unstripped*
		fi

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

DTBTOOL_DIR=project/build
dtb_files_count=0
mkdir -p ${OUT_AMLOGIC_DIR}/dtb
for dtb_file in ${KERNEL_DEVICETREE}; do
	cp ${DIST_DIR}/${dtb_file}.dtb ${OUT_AMLOGIC_DIR}/dtb/
	dtb_files_count=`expr ${dtb_files_count} + 1`
done
if [[ ${dtb_files_count} == 1 ]]; then
	if [[ ${KERNEL_DEVICETREE} == "adt4_1k_ui" ]]; then
		cp ${DIST_DIR}/${KERNEL_DEVICETREE}.dtb ${DEVICE_KERNEL_DIR}/${KERNEL_DEVICETREE}.dtb
	else
		cp ${DIST_DIR}/${KERNEL_DEVICETREE}.dtb ${DEVICE_KERNEL_DIR}/${BOARD_DEVICENAME}.dtb
	fi
else
	${DTBTOOL_DIR}/dtbTool -o ${DEVICE_KERNEL_DIR}/${BOARD_DEVICENAME}.dtb -p ${DTBTOOL_DIR}/ ${OUT_AMLOGIC_DIR}/dtb/
fi

fcc_dtb_files_count=0
mkdir -p ${OUT_AMLOGIC_DIR}/fcc_dtb
for dtb_file in ${KERNEL_DEVICETREE_FCC_PIP}; do
	cp ${DIST_DIR}/${dtb_file}.dtb ${OUT_AMLOGIC_DIR}/fcc_dtb/
	fcc_dtb_files_count=`expr ${fcc_dtb_files_count} + 1`
done
if [[ ${fcc_dtb_files_count} == 1 ]]; then
	cp -f ${DIST_DIR}/${KERNEL_DEVICETREE_FCC_PIP}.dtb ${DEVICE_KERNEL_DIR}/${BOARD_DEVICENAME}_mxl258c.dtb
elif [[ ${fcc_dtb_files_count} != 0 ]]; then
	${DTBTOOL_DIR}/dtbTool -o ${DEVICE_KERNEL_DIR}/${BOARD_DEVICENAME}_mxl258c.dtb -p ${DTBTOOL_DIR}/ ${OUT_AMLOGIC_DIR}/fcc_dtb/
fi

rm -f ${KERNEL_BUILD_VAR_FILE}
echo "========================================================"
echo "build end"
echo "========================================================"
echo
set +e
