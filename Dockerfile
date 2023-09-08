FROM us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.1-13.py310:latest

# Addressing minor quirks in the base image...
ENV PYTHONPATH=/opt/conda/lib/python3.10/site-packages:${PYTHONPATH}
RUN chmod 666 /var/log-storage/output.log

ENV STAGE_DIR=/tmp
RUN mkdir -p ${STAGE_DIR}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
 openssh-client openssh-server \
 dnsutils iputils-ping \
 net-tools \
 && rm -rf /var/lib/apt/lists/*

########################
# Set up the sshd config file
# the ssh_setup.sh script will complete the keys set up and start the server
#
# Should only use 2222
ENV SSH_PORT=2222 
COPY sshd_config.sed /tmp
RUN sed -i -E -f /tmp/sshd_config.sed /etc/ssh/sshd_config
# RUN cat /etc/ssh/sshd_config
RUN sed -E -i 's/^(PATH=.*)/#\1/' /etc/environment
EXPOSE ${SSH_PORT}

# Use a user account to set up ssh communication
RUN useradd -ms /bin/bash vertex
RUN adduser vertex sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
# echo 'mypassword' | openssl passwd -1 -stdin
# RUN echo 'vertex:$1$GGvDNEZ9$8pD2uS1HprTgVBKsiPzz1/' | chpasswd -e
WORKDIR /home/vertex
USER vertex
RUN mkdir -m 700 -p .ssh

########################
# 

COPY gen_hostfile.sh .
COPY ssh_setup.sh .
COPY train.sh .
COPY start.sh .

ENTRYPOINT ["bash", "./start.sh"]


