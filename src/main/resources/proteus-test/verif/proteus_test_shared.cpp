#include "proteus_test_runtime.hpp"

#include <exception>

namespace {
int status_code(ProteusTestStatus status) {
    switch (status) {
        case ProteusTestStatus::Success: return 0;
        case ProteusTestStatus::Fail: return 1;
        case ProteusTestStatus::Timeout: return 2;
        case ProteusTestStatus::Error: default: return 3;
    }
}
}

extern "C" int contract_proteus_test_attacker_batch_v1(
    int case_count, int max_cycles, const int* case_indices,
    const int* max_instruction_counts, const unsigned int* program1,
    const unsigned int* program2, int* statuses, int* failure_cutoffs,
    int* execution_cutoffs) {
    if (case_count < 0 || case_indices == nullptr || max_instruction_counts == nullptr ||
        program1 == nullptr || program2 == nullptr || statuses == nullptr ||
        failure_cutoffs == nullptr || execution_cutoffs == nullptr) return -1;
    try {
        for (int i = 0; i < case_count; i++) {
            ProteusTestCaseImage test_case;
            test_case.max_instr_count = max_instruction_counts[i];
            const int base = i * kProteusTestMaxInstr;
            for (int word = 0; word < kProteusTestMaxInstr; word++) {
                test_case.program1[static_cast<size_t>(word)] = program1[base + word];
                test_case.program2[static_cast<size_t>(word)] = program2[base + word];
            }
            const ProteusTestRunResult result = contract_proteus_run_case(test_case, max_cycles);
            statuses[i] = status_code(result.status);
            failure_cutoffs[i] = result.failure_cutoff;
            execution_cutoffs[i] = result.execution_cutoff;
        }
    } catch (const std::exception&) {
        for (int i = 0; i < case_count; i++) {
            statuses[i] = 3;
            failure_cutoffs[i] = -1;
            execution_cutoffs[i] = -1;
        }
        return -1;
    }
    return 0;
}
