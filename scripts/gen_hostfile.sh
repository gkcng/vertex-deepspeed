#!/bin/bash
#
# Copyright 2023 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
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
