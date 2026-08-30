#pragma once

#include <array>
#include <cstdint>

constexpr int kProteusTestMaxInstr = 2048;
constexpr uint32_t kProteusTestNop = 0x00000013u;

struct ProteusTestCaseImage {
    int max_instr_count = 0;
    std::array<uint32_t, kProteusTestMaxInstr> program1{};
    std::array<uint32_t, kProteusTestMaxInstr> program2{};
    ProteusTestCaseImage();
};

enum class ProteusTestStatus { Success, Fail, Timeout, Error };

struct ProteusTestRunResult {
    ProteusTestStatus status = ProteusTestStatus::Error;
    bool attacker_distinguishable = false;
    int failure_cutoff = -1;
    int execution_cutoff = -1;
};

ProteusTestRunResult contract_proteus_run_case(const ProteusTestCaseImage& test_case, int max_cycles);

extern "C" int contract_proteus_instr_word(int core_id, int word_index);
extern "C" int contract_proteus_max_instr_count();
