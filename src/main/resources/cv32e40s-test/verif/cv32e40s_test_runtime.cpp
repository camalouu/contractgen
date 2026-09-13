#include "cv32e40s_test_runtime.hpp"
#include "Vcv32e40s_test_top.h"
#include "verilated.h"

#include <algorithm>
#include <cstdio>
#include <exception>
#include <memory>

namespace {
thread_local const Cv32e40sCase* active_case = nullptr;

struct CaseScope {
    explicit CaseScope(const Cv32e40sCase& test) { active_case = &test; }
    ~CaseScope() { active_case = nullptr; }
};
}

extern "C" int contract_cv32e40s_instr_word(int core_id, int word_index) {
    if (!active_case || word_index < 0 || word_index >= kCv32e40sWords) {
        return kCv32e40sNop;
    }
    return static_cast<int>(
        (core_id == 2 ? active_case->program2 : active_case->program1)[word_index]);
}

Cv32e40sStatus cv32e40s_run(
    const Cv32e40sCase& test,
    int cycles,
    bool timing,
    bool inject_parity_error
) {
    if (test.max_instructions <= 0) return Cv32e40sStatus::Error;
    CaseScope scope(test);
    auto context = std::make_unique<VerilatedContext>();
    context->threads(1);
    auto top = std::make_unique<Vcv32e40s_test_top>(context.get());
    top->timing_i = timing;
    top->inject_parity_error_i = inject_parity_error;
    top->max_instr_i = test.max_instructions;

    // Generate an actual falling reset edge: hardened CSR cells behind closed
    // clock gates otherwise never see a clock/reset event in two-state simulation.
    top->clk = 0;
    top->rst_ni = 1;
    top->eval();
    top->rst_ni = 0;
    top->eval();
    for (int i = 0; i < 10; i++) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    }
    top->rst_ni = 1;

    Cv32e40sStatus status = Cv32e40sStatus::Timeout;
    for (int i = 0; i < (cycles > 0 ? cycles : 10000); i++) {
        bool done = false;
        for (int edge = 0; edge < 2; edge++) {
            top->clk = edge;
            top->eval();
            if (top->error_o) {
                std::fprintf(
                    stderr,
                    "CV32E40S error: flags=0x%x pc=0x%x cpuctrl=0x%x retire=%u\n",
                    top->error_code_o,
                    top->debug_pc_o,
                    top->debug_cpuctrl_o,
                    top->retire_count_o);
                status = Cv32e40sStatus::Error;
                done = true;
            } else if (top->finished_o) {
                status = top->atk_equiv_o
                    ? Cv32e40sStatus::Success
                    : Cv32e40sStatus::Fail;
                done = true;
            } else if (context->gotFinish()) {
                status = Cv32e40sStatus::Error;
                done = true;
            }
            if (done) break;
        }
        if (done) break;
    }
    top->final();
    return status;
}

extern "C" int contract_cv32e40s_test_attacker_batch_v1(
    int case_count,
    int max_cycles,
    int timing,
    const int* case_indices,
    const int* max_instruction_counts,
    const uint32_t* program1,
    const uint32_t* program2,
    int* statuses
) {
    if (case_count < 0 || (timing != 0 && timing != 1)) return -1;
    if (case_count == 0) return 0;
    if (!case_indices || !max_instruction_counts || !program1 || !program2 || !statuses) {
        return -1;
    }
    for (int i = 0; i < case_count; i++) {
        try {
            Cv32e40sCase test;
            test.max_instructions = max_instruction_counts[i];
            const size_t offset = static_cast<size_t>(i) * kCv32e40sWords;
            std::copy_n(program1 + offset, kCv32e40sWords, test.program1.begin());
            std::copy_n(program2 + offset, kCv32e40sWords, test.program2.begin());
            statuses[i] = static_cast<int>(cv32e40s_run(test, max_cycles, timing != 0));
        } catch (const std::exception&) {
            statuses[i] = static_cast<int>(Cv32e40sStatus::Error);
        }
    }
    return 0;
}
