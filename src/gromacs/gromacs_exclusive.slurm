#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=72
#SBATCH -p lncc-gh200_shared
#SBATCH -J gromacs+stmv+container_nvidia
#SBATCH --gpus-per-node=1
#SBATCH --time=00:20:00
#SBATCH -o gromacs_exclusive_%j.out

export BENCH_URL="https://zenodo.org/record/3893789/files/GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP.tar.gz"
export BENCH_DIR="GROMACS_heterogeneous_parallelization_benchmark_info_and_systems_JCP/stmv"
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
export GMX_ENABLE_DIRECT_GPU_COMM=1
export SINGULARITY="singularity run --nv -B ${PWD}:/host_pwd --pwd /host_pwd $GMX_IMAGE"

function setup() {
    module load arch_gpu_sc
    module load gromacs/2023.2_nv_container

    echo "$SLURM_JOB_NODELIST"
    nodeset -e "$SLURM_JOB_NODELIST"
    pushd "$SLURM_SUBMIT_DIR" || exit

    wget $BENCH_URL -O - | tar -xzf -
    pushd "$BENCH_DIR" || exit
}

setup

${SINGULARITY} gmx mdrun \
    -ntmpi "$SLURMNTASKS" \
    -ntomp "$SLURM_CPUS_PER_TASK" \
    -pin on \
    -pinoffset 0 \
    -gpu_id "$CUDA_VISIBLE_DEVICES" \
    -v \
    -s topol.tpr \
    -deffnm stmv \
    -nsteps 100000 \
    -resetstep 90000 \
    -noconfout \
    -dlb no \
    -nstlist 300
