start_time=$(date +%s%N)

# ./riscv-isa-sim/build/contract-spike-diff --testcases 1000-IBEX-testcases.json --case-index 310
./riscv-isa-sim/build/contract-spike-diff \
    --testcases 100000-IBEX-full-testcases.json \
    --all
    # --case-index 10526 | jq

end_time=$(date +%s%N)

elapsed=$(( (end_time - start_time) / 1000000 ))
echo "Elapsed time: ${elapsed} ms"
