#!/bin/bash

#SBATCH --job-name=array_benchmark
#SBATCH --partition=lncc-gh200_shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:10:00
#SBATCH --array=0-3
#SBATCH --gpus=1 
#SBATCH --output=shared_array_1gpu_node%a.txt
#SBATCH --error=shared_array_1gpu_node%a.err

export CUDA_VISIBLE_DEVICES=$SLURM_ARRAY_TASK_ID

echo "--- Job Array Task $SLURM_ARRAY_TASK_ID Starting ---"
echo "--- Requesting GPU $CUDA_VISIBLE_DEVICES ---"
echo ""

srun bash -c '
    echo "--- Executing on Slurm Node: $SLURM_JOB_NODELIST ---"; echo;
    numactl --hardware; echo;
    echo "--- My Assigned CPU/NUMA Node (Pinned by Slurm) ---";
    numactl --show; echo;
    echo "--- My Assigned GPU (Index $CUDA_VISIBLE_DEVICES) PCI ID ---";
    nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader -i $CUDA_VISIBLE_DEVICES; echo;
    echo "--- Running nvbandwidth Benchmark ---";
    nvbandwidth
'
