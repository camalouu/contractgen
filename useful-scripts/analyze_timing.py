#!/usr/bin/env python3
"""
Analyze timing data from Icarus vs Verilator performance measurements.
"""

import csv
import statistics
from pathlib import Path

def load_timing_data(csv_path):
    """Load timing data from CSV file."""
    data = {
        'dat_write': [],
        'sim_execution': [],
        'vcd_read': [],
        'vcd_parse': [],
        'vcd_size': [],
        'total': []
    }
    
    with open(csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            data['dat_write'].append(float(row['dat_write_ms']))
            data['sim_execution'].append(float(row['sim_execution_ms']))
            data['vcd_read'].append(float(row['vcd_read_ms']))
            data['vcd_parse'].append(float(row['vcd_parse_ms']))
            data['vcd_size'].append(float(row['vcd_size_kb']))
            data['total'].append(float(row['total_ms']))
    
    return data

def compute_stats(values):
    """Compute statistics for a list of values."""
    return {
        'mean': statistics.mean(values),
        'median': statistics.median(values),
        'stdev': statistics.stdev(values) if len(values) > 1 else 0,
        'min': min(values),
        'max': max(values),
        'p95': statistics.quantiles(values, n=20)[18],  # 95th percentile
        'p99': statistics.quantiles(values, n=100)[98]   # 99th percentile
    }

def print_comparison(metric_name, icarus_stats, verilator_stats):
    """Print comparison table for a metric."""
    print(f"\n### {metric_name}")
    print("| Metric | Icarus | Verilator | Speedup |")
    print("|--------|--------|-----------|---------|")
    
    for stat in ['mean', 'median', 'p95', 'p99', 'min', 'max', 'stdev']:
        icarus_val = icarus_stats[stat]
        verilator_val = verilator_stats[stat]
        
        if verilator_val > 0 and stat in ['mean', 'median', 'p95', 'p99']:
            speedup = icarus_val / verilator_val
            print(f"| {stat.capitalize()} | {icarus_val:.2f}ms | {verilator_val:.2f}ms | {speedup:.2f}x |")
        else:
            print(f"| {stat.capitalize()} | {icarus_val:.2f}ms | {verilator_val:.2f}ms | - |")

def main():
    icarus_data = load_timing_data('/home/viktor/thesis/contract-synthesis/icarus_timing.csv')
    verilator_data = load_timing_data('/home/viktor/thesis/contract-synthesis/verilator_timing.csv')
    
    print("# Detailed Performance Analysis: Icarus vs Verilator")
    print(f"\n**Number of tests:** {len(icarus_data['total'])}")
    
    metrics = [
        ('Total Time', 'total'),
        ('Simulation Execution', 'sim_execution'),
        ('VCD Parsing', 'vcd_parse'),
        ('.dat File Writes', 'dat_write'),
        ('VCD File Read', 'vcd_read'),
        ('VCD File Size (KB)', 'vcd_size')
    ]
    
    for name, key in metrics:
        icarus_stats = compute_stats(icarus_data[key])
        verilator_stats = compute_stats(verilator_data[key])
        print_comparison(name, icarus_stats, verilator_stats)
    
    # Percentage breakdown
    print("\n\n## Percentage Breakdown (Mean)")
    print("| Component | Icarus | Verilator |")
    print("|-----------|--------|-----------|")
    
    icarus_total = statistics.mean(icarus_data['total'])
    verilator_total = statistics.mean(verilator_data['total'])
    
    components = [
        ('Simulation', 'sim_execution'),
        ('VCD Parse', 'vcd_parse'),
        ('.dat Write', 'dat_write'),
        ('VCD Read', 'vcd_read')
    ]
    
    for name, key in components:
        icarus_mean = statistics.mean(icarus_data[key])
        verilator_mean = statistics.mean(verilator_data[key])
        icarus_pct = (icarus_mean / icarus_total) * 100
        verilator_pct = (verilator_mean / verilator_total) * 100
        print(f"| {name} | {icarus_pct:.1f}% ({icarus_mean:.2f}ms) | {verilator_pct:.1f}% ({verilator_mean:.2f}ms) |")
    
    # Overall speedup
    print("\n\n## Overall Performance")
    speedup = icarus_total / verilator_total
    time_saved = icarus_total - verilator_total
    print(f"- **Overall Speedup:** {speedup:.2f}x")
    print(f"- **Time Saved per Test:** {time_saved:.2f}ms ({(time_saved/icarus_total)*100:.1f}%)")
    print(f"- **For 100,000 tests:**")
    print(f"  - Icarus: {(icarus_total * 100000 / 1000 / 60 / 60):.1f} hours")
    print(f"  - Verilator: {(verilator_total * 100000 / 1000 / 60 / 60):.1f} hours")
    print(f"  - **Time Saved: {((icarus_total - verilator_total) * 100000 / 1000 / 60 / 60):.1f} hours**")

if __name__ == '__main__':
    main()
