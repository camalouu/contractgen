#pragma once

#include <array>
#include <cstdint>

constexpr int kSimpleTestMaxInstr = 2048;
constexpr uint32_t kSimpleTestNop = 0x00000013u;

struct SimpleTestCaseImage {
    int max_instr_count = 0;
    std::array<uint32_t, kSimpleTestMaxInstr> program1{};
    std::array<uint32_t, kSimpleTestMaxInstr> program2{};
    SimpleTestCaseImage();
};

enum class SimpleTestStatus { Success, Fail, Timeout };

SimpleTestStatus contract_simple_run_case(const SimpleTestCaseImage& test_case, int max_cycles);
extern "C" int contract_simple_instr_word(int core_id, int word_index);
extern "C" int contract_simple_max_instr_count();
