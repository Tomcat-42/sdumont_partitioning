#!/bin/bash

#SBATCH --job-name=gromacs_exclusive
#SBATCH --partition=lncc-gh200
#SBATCH --time=02:00:00
#SBATCH --output=gromacs_exclusive_%j.out
#SBATCH --error=gromacs_exclusive_%j.err

# GROMACS Benchmark - Exclusive Queue
# Tests GPU scaling: 1, 2, and 4 GPUs

# Path configuration - use SLURM_SUBMIT_DIR (where sbatch was called)
SCRIPT_DIR="$SLURM_SUBMIT_DIR"
export BASE_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")"
export ASSETS_PATH="$SCRIPT_DIR/assets"
export BENCH_TARBALL="$ASSETS_PATH/GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP.tar.gz"
export BENCH_DIR="$ASSETS_PATH/GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP/stmv"
export RESULTS_DIR="$BASE_PATH/data/gromacs"

# Create results directory
mkdir -p "$RESULTS_DIR"

echo "=== GROMACS Exclusive Queue Benchmark ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_JOB_NODELIST"
echo "SLURM_SUBMIT_DIR: $SLURM_SUBMIT_DIR"
echo "ASSETS_PATH: $ASSETS_PATH"
echo "Start time: $(date)"
echo ""

# Benchmark configuration
NSTEPS=100000
RESETSTEP=90000

# Extract benchmark if not already done
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

# GPU configurations to test: (num_gpus, ntmpi, ntomp, gpu_ids)
# Total cores = 288, divided equally among GPUs
GPU_CONFIGS=(
    "1 1 72 0"
    "2 2 72 0,1"
    "4 4 72 0,1,2,3"
)

for config in "${GPU_CONFIGS[@]}"; do
    read -r num_gpus ntmpi ntomp gpu_ids <<< "$config"

    echo ""
    echo "========================================"
    echo "=== Running GROMACS with $num_gpus GPU(s) ==="
    echo "========================================"
    echo "Configuration: ntmpi=$ntmpi, ntomp=$ntomp, gpu_ids=$gpu_ids"

    OUTPUT_FILE="${RESULTS_DIR}/exclusive_${num_gpus}gpu_${SLURM_JOB_ID}.log"

    export CUDA_VISIBLE_DEVICES="$gpu_ids"
    export OMP_NUM_THREADS=$ntomp

    echo "=== Environment ==="
    echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
    echo "OMP_NUM_THREADS: $OMP_NUM_THREADS"
    echo ""

    echo "=== GPU Info ==="
    nvidia-smi --query-gpu=index,name,memory.total,pci.bus_id --format=csv
    echo ""

    echo "=== Running GROMACS mdrun ==="
    # Build command - only use -npme 1 when ntmpi >= 2
    NPME_OPT=""
    if [ "$ntmpi" -ge 2 ]; then
        NPME_OPT="-npme 1"
    fi

    $SINGULARITY gmx mdrun \
        -ntmpi $ntmpi \
        -ntomp $ntomp \
        -pin on \
        -nb gpu \
        -bonded gpu \
        -pme gpu \
        $NPME_OPT \
        -v \
        -s topol.tpr \
        -deffnm "stmv_${num_gpus}gpu" \
        -nsteps $NSTEPS \
        -resetstep $RESETSTEP \
        -noconfout \
        -dlb no \
        -nstlist 300 2>&1 | tee "$OUTPUT_FILE"

    echo "Results saved to: $OUTPUT_FILE"
done

echo ""
echo "=== All GROMACS benchmarks completed ==="
echo "End time: $(date)"

# Copy SLURM output to logs directory
LOGS_DIR="$BASE_PATH/data/gromacs/logs"
mkdir -p "$LOGS_DIR"
cp "$SLURM_SUBMIT_DIR/gromacs_exclusive_${SLURM_JOB_ID}.out" "$LOGS_DIR/" 2>/dev/null
cp "$SLURM_SUBMIT_DIR/gromacs_exclusive_${SLURM_JOB_ID}.err" "$LOGS_DIR/" 2>/dev/null
echo "Logs copied to: $LOGS_DIR"
