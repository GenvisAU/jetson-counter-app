#!/bin/bash

# Copyright (c) 2011-2017, NVIDIA CORPORATION.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#
# flash.sh: Flash the target board.
#	    flash.sh performs the best in LDK release environment.
#
# Usage: Place the board in recovery mode and run:
#
#	flash.sh [options] <target_board> <root_device>
#
#	for more detail enter 'flash.sh -h'
#
# Examples:
# ./flash.sh <target_board> mmcblk0p1			- boot <target_board> from eMMC
# ./flash.sh <target_board> mmcblk1p1			- boot <target_board> from SDCARD
# ./flash.sh <target_board> sda1			- boot <target_board> from USB device
# ./flash.sh -N <IPaddr>:/nfsroot <target_board> eth0	- boot <target_board> from NFS
# ./flash.sh -k LNX <target_board> mmcblk1p1		- update <target_board> kernel
# ./flash.sh -k EBT <target_board> mmcblk1p1		- update <target_board> bootloader
#
# Optional Environment Variables:
# BCTFILE ---------------- Boot control table configuration file to be used.
# BOARDID ---------------- Pass boardid to override EEPROM value
# BOOTLOADER ------------- Bootloader binary to be flashed
# BOOTPARTLIMIT ---------- GPT data limit. (== Max BCT size + PPT size)
# BOOTPARTSIZE ----------- Total eMMC HW boot partition size.
# CFGFILE ---------------- Partition table configuration file to be used.
# CMDLINE ---------------- Target cmdline. See help for more information.
# DEVSECTSIZE ------------ Device Sector size. (default = 512Byte).
# DTBFILE ---------------- Device Tree file to be used.
# EMMCSIZE --------------- Size of target device eMMC (boot0+boot1+user).
# FLASHAPP --------------- Flash application running in host machine.
# FLASHER ---------------- Flash server running in target machine.
# IGNOREFASTBOOTCMDLINE -- Block fastboot from filling unspecified kernel
#                          cmdline parameters with its defaults.
# INITRD ----------------- Initrd image file to be flashed.
# KERNEL_IMAGE ----------- Linux kernel zImage file to be flashed.
# MTS -------------------- MTS file name such as mts_si.
# MTSPREBOOT ------------- MTS preboot file name such as mts_preboot_si.
# NFSARGS ---------------- Static Network assignments.
#			   <C-ipa>:<S-ipa>:<G-ipa>:<netmask>
# NFSROOT ---------------- NFSROOT i.e. <my IP addr>:/exported/rootfs_dir.
# ODMDATA ---------------- Odmdata to be used.
# ROOTFSSIZE ------------- Linux RootFS size (internal emmc/nand only).
# ROOTFS_DIR ------------- Linux RootFS directory name.
# SCEFILE ---------------- SCE firmware file such as camera-rtcpu-sce.bin.
# SPEFILE ---------------- SPE firmware file path such as bootloader/spe.bin.
# FAB -------------------- Target board's FAB ID.
# TEGRABOOT -------------- lowerlayer bootloader such as nvtboot.bin.
# WB0BOOT ---------------- Warmboot code such as nvtbootwb0.bin
#
chkerr ()
{
	if [ $? -ne 0 ]; then
		if [ "$1" != "" ]; then
			echo "$1";
		else
			echo "failed.";
		fi;
		exit 1;
	fi;
	if [ "$1" = "" ]; then
		echo "done.";
	fi;
}

pr_conf()
{
	if [ "${zflag}" != "true" ]; then
		return 0;
	fi;
	echo "target_board=${target_board}";
	echo "target_rootdev=${target_rootdev}";
	echo "rootdev_type=${rootdev_type}";
	echo "rootfssize=${rootfssize}";
	echo "odmdata=${odmdata}";
	echo "flashapp=${flashapp}";
	echo "flasher=${flasher}";
	echo "bootloader=${bootloader}";
	echo "tegraboot=${tegraboot}";
	echo "wb0boot=${wb0boot}";
	echo "mtspreboot=${mtspreboot}";
	echo "mts=${mts}";
	echo "bctfile=${bctfile}";
	echo "cfgfile=${cfgfile}";
	echo "kernel_fs=${kernel_fs}";
	echo "kernel_image=${kernel_image}";
	echo "rootfs_dir=${rootfs_dir}";
	echo "nfsroot=${nfsroot}";
	echo "nfsargs=${nfsargs}";
	echo "kernelinitrd=${kernelinitrd}";
	echo "cmdline=${cmdline}";
	echo "boardid=${boardid}";
	exit 0;
}

validateIP ()
{
	local ip=$1;
	local ret=1;

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=${IFS};
		IFS='.';
		ip=($ip);
		IFS=${OIFS};
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && \
		   ${ip[2]} -le 255 && ${ip[3]} -le 255 ]];
		ret=$?;
	fi;
	if [ ${ret} -ne 0 ]; then
		echo "Invalid IP address: $1";
		exit 1;
	fi;
}

netmasktbl=(\
	"255.255.255.252" \
	"255.255.255.248" \
	"255.255.255.240" \
	"255.255.255.224" \
	"255.255.255.192" \
	"255.255.255.128" \
	"255.255.255.0" \
	"255.255.254.0" \
	"255.255.252.0" \
	"255.255.248.0" \
	"255.255.240.0" \
	"255.255.224.0" \
	"255.255.192.0" \
	"255.255.128.0" \
	"255.255.0.0" \
	"255.254.0.0" \
	"255.252.0.0" \
	"255.248.0.0" \
	"255.240.0.0" \
	"255.224.0.0" \
	"255.192.0.0" \
	"255.128.0.0" \
	"255.0.0.0" \
);

validateNETMASK ()
{
	local i;
	local nm=$1;
	for (( i=0; i<${#netmasktbl[@]}; i++ )); do
		if [ "${nm}" = ${netmasktbl[$i]} ]; then
			return 0;
		fi;
	done;
	echo "Error: Invalid netmask($1)";
	exit 1;
}

validateNFSargs ()
{
	local a=$2;

	OIFS=${IFS};
	IFS=':';
	a=($a);
	IFS=${OIFS};

	if [ ${#a[@]} -ne 4 ]; then
		echo "Error: Invalid nfsargs($2)";
		exit 1;
	fi;
	validateIP ${a[0]};
	if [ "${serverip}" = "" ]; then
		validateIP ${a[1]};
	fi;
	validateIP ${a[2]};
	validateNETMASK ${a[3]};
	if [ "$1" != "" ]; then
		eval "$1=$2";
	fi;
	return 0;
}

validateNFSroot ()
{
	if [ "$2" = "" ]; then
		return 1;
	fi;
	OIFS=${IFS};
	IFS=':';
	local var=$1;
	local a=($2);
	IFS=${OIFS};
	if [ ${#a[@]} -ne 2 ]; then
		echo "Error: Invalid nfsroot($2)";
		exit 1;
	fi;
	validateIP ${a[0]};
	if [[ "${a[1]}" != /* ]]; then
		echo "Error: Invalid nfsroot($2)";
		exit 1;
	fi;
	eval "${var}=$2";
	return 0;
}

usage ()
{
	state=$1;
	retval=$2;

	if [[ $state == allunknown ]]; then
		echo -e "
Usage: sudo ./flash.sh [options] <target_board> <rootdev>
  Where,
	target board: Valid target board name.
	rootdev: Proper root device.";

	elif [[ $state == rootdevunknown ]]; then
		echo -e "
Usage: sudo ./flash.sh [options] ${target_board} <rootdev>
  Where,
    rootdev for ${target_board}:
	${ROOT_DEV}";

	else
		echo "
Usage: sudo ./flash.sh [options] ${target_board} ${target_rootdev}";
	fi;

	cat << EOF
    options:
        -b <bctfile> --------- nvflash boot control table config file.
        -c <cfgfile> --------- nvflash partition table config file.
        -d <dtbfile> --------- device tree file.
        -e <emmc size> ------- Target device's eMMC size.
        -f <flashapp> -------- Path to flash application: nvflash or tegra-rcm.
        -h ------------------- print this message.
        -i ------------------- pass user kernel commandline as-is to kernel.
        -k <partition id> ---- partition name or number specified in flash.cfg.
        -m <mts preboot> ----- MTS preboot such as mts_preboot_si.
        -n <nfs args> -------- Static nfs network assignments
                               <Client IP>:<Server IP>:<Gateway IP>:<Netmask>
        -o <odmdata> --------- ODM data.
        -p <bp size> --------- Total eMMC HW boot partition size.
        -r ------------------- skip building and reuse existing system.img.
        -t <tegraboot> ------- tegraboot binary such as nvtboot.bin
        -u <dbmaster> -------- PKC server in <user>@<IP address> format.
        -w <wb0boot> --------- warm boot binary such as nvtbootwb0.bin
        -x <tegraid> --------- Tegra CHIPID. default = 0x18(jetson-tx2)
                               0x21(jetson-tx1), 0x40(jetson-tk1).
        -y <fusetype> -------- PKC for secureboot, NS for non-secureboot.
        -z <sn> -------------- Serial Number of target board.
        -B <boardid> --------- BoardId.
        -C <cmdline> --------- Kernel commandline arguments.
                               WARNING:
                               Each option in this kernel commandline gets
                               higher preference over the same option from
                               fastboot. In case of NFS booting, this script
                               adds NFS booting related arguments, if -i option
                               is omitted.
        -F <flasher> --------- Flash server such as fastboot.bin.
        -G <file name> ------- Read partition and save image to file.
        -I <initrd> ---------- initrd file. Null initrd is default.
        -K <kernel> ---------- Kernel image file such as zImage or Image.
        -L <bootloader> ------ Bootloader such as cboot.bin or u-boot-dtb.bin.
        -M <mts boot> -------- MTS boot file such as mts_si.
        -N <nfsroot> --------- i.e. <my IP addr>:/my/exported/nfs/rootfs.
        -P <end of PPT + 1> -- Primary GPT start address + size of PPT + 1.
        -R <rootfs dir> ------ Sample rootfs directory.
        -S <size> ------------ Rootfs size in bytes. Valid only for internal
                               rootdev. KiB, MiB, GiB short hands are allowed,
                               for example, 1GiB means 1024 * 1024 * 1024 bytes.
        -T <its file> -------- ITS file name. Valid only for u-boot.
        --no-flash ----------- perform all steps except physically flashing the board.
                               This will create a system.img.
EOF
	exit $retval;
}

setdflt ()
{
	local var="$1";
	if [ "${!var}" = "" ]; then
		eval "${var}=$2";
	fi;
}

setval ()
{
	local var="$1";
	local val="$2";
	if [ "${!val}" = "" ]; then
		echo "Error: missing $val not defined.";
		exit 1;
	fi;
	eval "${var}=${!val}";
}

mkfilesoft ()
{
	local var="$1";
	local varname="$1name";

	eval "${var}=$2";
	if [ "${!var}" = "" -o ! -f "${!var}" ]; then
		if [ "$3" != "" -a -f "$3" ]; then
			eval "${var}=$3";
		fi;
	fi;
	if [ "${!var}" != "" ]; then
		if [ ! -f ${!var} ]; then
			echo "Warning: missing $var (${!var}), continue... ";
			eval "${var}=\"\"";
			eval "${varname}=\"\"";
			return 1;
		fi;
		eval "${var}=`readlink -f ${!var}`";
		eval "${varname}=`basename ${!var}`";
	fi;
	return 0;
}

mkfilepath ()
{
	local var="$1";
	local varname="$1name";

	eval "${var}=$2";
	setdflt "${var}" "$3";
	if [ "${!var}" != "" ]; then
		eval "${var}=`readlink -f ${!var}`";
		if [ ! -f "${!var}" ]; then
			echo "Error: missing $var (${!var}).";
			usage allknown 1;
		fi;
		eval "${varname}=`basename ${!var}`";
	fi;
}

mkdirpath ()
{
	local var="$1";
	eval "${var}=$2";
	setdflt "$1" "$3";
	if [ "${!var}" != "" ]; then
		eval "${var}=`readlink -f ${!var}`";
		if [ ! -d "${!var}" ]; then
			echo "Error: missing $var (${!var}).";
			usage allknown 1;
		fi;
	fi;
}

getsize ()
{
	local var="$1";
	local val="$2";
	if [[ ${!val} != *[!0-9]* ]]; then
		eval "${var}=${!val}";
	elif [[ (${!val} == *KiB) && (${!val} != *[!0-9]*KiB) ]]; then
		eval "${var}=$(( ${!val%KiB} * 1024 ))";
	elif [[ (${!val} == *MiB) && (${!val} != *[!0-9]*MiB) ]]; then
		eval "${var}=$(( ${!val%MiB} * 1024 * 1024 ))";
	elif [[ (${!val} == *GiB) && (${!val} != *[!0-9]*GiB) ]]; then
		eval "${var}=$(( ${!val%GiB} * 1024 * 1024 * 1024))";
	else
		echo "Error: Invalid $1: ${!val}";
		exit 1;
	fi;
}

validatePartID ()
{
	local idx=0;
	declare -A cf;

	while read aline; do
		if [ "$aline" != "" ]; then
			arr=( $(echo $aline | tr '=' ' ') );
			if [ "${arr[1]}" == "name" ]; then
				if [ "${arr[3]}" == "id" ]; then
					cf[$idx,1]="${arr[2]}";
					cf[$idx,0]="${arr[4]}";
				else
					cf[$idx,0]="${arr[2]}";
				fi
				idx=$((idx+1));
			fi
		fi;
	done < $4;

	if [ "${arr[3]}" == "id" ]; then
		for ((i = 0; i < idx; i++)) do
			if [ "\"$3\"" = "${cf[$i,0]}" -o  \
			     "\"$3\"" = "${cf[$i,1]}" ]; then
				eval "$1=${cf[$i,0]}";
				eval "$2=${cf[$i,1]}";
			return 0;
			fi;
		done;
		echo "Error: invalid partition id ($3)";
		exit 1;
	else
		return 0;
	fi;
}

cp2local ()
{
	local src=$1;
	if [ "${!src}" = "" ]; then return 1; fi;
	if [ ! -f "${!src}" ]; then return 1; fi;
	if [ "$2" = "" ];      then return 1; fi;
	if [ -f $2 -a ${!src} = $2 ]; then
		local sum1=`sum ${!src}`;
		local sum2=`sum $2`;
		if [ "$sum1" = "$sum2" ]; then
			echo "Existing ${src}($2) reused.";
			return 0;
		fi;
	fi;
	echo -n "copying ${src}(${!src})... ";
	cp -f ${!src} $2;
	chkerr;
	return 0;
}

chsuffix ()
{
	local var="$1";
	local fname=`basename "$2"`;
	local OIFS=${IFS};
	IFS='.';
	na=($fname);
	IFS=${OIFS};
	eval "${var}=${na[0]}.${3}";
}

build_fsimg ()
{
	echo "Making $1... ";
	local loop_dev="${LOOPDEV:-/dev/loop0}";
	if [ ! -b "${loop_dev}" ]; then
		echo "${loop_dev} is not block device. Terminating..";
		exit 1;
	fi;
	loop_dev=`losetup --find`;
	if [ $? -ne 0 ]; then
		echo "Cannot find loop device. Terminating..";
		exit 1;
	fi;
	umount "${loop_dev}" > /dev/null 2>&1;
	losetup -d "${loop_dev}" > /dev/null 2>&1;
	rm -f $1;	chkerr "clearing $1 failed.";
	rm -rf mnt;	chkerr "clearing $4 mount point failed.";

	local bcnt=$(( $3 / 512 ));
	local bcntdiv=$(( $3 % 512 ));
	if [ $bcnt -eq 0 -o $bcntdiv -ne 0 ]; then
		echo "Error: $4 file system size has to be 512 bytes allign.";
		exit 1;
	fi
	if [ "$2" != "" -a "$2" != "0" ]; then
		local fc=`printf '%d' $2`;
		local fillc=`printf \\\\$(printf '%02o' $fc)`;
		< /dev/zero head -c $3 | tr '\000' ${fillc} > $1;
		chkerr "making $1 with fillpattern($fillc}) failed.";
	else
		truncate --size $3 $1;
		chkerr "making $1 with zero fillpattern failed.";
	fi;
	losetup "${loop_dev}" $1 > /dev/null 2>&1;
	chkerr "mapping $1 to loop device failed.";
	if [ "$4" = "FAT32" ]; then
		mkfs.msdos -I -F 32 "${loop_dev}" > /dev/null 2>&1;
	else
		mkfs -t $4 "${loop_dev}" > /dev/null 2>&1;
	fi;
	chkerr "formating $4 filesystem on $1 failed.";
	mkdir -p mnt;		chkerr "make $4 mount point failed.";
	mount "${loop_dev}" mnt;	chkerr "mount $1 failed.";
	mkdir -p mnt/boot/dtb;	chkerr "make $1/boot/dtb failed.";
	cp -f "${kernel_fs}" mnt/boot;
	chkerr "Copying ${kernel_fs} failed.";
	if [ -f "${dtbfilename}" ]; then
		cp -f "${dtbfilename}" "mnt/boot/dtb/${dtbfilename}";
		chkerr "populating ${dtbfilename} to $1/boot/dtb failed.";
	fi;
	if [ "$4" = "FAT32" ]; then
		touch -f mnt/boot/cmdline.txt > /dev/null 2&>1;
		chkerr "Creating cmdline.txt failed.";
	fi;
	if [ "$5" != "" ]; then
		pushd mnt > /dev/null 2>&1;
		echo -n -e "\tpopulating rootfs from $5 ... ";
		(cd $5; tar cf - *) | tar xf - ; chkerr;
		popd > /dev/null 2>&1;
	fi;
	echo -e -n "\tSync'ing $1 ... ";
	sync; sync; sleep 5;	# Give FileBrowser time to terminate gracefully.
	echo "done.";
	umount "${loop_dev}" > /dev/null 2>&1;
	losetup -d "${loop_dev}" > /dev/null 2>&1;
	rmdir mnt > /dev/null 2>&1;

	if [ "$2" != "" -a -x mksparse ]; then
		echo -e "\tConverting RAW image to Sparse image... ";
		mv -f $1 $1.raw;
		./mksparse -v --fillpattern=$2 $1.raw $1; chkerr;
	fi;
	echo "$1 built successfully. ";
}

append_bootargs_to_dtb ()
{
	local trgdtbfilename="${1}";
	if [ "${flashappname}" != "tegraflash.py" ]; then
		return 1;
	fi;
	default_cmd="console=tty0 OS=l4t ";
	dtc -I dtb -O dts "${trgdtbfilename}" -o temp.dts;
	sed -i '/bootargs/d' temp.dts;
	for string in ${default_cmd}; do
		lcl_str=`echo $string | sed "s|\(.*\)=.*|\1|"`;
		[[ "${cmdline}" =~ $lcl_str ]] || cmdline+=" ${string}";
	done
	sed -i "/chosen {/ a \\\t\\tbootargs=\"${cmdline} console=ttyS0,115200n8 \";" temp.dts;
	sed -i "/stdout-path = \"/ a \\\t\\tplugin-manager {\n\\t\t\todm-data {\n\t\t\t\tl4t;\n\t\t\t};\n\t\t};" temp.dts;
	dtc -I dts -O dtb temp.dts -o "${trgdtbfilename}";
	rm temp.dts;
}

get_fuse_level ()
{
	local fuselevel="x";
	local ECID;

	if [ -f "${BL_DIR}/tegrarcm_v2" ]; then
		pushd "${BL_DIR}" > /dev/null 2>&1;
		ECID=$(./tegrarcm_v2 --uid | grep BR_CID | cut -d' ' -f2);
		popd > /dev/null 2>&1;
		fuselevel="${ECID:2:1}";
	fi;

	case ${fuselevel} in
	0|1) echo "fuselevel_nofuse";;
	8|a|b|d|e|f) echo "fuselevel_production";;
	*) echo "fuselevel_unknown";;
	esac;
}

function get_full_path ()
{
	local val="$1";
	local result="$2";
	local fullpath;
	fullpath=$(readlink -f ${val});	# null if path is invalid
	if [ "${fullpath}" == "" ]; then
		echo "Invalid path/filename ${val}";
		exit 1;
	fi;
	eval "${result}=${fullpath}";
}

#
# XXX: This EEPROM read shall be replaced with new FAB agnostic function.
#
get_board_version ()
{
	local args="";
	local __board_id=$1;
	local __board_version=$2;
	local boardid;
	local boardversion;
	args+="--chip ${CHIPID} ";
	args+="--applet \"${LDK_DIR}/${SOSFILE}\" ";
	args+="--cmd \"dump eeprom boardinfo cvm.bin\" ";
	args+="${SKIPUID} ";
	SKIPUID="";
	local cmd="./tegraflash.py ${args}";
	pushd "${BL_DIR}" > /dev/null 2>&1;
	if [ "${dbmaster}" != "" ]; then
		local keyfile;
		if [[ ${dbmaster} =~ ^/ ]]; then
			keyfile="${dbmaster}";
		else
			keyfile=`readlink -f "../${dbmaster}"`;
		fi;
		cmd+="--key \"${keyfile} \"";
	fi;
	echo "${cmd}";
	eval "${cmd}";
	chkerr "Reading board information failed.";
	boardid=`./chkbdinfo -i cvm.bin`;
	boardversion=`./chkbdinfo -f cvm.bin`;
	chkerr "Parsing board information failed.";
	popd > /dev/null 2>&1;
	eval ${__board_id}="${boardid}";
	eval ${__board_version}="${boardversion}";
}

if [ $# -lt 2 ]; then
	usage allunknown 1;
fi;

# if the user is not root, there is not point in going forward
if [ "${USER}" != "root" ]; then
	echo "flash.sh requires root privilege";
	exit 1;
fi
nargs=$#;
target_rootdev=${!nargs};
nargs=$(($nargs-1));
ext_target_board=${!nargs};

if [ ! -r ${ext_target_board}.conf ]; then
	echo "Error: Invalid target board - ${ext_target_board}.";
	usage allunknown 1;
fi

# set up LDK_DIR path
LDK_DIR=$(cd `dirname $0` && pwd);
LDK_DIR=`readlink -f "${LDK_DIR}"`;

source ${ext_target_board}.conf

# set up path variables
BL_DIR="${LDK_DIR}/bootloader";
TARGET_DIR="${BL_DIR}/${target_board}";
KERNEL_DIR="${LDK_DIR}/kernel";
export PATH="${KERNEL_DIR}:${PATH}";		# preference on our DTC
DTB_DIR="${KERNEL_DIR}/dtb";
if [ "${BINSARGS}" = "" -a "${BINS}" != "" ]; then			#COMPAT
	BINARGS="--bins \"";						#COMPAT
fi;									#COMPAT
if [ "${BINSARGS}" != "" ]; then
	SKIPUID="--skipuid";
fi;

# get the fuse level and update the data accordingly
declare -F -f process_fuse_level > /dev/null 2>&1;
if [ $? -eq 0 ]; then
	fuselevel="${FUSELEVEL}";
	if [ "${fuselevel}" = "" ]; then
		fuselevel=$(get_fuse_level);
	fi;
	process_fuse_level "${fuselevel}";
fi;

# Determine rootdev_type
#
rootdev_type="external";
if [[ "${target_rootdev}" == mmcblk0p* ]]; then
	rootdev_type="internal";
elif [ "${target_rootdev}" = "eth0" -o "${target_rootdev}" = "eth1" ]; then
	rootdev_type="network";
elif [[ "${target_rootdev}" != mmcblk1p* && \
	"${target_rootdev}" != sd* ]]; then
	echo "Error: Invalid target rootdev($target_rootdev).";
	usage rootdevunknown 1;
fi;

read_part_name="";
no_flash=0;
opstr+="b:c:d:e:f:hik:m:n:o:p:rs:t:u:w:x:y:z:B:C:F:G:I:K:L:M:N:P:R:S:T:Z:-:";
while getopts "${opstr}" OPTION
do
	case $OPTION in
	b) BCTFILE=${OPTARG}; ;;
	c) CFGFILE=${OPTARG}; ;;
	d) DTBFILE=${OPTARG}; ;;
	e) EMMCSIZE=${OPTARG}; ;;
	f) FLASHAPP=${OPTARG}; ;;
	h) usage allunknown 0; ;;
	i) IGNOREFASTBOOTCMDLINE="ignorefastboot"; ;;
	k) target_partname=${OPTARG}; ;;	# cmdline only
	m) MTSPREBOOT=${OPTARG}; ;;
	n) NFSARGS=${OPTARG}; ;;
	o) ODMDATA=${OPTARG}; ;;
	p) BOOTPARTSIZE=${OPTARG}; ;;
	r) reuse_systemimg="true"; ;;		# cmdline only
	t) TEGRABOOT=${OPTARG}; ;;
	u) dbmaster="${OPTARG}"; ;;
	w) WB0BOOT=${OPTARG}; ;;
	x) tegraid=${OPTARG}; ;;
	y) fusetype=${OPTARG}; ;;
	z) sn=${OPTARG}; ;;
	B) BOARDID=${OPTARG}; ;;
	C) CMDLINE="${OPTARG}"; ;;
	F) FLASHER=${OPTARG}; ;;
	G) read_part_name=${OPTARG}; ;;
	I) INITRD=${OPTARG}; ;;
	K) KERNEL_IMAGE=${OPTARG}; ;;
	L) BOOTLOADER=${OPTARG}; ;;
	M) MTS=${OPTARG}; ;;
	N) NFSROOT=${OPTARG}; ;;
	P) BOOTPARTLIMIT=${OPTARG}; ;;
	R) ROOTFS_DIR=${OPTARG}; ;;
	S) ROOTFSSIZE=${OPTARG}; ;;
	Z) zflag="true"; ;;			# cmdline only
	-) case ${OPTARG} in
	   no-flash) no_flash=1; ;;
	   esac;;
	*) usage allunknown 1; ;;
	esac;
done

#
# Handle -G option for reading partition image to file
#
if [ "${read_part_name}" != "" ]; then
	# Exit if path is invalid
	get_full_path ${read_part_name} read_part_name;
fi;

# get the board version and update the data accordingly
declare -F -f process_board_version > /dev/null 2>&1;
if [ $? -eq 0 ]; then
	board_version="${FAB}";
	if [ "${board_version}" = "" ]; then
		get_board_version board_id board_version;
	fi;
	process_board_version "${board_id}" "${board_version}";
fi;

###########################################################################
# System default values: should be defined AFTER target_board value.
#
ROOTFS_TYPE="${ROOTFS_TYPE:-ext4}";
DEVSECTSIZE="${DEVSECTSIZE:-512}";		# default sector size = 512
BOOTPARTLIMIT="${BOOTPARTLIMIT:-10485760}";	# 1MiB limit
fillpat="${FSFILLPATTERN:-0}";			# no cmdline: default=0
boardid="${BOARDID}";
if [ "${tegraid}" = "" ]; then
	tegraid="${CHIPID}";
fi;

if [ -z "${DFLT_KERNEL}" ]; then
	if [[ "${target_board}" == ardbeg* ]]; then
		DFLT_KERNEL=${KERNEL_DIR}/zImage;
	else
		DFLT_KERNEL=${KERNEL_DIR}/Image;
	fi;
else
	basekernel=`basename "${DFLT_KERNEL}"`;
	if [ "${DFLT_KERNEL}" = "${basekernel}" ]; then
		DFLT_KERNEL="${KERNEL_DIR}/${DFLT_KERNEL}";
	fi;
fi;
if [ -z "${DFLT_KERNEL_FS}" ]; then
	DFLT_KERNEL_FS=${DFLT_KERNEL};
fi;
if [ -z "${DFLT_KERNEL_IMAGE}" ]; then
	DFLT_KERNEL_IMAGE=${DFLT_KERNEL};
fi;

###########################################################################
# System mandatory vars:
#
setval     odmdata	ODMDATA;	# .conf mandatory
setval     rootfs_type	ROOTFS_TYPE;
setval     devsectsize	DEVSECTSIZE;
getsize    rootfssize	ROOTFSSIZE;	# .conf mandatory
getsize    emmcsize	EMMCSIZE;	# .conf mandatory
getsize    bootpartsize	BOOTPARTSIZE;	# .conf mandatory
getsize    bootpartlim	BOOTPARTLIMIT;
mkfilepath flashapp	"${FLASHAPP}"	"${BL_DIR}/nvflash";
mkfilepath flasher	"${FLASHER}"	"${TARGET_DIR}/fastboot.bin";
mkfilepath bootloader	"${BOOTLOADER}"	"${TARGET_DIR}/fastboot.bin";
mkdirpath  rootfs_dir	"${ROOTFS_DIR}"	"${LDK_DIR}/rootfs";
mkfilepath kernel_image	"$KERNEL_IMAGE" "${DFLT_KERNEL_IMAGE}";
mkfilepath kernel_fs	"$KERNEL_IMAGE" "${DFLT_KERNEL_FS}";
mkfilepath bctfile	"${BCTFILE}"	"${TARGET_DIR}/BCT/${EMMC_BCT}";
mkfilepath cfgfile	"${CFGFILE}"	"${TARGET_DIR}/cfg/${EMMC_CFG}";
mkfilepath dtbfile	"${DTBFILE}"	"${DTB_DIR}/${DTB_FILE}";

if [[ "${bootloadername}" == u-boot* ]]; then
	bootloader_is_uboot=1;
else
	bootloader_is_uboot=0;
fi;
if [[ "${kernel_imagename}" == u-boot* ]]; then
	kernel_image_is_uboot=1;
else
	kernel_image_is_uboot=0;
fi;
if [ ${bootloader_is_uboot} -eq 1 -o ${kernel_image_is_uboot} -eq 1 ]; then
	using_uboot=1;
else
	using_uboot=0;
fi;
case "${target_board}" in
t210ref)
	uboot_replaces_tboot=0;
	uboot_in_tboot_img=1;
	if [ "${tegraid}" = "" ]; then
		tegraid="0x21";
	fi;
	;;
t186ref)
	uboot_replaces_tboot=0;
	uboot_in_tboot_img=0;
	if [ "${tegraid}" = "" ]; then
		tegraid="0x18";
	fi;
	;;
*)
	uboot_replaces_tboot=1;
	uboot_in_tboot_img=0;
	;;
esac;

mkfilesoft kernelinitrd	"${INITRD}"	"";
if [ ${using_uboot} -eq 0 -o ${uboot_replaces_tboot} -eq 0 ]; then
	mkfilesoft tegraboot	"${TEGRABOOT}"	"${TARGET_DIR}/nvtboot.bin";
	mkfilesoft wb0boot	"${WB0BOOT}"	"${TARGET_DIR}/nvtbootwb0.bin";
fi
mkfilesoft mtspreboot	"${MTSPREBOOT}"	"${BL_DIR}/mts_preboot_si";
mkfilesoft mts		"${MTS}"	"${BL_DIR}/mts_si";
mkfilesoft mb1file	"${MB1FILE}"	"${BL_DIR}/mb1_prod.bin";
mkfilesoft bpffile	"${BPFFILE}"	"${BL_DIR}/bpmp.bin";
mkfilesoft bpfdtbfile	"${BPFDTBFILE}" "${TARGET_DIR}/${BPFDTB_FILE}";
if [ "${bpfdtbfile}" = "" -a "${BPMPDTB_FILE}" != "" ]; then		#COMPAT
	mkfilesoft bpfdtbfile	"${BL_DIR}/${BPMPDTB_FILE}"	"";	#COMPAT
fi;									#COMPAT
mkfilesoft nctfile	"${NCTFILE}"	"${TARGET_DIR}/cfg/${NCT_FILE}";
mkfilesoft tosfile	"${TOSFILE}"	"${TARGET_DIR}/tos.img";
mkfilesoft eksfile	"${EKSFILE}"	"${TARGET_DIR}/eks.img";
mkfilesoft fbfile	"${FBFILE}"	"";
mkfilesoft bcffile	"${BCFFILE}"	"";
mkfilesoft sosfile	"${SOSFILE}"	"";
mkfilesoft mb2blfile	"${MB2BLFILE}"	"";
mkfilesoft scefile	"${SCEFILE}"	"${BL_DIR}/camera-rtcpu-sce.bin";
mkfilesoft spefile	"${SPEFILE}"	"${BL_DIR}/spe.bin";

mkfilesoft misc_config    "${TARGET_DIR}/BCT/${MISC_CONFIG}" "";
mkfilesoft pinmux_config  "${TARGET_DIR}/BCT/${PINMUX_CONFIG}" "";
mkfilesoft pmic_config    "${TARGET_DIR}/BCT/${PMIC_CONFIG}" "";
mkfilesoft pmc_config     "${TARGET_DIR}/BCT/${PMC_CONFIG}" "";
mkfilesoft prod_config    "${TARGET_DIR}/BCT/${PROD_CONFIG}" "";
mkfilesoft scr_config     "${TARGET_DIR}/BCT/${SCR_CONFIG}" "";
mkfilesoft dev_params     "${TARGET_DIR}/BCT/${DEV_PARAMS}" "";
mkfilesoft bootrom_config "${TARGET_DIR}/BCT/${BOOTROM_CONFIG}" "";

if [ ${using_uboot} -eq 0 -o ${uboot_replaces_tboot} -eq 0 ]; then
	mkfilesoft tbcfile	"${TBCFILE}"	 "";
	mkfilesoft tbcdtbfile	"${TBCDTB_FILE}" "${DTB_DIR}/${DTB_FILE}";
fi

if [ "${rootdev_type}" = "network" ]; then
	if [ "${NFSROOT}" = "" -a "${NFSARGS}" = "" ]; then
		echo "Error: network argument(s) missing.";
		usage allknown 1;
	fi;
	if [ "${NFSROOT}" != "" ]; then
		validateNFSroot nfsroot "${NFSROOT}";
	fi;
	if [ "${NFSARGS}" != "" ]; then
		validateNFSargs nfsargs "${NFSARGS}";
	fi;
	if [ "${nfsroot}" != "" ]; then
		nfsdargs="root=/dev/nfs rw netdevwait";
		cmdline+="${nfsdargs} ";
		if [ "${nfsargs}" != "" ]; then
			nfsiargs="ip=${nfsargs}";
			nfsiargs+="::${target_rootdev}:off";
		else
			nfsiargs="ip=:::::${target_rootdev}:on";
		fi;
		cmdline+="${nfsiargs} ";
		cmdline+="nfsroot=${nfsroot} ";
	fi;
elif [ "${flashappname}" = "tegraflash.py" ]; then
	cmdline+="root=/dev/${target_rootdev} rw rootwait ";
fi;

if [ "${CMDLINE_ADD}" != "" ]; then
	cmdline+="${CMDLINE_ADD} ";
fi;

if [ "${CMDLINE}" != "" ]; then
	for string in ${CMDLINE}; do
		lcl_str=`echo $string | sed "s|\(.*\)=.*|\1|"`
		if [[ "${cmdline}" =~ $lcl_str ]]
		then
			cmdline=`echo "$cmdline" | sed "s|$lcl_str=[0-9a-zA-Z:/]*|$string|"`
		else
			cmdline+="${string} ";
		fi
	done
fi;

if [ "${IGNOREFASTBOOTCMDLINE}" != "" ]; then
	cmdline+="${IGNOREFASTBOOTCMDLINE} ";
fi;

if [ ${using_uboot} -eq 1 ]; then
	if [ "${rootdev_type}" = "network" ]; then
		SYSBOOTFILE="${TARGET_DIR}/${SYSBOOTFILE}.nfs";
	elif [[ "${target_rootdev}" == mmcblk1p* ]]; then
		SYSBOOTFILE="${TARGET_DIR}/${SYSBOOTFILE}.sdcard";
	elif [[ "${target_rootdev}" == sd* ]]; then
		SYSBOOTFILE="${TARGET_DIR}/${SYSBOOTFILE}.usb";
	else
		SYSBOOTFILE="${TARGET_DIR}/${SYSBOOTFILE}.emmc";
	fi;
	mkfilesoft sysbootfile "${SYSBOOTFILE}";
fi;

##########################################################################
pr_conf;	# print config and terminate if requested.
##########################################################################

pushd $BL_DIR > /dev/null 2>&1;

### Localize files and build TAGS ########################################
# BCT_TAG:::
#
cp2local bctfile "${BL_DIR}/${bctfilename}";
if [ "${BINSARGS}" != "" ]; then
	# Build up BCT parameters:
	if [ "${misc_config}" != "" ]; then
		cp2local misc_config "${BL_DIR}/${misc_configname}";
		BCTARGS+="--misc_config ${misc_configname} ";
	fi;
	if [ "${pinmux_config}" != "" ]; then
		cp2local pinmux_config "${BL_DIR}/${pinmux_configname}";
		BCTARGS+="--pinmux_config ${pinmux_configname} ";
	fi;
	if [ "${pmic_config}" != "" ]; then
		cp2local pmic_config "${BL_DIR}/${pmic_configname}";
		BCTARGS+="--pmic_config ${pmic_configname} ";
	fi;
	if [ "${pmc_config}" != "" ]; then
		cp2local pmc_config "${BL_DIR}/${pmc_configname}";
		BCTARGS+="--pmc_config ${pmc_configname} ";
	fi;
	if [ "${prod_config}" != "" ]; then
		cp2local prod_config "${BL_DIR}/${prod_configname}";
		BCTARGS+="--prod_config ${prod_configname} ";
	fi;
	if [ "${scr_config}" != "" ]; then
		cp2local scr_config "${BL_DIR}/${scr_configname}";
		BCTARGS+="--scr_config ${scr_configname} ";
	fi;
	if [ "${bootrom_config}" != "" ]; then
		cp2local bootrom_config "${BL_DIR}/${bootrom_configname}";
		BCTARGS+="--br_cmd_config ${bootrom_configname} ";
	fi;
	if [ "${dev_params}" != "" ]; then
		cp2local dev_params "${BL_DIR}/${dev_paramsname}";
		BCTARGS+="--dev_params ${dev_paramsname} ";
	fi;
	if [ "${BCT}" = "" ]; then
		BCT="--sdram_config";
	fi;
elif [ "${BCT}" = "" ]; then
	BCT="--bct";
fi;

# EBT_TAG:
#
if [ ${using_uboot} -eq 1 -a ${uboot_in_tboot_img} -eq 1 ]; then
	bootloaderdir=`dirname "${bootloader}"`;
	uboot_elf="${bootloaderdir}/u-boot";
	uboot_entry=`"${LDK_DIR}/elf-get-entry.py" "${uboot_elf}"`;
	chkerr "Could not determine entry point of bootloader binary";

	"${BL_DIR}/gen-tboot-img.py" "${bootloader}" ${uboot_entry} "${BL_DIR}/${bootloadername}";
	chkerr "Failed to add TBOOT header to bootloader";
else
	cp2local bootloader "${BL_DIR}/${bootloadername}";
fi;
EBT_TAG+="-e s/fastboot.bin/${bootloadername}/ ";
EBT_TAG+="-e s/EBTFILE/${bootloadername}/ ";

# LNX_TAG:
#
localbootfile=boot.img;
rm -f initrd; touch initrd;
if [ "$kernelinitrd" != "" -a -f "$kernelinitrd" ]; then
	echo -n "copying initrd(${kernelinitrd})... ";
	cp -f "${kernelinitrd}" initrd;
	chkerr;
fi;
if [ ${using_uboot} -eq 1 ]; then
	mkdir -p "${rootfs_dir}/boot" > /dev/null 2>&1;
	echo -e -n "\tpopulating kernel to rootfs... ";
	cp -f "${kernel_fs}" "${rootfs_dir}/boot"; chkerr;
	echo -e -n "\tpopulating initrd to rootfs... ";
	cp -f initrd "${rootfs_dir}/boot"; chkerr;
	echo -e -n "\tpopulating ${sysbootfilename} to rootfs... ";
	cp -f "${dtbfile}" "${rootfs_dir}/boot"; chkerr;
	echo -e -n "\tpopulating ${dtbfile} to rootfs... ";
	mkdir -p "${rootfs_dir}/boot/extlinux"; chkerr;
	cp -f "${sysbootfile}" "${rootfs_dir}/boot/extlinux/extlinux.conf";
	sed -i "s|fbcon=map:.|${CMDLINE_ADD}|" "${rootfs_dir}/boot/extlinux/extlinux.conf";
	chkerr;
fi

LNX_TAG+="-e s/LNXNAME/kernel/ ";
LNX_TAG+="-e s/LNXSIZE/67108864/ ";
if [ ${using_uboot} -eq 1 -a ${kernel_image_is_uboot} -eq 0 ]; then
	LNX_TAG+="-e /filename=${localbootfile}/d ";
	LNX_TAG+="-e /LNXFILE/d ";
else
	echo -n "Making Boot image... ";
	MKBOOTARG+="--kernel ${kernel_image} ";
	MKBOOTARG+="--ramdisk initrd ";
	MKBOOTARG+="--board ${target_rootdev} ";
	MKBOOTARG+="--output ${localbootfile} ";
	./mkbootimg ${MKBOOTARG} --cmdline "${cmdline}" > /dev/null 2>&1;
	chkerr;
	LNX_TAG+="-e s/LNXFILE/${localbootfile}/ ";
fi;

# NCT_TAG:
#
if [ "${bcffile}" != "" ]; then
	cp2local bcffile "${BL_DIR}/${bcffilename}";
	NCTARGS+="--boardconfig ${bcffilename} ";
	NCT_TAG+="-e /NCTFILE/d ";
	NCT_TAG+="-e s/NCTTYPE/data/ ";
elif [ "${boardid}" != "" ]; then
	NCTARGS+="--boardid $boardid";
	NCT_TAG+="-e /NCTFILE/d ";
	NCT_TAG+="-e s/NCTTYPE/data/ ";
elif [ "${nctfile}" != "" ]; then
	cp2local nctfile "${BL_DIR}/${nctfilename}";
	NCT_TAG+="-e s/name=NXT/name=NCT/ ";
	NCT_TAG+="-e s/NCTFILE/${nctfilename}/ ";
	NCT_TAG+="-e s/NCTTYPE/config_table/ ";
	NCTARGS+="--nct ${nctfilename}";
else
	NCT_TAG+="-e /NCTFILE/d ";
	NCT_TAG+="-e s/NCTTYPE/data/ ";
fi;

# SOS_TAG: XXX: recovery is yet to be implemented.
#
SOS_TAG+="-e /SOSFILE/d ";
if [ "${sosfile}" != "" ]; then
	cp2local sosfile "${BL_DIR}/${sosfilename}";
	SOSARGS+="--applet ${sosfilename} ";
else
	SOS_TAG+="-e /filename=recovery.img/d ";
fi;

# NVC_TAG:== MB2
#
if [ "${tegraboot}" != "" ]; then
	cp2local tegraboot "${BL_DIR}/${tegrabootname}";
	NVC_TAG+="-e s/NXC/NVC/ ";
	NVC_TAG+="-e s/MB2NAME/mb2/ ";
	NVC_TAG+="-e s/type=data\s\+#TEGRABOOT/type=bootloader/ ";
	NVC_TAG+="-e s/NVCTYPE/bootloader/ ";
	NVC_TAG+="-e s/MB2TYPE/mb2_bootloader/ ";
	NVC_TAG+="-e s/#filename=nvtboot.bin/filename=${tegrabootname}/ ";
	NVC_TAG+="-e s/NVCFILE/${tegrabootname}/ ";
	NVC_TAG+="-e s/MB2FILE/${tegrabootname}/ ";
else
	NVC_TAG+="-e s/NVCTYPE/data/ ";
	NVC_TAG+="-e s/MB2TYPE/data/ ";
	NVC_TAG+="-e /NVCFILE/d ";
	NVC_TAG+="-e /MB2FILE/d ";
	NVC_TAG+="-e /filename=nvtboot.bin/d ";
fi;

# MB2BL_TAG:== tboot_recovery
#
if [ "${mb2blfile}" != "" ]; then
	cp2local mb2blfile "${BL_DIR}/${mb2blfilename}";
	if [ "${BINSARGS}" != "" ]; then
		BINSARGS+="mb2_bootloader ${mb2blfilename}; ";
	fi;
fi;

# MPB_TAG:
#
if [ "${mtspreboot}" != "" ]; then
	cp2local mtspreboot "${BL_DIR}/${mtsprebootname}";
	MPB_TAG+="-e s/MXB/MPB/ ";
	MPB_TAG+="-e s/MPBNAME/mts-preboot/ ";
	MPB_TAG+="-e s/type=data\s\+#MTSPREBOOT/type=mts_preboot/ ";
	MPB_TAG+="-e s/MPBTYPE/mts_preboot/ ";
	MPB_TAG+="-e s/#filename=mts_preboot_si/filename=${mtsprebootname}/ ";
	MPB_TAG+="-e s/MPBFILE/${mtsprebootname}/ ";
	if [ "${BINSARGS}" != "" ]; then
		BINSARGS+="mts_preboot ${mtsprebootname}; ";
	else
		MTSARGS+="--preboot ${mtsprebootname} ";
	fi;
else
	MPB_TAG+="-e s/MPBTYPE/data/ ";
	MPB_TAG+="-e /#filename=mts_preboot_si/d ";
	MPB_TAG+="-e /MPBFILE/d ";
fi;

# MBP_TAG:
#
if [ "${mts}" != "" ]; then
	cp2local mts "${BL_DIR}/${mtsname}";
	MBP_TAG+="-e s/MXP/MBP/ ";
	MBP_TAG+="-e s/MBPNAME/mts-bootpack/ ";
	MBP_TAG+="-e s/type=data\s\+#MTSBOOTPACK/type=mts_bootpack/ ";
	MBP_TAG+="-e s/MBPTYPE/mts_bootpack/ ";
	MBP_TAG+="-e s/#filename=mts_si/filename=${mtsname}/ ";
	MBP_TAG+="-e s/MBPFILE/${mtsname}/ ";
	if [ "${BINSARGS}" != "" ]; then
		BINSARGS+="mts_bootpack ${mtsname}; ";
	else
		MTSARGS+="--bootpack ${mtsname} ";
	fi;
else
	MBP_TAG+="-e s/MBPTYPE/data/ ";
	MBP_TAG+="-e /#filename=mts_si/d ";
	MBP_TAG+="-e /MBPFILE/d ";
fi;

# MB1_TAG:
#
if [ "${mb1file}" != "" ]; then
	cp2local mb1file "${BL_DIR}/${mb1filename}";
	MB1_TAG+="-e s/MB1NAME/mb1/ ";
	MB1_TAG+="-e s/MB1TYPE/mb1_bootloader/ ";
	MB1_TAG+="-e s/MB1FILE/${mb1filename}/ ";
else
	MB1_TAG+="-e s/MB1TYPE/data/ ";
	MB1_TAG+="-e /MB1FILE/d ";
fi;

# BPF_TAG:
#
if [ "${bpffile}" != "" ]; then
	cp2local bpffile "${BL_DIR}/${bpffilename}";
	BPF_TAG+="-e s/BXF/BPF/ ";
	BPF_TAG+="-e s/BPFNAME/bpmp-fw/ ";
	BPF_TAG+="-e s/BPFFILE/${bpffilename}/ ";
	BPF_TAG+="-e s/BPFSIGN/true/ ";
	if [ "${BINSARGS}" != "" ]; then
		BINSARGS+="bpmp_fw ${bpffilename}; ";
	fi;
else
	BPF_TAG+="-e /BPFFILE/d ";
	BPF_TAG+="-e s/BPFSIGN/false/ ";
fi;

# BPFDTB_TAG:
if [ "${bpfdtbfile}" != "" ]; then
	cp2local bpfdtbfile "${BL_DIR}/${bpfdtbfilename}";
	BPFDTB_TAG+="-e s/BPFDTB-NAME/bpmp-fw-dtb/ ";
	BPFDTB_TAG+="-e s/BPFDTB-FILE/${bpfdtbfilename}/ ";
	BPFDTB_TAG+="-e s/BPMPDTB-SIGN/true/ ";
	BPFDTB_TAG+="-e s/BPMPDTB/${bpfdtbfilename}/ ";			#COMPAT
	if [ "${BINSARGS}" != "" ]; then
		BINSARGS+="bpmp_fw_dtb ${bpfdtbfilename}; ";
	fi;
else
	BPFDTB_TAG+="-e /BPFDTB-FILE/d ";
	BPFDTB_TAG+="-e s/BPMPDTB-SIGN/false/ ";
fi;

# SCE_TAG:
if [ "${scefile}" != "" ]; then
	cp2local scefile "${BL_DIR}/${scefilename}";
	SCE_TAG+="-e s/SCENAME/sce-fw/ ";
	SCE_TAG+="-e s/SCESIGN/true/ ";
	SCE_TAG+="-e s/SCEFILE/${scefilename}/ ";
	SCE_TAG+="-e s/SCEFIRMWARE/${scefilename}/ ";			#COMPAT
else
	SCE_TAG+="-e s/SCESIGN/flase/ ";
	SCE_TAG+="-e /SCEFILE/d ";
fi;

# SPE_TAG:
if [ "${spefile}" != "" ]; then
	cp2local spefile "${BL_DIR}/${spefilename}";
	SPE_TAG+="-e s/SPENAME/spe-fw/ ";
	SPE_TAG+="-e s/SPETYPE/spe_fw/ ";
	SPE_TAG+="-e s/SPEFILE/${spefilename}/ ";
	SPE_TAG+="-e s/spe.bin/${spefilename}/ ";
else
	SPE_TAG+="-e s/SPETYPE/data/ ";
	SPE_TAG+="-e /SPEFILE/d ";
fi;

# WB0_TAG:
#
if [ "${wb0boot}" != "" ]; then
	cp2local wb0boot "${BL_DIR}/${wb0bootname}";
	WB0_TAG+="-e s/WX0/WB0/ ";
	WB0_TAG+="-e s/SC7NAME/sc7/ ";
	WB0_TAG+="-e s/WB0SIZE/20480/ ";
	WB0_TAG+="-e s/type=data\s\+#WB0BOOT/type=WB0/ ";
	WB0_TAG+="-e s/WB0TYPE/WB0/ ";
	WB0_TAG+="-e s/#filename=warmboot.bin/filename=${wb0bootname}/ ";
	WB0_TAG+="-e s/WB0FILE/${wb0bootname}/ ";
else
	WB0_TAG+="-e s/WB0TYPE/data/ ";
	WB0_TAG+="-e s/WB0SIZE/20480/ ";
	WB0_TAG+="-e /WB0FILE/d ";
	WB0_TAG+="-e /filename=warmboot.bin/d ";
fi;

# TOS_TAG:
#
if [ "${tosfile}" != "" ]; then
	cp2local tosfile "${BL_DIR}/${tosfilename}";
	TOS_TAG+="-e s/TXS/TOS/ ";
	TOS_TAG+="-e s/TOSNAME/secure-os/ ";
	TOS_TAG+="-e s/TOSFILE/${tosfilename}/ ";
	if [ "${BINSARGS}" != "" ]; then
		BINSARGS+="tlk ${tosfilename}; ";
	fi;
else
	TOS_TAG+="-e /TOSFILE/d ";
fi;

# EKS_TAG:
#
EKS_TAG+="-e s/EXS/EKS/ ";
if [ "${eksfile}" != "" ]; then
	cp2local eksfile "${BL_DIR}/${eksfilename}";
	EKS_TAG+="-e s/EKSFILE/${eksfilename}/ ";
	if [ "${BINSARGS}" != "" ]; then
		BINSARGS+="eks ${eksfilename}; ";
	fi;
else
	EKS_TAG+="-e /EKSFILE/d ";
fi;

# FB_TAG:
#
if [ "${fbfile}" != "" ]; then
	chsuffix fbfilebin ${fbfilename} "bin";
	fbfilexml="reserved_fb.xml";
	cp2local fbfile "${BL_DIR}/${fbfilename}";
	FB_TAG+="-e s/FBFILE/${fbfilebin}/ ";
	FB_TAG+="-e s/FX/FB/ ";
	FB_TAG+="-e s/FBNAME/fusebypass/ ";
	FB_TAG+="-e s/FBTYPE/fuse_bypass/ ";
	FB_TAG+="-e s/FBSIGN/true/ ";
	if [ "${flashappname}" = "tegraflash.py" ]; then
		FBARGS+="--fb ${fbfilebin} "
		FBARGS+="--cmd \"parse fusebypass ${fbfilename} ";
		FBARGS+="non-secure;flash;reboot\" ";
	fi;
else
	FB_TAG+="-e s/FBTYPE/data/ ";
	FB_TAG+="-e s/FBSIGN/false/ ";
	FB_TAG+="-e /FBFILE/d ";
	if [ "${flashappname}" = "tegraflash.py" ]; then
		FBARGS+="--cmd \"flash;reboot\" ";
	fi;
fi;

# DTB_TAG: Kernel DTB
#
if [ "${dtbfile}" != "" ]; then
	cp2local dtbfile "${BL_DIR}/${dtbfilename}";
	append_bootargs_to_dtb "${dtbfilename}";
	DTB_TAG+="-e s/DXB/DTB/ ";
	DTB_TAG+="-e s/KERNELDTB-NAME/kernel-dtb/ ";
	DTB_TAG+="-e s/#filename=tegra.dtb/filename=${dtbfilename}/ ";
	DTB_TAG+="-e s/DTBFILE/${dtbfilename}/ ";
	DTB_TAG+="-e s/KERNELDTB-FILE/${dtbfilename}/ ";
	DTB_TAG+="-e s/KERNEL-DTB/${dtbfilename}/ ";			#COMPAT
	if [ "${flashappname}" = "tegraflash.py" ]; then
		if [ "${tegraid}" != "0x18" ]; then
			DTBARGS+="--bldtb ${dtbfilename} ";
		fi
	else
		DTBARGS+="--dtbfile ${dtbfilename} ";
	fi;
else
	DTB_TAG+="-e /tegra.dtb/d ";
	DTB_TAG+="-e /DTBFILE/d ";
	DTB_TAG+="-e /KERNELDTB-FILE/d ";
fi;

# APP_TAG: RootFS
#
localsysfile=system.img;
APP_TAG+="-e s/size=1073741824/size=${rootfssize}/ ";
APP_TAG+="-e s/APPSIZE/${rootfssize}/ ";
APP_TAG+="-e /recovery.img/d ";
if [ "${reuse_systemimg}" = "true" ]; then
	APP_TAG+="-e s/filename=system.img/filename=${localsysfile}/ ";
	APP_TAG+="-e s/APPFILE/${localsysfile}/ ";
	if [ "${read_part_name}" == "" ]; then
		echo "Reusing existing ${localsysfile}... ";
		if [ ! -e "${localsysfile}" ]; then
			echo "file does not exist.";
			exit 1;
		fi;
		echo "done.";
	fi;
elif [ "${rootdev_type}" = "internal" ]; then
	APP_TAG+="-e s/filename=system.img/filename=${localsysfile}/ ";
	APP_TAG+="-e s/APPFILE/${localsysfile}/ ";
	if [ "${target_partname}" = "" -o "${target_partname}" = "APP" ]; then
		build_fsimg "$localsysfile" "$fillpat" \
		    "$rootfssize" "$rootfs_type" "$rootfs_dir";
	fi;
elif [ "${rootdev_type}" = "network" -o "${rootdev_type}" = "external" -a \
	${using_uboot} -eq 1 ]; then
	echo -n "generating /boot/extlinux/extlinux.conf files... ";
	APP_TAG+="-e s/filename=system.img/filename=${localsysfile}/ ";
	APP_TAG+="-e s/APPFILE/${localsysfile}/ ";
	NFSCONV="-e s/NFSARGS/${nfsiargs}/ ";
	NFSCONV+="-e s%NFSROOT%${nfsroot}% ";
	sed ${NFSCONV} < "${rootfs_dir}/boot/extlinux/extlinux.conf" > ./extlinux.conf;
	mv ./extlinux.conf "${rootfs_dir}/boot/extlinux/extlinux.conf";
	echo "done.";

	echo "generating system.img for booting... ";
	tmpdir=`mktemp -d`;
	mkdir -p "${tmpdir}/boot/extlinux" > /dev/null 2>&1;
	cp -f "${rootfs_dir}/boot/extlinux/extlinux.conf" "${tmpdir}/boot/extlinux" > /dev/null 2>&1;
	cp -f "${kernel_fs}" "${tmpdir}/boot" > /dev/null 2>&1;
	cp -f "${dtbfile}" "${tmpdir}/boot" > /dev/null 2>&1;
	cp -f initrd "${tmpdir}/boot" > /dev/null 2>&1;
	build_fsimg "$localsysfile" "$fillpat" \
		    "$rootfssize" "$rootfs_type" "$tmpdir";
else
	APP_TAG+="-e /filename=system.img/d ";
	APP_TAG+="-e /system.img/d ";
	APP_TAG+="-e /APPFILE/d ";
fi;

# TBC_TAG:== EBT
#
if [ "${tbcfile}" != "" ]; then
	cp2local tbcfile "${BL_DIR}/${tbcfilename}";
	TBC_TAG+="-e s/TXC/TBC/ ";
	TBC_TAG+="-e s/TBCNAME/cpu-bootloader/ ";
	TBC_TAG+="-e s/TBCTYPE/bootloader/ ";
	TBC_TAG+="-e s/TBCFILE/${tbcfilename}/ ";
else
	TBC_TAG+="-e s/TBCTYPE/data/ ";
	TBC_TAG+="-e /TBCFILE/d ";
fi;

# TBCDTB_TAG:== Bootloader DTB
#
if [ "${tbcdtbfile}" != "" ]; then
	cp2local tbcdtbfile "${BL_DIR}/${tbcdtbfilename}";
	append_bootargs_to_dtb "${tbcdtbfilename}";
	TBCDTB_TAG+="-e s/TBCDTB-NAME/bootloader-dtb/ ";
	TBCDTB_TAG+="-e s/TBCDTB-FILE/${tbcdtbfilename}/ ";
	if [ "${BINSARGS}" != "" ]; then
		BINSARGS+="bootloader_dtb ${tbcdtbfilename}; ";
	fi;
else
	TBCDTB_TAG+="-e s/TBCTYPE/data/ ";
	TBCDTB_TAG+="-e /TBCDTB-FILE/d ";
fi;

# EFI_TAG: Minimum FAT32 partition size is 64MiB (== 1 FAT cluster)
#
localefifile=efi.img;
efifs_size=$(( 64 * 1024 * 1024 ));
EFI_TAG+="-e s/size=67108864\s\+#EFISIZE/size=${efifs_size}/ ";
EFI_TAG+="-e s/EFISIZE/${efifs_size}/ ";
if [ "${bootloadername}" = "uefi.bin" ]; then
	build_fsimg $localefifile "" $efifs_size "FAT32" "";
	EFI_TAG+="-e s/EXI/EFI/ ";
	EFI_TAG+="-e s/#filename=efi.img/filename=${localefifile}/ ";
	EFI_TAG+="-e s/EFIFILE/${localefifile}/ ";
else
	EFI_TAG+="-e /EFIFILE/d ";
fi;

# GPT_TAG: tag should created before cfg and actual img should be
#	   created after cfg.
#
localpptfile=ppt.img;
localsptfile=gpt.img;
if [ ! -z "${bootpartsize}" -a ! -z "${emmcsize}" ]; then
	bplmod=$(( ${bootpartlim} % ${devsectsize} ));
	if [ ${bplmod} -ne 0 ]; then
		echo "Error: Boot partition limit is not modulo ${devsectsize}";
		exit 1;
	fi;
	bpsmod=$(( ${bootpartsize} % ${devsectsize} ));
	if [ ${bpsmod} -ne 0 ]; then
		echo "Error: Boot partition size is not modulo ${devsectsize}";
		exit 1;
	fi;
	gptsize=$(( ${bootpartlim} - ${bootpartsize} ));
	if [ ${gptsize} -lt ${devsectsize} ]; then
		echo "Error: No space for primary GPT.";
		exit 1;
	fi;
	GPT_TAG+="-e s/size=2097152\s\+#BCTSIZE/size=${bootpartsize}/ ";
	GPT_TAG+="-e s/size=8388608\s\+#PPTSIZE/size=${gptsize}/ ";
	GPT_TAG+="-e s/PPTSIZE/${gptsize}/ ";
	GPT_TAG+="-e s/#filename=ppt.img/filename=${localpptfile}/ ";
	GPT_TAG+="-e s/#filename=spt.img/filename=${localsptfile}/ ";
else
	GPT_TAG+="-e s/PPTSIZE/16896/ ";
fi;

# CFG:
#
if [[ ${cfgfile} =~ \.xml$ ]]; then
	localcfgfile=flash.xml;
else
	localcfgfile=flash.cfg;
fi;
echo -n "copying cfgfile(${cfgfile}) to ${localcfgfile}... ";
if [ "${BINSARGS}" != "" ]; then
	# Close BINSARGS before get used for the first time.
	BINSARGS+="\"";
	BINSCONV+="-e s/\"[[:space:]]*/\"/ ";
	BINSCONV+="-e s/\;[[:space:]]*\"/\"/ ";
	BINSARGS=`echo "${BINSARGS}" | sed ${BINSCONV}`;
fi;
CFGCONV+="${EBT_TAG} ";
CFGCONV+="${LNX_TAG} ";
CFGCONV+="${SOS_TAG} ";
CFGCONV+="${NCT_TAG} ";
CFGCONV+="${NVC_TAG} ";
CFGCONV+="${MB2BL_TAG} ";
CFGCONV+="${MPB_TAG} ";
CFGCONV+="${MBP_TAG} ";
CFGCONV+="${MB1_TAG} ";
CFGCONV+="${BPF_TAG} ";
CFGCONV+="${BPFDTB_TAG} ";
CFGCONV+="${SCE_TAG} ";
CFGCONV+="${SPE_TAG} ";
CFGCONV+="${TOS_TAG} ";
CFGCONV+="${EKS_TAG} ";
CFGCONV+="${FB_TAG}  ";
CFGCONV+="${WB0_TAG} ";
CFGCONV+="${APP_TAG} ";
CFGCONV+="${EFI_TAG} ";
CFGCONV+="${DTB_TAG} ";
CFGCONV+="${TBC_TAG} ";
CFGCONV+="${TBCDTB_TAG} ";
CFGCONV+="${GPT_TAG} ";
cat ${cfgfile} | sed ${CFGCONV} > ${localcfgfile}; chkerr;

# GPT:
# mkgpt need to update as per new flash_t186_l4t.xml,
# currently skipping mkgpt as gpt partition is taken care by tegraflash.
if [ ! -z "${bootpartsize}" -a ! -z "${emmcsize}" -a \
    "${tegraid}" != "0x18" ]; then
	echo "creating gpt(${localpptfile})... ";
	MKGPTOPTS="-c ${localcfgfile} -P ${localpptfile} ";
	MKGPTOPTS+="-t ${emmcsize} -b ${bootpartsize} -s 4KiB ";
	MKGPTOPTS+="-a GPT -v GP1 ";
	MKGPTOPTS+="-V ${MKGPTCMD} ";
	./mkgpt ${MKGPTOPTS};
	chkerr "creating gpt(${localpptfile}) failed.";
fi;

# FLASH:
#
cp2local flasher	"${BL_DIR}/${flashername}";
cp2local flashapp	"${BL_DIR}/${flashappname}";

if [ "${target_partname}" != "" ]; then
	validatePartID target_partid target_partname $target_partname $localcfgfile;
	tmp_updateid="${target_partid}:${target_partname}";
	sigheader=0;
	sigext=bin;
	case ${target_partname} in
	BCT) target_partfile="${bctfilename}";
	     FLASHARGS="${BCT} ${target_partfile} --updatebct SDRAM ";
	     ;;
	mb2) target_partfile="nvtboot.bin";
	     need_sign=1;
	     sigheader=1;
	     ;;
	bpmp-fw)
	     target_partfile="${bpffile}";
	     need_sign=1;
	     sigheader=1;
	     ;;
	bpmp-fw-dtb)
	     target_partfile="${bpfdtbfile}";
	     need_sign=1;
	     sigheader=1;
	     sigext=dtb;
	     ;;
	PPT) target_partfile="${localpptfile}"; ;;
	EBT) target_partfile="${bootloadername}"; need_sign=1; ;;
	cpu-bootloader)
	     target_partfile="${tbcfilename}";
	     need_sign=1;
	     sigheader=1;
	     ;;
	secure-os)
	     target_partfile="${tosfilename}";
	     need_sign=1;
	     sigheader=1;
	     sigext=img;
	     ;;
	eks) target_partfile="${eksfilename}";
	     need_sign=1;
	     sigheader=1;
	     sigext=img;
	     ;;
	LNX) target_partfile="${localbootfile}";
	     pre_cmds="write DTB ${dtbfilename}; ";
	     ;;
	kernel)
	     target_partfile="${localbootfile}";
	     pre_cmds="write kernel-dtb ${dtbfilename}; ";
	     ;;
	kernel-dtb) target_partfile="${dtbfilename}"; ;;
	NCT) target_partfile="${nctfilename}"; ;;
	SOS) target_partfile="${sosfilename}"; ;;
	NVC) target_partfile="${tegrabootname}"; need_sign=1; ;;
	MPB) target_partfile="${mtsprebootname}"; ;;
	MBP) target_partfile="${mtsname}"; ;;
	BPF) target_partfile="${bpffilename}"; ;;
	APP) target_partfile="${localsysfile}"; ;;
	DTB) target_partfile="${dtbfilename}"; ;;
	EFI) target_partfile="${localefifile}"; ;;
	TOS) target_partfile="${tosfilename}"; ;;
	EKS) target_partfile="${eksfilename}"; ;;
	FB)  target_partfile="${fbfilename}"; ;;
	WB0) target_partfile="${wb0bootname}"; ;;
	GPT) target_partfile="${localsptfile}"; ;;
	spe-fw)
	     target_partfile="${spefilename}";
	     need_sign=1;
	     sigheader=1;
	     ;;
	*)   echo "*** Update ${tmp_updateid} is not supported. ***";
	     exit 1; ;;
	esac;
	if [ "${read_part_name}" != "" ]; then
		target_partfile="${read_part_name}";
		echo "*** Reading ${tmp_updateid} and storing to ${target_partfile} ***";
	else
		echo "*** Updating ${tmp_updateid} with ${target_partfile} ***";
	fi;
	if [ "${FLASHARGS}" = "" ]; then
		FLASHARGS+=" --bl ${flashername} ${DTBARGS} ";
		FLASHARGS+=" --chip ${tegraid} --applet ${sosfilename} ";
	fi;

	if [ ${need_sign} -eq 1 ]; then
		pf_dir="$(dirname "${target_partfile}")";
		pf_fn="$(basename "${target_partfile}")";
		if [ ${sigheader} -eq 1 ]; then
			sighdr="_sigheader.${sigext}.encrypt";
			target_partfile=`echo "${pf_fn}" | awk -F '.' '{print $1}'`;
			target_partfile="${pf_dir}/signed/${target_partfile}${sighdr}";
		else
			target_partfile="${pf_dir}/signed/${pf_fn}.encrypt";
		fi;
		FLASHARGS+=" --cfg ${localcfgfile} ";
		FLASHARGS+=" ${BCT} ${bctfilename} ";
		pre_cmds+="sign; ";
	fi
	FLASHARGS+="$BCT ${bctfilename} ";
	FLASHARGS+="${BCTARGS} ";
	FLASHARGS+="--cfg  ${localcfgfile} ${BINSARGS} ";
	FLASHARGS+=" --cmd \"";
	FLASHARGS+="${pre_cmds}";
	if [ "${read_part_name}" != "" ]; then
		FLASHARGS+="read ${target_partname} ${target_partfile};\"";
	else
		FLASHARGS+="write ${target_partname} ${target_partfile};\"";
	fi
	echo "./${flashappname} ${FLASHARGS}";
	cmd="./${flashappname} ${FLASHARGS}";
	eval ${cmd};
	chkerr "Failed to flash/read ${target_board}.";
	if [ "${read_part_name}" != "" ]; then
		echo "*** The ${tmp_updateid} has been read successfully. ***";
		if [ "${target_partname}" = "APP" -a -x mksparse ]; then
			echo -e "\tConverting RAW image to Sparse image... ";
			mv -f ${target_partfile} ${target_partfile}.raw;
			./mksparse -v --fillpattern=0 ${target_partfile}.raw ${target_partfile};
		fi;
	else
		echo "*** The ${tmp_updateid} has been updated successfully. ***";
	fi;
	exit 0;
fi;

if [ -f odmsign.func ]; then
	source odmsign.func;
	odmsign;
	if [ $? -ne 0 ]; then
		exit 1;
	fi;
fi;

FLASHARGS+="--bl ${flashername} ${BCT} ${bctfilename} ";
FLASHARGS+="--odmdata ${odmdata} ";
FLASHARGS+="${DTBARGS}${MTSARGS}${SOSARGS}${NCTARGS}${FBARGS} ";
if [ "${flashappname}" = "tegraflash.py" ]; then
	FLASHARGS+="--cfg ${localcfgfile} ";
	FLASHARGS+="--chip ${tegraid} ";
	FLASHARGS+="${BCTARGS} ";
	FLASHARGS+="${BINSARGS} ";
	FLASHARGS+="${SKIPUID} ";
else
	FLASHARGS+="--configfile ${localcfgfile} ";
	FLASHARGS+="--setbct --create --wait -s 0 --go ";
fi;
flashcmd="./${flashappname} ${FLASHARGS}";
echo "${flashcmd}";
flashcmdfile="${BL_DIR}/flashcmd.txt";
echo "saving flash command in ${flashcmdfile}";
echo "${flashcmd}" | tee "${flashcmdfile}";

if [ ${no_flash} -ne 0 ]; then
	echo "*** no-flash flag enabled. Exiting now... *** ";
	exit 0;
fi;

echo "*** Flashing target device started. ***"
eval "${flashcmd}";
chkerr "Failed flashing ${target_board}.";
echo "*** The target ${target_board} has been flashed successfully. ***"
if [ "${rootdev_type}" = "internal" ]; then
	echo "Reset the board to boot from internal eMMC.";
elif [ "${rootdev_type}" = "network" ]; then
	if [ "${nfsroot}" != "" ]; then
		echo -n "Make target nfsroot(${nfsroot}) exported ";
		echo "on the network and reset the board to boot";
	else
		echo -n "Make the target nfsroot exported on the ";
		echo -n "network, configure your own DHCP server ";
		echo -n "with \"option-root=<nfsroot export path>;\" ";
		echo "properly and reset the board to boot";
	fi;
else
	echo -n "Make the target filesystem available to the device ";
	echo -n "and reset the board to boot from external ";
	echo "${target_rootdev}.";
fi;
echo;
exit 0;

# vi: ts=8 sw=8 noexpandtab
