#!/usr/bin/env bash

cd /home/yosys/project
mvn package

# Final synthesis with 2,000,000 test cases using full refined template
# This matches the paper's final contract synthesis parameters
# Template includes all leakage types:
# BASE = IL (Instruction leakages), RL (Register leakages), ML (Memory leakages)
# ALIGNED = AL (Alignment leakages)
# BRANCH = BL (Branch leakages)
# DEPENDENCIES = DL (Data-dependency leakages)
java -cp target/contractgen-1.0-SNAPSHOT.jar contractgen.Main synthesize \
  -p IBEX \
  -i BASE,M \
  -c BASE,ALIGNED,BRANCH,DEPENDENCIES \
  -n 1000 \
  -t 8 \
  -s 12 \
  -o /home/yosys/project/1k-3times-no-reset.json \
  --multi 3 \
  --txt /home/yosys/project/1k-3times-no-reset.txt
