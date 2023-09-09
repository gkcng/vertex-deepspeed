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

nvidia-smi

ds_report

if [ -f ${DS_HOSTFILE} ]; then 
    echo "HOSTFILE:"
    cat $DS_HOSTFILE
    echo "HOSTFILE FLAG:" $HOSTFILE_FLAG
else
    echo "No hostfile"
fi

if [ -n "${JOBLOG_FOLDER}" ]; then

    OTHER_OPTIONS=${OTHER_OPTIONS}" \
    --enable_tensorboard \
    --tensorboard_path=${JOBLOG_FOLDER}"

fi

#
# This is taken from https://github.com/microsoft/DeepSpeedExamples/blob/master/applications/DeepSpeed-Chat/training/step1_supervised_finetuning/training_scripts/llama2/run_llama2_7b.sh
#
# Original settings was for SFT with 4 datasets, the script goes through
#  --data_path Dahoas/rm-static Dahoas/full-hh-rlhf Dahoas/synthetic-instruct-gptj-pairwise yitingxie/rlhf-reward-datasets \
#  --data_split 2,4,4 \
#  --model_name_or_path meta-llama/Llama-2-7b-hf \
# 
# The remaining variables are expected to be provided when the CustomJob is configured:
#
# "container_spec": {
#     "env": [                
#        {"name": "MODEL_PATH", "value": "facebook/opt-125m"},                        
#        {"name": "DATA_PATHS", "value": "Dahoas/synthetic-instruct-gptj-pairwise"},                        
#        {"name": "DATA_SPLIT", "value": "1,4,5"},
#        {"name": "ZERO_STAGE", "value": "3"},
#        {"name": "PER_DEVICE_BATCH_SIZE", "value": "4"},
#     ]
#     
deepspeed ${HOSTFILE_FLAG} \
   main.py \
   --data_path $DATA_PATHS \
   --data_split $DATA_SPLIT \
   --model_name_or_path $MODEL_PATH \
   --per_device_train_batch_size $PER_DEVICE_BATCH_SIZE \
   --per_device_eval_batch_size $PER_DEVICE_BATCH_SIZE \
   --max_seq_len 512 \
   --learning_rate 9.65e-6 \
   --weight_decay 0. \
   --num_train_epochs 1  \
   --gradient_accumulation_steps 1 \
   --lr_scheduler_type cosine \
   --num_warmup_steps 0 \
   --seed 1234 \
   --gradient_checkpointing \
   --zero_stage $ZERO_STAGE \
   --deepspeed \
   --output_dir ${OUTPUT_FOLDER} \
   --print_loss \
   ${OTHER_OPTIONS}
