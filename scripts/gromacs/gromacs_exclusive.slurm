#!/bin/bash

#SBATCH --job-name=gromacs_exclusive
#SBATCH --partition=lncc-gh200
#SBATCH --time=01:00:00
# GROMACS Benchmark - Exclusive Queue with NUMA Pinning
# Tests performance on each NUMA node (0-3) with its local GPU

# Path configuration - use script directory as base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASE_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")"
export ASSETS_PATH="$SCRIPT_DIR/assets"
export BENCH_TARBALL="$ASSETS_PATH/GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP.tar.gz"
export BENCH_DIR="$ASSETS_PATH/GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP/stmv"
export RESULTS_DIR="$BASE_PATH/data/gromacs"
export LOGS_DIR="$RESULTS_DIR/logs"

# Create directories
mkdir -p "$RESULTS_DIR" "$LOGS_DIR"

# Redirect SLURM output to logs directory
exec > "$LOGS_DIR/gromacs_exclusive_${SLURM_JOB_ID}.out" 2> "$LOGS_DIR/gromacs_exclusive_${SLURM_JOB_ID}.err"

echo "=== GROMACS Exclusive Queue Benchmark ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_JOB_NODELIST"
nodeset -e "$SLURM_JOB_NODELIST"
echo "Start time: $(date)"
echo ""

# Benchmark configuration
NSTEPS=100000
RESETSTEP=90000

# Extract benchmark if not already done
mkdir -p "$ASSETS_PATH"
if [ ! -d "$BENCH_DIR" ]; then
    if [ -f "$BENCH_TARBALL" ]; then
        echo "Extracting benchmark from local tarball..."
        tar -xzf "$BENCH_TARBALL" -C "$ASSETS_PATH"
    else
        echo "ERROR: Benchmark tarball not found at $BENCH_TARBALL"
        echo "Please download it first:"
        echo "  wget https://zenodo.org/record/3893789/files/GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP.tar.gz -P $ASSETS_PATH"
        exit 1
    fi
fi

cd "$BENCH_DIR" || exit 1

# Load modules
module load arch_gpu_sc
module load gromacs/2023.2_nv_container

export GMX_ENABLE_DIRECT_GPU_COMM=1
SINGULARITY="singularity run --nv -B ${PWD}:/host_pwd --pwd /host_pwd $GMX_IMAGE"

# Directories already created above

# Test each NUMA node with its corresponding GPU
NUMA_NODES=(0 1 2 3)

for numa in "${NUMA_NODES[@]}"; do
    echo ""
    echo "=== Running GROMACS on NUMA $numa with GPU $numa ==="

    OUTPUT_FILE="${RESULTS_DIR}/exclusive_numa${numa}_${SLURM_JOB_ID}.log"

    numactl --cpunodebind="$numa" --membind="$numa" bash -c "
        export CUDA_VISIBLE_DEVICES=$numa
        export OMP_NUM_THREADS=72

        echo '=== Environment ==='
        echo 'NUMA Node: $numa'
        echo 'GPU: '\$CUDA_VISIBLE_DEVICES
        echo 'OMP_NUM_THREADS: '\$OMP_NUM_THREADS
        numactl --show
        echo ''

        echo '=== GPU Info ==='
        nvidia-smi -i \$CUDA_VISIBLE_DEVICES --query-gpu=name,memory.total,pci.bus_id --format=csv
        echo ''

        echo '=== Running GROMACS mdrun ==='
        $SINGULARITY gmx mdrun \
            -ntmpi 1 \
            -ntomp 72 \
            -pin on \
            -pinoffset 0 \
            -nb gpu \
            -bonded gpu \
            -pme gpu \
            -v \
            -s topol.tpr \
            -deffnm stmv_numa${numa} \
            -nsteps $NSTEPS \
            -resetstep $RESETSTEP \
            -noconfout \
            -dlb no \
            -nstlist 300
    " 2>&1 | tee "$OUTPUT_FILE"

    echo "Results saved to: $OUTPUT_FILE"
done

echo ""
echo "=== All GROMACS benchmarks completed ==="
echo "End time: $(date)"
