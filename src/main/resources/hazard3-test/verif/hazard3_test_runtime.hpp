#pragma once

#include <array>
#include <cstdint>

constexpr int kHazard3TestMaxInstr = 2048;
constexpr uint32_t kHazard3TestNop = 0x00000013u;

struct Hazard3TestCaseImage {
    int max_instr_count = 0;
    std::array<uint32_t, kHazard3TestMaxInstr> program1{};
    std::array<uint32_t, kHazard3TestMaxInstr> program2{};
    Hazard3TestCaseImage();
};

enum class Hazard3TestStatus { Success, Fail, Timeout };

Hazard3TestStatus contract_hazard3_run_case(const Hazard3TestCaseImage& test_case, int max_cycles);
extern "C" int contract_hazard3_instr_word(int core_id, int word_index);
extern "C" int contract_hazard3_max_instr_count();
