#pragma once

#include <array>
#include <cstdint>
#include <string>

constexpr int kIbexTestMaxInstr = 2048;
constexpr uint32_t kIbexTestNop = 0x00000013u;

struct IbexTestCaseImage {
    int ordinal = 0;
    int case_index = 0;
    int max_instr_count = 0;
    std::array<uint32_t, kIbexTestMaxInstr> program1{};
    std::array<uint32_t, kIbexTestMaxInstr> program2{};

    IbexTestCaseImage();
};

enum class IbexTestStatus {
    Success,
    Fail,
    Timeout,
    Error,
};

struct IbexTestRunResult {
    int ordinal = 0;
    int case_index = 0;
    IbexTestStatus status = IbexTestStatus::Error;
    bool attacker_distinguishable = false;
    int failure_cutoff = -1;
    int execution_cutoff = -1;
    std::string error;
};

IbexTestRunResult contract_ibex_run_case(const IbexTestCaseImage& test_case, int max_cycles);
const char* contract_ibex_status_name(IbexTestStatus status);

void contract_ibex_load_legacy_dat_files(IbexTestCaseImage& test_case, const std::string& directory);

extern "C" int contract_ibex_instr_word(int core_id, int word_index);
extern "C" int contract_ibex_max_instr_count();
