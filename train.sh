#!/bin/bash

#
# Free to delete
# For debugging nodes' environments in realtime, especially useful with 
# custom job .run(... enable_web_access=True, ...) 
#
if [[ -z "${TESTING}" ]]; then
    echo "Entering Sleep..."
    sleep 3600
fi

#
# train.sh
# 
DS_HOSTFILE=$1    # Filename of the created Deepspeed hostfile
IS_MULTINODE=$2   # Filename of the is multinode flag. if [ -f "${IS_MULTINODE}"]; ...
OUTPUT_FOLDER=$3  # Local output folder

mkdir -p ${OUTPUT_FOLDER}

##############################
# Put your training code here
##############################