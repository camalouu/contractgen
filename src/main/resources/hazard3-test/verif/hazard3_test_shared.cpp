#include "hazard3_test_runtime.hpp"

#include <exception>

namespace {
int status_code(Hazard3TestStatus status) {
    switch (status) {
        case Hazard3TestStatus::Success: return 0;
        case Hazard3TestStatus::Fail: return 1;
        case Hazard3TestStatus::Timeout: return 2;
    }
    return 3;
}
}

extern "C" int contract_hazard3_test_attacker_batch(
    int case_count,
    int max_cycles,
    const int* case_indices,
    const int* max_instruction_counts,
    const unsigned int* program1,
    const unsigned int* program2,
    int* statuses
) {
    if (case_count < 0 || case_indices == nullptr || max_instruction_counts == nullptr ||
        program1 == nullptr || program2 == nullptr || statuses == nullptr) return -1;
    try {
        for (int i = 0; i < case_count; i++) {
            Hazard3TestCaseImage test_case;
            test_case.max_instr_count = max_instruction_counts[i];
            const int base = i * kHazard3TestMaxInstr;
            for (int word = 0; word < kHazard3TestMaxInstr; word++) {
                test_case.program1[static_cast<size_t>(word)] = program1[base + word];
                test_case.program2[static_cast<size_t>(word)] = program2[base + word];
            }
            statuses[i] = status_code(contract_hazard3_run_case(test_case, max_cycles));
        }
    } catch (const std::exception&) {
        for (int i = 0; i < case_count; i++) statuses[i] = 3;
        return -1;
    }
    return 0;
}
