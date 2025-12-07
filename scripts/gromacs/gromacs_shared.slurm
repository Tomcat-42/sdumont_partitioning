#!/bin/bash

#SBATCH --job-name=gromacs_shared
#SBATCH --partition=lncc-gh200_shared
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=72
#SBATCH --gpus-per-node=1
#SBATCH --time=00:30:00
#SBATCH --array=0-3

# GROMACS Benchmark - Shared Queue
# Runs 4 jobs in parallel, each with 1 GPU allocated by SLURM
# SLURM automatically handles NUMA affinity in shared mode

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
exec > "$LOGS_DIR/gromacs_shared_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out" 2> "$LOGS_DIR/gromacs_shared_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.err"

echo "=== GROMACS Shared Queue Benchmark ==="
echo "Job ID: $SLURM_JOB_ID"
echo "Array Task ID: $SLURM_ARRAY_TASK_ID"
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
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
SINGULARITY="singularity run --nv -B ${PWD}:/host_pwd --pwd /host_pwd $GMX_IMAGE"

# Directories already created above

OUTPUT_FILE="${RESULTS_DIR}/shared_task${SLURM_ARRAY_TASK_ID}_${SLURM_JOB_ID}.log"

echo "=== Environment ===" | tee "$OUTPUT_FILE"
echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES" | tee -a "$OUTPUT_FILE"
echo "OMP_NUM_THREADS: $OMP_NUM_THREADS" | tee -a "$OUTPUT_FILE"
echo "SLURM_CPUS_PER_TASK: $SLURM_CPUS_PER_TASK" | tee -a "$OUTPUT_FILE"
numactl --show | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "=== GPU Info ===" | tee -a "$OUTPUT_FILE"
nvidia-smi --query-gpu=name,memory.total,pci.bus_id --format=csv | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

echo "=== Running GROMACS mdrun ===" | tee -a "$OUTPUT_FILE"
$SINGULARITY gmx mdrun \
    -ntmpi 1 \
    -ntomp "$OMP_NUM_THREADS" \
    -pin on \
    -pinoffset 0 \
    -nb gpu \
    -bonded gpu \
    -pme gpu \
    -v \
    -s topol.tpr \
    -deffnm "stmv_shared_${SLURM_ARRAY_TASK_ID}" \
    -nsteps $NSTEPS \
    -resetstep $RESETSTEP \
    -noconfout \
    -dlb no \
    -nstlist 300 2>&1 | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "=== GROMACS benchmark completed ===" | tee -a "$OUTPUT_FILE"
echo "End time: $(date)" | tee -a "$OUTPUT_FILE"
echo "Results saved to: $OUTPUT_FILE"
