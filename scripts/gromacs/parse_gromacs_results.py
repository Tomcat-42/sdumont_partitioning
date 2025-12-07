#!/usr/bin/env python3
"""
GROMACS Benchmark Results Parser

Extracts performance metrics from GROMACS mdrun output logs.
Outputs structured data for analysis in the Jupyter notebook.
"""

import re
import json
import argparse
from pathlib import Path


def parse_gromacs_log(filepath: Path) -> dict:
    """Parse a single GROMACS output log file."""
    content = filepath.read_text()
    result = {
        'file': filepath.name,
        'type': 'exclusive' if 'exclusive' in filepath.name else 'shared',
        'numa_node': None,
        'task_id': None,
        'gpu_id': None,
        'performance_ns_day': None,
        'wall_time_s': None,
        'core_time_s': None,
    }

    # Extract NUMA node (exclusive) or task ID (shared)
    if 'exclusive' in filepath.name:
        match = re.search(r'exclusive_numa(\d+)', filepath.name)
        if match:
            result['numa_node'] = int(match.group(1))
    else:
        match = re.search(r'shared_task(\d+)', filepath.name)
        if match:
            result['task_id'] = int(match.group(1))

    # Extract NUMA binding from numactl --show
    numa_match = re.search(r'cpubind:\s*(\d+)', content)
    if numa_match:
        result['numa_node'] = int(numa_match.group(1))

    # Extract GPU ID
    gpu_match = re.search(r'CUDA_VISIBLE_DEVICES:\s*(\d+)', content)
    if gpu_match:
        result['gpu_id'] = int(gpu_match.group(1))

    # Extract performance (ns/day) from GROMACS output
    # Pattern: "Performance:    X.XXX    ns/day"
    perf_match = re.search(r'Performance:\s+([\d.]+)\s+ns/day', content)
    if perf_match:
        result['performance_ns_day'] = float(perf_match.group(1))

    # Alternative pattern for newer GROMACS versions
    if result['performance_ns_day'] is None:
        perf_match = re.search(r'([\d.]+)\s+ns/day', content)
        if perf_match:
            result['performance_ns_day'] = float(perf_match.group(1))

    # Extract wall time
    wall_match = re.search(r'Time:\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)', content)
    if wall_match:
        result['wall_time_s'] = float(wall_match.group(2))
        result['core_time_s'] = float(wall_match.group(1))

    # Extract from "Finished mdrun" timing line
    finished_match = re.search(r'Finished mdrun.*\n.*wall\s+([\d.]+)\s+s', content, re.MULTILINE)
    if finished_match:
        result['wall_time_s'] = float(finished_match.group(1))

    return result


def parse_all_results(data_dir: Path) -> list:
    """Parse all GROMACS log files in the data directory."""
    results = []

    for pattern in ['exclusive_numa*.log', 'shared_task*.log']:
        for filepath in sorted(data_dir.glob(pattern)):
            try:
                result = parse_gromacs_log(filepath)
                results.append(result)
                print(f"Parsed: {filepath.name}")
            except Exception as e:
                print(f"Error parsing {filepath.name}: {e}")

    return results


def print_summary(results: list):
    """Print a summary table of results."""
    if not results:
        print("No results found.")
        return

    print("\n" + "=" * 70)
    print("GROMACS Benchmark Results Summary")
    print("=" * 70)

    # Separate exclusive and shared results
    exclusive = [r for r in results if r['type'] == 'exclusive']
    shared = [r for r in results if r['type'] == 'shared']

    if exclusive:
        print("\n--- Exclusive Queue (NUMA Pinned) ---")
        print(f"{'NUMA':<6} {'GPU':<5} {'ns/day':<12} {'Wall Time (s)':<15}")
        print("-" * 40)
        for r in sorted(exclusive, key=lambda x: x['numa_node'] or 0):
            numa = r['numa_node'] if r['numa_node'] is not None else 'N/A'
            gpu = r['gpu_id'] if r['gpu_id'] is not None else 'N/A'
            perf = f"{r['performance_ns_day']:.3f}" if r['performance_ns_day'] else 'N/A'
            wall = f"{r['wall_time_s']:.1f}" if r['wall_time_s'] else 'N/A'
            print(f"{numa:<6} {gpu:<5} {perf:<12} {wall:<15}")

        perfs = [r['performance_ns_day'] for r in exclusive if r['performance_ns_day']]
        if perfs:
            print(f"\nAverage: {sum(perfs)/len(perfs):.3f} ns/day")

    if shared:
        print("\n--- Shared Queue (SLURM Scheduled) ---")
        print(f"{'Task':<6} {'NUMA':<6} {'GPU':<5} {'ns/day':<12} {'Wall Time (s)':<15}")
        print("-" * 50)
        for r in sorted(shared, key=lambda x: x['task_id'] or 0):
            task = r['task_id'] if r['task_id'] is not None else 'N/A'
            numa = r['numa_node'] if r['numa_node'] is not None else 'N/A'
            gpu = r['gpu_id'] if r['gpu_id'] is not None else 'N/A'
            perf = f"{r['performance_ns_day']:.3f}" if r['performance_ns_day'] else 'N/A'
            wall = f"{r['wall_time_s']:.1f}" if r['wall_time_s'] else 'N/A'
            print(f"{task:<6} {numa:<6} {gpu:<5} {perf:<12} {wall:<15}")

        perfs = [r['performance_ns_day'] for r in shared if r['performance_ns_day']]
        if perfs:
            print(f"\nAverage: {sum(perfs)/len(perfs):.3f} ns/day")

    print("\n" + "=" * 70)


def main():
    parser = argparse.ArgumentParser(description='Parse GROMACS benchmark results')
    parser.add_argument('--data-dir', type=Path,
                        default=Path(__file__).parent.parent.parent / 'data' / 'gromacs',
                        help='Directory containing GROMACS log files')
    parser.add_argument('--output', type=Path, help='Output JSON file for results')
    parser.add_argument('--quiet', action='store_true', help='Suppress file-by-file output')

    args = parser.parse_args()

    if not args.data_dir.exists():
        print(f"Data directory not found: {args.data_dir}")
        print("Run the GROMACS benchmarks first to generate results.")
        return

    results = parse_all_results(args.data_dir)

    if not args.quiet:
        print_summary(results)

    if args.output:
        args.output.write_text(json.dumps(results, indent=2))
        print(f"\nResults saved to: {args.output}")


if __name__ == '__main__':
    main()
