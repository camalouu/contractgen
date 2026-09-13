#include "cv32e40s_test_runtime.hpp"

#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <string>

namespace {

constexpr int kProgramOffset = 32;

uint32_t i_type(uint32_t opcode, int rd, int funct3, int rs1, int imm) {
    return (static_cast<uint32_t>(imm) & 0xfffU) << 20 |
           (static_cast<uint32_t>(rs1) & 0x1fU) << 15 |
           (static_cast<uint32_t>(funct3) & 7U) << 12 |
           (static_cast<uint32_t>(rd) & 0x1fU) << 7 |
           opcode;
}

uint32_t r_type(int rd, int funct3, int rs1, int rs2, int funct7 = 0) {
    return (static_cast<uint32_t>(funct7) & 0x7fU) << 25 |
           (static_cast<uint32_t>(rs2) & 0x1fU) << 20 |
           (static_cast<uint32_t>(rs1) & 0x1fU) << 15 |
           (static_cast<uint32_t>(funct3) & 7U) << 12 |
           (static_cast<uint32_t>(rd) & 0x1fU) << 7 |
           0x33U;
}

uint32_t b_type(int funct3, int rs1, int rs2, int imm) {
    const uint32_t value = static_cast<uint32_t>(imm);
    return ((value >> 12) & 1U) << 31 |
           ((value >> 5) & 0x3fU) << 25 |
           (static_cast<uint32_t>(rs2) & 0x1fU) << 20 |
           (static_cast<uint32_t>(rs1) & 0x1fU) << 15 |
           (static_cast<uint32_t>(funct3) & 7U) << 12 |
           ((value >> 1) & 0xfU) << 8 |
           ((value >> 11) & 1U) << 7 |
           0x63U;
}

void init(Cv32e40sCase& test, int side, int reg, int value) {
    auto& image = side == 1 ? test.program1 : test.program2;
    image[reg - 1] = i_type(0x13, reg, 0, 0, value); // ADDI reg,x0,value
}

void put(Cv32e40sCase& test, int side, int offset, uint32_t instruction) {
    auto& image = side == 1 ? test.program1 : test.program2;
    image[kProgramOffset + offset] = instruction;
}

void expect(const std::string& name, Cv32e40sStatus expected, Cv32e40sStatus actual) {
    if (actual != expected) {
        std::cerr << name << ": expected " << static_cast<int>(expected)
                  << ", got " << static_cast<int>(actual) << '\n';
        std::exit(1);
    }
}

Cv32e40sCase identical_add() {
    Cv32e40sCase test;
    test.max_instructions = 34;
    init(test, 1, 1, 17);
    init(test, 2, 1, 17);
    put(test, 1, 0, r_type(2, 0, 1, 1));
    put(test, 2, 0, r_type(2, 0, 1, 1));
    return test;
}

Cv32e40sCase division_pair() {
    Cv32e40sCase test;
    test.max_instructions = 35;
    init(test, 1, 1, 100);
    init(test, 2, 1, 100);
    init(test, 1, 2, 1);
    init(test, 2, 2, 100);
    const uint32_t divu = r_type(3, 5, 1, 2, 1);
    put(test, 1, 0, divu);
    put(test, 2, 0, divu);
    return test;
}

Cv32e40sCase branch_pair() {
    Cv32e40sCase test;
    test.max_instructions = 36;
    init(test, 1, 1, 1);
    init(test, 2, 1, 1);
    init(test, 1, 2, 1);
    init(test, 2, 2, 2);
    const uint32_t beq = b_type(0, 1, 2, 8);
    put(test, 1, 0, beq);
    put(test, 2, 0, beq);
    return test;
}

Cv32e40sCase jalr_hazard_pair(bool gap) {
    Cv32e40sCase test;
    test.max_instructions = gap ? 37 : 36;
    put(test, 1, 0, i_type(0x13, 0, 7, 0, -4));       // ANDI x0,x0,-4
    put(test, 2, 0, i_type(0x13, 18, 7, 18, -4));     // ANDI x18,x18,-4
    const int jalr_offset = gap ? 2 : 1;
    put(test, 1, jalr_offset, i_type(0x67, 1, 0, 0, 512));
    put(test, 2, jalr_offset, i_type(0x67, 1, 0, 18, 512));
    return test;
}

} // namespace

int main() {
    auto identical = identical_add();
    expect("identical", Cv32e40sStatus::Success, cv32e40s_run(identical, 10000, false));
    expect("timeout", Cv32e40sStatus::Timeout, cv32e40s_run(identical, 1, false));

    auto division = division_pair();
    expect("division timing off", Cv32e40sStatus::Fail, cv32e40s_run(division, 10000, false));
    expect("division timing on", Cv32e40sStatus::Success, cv32e40s_run(division, 10000, true));

    auto branch = branch_pair();
    expect("branch timing off", Cv32e40sStatus::Fail, cv32e40s_run(branch, 10000, false));
    expect("branch timing on", Cv32e40sStatus::Success, cv32e40s_run(branch, 10000, true));

    auto jalr_hazard = jalr_hazard_pair(false);
    expect("JALR hazard timing off", Cv32e40sStatus::Fail, cv32e40s_run(jalr_hazard, 10000, false));
    expect("JALR hazard timing on", Cv32e40sStatus::Fail, cv32e40s_run(jalr_hazard, 10000, true));
    auto jalr_gap = jalr_hazard_pair(true);
    expect("JALR forwarding gap", Cv32e40sStatus::Success, cv32e40s_run(jalr_gap, 10000, true));

    Cv32e40sCase illegal;
    illegal.max_instructions = 34;
    put(illegal, 1, 0, 0xffffffffU);
    put(illegal, 2, 0, 0xffffffffU);
    expect("illegal instruction", Cv32e40sStatus::Error, cv32e40s_run(illegal, 10000, false));

    Cv32e40sCase alignment;
    alignment.max_instructions = 34;
    init(alignment, 1, 1, 2);
    init(alignment, 2, 1, 2);
    const uint32_t lh = i_type(0x03, 2, 1, 1, 0);
    put(alignment, 1, 0, lh);
    put(alignment, 2, 0, lh);
    expect("unsupported alignment", Cv32e40sStatus::Error, cv32e40s_run(alignment, 10000, false));

    expect("injected parity", Cv32e40sStatus::Error,
           cv32e40s_run(identical, 10000, false, true));

    std::cout << "CV32E40S native smoke tests passed\n";
    return 0;
}
