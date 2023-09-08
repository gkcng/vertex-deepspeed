#!/bin/bash

NODES_FILE=$1
if [ -z ${NODES_FILE} ]; then
    NODES_FILE=nodes
fi

DS_HOSTFILE=$2
if [ -z ${DS_HOSTFILE} ]; then
    DS_HOSTFILE=hostfile
fi

rm -f hostfile
while read wkr; do
    HOST=$(echo "$wkr" | grep -o "^[^:]\+")
    GPUS=$(ssh -n ${HOST} 'nvidia-smi -L | wc -l' || echo 0)
    echo "${HOST} has ${GPUS} accelerators"
    echo "${HOST} slots=${GPUS}" >> ${DS_HOSTFILE}
done < $NODES_FILE
