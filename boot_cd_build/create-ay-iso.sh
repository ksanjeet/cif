#!/bin/bash
#
# Author: Jochen Schaefer <jochen.schaefer@suse.com>
#         Frieder Schmidt <frieder.schmidt@microfocus.com>
#         Martin Weiss    <martin.weiss@suse.com>
#
# copyright (c) Novell Deutschland GmbH, 2001-2020. All rights reserved.
# GNU Public License
#
# create-ay-cd-v01.sh 					27 Apr 2013
# change copy to move for backup			25 Feb 2019
# add efi boot via grub2				13 May 2019
# efi adjustments and standardization			 6 May 2020
# adding -follow on to allow /data/boot_cd_build linked	 8 May 2020
# EFI support conditinal on existence of /EFI directory	 5 Jun 2020


ARGV=$@
debug=0


function debug()
{
	if [ "$debug" == "1" ];then
		set -x
	else
		set +x
	fi
}


function usage()
{
	cat <<HERE

usage $0
	--customer	# customer name; will be part of the name of the ISO file that is created
			# default: $CUSTOMER
	--name		# complete name of the ISO file that is created (should end in ".iso")
			# default: $ISO_NAME
	--isodir	# directory where the iso file is created
			# default: $ISO_DIR
	--tempdir	# directory for temporary files required for EFI support
			# default: $TEMP_DIR
	--workdir	# directory where the directories EFI, boot, grub, and kernel are located
			# default: $WORK_DIR
	--debug         # optional - increases verbosity
	--help		# this help


        example1: $0
        example2: $0 --customer $CUSTOMER --name $ISO_NAME --isodir $ISO_DIR --tempdir $TEMP_DIR  --workdir $WORK_DIR --debug

HERE
	exit 1
}


function getopt()
{
	while [ $# -gt 0 ];do
		case $1 in --customer) CUSTOMER=$2;shift;;
			   --name) ISO_NAME=$2;shift;;
			   --isodir) ISO_DIR=$2;shift;;
			   --tempdir) TEMP_DIR=$2;shift;;
			   --workdir) WORK_DIR=$2;shift;;
			   --debug) debug=1;debug;;
			   *) usage;;
		esac
		shift
	done	

	if [ -n "$ISO_DIR" -a ! -d "$ISO_DIR" ]; then
		echo directory "$ISO_DIR" does not exists
		usage
	fi

	if [ -n "$TEMP_DIR" -a ! -d "$TEMP_DIR" ]; then
		echo directory "$TEMP_DIR" does not exists
		usage
	fi

	if [ -n "$WORK_DIR" -a ! -d "$WORK_DIR" ]; then
		echo directory "$WORK_DIR" does not exists
		usage
	fi
}


function set_vars()
{
	MY_DATE=$(date +%Y-%m-%d_%H%M)

	CUSTOMER=${CUSTOMER:="CIF"}
	ISO_DIR=${ISO_DIR:="/data/isos"}
	ISO_LABEL="AUTOYAST_$CUSTOMER"
	ISO_PREF=autoyast-$(tr A-Z a-z <<<$CUSTOMER)
	ISO_NAME=${ISO_NAME:="$ISO_PREF.iso"}
	ISO_NAME_COPIED=$ISO_NAME.$MY_DATE
	WORK_DIR=${WORK_DIR:="/data/boot_cd_build"}
	TEMP_DIR=${TEMP_DIR:="/tmp"}
}


function prepare_efi()
{
	EFI_IMAGE="/EFI/efiboot.img=$TEMP_DIR/efiboot.img"
	EFI_PARAM="-eltorito-alt-boot -e EFI/efiboot.img -no-emul-boot -append_partition 2 0xef $TEMP_DIR/efiboot.img"

	grub2-mkstandalone --format=x86_64-efi --output=$TEMP_DIR/bootx64.efi --locales="" --fonts="" \
	       		   "boot/grub/grub.cfg=$WORK_DIR/EFI/grub.cfg" --modules="efi_gop efi_uga all_video gzio gettext gfxterm gfxmenu png"
	dd if=/dev/zero of=$TEMP_DIR/efiboot.img bs=1M count=10 && mkfs.vfat $TEMP_DIR/efiboot.img \
	       		   && mmd -i $TEMP_DIR/efiboot.img efi efi/boot && mcopy -i $TEMP_DIR/efiboot.img $TEMP_DIR/bootx64.efi ::efi/boot/
}


function make_iso()
{
	test -f "$ISO_DIR/$ISO_NAME" && mv "$ISO_DIR/$ISO_NAME" $ISO_DIR/$ISO_NAME_COPIED
	
	xorriso \
	-follow on \
	-as mkisofs \
	-volid "$ISO_LABEL" \
	-full-iso9660-filenames \
	-J -joliet-long -l -R -rock \
	-no-emul-boot -boot-load-size 4 \
	-boot-info-table \
	-iso-level 4 \
	-b boot/grub/iso9660_stage1_5 -no-emul-boot -boot-load-size 4 -boot-info-table \
	${EFI_PARAM} \
	-output $ISO_DIR/$ISO_NAME \
 	--graft-points "$WORK_DIR" ${EFI_IMAGE}
}	

function print_info()
{
	cat <<HERE


You will find the IMAGE here: $ISO_DIR/$ISO_NAME

HERE
}


function clean_up()
{
	if [ -f ${TEMP_DIR}/efiboot.img ]; then rm ${TEMP_DIR}/efiboot.img ${TEMP_DIR}/bootx64.efi; fi
}


function main()
{
	clear
	cat <<HERE

	* * * * * * * *  Consulting Installation Framework (CIF) - $0  * * * * * * *

HERE
	getopt  $ARGV
	set_vars
	if [ -d ${WORK_DIR}/EFI ]; then prepare_efi; fi
	make_iso
	print_info
	clean_up
}

main

