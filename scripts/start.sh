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

############
# This script and several scripts it directly calls assumes it is running inside a Vertex Custom Training cluster [1].
# 
#   By default the training script to execute after the cluster is setup is train.sh. 
#   You can provide your own with $1.
#
# IMPORTANT: It is expecting four environmental variables:
#
#   CLUSTER_SPEC  - Descriptor of the cluster. See doc for an example [2] 
#                   The code-blocks are contingent on having something to so, without a CLUSTER_SPEC to trigger,
#                   the code will simply EXIT but will not have done anything.
#
#   AIP_MODEL_DIR           - AI Platform GCS Path for saving model artifacts, of the form gs://<bucket>/<base-output-path>/model/
#   AIP_CHECKPOINT_DIR      - AI Platform GCS Path for saving checkpoints, of the form gs://<bucket>/<base-output-path>/checkpoints/
#   AIP_TENSORBOARD_LOG_DIR - AI Platform GCS Path for saving TensorBoard logs, of the form gs://<bucket>/<base-output-path>/logs/
#
# Two file-based flags is set for convenience for other scripts:
#
#   .is_vertex_primary - The primary node will have this file.
#   .is_multinode      - Indicates a multiple node cluster. 
# 
# 
# ${NODE_FILE}   holds the Hostnames of worker nodes.
# ${DS_HOSTFILE} holds the name of the Deepspeed hostfile.
#   The hostfile is non-empty when there are multiple nodes (i.e. the file .is_multinode exists)
# 
#
# [1] https://cloud.google.com/vertex-ai/docs/training/overview
# [2] https://cloud.google.com/vertex-ai/docs/training/distributed-training#cluster-spec-example
# [3] https://cloud.google.com/vertex-ai/docs/training/code-requirements
#
#
TRAIN_SCRIPT="train.sh"
if [[ -n "$1" ]];             then TRAIN_SCRIPT=$1; fi

if [[ -z ${NODES_FILE} ]];    then NODES_FILE="nodes"; fi
if [[ -z ${DS_HOSTFILE} ]];   then DS_HOSTFILE="hostfile"; fi
if [[ -z ${IS_PRIMARY} ]];    then IS_PRIMARY=".is_vertex_primary"; fi
if [[ -z ${IS_MULTINODE} ]];  then IS_MULTINODE=".is_multinode"; fi

#
# Maps the Vertex CustomJob GCS locations to the local FUSE dir supported by Vertex.
# 
if [[ -z ${OUTPUT_FOLDER} ]]; then OUTPUT_FOLDER=$(echo ${AIP_MODEL_DIR} | sed -E -e 's|^gs:/|/gcs|' -e 's|/$||'); fi
if [[ -z ${CHKPTS_FOLDER} ]]; then CHKPTS_FOLDER=$(echo ${AIP_CHECKPOINT_DIR} | sed -E -e 's|^gs:/|/gcs|' -e 's|/$||'); fi
if [[ -z ${JOBLOG_FOLDER} ]]; then JOBLOG_FOLDER=$(echo ${AIP_TENSORBOARD_LOG_DIR} | sed -E -e 's|^gs:/|/gcs|' -e 's|/$||'); fi
if [ ! -d "/gcs" ]; then # Create the folder under test conditions
    sudo mkdir -p ${OUTPUT_FOLDER}; sudo chmod 777 -R ${OUTPUT_FOLDER}
    sudo mkdir -p ${CHKPTS_FOLDER}; sudo chmod 777 -R ${CHKPTS_FOLDER}
    sudo mkdir -p ${JOBLOG_FOLDER}; sudo chmod 777 -R ${JOBLOG_FOLDER}
fi

# Checking the account running this
echo Service Account: $(gcloud config get account)

# Use docker run --rm -e TESTING="true" -e AIP_MODEL_DIR="gs://gkcng-west1-test/" $IMAGE_URI to test. 
# This is such that we can test a sample CLUSTER_SPEC; JSON string arg fails with docker run.
if [ -n "${TESTING}" ]; then
    echo "**** TESTING ****"
    echo "* Testing an example CLUSTER_SPEC and GCS $AIP_MODEL_DIR, ssh_setup not executed."
    echo "*"
    CLUSTER_SPEC='{"cluster":{"workerpool0":["workerpool0-9b6f87bcee-0:2222"],"workerpool1":["workerpool1-9b6f87bcee-0:2222","workerpool1-9b6f87bcee-1:2222"]},"task":{"type":"workerpool0","index":0}}'
    sudo mkdir -p ${OUTPUT_FOLDER} # If ran under Vertex GCS is mounted at /gcs/
    sudo chmod 777 -R ${OUTPUT_FOLDER}
fi

####
# Process the CLUSTER_SPEC
#
# Enumerates a list of nodes to setup ssh access
# Mark the primary node with the existence a dot file.
#
rm -f ${NODES_FILE}
if [ -n "$CLUSTER_SPEC" ]; then
    echo "Parsing Cluster Spec..."
    PRIMARY=$(echo $CLUSTER_SPEC | jq -r ".cluster.workerpool0[]")
    echo $PRIMARY >> $NODES_FILE
    echo $CLUSTER_SPEC | jq -r ".cluster.workerpool1[]?" >> $NODES_FILE
    node_index=$(echo $CLUSTER_SPEC | jq -r '.task | {type, index} | join(" ")')
    if [ "workerpool0 0" == "$node_index" ]; then touch ${IS_PRIMARY}; fi
    if [[ $(wc -l <${NODES_FILE}) -gt 1 ]]; then touch ${IS_MULTINODE}; fi
    echo "Generated file ${NODES_FILE}"
    cat $NODES_FILE
fi

####
# Perform any node set up here 
# Create and include your own node_setup.sh if needed.
#
if [ -f "node_setup.sh" ]; then 
    bash node_setup.sh 
fi

####
# Multi-node only: Set up primary to workers SSH access
#
# For workers this scripts ends with sshd in the foreground, i.e. blocking.
# For primary this script returns here.
#
if [[ -f ${IS_MULTINODE} && -z "${TESTING}" ]]; then
    bash ./ssh_setup.sh ${NODES_FILE} ${IS_PRIMARY}
fi

####
# Code to execute on primary
# If we have multiple nodes, this will generate a hostfile for Deepspeed
#
if [ -f "${IS_PRIMARY}" ]; then 

    if [ -f ${IS_MULTINODE} ]; then
        echo "Generating ${DS_HOSTFILE}..."    
        bash ./gen_hostfile.sh ${NODES_FILE} ${DS_HOSTFILE} # Results stored in ${DS_HOSTFILE}
        echo "Generated:" ${DS_HOSTFILE}
        cat ${DS_HOSTFILE}
        if [ -n "${TESTING}" ]; then rm -f ${DS_HOSTFILE}; echo "Clean up the test."; fi # Clean up - removing the generated file.
    fi
    
    if [ -f "${TRAIN_SCRIPT}" ]; then 
        
        ################
        # Put your Deepspeed training code in train.sh
        ################
        bash ${TRAIN_SCRIPT} "${DS_HOSTFILE}" "${IS_MULTINODE}" "${OUTPUT_FOLDER}" "${CHKPTS_FOLDER}" "${JOBLOG_FOLDER}"

        if [ -n "${TESTING}" ]; then bash ./to_gcs.sh ${OUTPUT_FOLDER} ${AIP_MODEL_DIR}; fi    
    fi    
    
fi
