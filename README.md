# Distributed training with DeepSpeed on Vertex AI

This repository provides the scripts to build a custom container for training large models across multiple nodes and multi-GPUs supporting DeepSpeed. The container can be deployed across a pool of nodes on Vertex AI as a [`CustomJob`](https://cloud.google.com/vertex-ai/docs/training/create-custom-job), and the job in turn can be part of a Vertex training pipeline. 

Once the nodes are provisioned, the container automatically establishes passwordless authentication between the primary and the worker nodes, and generate the necessary hostfile for DeepSpeed. 

The container also takes advantage of [FUSE](https://cloud.google.com/vertex-ai/docs/training/code-requirements#fuse) which mounts Google Cloud Storage to the local file system. Within a Vertex AI `CustomJob`, training code can read data, write tensorflow logs, checkpoints and models files on GCS by simply interacting with the local file system.


## Challenges of Training LLMs

Training LLMs is challenging because it requires a large infrastructure of compute resources. Multiple machines with multiple hardware accelerators such as GPUs and TPUs are needed to train a single model. This infrastructure is often scarce and expensive, especially at a large scale.


## DeepSpeed 

DeepSpeed is an open-source framework for memory-efficient multi-node multi-GPU training. It removes the memory redundancies across data-parallel processes by partitioning the three model states (optimizer states, gradients, and parameters) across data-parallel processes instead of replicating them. Using DeepSpeed ZeRO to train LLMs can significantly reduce the memory requirements and costs associated with training. This makes it possible to train LLMs on smaller and more affordable hardware clusters.


## How to Use This Repository

To use this repository, choose one of the examples. Three examples are provided. For each example, a Dockerfile and a Juypter Notebook is included along with any script specific to that example. The notebook illustrates the steps to build and test the container, specifying the workers pool, then deploy it in a CustomJob.

1. A [template](examples/deepspeed-template) DeepSpeed container to be customized with your code. Fill in your training code in `deepspeed_train.sh` and build the container.
1. A fully functioning [example](examples/deepspeed-chat) executing a single fine tuning epoch with LLMs like OPT-125m and Llama-2. The code is adopted from [DeepSpeed-Chat](https://github.com/microsoft/DeepSpeedExamples/tree/master/applications/DeepSpeed-Chat), specifically, [Step-1 Supervised Fine Tuning](https://github.com/microsoft/DeepSpeedExamples/tree/master/applications/DeepSpeed-Chat/training/step1_supervised_finetuning). DeepSpeed-Chat is a general system framework for enabling an end-to-end training experience for ChatGPT-like models. It uses other popular model development libraries like `datasets`, `sentencepiece`, `accelerate`, and `transformers`. See the [README](third_party/deepspeed_examples/README.md) on which part of the code to bring over.
1. The basic [ssh-only](examples/deepspeed-template) multi-node set up without DeepSpeed and its dependencies. Use this template for your own multi-node training development on Vertex AI. The out of the box script will build and deploy without any training code. Deploy it with `enable_web_access=True` to verify the inter-node communication. The deployed cluster will be in an idle state for inspection and debugging. The `nodes` file in the home directory contains the hostnames of the cluster.


## Intructions

For a step-by-step illustration, step through the example notebooks within Vertex Workbench. 

To build the container, assuming a corresponding Artifact Registry repo has already been set up:
```
$ AR_REPO=<ARTIFACT_REGISTRY_REPO>
$ IMG_NAME=<IMAGE_NAME>
$ EXAMPLE_DIR=<EXAMPLE_DIR>

$ PROJECT_ID=<PROJECT_ID>
$ LOCATION=<LOCATION>
$ IMAGE_URI="${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${IMG_NAME}:latest"

$ DOCKERFILE=f"examples/${EXAMPLE_DIR}/${IMG_NAME}.Dockerfile"

$ docker build . -t ${IMAGE_URI} -f ${DOCKERFILE}
```


## [OPTIONAL] Use Vertex AI TensorBoard with custom training

When using custom training to train models, you can set up your training job to automatically upload your TensorBoard logs to Vertex AI TensorBoard. 

The Vertex AI TensorBoard integration with custom training requires binding a service account to the Vertex service agent. If you don't already have a service account for custom training, follow the [instructions](https://cloud.google.com/vertex-ai/docs/experiments/tensorboard-training#create_a_service_account_with_required_permissions) to set one up.

Your training script has access to three locations on the local file system `OUTPUT_FOLDER`,`CHKPTS_FOLDER`, and `JOBLOGS_FOLDER` that mapped to their corresponding locations on Cloud Storage `AIP_MODEL_DIR`, `AIP_CHECKPOINT_DIR`, and `AIP_TENSORBOARD_LOG_DIR`. These Vertex AI [environment variables](https://cloud.google.com/vertex-ai/docs/training/code-requirements#environment-variables) are set during custom training.

See the notebook [DeepSpeed-Chat example](examples/deepspeed-chat/Vertex_DeepspeedChat.ipynb) on how to include TensorBoard in your set up with this container.

## Related 

Here are other DeepSpeed examples from Google Cloud.

### Training Large Language Models on Google Cloud 

[`llm-pipeline-examples`](https://github.com/GoogleCloudPlatform/llm-pipeline-examples) is another example on multi-node distributed training with DeepSpeed on Google Cloud. The approach differs in its cluster provisioning method. 

As explained above, in this repo, the training cluster is provisioned as a worker pool within Vertex AI Training. It offers you a simple way to get started with DeepSpeed on Vertex.

While `llm-pipeline-examples` uses Vertex AI for the production pipeline, model management and deployment endpoint, the training cluster is provisioned under the user's project directly as a Compute Engine cluster. It is based on the [AI infra cluster provisioning tool](https://github.com/GoogleCloudPlatform/ai-infra-cluster-provisioning). The tool is intended as an easy way to configure everything needed to successfully run a GPU cluster at large-scale using a variety of machines including A3.

> To provision the cluster of VMs, we use a pre created container we call ‘batch container’ [...] Creating VMs using the tool is as simple as filling a few environment variables and calling an entry point. It will automatically create the cluster with an image of choice and run a starting command on all VMs. [...] When the job completes successfully, we call the entry point again requesting the destruction of the cluster.

Using the CPT tool to provision in your project has the following benefits:

1. Have more control on the cluster, for example ability to rerun the jobs without deleting the cluster.
2. Larger GPU clusters needed more custom networking configuration (e.g. multi NIC); Requires control over the network to be able to run these configurations.


### Fine-tuning FLAN-T5 XXL with DeepSpeed and Vertex AI

In this [article](https://medium.com/google-cloud/fine-tuning-flan-t5-xxl-with-deepspeed-and-vertex-ai-af499daf694d), the post shows how to fine-tune a FLAN-T5 XXL model (11B parameters) using one a2-highgpu-8g (680 GB RAM, 96 vCPU) machine with 8xA100 GPUs with Vertex AI Custom Training. The code is on this [repo](https://github.com/rafaelsf80/vertex-flant5xxl-multitask-finetuning). 

