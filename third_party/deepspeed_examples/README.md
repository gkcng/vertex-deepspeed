# Bringing over training code from DeepSpeed-Chat

The example illustrating how to use the Vertex DeepSpeed container with [DeepSpeed-Chat](https://github.com/microsoft/DeepSpeedExamples/tree/master/applications/DeepSpeed-Chat) requires bringing over some code from [Step-1 Supervised Fine Tuning](https://github.com/microsoft/DeepSpeedExamples/tree/master/applications/DeepSpeed-Chat/training/step1_supervised_finetuning). 

The deepspeed-chat.Dockerfile relies on the following being in the correct path to build: `main.py` and `utils`. To download the code:

```
git clone https://github.com/microsoft/DeepSpeedExamples.git
```

Given the relative location of this repo `./vertex-deepspeed`, copy the following over into the third_party directory:

```
cp -R DeepSpeedExamples/applications/DeepSpeed-Chat/training/utils ./vertex-deepspeed/third_party/deepspeed_examples/
```

```
cp DeepSpeedExamples/applications/DeepSpeed-Chat/training/step1_supervised_finetuning/main.py ./vertex-deepspeed/third_party/deepspeed_examples/
```

The deepspeed_examples directory should look like:
```
$ ls -l ./vertex-deepspeed/third_party/deepspeed_examples/
total 32
-rwxr-xr-x  1 user  group  13909 Sep  9 15:09 main.py
drwxr-xr-x  9 user  group    288 Sep  9 14:47 utils
```

You are ready to try the [example](../../examples/deepspeed-chat/Vertex_DeepspeedChat.ipynb)

