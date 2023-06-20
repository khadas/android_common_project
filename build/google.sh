#!/bin/bash

set -e
build_command_line="$0 $*"
command_line=
project=
clean=
for param in ${build_command_line}; do
	if [[ ${param} =~ ":" && ${param} =~ "//" ]]; then
		param=${param#*:}
		project=${param%%_*}
		param=${param#*_}
		param="//common:amlogic_${param}"
	fi
	command_line="${command_line} $param"
	if [[ "${param}" == "clean" ]]; then
		clean=1
	fi
done

export GOOGLE_BAZEL_BUILD_COMMAND_LINE=`echo ${command_line} | sed 's/^[ ]*//'`
echo GOOGLE_BAZEL_BUILD_COMMAND_LINE=${GOOGLE_BAZEL_BUILD_COMMAND_LINE}

common=`ls common*/mk.sh`
common_kernel=${common%%/*}

if [[ "${clean}" == "1" ]]; then
	(cd ${common_kernel}/common; git checkout .)
	(cd driver_modules/wifi_bt/wifi; git checkout .)
	./mk clean
	exit
fi

android_kernel_build_command="./mk ${project} -v ${common_kernel}"
echo android_kernel_build_command=${android_kernel_build_command}
${android_kernel_build_command}

echo "========================================================"
vmlinux=`ls ${common_kernel}/out/android*/dist/vmlinux`
echo "google copy"
[[ -z ${vmlinux} ]] && exit
dist_dir=`dirname $vmlinux`
google_dist_dir=${dist_dir#*/}
rm -rf ${google_dist_dir}
mkdir -p ${google_dist_dir}
cp -a ${dist_dir}/* ${google_dist_dir}
cp -a ${common_kernel}/out/android/${project} ${google_dist_dir}
(cd ${google_dist_dir}; tar czf ${project}.tar.gz ${project})
echo "========================================================"
set +e
