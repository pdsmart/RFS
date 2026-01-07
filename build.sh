#!/bin/bash

ROOT_DIR=`pwd`
SW_DIR=${ROOT_DIR}/
PROCESS_MZF_FILES=0
if [ "$1" = '-m' ]; then
    PROCESS_MZF_FILES=1
fi

# Make sure cpmtools is compiled and available in the tools directory.
if [[ ! -f ${ROOT_DIR}/tools/cpmcp ]]; then
    cd ${ROOT_DIR}/cpmtools
    ./configure -prefix=${ROOT_DIR}/tools -libdir=${ROOT_DIR}/tools/lib -bindir=${ROOT_DIR}/tools
    make all
    make install
    cp ${ROOT_DIR}/config/diskdefs ${ROOT_DIR}/tools/share/
fi

# Update path to ensure we use our locally compiled tools.
export PATH=${ROOT_DIR}/tools:${PATH}

(
    cd $SW_DIR
    tools/assemble_rfs.sh
    if [ $? != 0 ]; then
    	echo "RFS assembly failed..."
    	exit 1
    fi
    tools/assemble_cpm.sh
    if [ $? != 0 ]; then
    	echo "CPM assembly failed..."
    	exit 1
    fi
    tools/assemble_roms.sh
    if [ $? != 0 ]; then
    	echo "ROMS assembly failed..."
    	exit 1
    fi
    
    # Only needed if the program source tree changes, takes too long to run on every build!
    if [[ ${PROCESS_MZF_FILES} -eq 1 ]]; then
    	tools/processMZFfiles.sh
    	if [ $? != 0 ]; then
    		echo "Failed to process MZF files into sectored variants...."
    		exit 1
    	fi
    fi

    tools/make_roms.sh
    if [ $? != 0 ]; then
    	echo "ROM disk assembly failed..."
    	exit 1
    fi
    tools/make_cpmdisks.sh
    if [ $? != 0 ]; then
    	echo "CPM disks assembly failed..."
    	exit 1
    fi
    tools/make_sdcard.sh
    if [ $? != 0 ]; then
    	echo "SD card assembly failed..."
    	exit 1
    fi
)
if [ $? != 0 ]; then
	exit 1
fi

echo "" 
echo "Program ROMS via TL866 or similar using command:"
echo "    minipro --infoic /dvlp/Projects/minipro/infoic.xml -p SST39SF040 -s -w roms/SFD700_256.bin"
echo "" 
echo "Done!"
