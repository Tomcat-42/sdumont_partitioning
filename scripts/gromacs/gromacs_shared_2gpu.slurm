#!/bin/bash

#SBATCH --job-name=gromacs_shared_2gpu
#SBATCH --partition=lncc-gh200_shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=144
#SBATCH --gpus-per-node=2
#SBATCH --time=01:00:00
#SBATCH --output=gromacs_shared_2gpu_%j.out
#SBATCH --error=gromacs_shared_2gpu_%j.err

# GROMACS Benchmark - Shared Queue with 2 GPUs

# Path configuration - use SLURM_SUBMIT_DIR (where sbatch was called)
SCRIPT_DIR="$SLURM_SUBMIT_DIR"
export BASE_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")"
export ASSETS_PATH="$SCRIPT_DIR/assets"
export BENCH_TARBALL="$ASSETS_PATH/GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP.tar.gz"
export BENCH_DIR="$ASSETS_PATH/GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP/stmv"
export RESULTS_DIR="$BASE_PATH/data/gromacs"

# Configuration
NGPUS=2
NTMPI=2
NTOMP=72

# Create results directory
mkdir -p "$RESULTS_DIR"

echo "=== GROMACS Shared Queue Benchmark (2 GPUs) ==="
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
export OMP_NUM_THREADS=$NTOMP
SINGULARITY="singularity run --nv -B ${PWD}:/host_pwd --pwd /host_pwd $GMX_IMAGE"

OUTPUT_FILE="${RESULTS_DIR}/shared_${NGPUS}gpu_${SLURM_JOB_ID}.log"

echo "=== Environment ==="
echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
echo "OMP_NUM_THREADS: $OMP_NUM_THREADS"
echo "NTMPI: $NTMPI"
echo "NTOMP: $NTOMP"
echo ""

echo "=== GPU Info ==="
nvidia-smi --query-gpu=index,name,memory.total,pci.bus_id --format=csv
echo ""

echo "=== Running GROMACS mdrun with $NGPUS GPU(s) ==="
$SINGULARITY gmx mdrun \
    -ntmpi $NTMPI \
    -ntomp $NTOMP \
    -pin on \
    -nb gpu \
    -bonded gpu \
    -pme gpu \
    -npme 1 \
    -v \
    -s topol.tpr \
    -deffnm "stmv_shared_${NGPUS}gpu" \
    -nsteps $NSTEPS \
    -resetstep $RESETSTEP \
    -noconfout \
    -dlb no \
    -nstlist 300 2>&1 | tee "$OUTPUT_FILE"

echo ""
echo "=== GROMACS benchmark completed ==="
echo "End time: $(date)"
echo "Results saved to: $OUTPUT_FILE"

# Copy SLURM output to logs directory
LOGS_DIR="$BASE_PATH/data/gromacs/logs"
mkdir -p "$LOGS_DIR"
cp "$SLURM_SUBMIT_DIR/gromacs_shared_2gpu_${SLURM_JOB_ID}.out" "$LOGS_DIR/" 2>/dev/null
cp "$SLURM_SUBMIT_DIR/gromacs_shared_2gpu_${SLURM_JOB_ID}.err" "$LOGS_DIR/" 2>/dev/null
echo "Logs copied to: $LOGS_DIR"
