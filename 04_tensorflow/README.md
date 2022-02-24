# TensorFlow

The starting point for [multi-GPU training with Keras](https://www.tensorflow.org/tutorials/distribute/keras) is `tf.distribute.MirroredStrategy`. In this approach, the model is copied to `N` GPUs and gradients are synced as we saw previously. Be sure to use [`tf.data`](https://www.tensorflow.org/api_docs/python/tf/data) to handle data loading as is done in the example on this page.

## Single-Node, Synchronous, Multi-GPU Training

### Step 1: Installation

**Skip this step for the live workship.**

Install TensorFlow for the V100 nodes:

```bash
$ ssh <YourNetID>@adroit.princeton.edu
$ module load anaconda3/2021.11
$ conda create --name tf2-gpu tensorflow-gpu tensorflow-datasets -y
```

### Step 2: Download the Data

```
$ module load anaconda3/2021.11
$ conda activate /scratch/network/jdh4/CONDA/envs/tf2-gpu
$ python
Python 3.9.7 (default, Sep 16 2021, 13:09:58) 
[GCC 7.5.0] :: Anaconda, Inc. on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import tensorflow_datasets as tfds
>>> datasets, info = tfds.load(name='mnist', with_info=True, as_supervised=True)
>>> exit()
```

### Step 3: Inspect the Script

Below is the contents of `mnist_classify.py`:

```python
import tensorflow_datasets as tfds
import tensorflow as tf

import os

print(tf.__version__)

datasets, info = tfds.load(name='mnist', with_info=True, as_supervised=True)
mnist_train, mnist_test = datasets['train'], datasets['test']

# multiple GPUs on a single machine
strategy = tf.distribute.MirroredStrategy()
print('Number of devices: {}'.format(strategy.num_replicas_in_sync))

num_train_examples = info.splits['train'].num_examples
num_test_examples = info.splits['test'].num_examples

BUFFER_SIZE = 10000

BATCH_SIZE_PER_REPLICA = 64
BATCH_SIZE = BATCH_SIZE_PER_REPLICA * strategy.num_replicas_in_sync

def scale(image, label):
  image = tf.cast(image, tf.float32)
  image /= 255

  return image, label

train_dataset = mnist_train.map(scale).cache().shuffle(BUFFER_SIZE).batch(BATCH_SIZE)
eval_dataset = mnist_test.map(scale).batch(BATCH_SIZE)

with strategy.scope():
  model = tf.keras.Sequential([
      tf.keras.layers.Conv2D(32, 3, activation='relu', input_shape=(28, 28, 1)),
      tf.keras.layers.MaxPooling2D(),
      tf.keras.layers.Flatten(),
      tf.keras.layers.Dense(64, activation='relu'),
      tf.keras.layers.Dense(10)
  ])

  model.compile(loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True),
                optimizer=tf.keras.optimizers.Adam(),
                metrics=['accuracy'])

# Define a function for decaying the learning rate.
# You can define any decay function you need.
def decay(epoch):
  if epoch < 3:
    return 1e-3
  elif epoch >= 3 and epoch < 7:
    return 1e-4
  else:
    return 1e-5

# Define a callback for printing the learning rate at the end of each epoch.
class PrintLR(tf.keras.callbacks.Callback):
  def on_epoch_end(self, epoch, logs=None):
    print('\nLearning rate for epoch {} is {}'.format(epoch + 1,
                                                      model.optimizer.lr.numpy()))

callbacks = [
    tf.keras.callbacks.LearningRateScheduler(decay),
    PrintLR()
]

EPOCHS = 12
model.fit(train_dataset, epochs=EPOCHS, callbacks=callbacks)
```

### Step 4: Submit the Job

Below is a sample Slurm script:

```bash
#!/bin/bash
#SBATCH --job-name=tf2-multi     # create a short name for your job
#SBATCH --nodes=1                # node count
#SBATCH --ntasks=1               # total number of tasks across all nodes
#SBATCH --cpus-per-task=16       # cpu-cores per task (>1 if multi-threaded tasks)
#SBATCH --mem=64G                # total memory per node (4G per cpu-core is default)
#SBATCH --gres=gpu:2             # number of gpus per node
#SBATCH --time=00:05:00          # total run time limit (HH:MM:SS)
#SBATCH --reservation=multigpu   # REMOVE THIS LINE AFTER THE WORKSHOP

module purge
module load anaconda3/2021.11
conda activate /scratch/network/jdh4/CONDA/envs/tf2-gpu

python mnist_classify.py
```

Note that `srun` is not called and there is only one task. Submit the job as follows:

```
$ cd multi_gpu_training/04_tensorflow
$ sbatch job.slurm
```

## Multi-node Training

Look to [MultiWorkerMirroredStrategy](https://www.tensorflow.org/guide/distributed_training#multiworkermirroredstrategy) for using the GPUs on more than one compute node. There is an example for the [Keras API](https://www.tensorflow.org/tutorials/distribute/multi_worker_with_keras). Consider using Horovod instead of this approach (see below).

## Horovod

[Horovod](https://horovod.ai/) is a distributed deep learning training framework for TensorFlow, Keras, PyTorch, and Apache MXNet. It is based on MPI.