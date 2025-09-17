# sdumont II partitioning

GPU sharing and partitioning experiments made in the [SDumont HPC Cluster](https://sdumont.lncc.br).

## Hardware

The tests were executed in 2 queues: `lncc-gh200` and `lncc-gh200_shared`, Both with [GH200](https://www.nvidia.com/en-us/data-center/grace-hopper-superchip). The former is an _exclusive queue_, meaning that allocating a job implies in the full reservation of the node for the time needed to complete it, while the latter is a _shared one_, using the [Generic Resource (GRES) Scheduling](https://slurm.schedmd.com/gres.html) scheme to share resources (GPUS, CPUS, ...) amongst jobs [*].

- *: Each job can take at most half of each type of resource. For example, each Node has 4 gpus, so a job can take at most 2 of them.

The following illustrate the topology of each GH200 node:

![topo](./doc/img/exclusive.svg)
