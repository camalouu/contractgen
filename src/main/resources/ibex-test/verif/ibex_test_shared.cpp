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

extern "C" int contract_ibex_test_attacker_batch_v4(
    int case_count,
    int max_cycles,
    const int* case_indices,
    const int* max_instruction_counts,
    const unsigned int* program1,
    const unsigned int* program2,
    int* statuses,
    int* failure_cutoffs,
    int* execution_cutoffs
) {
    try {
        if (case_count < 0 || case_indices == nullptr || max_instruction_counts == nullptr ||
            program1 == nullptr || program2 == nullptr || statuses == nullptr || failure_cutoffs == nullptr ||
            execution_cutoffs == nullptr) {
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
            IbexTestRunResult result = contract_ibex_run_case(test_case, max_cycles);
            statuses[i] = status_code(result.status);
            failure_cutoffs[i] = result.failure_cutoff;
            execution_cutoffs[i] = result.execution_cutoff;
        }
    } catch (const std::exception& e) {
        for (int i = 0; i < case_count; i++) {
            statuses[i] = status_code(IbexTestStatus::Error);
            failure_cutoffs[i] = -1;
            execution_cutoffs[i] = -1;
        }
        return -1;
    }
    return 0;
}

// Benchmark entry point: use the same model and file parser as the compatibility
// executable, while allowing a long-lived caller to retain the library.
extern "C" int contract_ibex_test_attacker_file_v1(
    const char* directory, int max_cycles, int* status,
    int* failure_cutoff, int* execution_cutoff
) {
    if (directory == nullptr || status == nullptr || failure_cutoff == nullptr ||
        execution_cutoff == nullptr) return -1;
    try {
        IbexTestCaseImage test_case;
        contract_ibex_load_legacy_dat_files(test_case, directory);
        const IbexTestRunResult result = contract_ibex_run_case(test_case, max_cycles);
        *status = status_code(result.status);
        *failure_cutoff = result.failure_cutoff;
        *execution_cutoff = result.execution_cutoff;
        return 0;
    } catch (const std::exception&) {
        *status = status_code(IbexTestStatus::Error);
        *failure_cutoff = -1;
        *execution_cutoff = -1;
        return -1;
    }
}
