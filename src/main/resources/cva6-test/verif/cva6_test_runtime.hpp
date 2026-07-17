#pragma once

#include <array>
#include <cstdint>
#include <string>

constexpr int kCva6TestMaxInstr = 2048;
constexpr uint32_t kCva6TestNop = 0x00000013u;

struct Cva6TestCaseImage {
    int ordinal = 0;
    int case_index = 0;
    int max_instr_count = 0;
    std::array<uint32_t, kCva6TestMaxInstr> program1{};
    std::array<uint32_t, kCva6TestMaxInstr> program2{};

    Cva6TestCaseImage();
};

enum class Cva6TestStatus {
    Success,
    Fail,
    Timeout,
    Error,
};

Cva6TestStatus contract_cva6_run_case(const Cva6TestCaseImage& test_case, int max_cycles);
const char* contract_cva6_status_name(Cva6TestStatus status);
void contract_cva6_load_legacy_dat_files(Cva6TestCaseImage& test_case, const std::string& directory);

extern "C" int contract_cva6_instr_word(int core_id, int word_index);
extern "C" int contract_cva6_max_instr_count();
