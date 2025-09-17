# SDumont II Partitioning

These are the results from GPU sharing and partitioning experiments conducted on the [SDumont HPC Cluster](https://sdumont.lncc.br).

## Hardware

The tests were executed on two queues: `lncc-gh200` and `lncc-gh200_shared`. Both queues use nodes equipped with the [NVIDIA GH200 Grace Hopper Superchip](https://www.nvidia.com/en-us/data-center/grace-hopper-superchip).

The former is an **exclusive queue**, meaning a job reserves the entire node for its duration. The latter is a **shared queue** that uses the [Generic Resource (GRES) Scheduling](https://slurm.schedmd.com/gres.html) scheme to share resources (GPUs, CPUs, etc.) among jobs. [*]

*: Each job can be allocated at most half of each resource type. For example, since each node has 4 GPUs, a single job can use a maximum of 2.

The following diagram illustrates the topology of a GH200 node:

![Node topology diagram](./doc/img/exclusive.svg)

Note the NUMA package layout: GPU <-> CPU <-> RAM.

## Tools Used

- [**numactl**](https://linux.die.net/man/8/numactl): Used on Linux to manage the NUMA scheduling policy of a process.
- [**nvbandwidth**](https://github.com/NVIDIA/nvbandwidth): Used to measure CPU-GPU and GPU-GPU bandwidth.

## Experiments

### Exclusive Queue

In this experiment, a node in the `lncc-gh200` queue was reserved, making all four GPUs visible to the process.

The job was pinned to each of the four CPU NUMA packages. For each pinning, a bandwidth test was run against every GPU in the system.

[exclusive.slurm script](./src/exclusive.slurm)

The objective was to measure the baseline bandwidth metrics for each pair in the set {p0, p1, p2, p3} x {gpu0, gpu1, gpu2, gpu3}.

### Shared Queue

The `lncc-gh200_shared` case is more complex because SLURM manages the NUMA scheduling, removing direct user control. However, we can control the number of processes and the number of GPUs allocated to each process.

Therefore, two scenarios were tested:

- *4 jobs, each one with 1 process and 1 gpu per process*: [shared 1 gpu script](./src/shared_array_1gpu.slurm)
- *2 jobs, each one with 1 process and 2 gpus per process*: [shared 2 gpu script](./src/shared_array_2gpu.slurm)

The objective was to observe the NUMA package-to-GPU mapping scheduled by SLURM, measure the resulting bandwidth, and compare these metrics to the baseline established previously.

## Results and Discussion

TODO

## Resources

- https://slurm.schedmd.com/gres.html
- https://github.com/lncc-sered/manual-sdumont2nd
- https://github.com/jeffhammond/STREAM
- https://developer.nvidia.com/nvidia-hpc-benchmarks-downloads?target_os=Linux&target_arch=arm64-sbsa&Compilation=Native&Distribution=Agnostic&Implementation=OpenMPI
- https://catalog.ngc.nvidia.com/orgs/nvidia/containers/hpc-benchmarks
- https://nvidia.github.io/grace-cpu-benchmarking-guide/benchmarks/HPL/index.html
- https://docs.nvidia.com/nvidia-hpc-benchmarks/STREAM_Benchmark.html
- https://docs.nvidia.com/gh200-superchip-benchmark-guide.pdf#page=8.62
- https://www.nvidia.com/en-us/data-center/grace-hopper-superchip/
- https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/managing_monitoring_and_updating_the_kernel/assembly_configuring-cpu-affinity-and-numa-policies-using-systemd_managing-monitoring-and-updating-the-kernel
