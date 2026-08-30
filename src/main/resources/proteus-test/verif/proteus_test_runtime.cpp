#include "proteus_test_runtime.hpp"

#include "Vtop.h"
#include "verilated.h"

#include <algorithm>
#include <memory>

namespace {

thread_local const ProteusTestCaseImage* current_case = nullptr;

struct SingleRunResult {
    ProteusTestStatus status = ProteusTestStatus::Timeout;
    int last_non_nop_retire = -1;
    int final_retire = 0;
};

SingleRunResult run_once(const ProteusTestCaseImage& original_case, int retirement_bound,
                         int max_cycles) {
    ProteusTestCaseImage bounded_case = original_case;
    bounded_case.max_instr_count = retirement_bound;
    current_case = &bounded_case;

    auto context = std::make_unique<VerilatedContext>();
    auto top = std::make_unique<Vtop>(context.get());
    SingleRunResult result;
    const int cycles = max_cycles > 0 ? max_cycles : 10000;

    auto observe = [&]() {
        if ((top->rvfi_valid_1_o && top->rvfi_trap_1_o) ||
            (top->rvfi_valid_2_o && top->rvfi_trap_2_o)) {
            result.status = ProteusTestStatus::Error;
            return false;
        }
        if (top->rvfi_valid_1_o && static_cast<uint32_t>(top->rvfi_insn_1_o) != kProteusTestNop) {
            result.last_non_nop_retire = std::max(
                result.last_non_nop_retire, static_cast<int>(top->rvfi_order_1_o) + 1);
        }
        if (top->rvfi_valid_2_o && static_cast<uint32_t>(top->rvfi_insn_2_o) != kProteusTestNop) {
            result.last_non_nop_retire = std::max(
                result.last_non_nop_retire, static_cast<int>(top->rvfi_order_2_o) + 1);
        }
        return true;
    };

    for (int cycle = 0; cycle < cycles; cycle++) {
        top->clk = 0;
        top->eval();
        if (!observe()) break;
        if (top->finished_o || context->gotFinish()) {
            result.status = top->atk_equiv_o ? ProteusTestStatus::Success : ProteusTestStatus::Fail;
            break;
        }

        top->clk = 1;
        top->eval();
        if (!observe()) break;
        if (top->finished_o || context->gotFinish()) {
            result.status = top->atk_equiv_o ? ProteusTestStatus::Success : ProteusTestStatus::Fail;
            break;
        }
    }

    result.final_retire = static_cast<int>(top->retire_count_o);
    top->final();
    current_case = nullptr;
    return result;
}

} // namespace

ProteusTestCaseImage::ProteusTestCaseImage() {
    program1.fill(kProteusTestNop);
    program2.fill(kProteusTestNop);
}

extern "C" int contract_proteus_instr_word(int core_id, int word_index) {
    if (current_case == nullptr || word_index < 0 || word_index >= kProteusTestMaxInstr)
        return static_cast<int>(kProteusTestNop);
    const auto& program = core_id == 2 ? current_case->program2 : current_case->program1;
    return static_cast<int>(program[static_cast<size_t>(word_index)]);
}

extern "C" int contract_proteus_max_instr_count() {
    return current_case == nullptr ? 0 : current_case->max_instr_count;
}

ProteusTestRunResult contract_proteus_run_case(const ProteusTestCaseImage& test_case,
                                                int max_cycles) {
    ProteusTestRunResult result;
    const SingleRunResult initial = run_once(test_case, test_case.max_instr_count, max_cycles);
    result.status = initial.status;
    result.execution_cutoff = initial.last_non_nop_retire;
    result.attacker_distinguishable = initial.status == ProteusTestStatus::Fail;
    if (!result.attacker_distinguishable) return result;

    int smallest_failing_bound = test_case.max_instr_count;
    for (int bound = test_case.max_instr_count - 1; bound > 0; bound--) {
        const SingleRunResult candidate = run_once(test_case, bound, max_cycles);
        if (candidate.status == ProteusTestStatus::Fail) {
            smallest_failing_bound = bound;
            continue;
        }
        if (candidate.status == ProteusTestStatus::Success) break;
        result.status = ProteusTestStatus::Error;
        result.attacker_distinguishable = false;
        return result;
    }

    const SingleRunResult minimized = run_once(test_case, smallest_failing_bound, max_cycles);
    if (minimized.status != ProteusTestStatus::Fail) {
        result.status = ProteusTestStatus::Error;
        result.attacker_distinguishable = false;
        return result;
    }
    result.failure_cutoff = minimized.final_retire;
    return result;
}
