#pragma once

#include <array>
#include <cstdint>

constexpr int kCv32e40sWords = 2048;
constexpr uint32_t kCv32e40sNop = 0x13;

enum class Cv32e40sStatus { Success = 0, Fail = 1, Timeout = 2, Error = 3 };

struct Cv32e40sCase {
    int max_instructions = 0;
    std::array<uint32_t, kCv32e40sWords> program1{}, program2{};
    Cv32e40sCase() { program1.fill(kCv32e40sNop); program2.fill(kCv32e40sNop); }
};

Cv32e40sStatus cv32e40s_run(
    const Cv32e40sCase& test,
    int cycles,
    bool timing,
    bool inject_parity_error = false
);

extern "C" int contract_cv32e40s_test_attacker_batch_v1(
    int case_count,
    int max_cycles,
    int timing,
    const int* case_indices,
    const int* max_instruction_counts,
    const uint32_t* program1,
    const uint32_t* program2,
    int* statuses
);
