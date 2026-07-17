#include "cva6_test_runtime.hpp"

#include "Vtop.h"
#include "verilated.h"

#include <cstdlib>
#include <fstream>
#include <memory>
#include <sstream>
#include <stdexcept>

namespace {

thread_local const Cva6TestCaseImage* current_case = nullptr;

void load_hex_file(const std::string& path, std::array<uint32_t, kCva6TestMaxInstr>& program, int start) {
    std::ifstream in(path);
    if (!in) return;
    std::string line;
    int index = start;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        if (index >= kCva6TestMaxInstr) {
            throw std::runtime_error("legacy .dat program exceeds cva6-test instruction memory");
        }
        program[index++] = static_cast<uint32_t>(std::strtoull(line.c_str(), nullptr, 16));
    }
}

} // namespace

Cva6TestCaseImage::Cva6TestCaseImage() {
    program1.fill(kCva6TestNop);
    program2.fill(kCva6TestNop);
}

extern "C" int contract_cva6_instr_word(int core_id, int word_index) {
    if (current_case == nullptr || word_index < 0 || word_index >= kCva6TestMaxInstr) {
        return static_cast<int>(kCva6TestNop);
    }
    const auto& program = core_id == 2 ? current_case->program2 : current_case->program1;
    return static_cast<int>(program[static_cast<size_t>(word_index)]);
}

extern "C" int contract_cva6_max_instr_count() {
    if (current_case == nullptr || current_case->max_instr_count <= 0) {
        return 0;
    }
    return current_case->max_instr_count;
}

Cva6TestStatus contract_cva6_run_case(const Cva6TestCaseImage& test_case, int max_cycles) {
    current_case = &test_case;
    auto context = std::make_unique<VerilatedContext>();

    Vtop* top = new Vtop(context.get());
    Cva6TestStatus status = Cva6TestStatus::Timeout;
    const int cycles = max_cycles > 0 ? max_cycles : 10000;

    top->rst_ni = 0;
    for (int i = 0; i < 10; i++) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    }
    top->rst_ni = 1;

    for (int i = 0; i < cycles; i++) {
        top->clk = 0;
        top->eval();
        if (top->trap_o || context->gotFinish()) {
            status = top->trap_o ? Cva6TestStatus::Error : (top->atk_equiv_o ? Cva6TestStatus::Success : Cva6TestStatus::Fail);
            break;
        }
        if (top->finished_o) {
            status = top->atk_equiv_o ? Cva6TestStatus::Success : Cva6TestStatus::Fail;
            break;
        }

        top->clk = 1;
        top->eval();
        if (top->trap_o || context->gotFinish()) {
            status = top->trap_o ? Cva6TestStatus::Error : (top->atk_equiv_o ? Cva6TestStatus::Success : Cva6TestStatus::Fail);
            break;
        }
        if (top->finished_o) {
            status = top->atk_equiv_o ? Cva6TestStatus::Success : Cva6TestStatus::Fail;
            break;
        }
    }

    top->final();
    delete top;
    current_case = nullptr;
    return status;
}

const char* contract_cva6_status_name(Cva6TestStatus status) {
    switch (status) {
        case Cva6TestStatus::Success:
            return "SUCCESS";
        case Cva6TestStatus::Fail:
            return "FAIL";
        case Cva6TestStatus::Timeout:
            return "TIMEOUT";
        case Cva6TestStatus::Error:
        default:
            return "ERROR";
    }
}

void contract_cva6_load_legacy_dat_files(Cva6TestCaseImage& test_case, const std::string& directory) {
    test_case.program1.fill(kCva6TestNop);
    test_case.program2.fill(kCva6TestNop);
    load_hex_file(directory + "/init_1.dat", test_case.program1, 0);
    load_hex_file(directory + "/memory_1.dat", test_case.program1, 32);
    load_hex_file(directory + "/init_2.dat", test_case.program2, 0);
    load_hex_file(directory + "/memory_2.dat", test_case.program2, 32);

    std::ifstream count(directory + "/count.dat");
    std::string line;
    if (count && std::getline(count, line) && !line.empty()) {
        test_case.max_instr_count = static_cast<int>(std::strtoull(line.c_str(), nullptr, 16));
    }
}
