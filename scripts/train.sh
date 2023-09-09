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
# train.sh - called from start.sh
# 
DS_HOSTFILE=$1    # Filename of the created Deepspeed hostfile
IS_MULTINODE=$2   # Filename of the is multinode flag. if [ -f "${IS_MULTINODE}"]; ...

OUTPUT_FOLDER=$3  # Local output folder
CHKPTS_FOLDER=$4  # Local checkpoints folder
JOBLOG_FOLDER=$5  # Local logs folder

if [[ -f ${IS_MULTINODE} && -f ${DS_HOSTFILE} && $(wc -l <${DS_HOSTFILE}) -gt 1 ]]; then
   HOSTFILE_FLAG="--hostfile=${DS_HOSTFILE}"
fi

mkdir -p ${OUTPUT_FOLDER}

##############################
# Put your training code here
##############################