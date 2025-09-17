#!/bin/bash

#SBATCH --job-name=multi_numa_benchmark
#SBATCH --partition=lncc-gh200
#SBATCH --time=00:10:00
#SBATCH --output=benchmark_output_%j.out
#SBATCH --error=benchmark_output_%j.err

echo "--- Job Starting on $(hostname) ---"
echo "Start time: $(date)"
echo ""

NUMA_NODES=(0 1 2 3)
export CUDA_VISIBLE_DEVICES="0,1,2,3"

for i in "${NUMA_NODES[@]}"; do
    echo "--- Launching benchmark for NUMA Node $i, output will be in exclusive_4gpu_node${i}.txt ---"
    
    srun numactl --cpunodebind="$i" --membind="$i" bash -c '
     	echo "--- Executing on Slurm Node: $SLURM_JOB_NODELIST ---"; echo;
	numactl --hardware; echo;
        echo "--- My Assigned CPU/NUMA Node (PINNED to $0) ---";
        numactl --show; echo;
        echo "--- My Assigned GPU PCI ID ---";
        nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader -i $CUDA_VISIBLE_DEVICES; echo;
        echo "--- GPU Topology ---";
        nvidia-smi topo -m; echo;
        echo "--- Running nvbandwidth Benchmark ---";
        nvbandwidth
    ' $i > exclusive_4gpu_node${i}.txt 2>&1
done

echo ""
echo "--- All benchmarks launched. Job Finished ---"
echo "End time: $(date)"
