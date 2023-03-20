#!/bin/bash
#SBATCH --job-name=horovod-pytorch
#SBATCH --time=02:00:00
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:2
#SBATCH -N 2
#SBATCH -n 4
#SBATCH --exclusive

module purge
module load gcc/9.2.0
module load openmpi/4.1.1-gdr

export LD_LIBRARY_PATH=/spack/apps/linux-centos7-x86_64/gcc-8.3.0/nccl-2.8.3-1-j6vfxde24ij7cwixihki347ipohx5duf/lib:$LD_LIBRARY_PATH
export LIBRARY_PATH=/spack/apps/linux-centos7-x86_64/gcc-8.3.0/nccl-2.8.3-1-j6vfxde24ij7cwixihki347ipohx5duf/lib:$LIBRARY_PATH
export CPATH=/spack/apps/linux-centos7-x86_64/gcc-8.3.0/nccl-2.8.3-1-j6vfxde24ij7cwixihki347ipohx5duf/include:$CPATH
export NCCL_ROOT=/spack/apps/linux-centos7-x86_64/gcc-8.3.0/nccl-2.8.3-1-j6vfxde24ij7cwixihki347ipohx5duf

eval "$(conda shell.bash hook)"
conda activate horovod-pytorch

srun --mpi=pmix_v2 -n 4 python pytorch_synthetic_benchmark.py > output-N2-n4.log
