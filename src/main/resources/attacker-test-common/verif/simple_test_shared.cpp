#include "simple_test_runtime.hpp"

#include <exception>

namespace {
int status_code(SimpleTestStatus status) {
    switch (status) {
        case SimpleTestStatus::Success: return 0;
        case SimpleTestStatus::Fail: return 1;
        case SimpleTestStatus::Timeout: return 2;
    }
    return 3;
}
}

extern "C" int contract_simple_attacker_batch_v1(
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
            SimpleTestCaseImage test_case;
            test_case.max_instr_count = max_instruction_counts[i];
            const int base = i * kSimpleTestMaxInstr;
            for (int word = 0; word < kSimpleTestMaxInstr; word++) {
                test_case.program1[static_cast<size_t>(word)] = program1[base + word];
                test_case.program2[static_cast<size_t>(word)] = program2[base + word];
            }
            statuses[i] = status_code(contract_simple_run_case(test_case, max_cycles));
        }
    } catch (const std::exception&) {
        for (int i = 0; i < case_count; i++) statuses[i] = 3;
        return -1;
    }
    return 0;
}
