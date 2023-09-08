#!/bin/bash
 
########################
# Setting up Passwordless Authentication from primary to all workers (incl primary).
#      e.g ssh cmle-training-workerpool1-e57bb38b8c-0
#
# Multi-node only:
#      For workers this scripts ends with sshd in the foreground, i.e. blocking.
#      For primary this script exits when it is done.
#
# This script uses the path given in the env variable $AIP_MODEL_DIR
# and it takes on two arguments:
#
#     ./ssh_setup.sh ${NODES_FILE} ${IS_PRIMARY}
# 
#      NODES_FILE is the filename containing the hostname of the nodes
#      IS_PRIMARY is a filename. The file's existence will be tested with [ -f "${IS_PRIMARY}"] 
# 
echo "*****"
echo Setting up SSH
echo "*****"

if [ -z ${SSH_PORT+x} ]; then
    SSH_PORT=2222 # Do not change this
fi
    
NODES_FILE=$1
if [[ -z ${NODES_FILE} ]]; then
    NODES_FILE="nodes"
fi
touch $NODES_FILE

IS_PRIMARY=$2
if [[ -z ${IS_PRIMARY} ]]; then
    IS_PRIMARY=".is_vertex_primary" 
fi

####
# We need to set up the following on Worker:
# -rw-r--r-- 1 vertex vertex 1218 Sep  6 11:57 authorized_keys # For incoming logins
#
# and...
#
# We need to set up the following on Primary:
# -rw-r--r-- 1 vertex vertex 1218 Sep  6 11:57 authorized_keys # For incoming logins
# -rw-r--r-- 1 vertex vertex  369 Sep  6 11:21 config          # For outgoing logins
# -rw------- 1 vertex vertex 2655 Sep  6 11:11 id_rsa          # Private Key referenced in config                                                    
# -rw-r--r-- 1 vertex vertex  609 Sep  6 11:11 id_rsa.pub      # Public Key send to other servers
# -rw-r--r-- 1 vertex vertex 1678 Sep  6 11:34 known_hosts     # Use StrictHostKeyChecking no to avoid user input
#
if [ -f $NODES_FILE ]; then   
    
    ####
    # 1. Create & exchange public key
    #
    # Using the system provided AIP_MODEL_DIR to make a temporary key exchange config path
    # 
    # AIP_MODEL_DIR=gs://<bucket>/aiplatform-custom-job-2023-09-06-hh:mm:ss.SSS/model/
    # PUBKEY_LOC=gs://<bucket>/aiplatform-custom-job-2023-09-06-hh:mm:ss.SSS/config/primary
    #
    PUBKEY_LOC=$(echo $AIP_MODEL_DIR | sed -E 's|(.*)/model/|\1/|')config/primary

    if [ ! -f "${IS_PRIMARY}" ]; then
        ####
        # 2. [WORKER] Polling for Primary's public key
        #    
        echo "Registering Primary's public key..."        
        until gsutil ls "${PUBKEY_LOC}"; do
            echo "Waiting for primary's file..."
            sleep 2
        done
        gsutil cp ${PUBKEY_LOC} .
        
        ####
        # 3. [WORKER] Set up authorized keys so Primary can login
        # 
        mv primary .ssh/authorized_keys
        chmod 600 .ssh/authorized_keys
        # Copy the interactive environment
        env > .ssh/environment

        ####
        # 4. [WORKER] Simply go into listening mode
        #
        echo "Starting sshd at Worker"   
        sudo service ssh status                                                             
        # * sshd is not running        
        sudo service ssh restart -D # This is a blocking call for the Workers. 
    else
        #### On Primary  
        # 2. [PRIMARY] Creating and posting Primary's public key
        #            
        echo "Sharing Primary's public key..."        
        ssh-keygen -f .ssh/id_rsa -q -N ""
        # Send id_rsa.pub to all nodes
        gsutil cp .ssh/id_rsa.pub ${PUBKEY_LOC} 
        
        ####
        # 3. [PRIMARY] Set up authorized keys locally too for self ssh
        # 
        cp .ssh/id_rsa.pub .ssh/authorized_keys
        chmod 600 .ssh/authorized_keys
        env > .ssh/environment      
        
        ####
        # 4. [PRIMARY] Start sshd as daemon
        #        
        echo "Starting sshd at Primary"
        sudo service ssh restart
    fi
            
    echo "*****"
    echo Setting up .ssh/config on Primary
    echo "*****"  
    USER=$(whoami)
    echo "User " ${USER}    
    
    #
    # For each node specified in the CLUSTER_SPEC:
    #    e.g. cmle-training-workerpool0-6d3xxxxxxx-0:2222
    #    The host is cmle-training-workerpool0-6d3xxxxxxx-0
    #
    # Although not used in this script, there are a number of variables set by Vertex in the environment:
    #   CMLE_TRAINING_WORKERPOOL0_6d3xxxxxxx_0_SERVICE_HOST=10.12.0.81
    #   CMLE_TRAINING_WORKERPOOL0_6d3xxxxxxx_0_SERVICE_PORT=2222
    #   CMLE_TRAINING_WORKERPOOL0_6d3xxxxxxx_0_SERVICE_PORT_STATUSZ=6000
    #   CMLE_TRAINING_WORKERPOOL0_6d3xxxxxxx_0_SERVICE_PORT_TF_PORT=2222
    #   CMLE_TRAINING_WORKERPOOL0_6d3xxxxxxx_0_SERVICE_PORT_TRAINING_PORT=3333
    #
    while read wkr; do 
        echo $wkr
        HOST=$(echo "$wkr" | grep -o "^[^:]\+")
        IP=$(host ${HOST} | head -n 1 | sed "s/.* \([0-9\.]\+[0-9]\+\)/\1/")
        echo "Got HOST:" $HOST " IP:" $IP  
        
        if [[ ! -e .ssh/config || -z "$(cat .ssh/config | grep ${HOST})" ]]; then
            echo "Host ${HOST}
    Hostname ${IP}
    User ${USER}    
    Port ${SSH_PORT}
    StrictHostKeyChecking no
    IdentityFile ~/.ssh/id_rsa

" >> .ssh/config
        fi
    done < $NODES_FILE 
    
    # Wait a short while before testing configs...
    sleep 5
    
    echo "*****"
    echo Testing SSH Configs...
    echo "*****" 
    CHECKLIST=$(<$NODES_FILE)
    PENDING=""
    while [ -n "$CHECKLIST" ]; do
        for wkr in $CHECKLIST
        do
            HOST=$(echo "$wkr" | grep -o "^[^:]\+")    
            STATUS=$(ssh -n ${HOST} echo "PASSED" || echo "FAILED")
            echo $HOST $STATUS
            if [[ "FAILED" == "$STATUS" && ! "$PENDING" =~ "$wkr" ]]; then
               PENDING=$PENDING" $wkr"                          # Adding to the list
            elif [[ "PASSED" == "$STATUS" && "$PENDING" =~ "$wkr" ]]; then
               PENDING=$(echo "$PENDING" | sed "s/\s*${wkr}//") # Removing from list
            fi
        done
        echo "PENDING" $PENDING
        CHECKLIST=$PENDING
        sleep 5 # Wait a short while before scanning the whole pending list again.
    done
    
    echo "*****"
    echo Passwordless SSH from primary to all nodes succeeded.
    echo "*****" 
    # Clean up
    gsutil rm ${PUBKEY_LOC}
fi