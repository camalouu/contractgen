#!/usr/bin/env python3
import sys
import time
from collections import Counter
from pathlib import Path

def main():
    if len(sys.argv) != 2:
        print("Usage: python analyze_inconsistent_signatures.py <result.json>")
        return
        
    file_path = Path(sys.argv[1])
    if not file_path.exists():
        print(f"File not found: {file_path}")
        return

    print(f"Analyzing {file_path} for inconsistent signatures...")
    
    # signature -> {'dist': count, 'non_dist': count}
    sig_stats = {}
    
    total_tests = 0
    current_atoms = []
    in_observations = False
    current_atom_type = None
    current_atom_obs = None
    
    t0 = time.time()
    
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            for line in f:
                stripped = line.strip()
                
                if stripped == '"observations": [':
                    in_observations = True
                    current_atoms = []
                elif in_observations:
                    if stripped == '],' or stripped == ']':
                        in_observations = False
                    elif stripped.startswith('"type":'):
                        parts = stripped.split('"')
                        if len(parts) >= 4:
                            current_atom_type = parts[3]
                    elif stripped.startswith('"observation":'):
                        parts = stripped.split('"')
                        if len(parts) >= 4:
                            current_atom_obs = parts[3]
                        if current_atom_type is not None and current_atom_obs is not None:
                            current_atoms.append((current_atom_type, current_atom_obs))
                            current_atom_type = None
                            current_atom_obs = None
                
                elif stripped.startswith('"adversaryDistinguishable":'):
                    is_distinguishable = "true" in stripped
                    
                    sig = tuple(sorted(set(current_atoms)))
                    
                    if sig not in sig_stats:
                        sig_stats[sig] = {'dist': 0, 'non_dist': 0}
                    
                    if is_distinguishable:
                        sig_stats[sig]['dist'] += 1
                    else:
                        sig_stats[sig]['non_dist'] += 1
                    
                    total_tests += 1
                    if total_tests % 100000 == 0:
                        print(f"Processed {total_tests} test cases... ({(time.time()-t0):.2f}s)")
    except Exception as exc:
        print(f"Error parsing file: {exc}")
        return
        
    print(f"\nFinished parsing in {time.time()-t0:.2f}s")
    print(f"Total test cases: {total_tests}")
    
    inconsistent = []
    for sig, stats in sig_stats.items():
        if stats['dist'] > 0 and stats['non_dist'] > 0:
            inconsistent.append((sig, stats))
            
    if not inconsistent:
        print("No inconsistent signatures found.")
    else:
        print(f"\nFound {len(inconsistent)} inconsistent signatures:")
        print("-" * 100)
        print(f"{'Dist':>8} | {'Non-Dist':>8} | {'Total':>8} | Signature")
        print("-" * 100)
        
        # Sort by total count descending
        inconsistent.sort(key=lambda x: x[1]['dist'] + x[1]['non_dist'], reverse=True)
        
        for sig, stats in inconsistent:
            dist = stats['dist']
            non_dist = stats['non_dist']
            total = dist + non_dist
            sig_text = ", ".join(f"{t}:{o}" for t, o in sig) if sig else "<empty>"
            print(f"{dist:8d} | {non_dist:8d} | {total:8d} | {sig_text}")

if __name__ == "__main__":
    main()
