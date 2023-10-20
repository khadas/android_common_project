#!/bin/bash
#
#  author: wanwei.jiang@amlogic.com
#  2023.10.20

if [[ "$*" =~ "5.4" ]]; then
	source device/amlogic/common/kernelbuild/mk_script.sh
else
	build_dir=$(realpath $(dirname $(readlink $0)))
	source ${build_dir}/mk_script_5.15.sh
fi
