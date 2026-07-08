#include "ibex_test_runtime.hpp"

#include <exception>

namespace {

int status_code(IbexTestStatus status) {
    switch (status) {
        case IbexTestStatus::Success:
            return 0;
        case IbexTestStatus::Fail:
            return 1;
        case IbexTestStatus::Timeout:
            return 2;
        case IbexTestStatus::Error:
        default:
            return 3;
    }
}

} // namespace

extern "C" int contract_ibex_test_attacker_batch(
    int case_count,
    int max_cycles,
    const int* case_indices,
    const int* max_instruction_counts,
    const unsigned int* program1,
    const unsigned int* program2,
    int* statuses
) {
    try {
        if (case_count < 0 || case_indices == nullptr || max_instruction_counts == nullptr ||
            program1 == nullptr || program2 == nullptr || statuses == nullptr) {
            return -1;
        }
        for (int i = 0; i < case_count; i++) {
            IbexTestCaseImage test_case;
            test_case.ordinal = i;
            test_case.case_index = case_indices[i];
            test_case.max_instr_count = max_instruction_counts[i];
            const int base = i * kIbexTestMaxInstr;
            for (int word = 0; word < kIbexTestMaxInstr; word++) {
                test_case.program1[static_cast<size_t>(word)] = program1[base + word];
                test_case.program2[static_cast<size_t>(word)] = program2[base + word];
            }
            IbexTestStatus status = contract_ibex_run_case(test_case, max_cycles);
            statuses[i] = status_code(status);
        }
    } catch (const std::exception& e) {
        for (int i = 0; i < case_count; i++) {
            statuses[i] = status_code(IbexTestStatus::Error);
        }
        return -1;
    }
    return 0;
}
