#include "ibex_test_runtime.hpp"

#include "Vtop.h"
#include "verilated.h"

#include <algorithm>
#include <cstdlib>
#include <fstream>
#include <memory>
#include <sstream>
#include <stdexcept>

namespace {

thread_local const IbexTestCaseImage* current_case = nullptr;

struct SingleRunResult {
    IbexTestStatus status = IbexTestStatus::Timeout;
    int first_failure_fetch_1 = -1;
    int first_failure_fetch_2 = -1;
    int first_failure_retire = -1;
    int last_non_nop_retire = -1;
    int final_retire = 0;
};

void load_hex_file(const std::string& path, std::array<uint32_t, kIbexTestMaxInstr>& program, int start) {
    std::ifstream in(path);
    if (!in) return;
    std::string line;
    int index = start;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        if (index >= kIbexTestMaxInstr) {
            throw std::runtime_error("legacy .dat program exceeds ibex-test instruction memory");
        }
        program[index++] = static_cast<uint32_t>(std::strtoull(line.c_str(), nullptr, 16));
    }
}

SingleRunResult run_once(const IbexTestCaseImage& original_case, int instruction_bound, int max_cycles) {
    IbexTestCaseImage bounded_case = original_case;
    bounded_case.max_instr_count = instruction_bound;
    current_case = &bounded_case;

    auto context = std::make_unique<VerilatedContext>();
    Vtop* top = new Vtop(context.get());
    SingleRunResult result;
    const int cycles = max_cycles > 0 ? max_cycles : 10000;
    bool attacker_equivalent = true;

    auto observe_attacker = [&]() {
        const bool currently_equivalent = top->atk_equiv_o;
        if (attacker_equivalent && !currently_equivalent && result.first_failure_retire < 0) {
            result.first_failure_fetch_1 = static_cast<int>(top->fetch_1_count_o);
            result.first_failure_fetch_2 = static_cast<int>(top->fetch_2_count_o);
            result.first_failure_retire = static_cast<int>(top->retire_count_o);
        }
        attacker_equivalent = currently_equivalent;

        if (top->rvfi_valid_1_o && static_cast<uint32_t>(top->rvfi_insn_1_o) != kIbexTestNop) {
            result.last_non_nop_retire = std::max(
                    result.last_non_nop_retire, static_cast<int>(top->rvfi_order_1_o));
        }
        if (top->rvfi_valid_2_o && static_cast<uint32_t>(top->rvfi_insn_2_o) != kIbexTestNop) {
            result.last_non_nop_retire = std::max(
                    result.last_non_nop_retire, static_cast<int>(top->rvfi_order_2_o));
        }
    };

    for (int i = 0; i < cycles; i++) {
        top->clk = 0;
        top->eval();
        observe_attacker();
        if (top->finished_o || context->gotFinish()) {
            result.status = top->atk_equiv_o ? IbexTestStatus::Success : IbexTestStatus::Fail;
            break;
        }

        top->clk = 1;
        top->eval();
        observe_attacker();
        if (top->finished_o || context->gotFinish()) {
            result.status = top->atk_equiv_o ? IbexTestStatus::Success : IbexTestStatus::Fail;
            break;
        }
    }

    result.final_retire = static_cast<int>(top->retire_count_o);
    top->final();
    delete top;
    current_case = nullptr;
    return result;
}

} // namespace

IbexTestCaseImage::IbexTestCaseImage() {
    program1.fill(kIbexTestNop);
    program2.fill(kIbexTestNop);
}

extern "C" int contract_ibex_instr_word(int core_id, int word_index) {
    if (current_case == nullptr || word_index < 0 || word_index >= kIbexTestMaxInstr) {
        return static_cast<int>(kIbexTestNop);
    }
    const auto& program = core_id == 2 ? current_case->program2 : current_case->program1;
    return static_cast<int>(program[static_cast<size_t>(word_index)]);
}

extern "C" int contract_ibex_max_instr_count() {
    if (current_case == nullptr || current_case->max_instr_count <= 0) {
        return 0;
    }
    return current_case->max_instr_count;
}

IbexTestRunResult contract_ibex_run_case(const IbexTestCaseImage& test_case, int max_cycles) {
    IbexTestRunResult result;
    result.ordinal = test_case.ordinal;
    result.case_index = test_case.case_index;
    const SingleRunResult initial = run_once(test_case, test_case.max_instr_count, max_cycles);
    result.status = initial.status;
    result.attacker_distinguishable = result.status == IbexTestStatus::Fail;
    result.execution_cutoff = initial.last_non_nop_retire;
    if (!result.attacker_distinguishable) return result;

    if (initial.first_failure_fetch_1 < 0 || initial.first_failure_fetch_2 < 0 ||
        initial.first_failure_retire < 0) {
        result.status = IbexTestStatus::Error;
        result.attacker_distinguishable = false;
        result.error = "attacker failed without a recorded first-failure boundary";
        return result;
    }

    int current_guess = std::max(initial.first_failure_fetch_1, initial.first_failure_fetch_2);
    while (current_guess >= initial.first_failure_retire) {
        const SingleRunResult candidate = run_once(test_case, current_guess, max_cycles);
        if (candidate.status != IbexTestStatus::Fail) break;
        current_guess--;
    }

    // Match the historical IBEX.extractCTX flow: after finding the first bound
    // that does not fail, rerun once at the preceding (smallest failing) bound.
    const int minimized_bound = current_guess + 1;
    const SingleRunResult minimized = run_once(test_case, minimized_bound, max_cycles);
    if (minimized.status != IbexTestStatus::Fail) {
        result.status = IbexTestStatus::Error;
        result.attacker_distinguishable = false;
        result.error = "native attacker prefix minimization did not reproduce the failure";
        return result;
    }

    result.failure_cutoff = minimized.final_retire;
    return result;
}

const char* contract_ibex_status_name(IbexTestStatus status) {
    switch (status) {
        case IbexTestStatus::Success:
            return "SUCCESS";
        case IbexTestStatus::Fail:
            return "FAIL";
        case IbexTestStatus::Timeout:
            return "TIMEOUT";
        case IbexTestStatus::Error:
        default:
            return "ERROR";
    }
}

void contract_ibex_load_legacy_dat_files(IbexTestCaseImage& test_case, const std::string& directory) {
    test_case.program1.fill(kIbexTestNop);
    test_case.program2.fill(kIbexTestNop);
    load_hex_file(directory + "/init_1.dat", test_case.program1, 0);
    load_hex_file(directory + "/memory_1.dat", test_case.program1, 32);
    load_hex_file(directory + "/init_2.dat", test_case.program2, 0);
    load_hex_file(directory + "/memory_2.dat", test_case.program2, 32);

    std::ifstream count(directory + "/count.dat");
    std::string line;
    if (count && std::getline(count, line) && !line.empty()) {
        test_case.max_instr_count = static_cast<int>(std::strtoull(line.c_str(), nullptr, 16));
    }
}
