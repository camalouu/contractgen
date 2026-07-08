#include "ibex_test_runtime.hpp"

#include "Vtop.h"
#include "verilated.h"

#include <cstdlib>
#include <fstream>
#include <memory>
#include <sstream>
#include <stdexcept>

namespace {

thread_local const IbexTestCaseImage* current_case = nullptr;

void load_hex_file(const std::string& path, std::array<uint32_t, kIbexTestMaxInstr>& program, int start) {
    std::ifstream in(path);
    if (!in) return;
    std::string line;
    int index = start;
    while (std::getline(in, line)) {
        if (line.empty()) continue;
        if (index >= kIbexTestMaxInstr) {
            throw std::runtime_error("legacy .dat program exceeds ibex-test instruction memory");
        }
        program[index++] = static_cast<uint32_t>(std::strtoull(line.c_str(), nullptr, 16));
    }
}

} // namespace

IbexTestCaseImage::IbexTestCaseImage() {
    program1.fill(kIbexTestNop);
    program2.fill(kIbexTestNop);
}

extern "C" int contract_ibex_instr_word(int core_id, int word_index) {
    if (current_case == nullptr || word_index < 0 || word_index >= kIbexTestMaxInstr) {
        return static_cast<int>(kIbexTestNop);
    }
    const auto& program = core_id == 2 ? current_case->program2 : current_case->program1;
    return static_cast<int>(program[static_cast<size_t>(word_index)]);
}

extern "C" int contract_ibex_max_instr_count() {
    if (current_case == nullptr || current_case->max_instr_count <= 0) {
        return 0;
    }
    return current_case->max_instr_count;
}

IbexTestStatus contract_ibex_run_case(const IbexTestCaseImage& test_case, int max_cycles) {
    current_case = &test_case;
    auto context = std::make_unique<VerilatedContext>();

    Vtop* top = new Vtop(context.get());
    IbexTestStatus status = IbexTestStatus::Timeout;
    const int cycles = max_cycles > 0 ? max_cycles : 10000;

    for (int i = 0; i < cycles; i++) {
        top->clk = 0;
        top->eval();
        if (top->finished_o || context->gotFinish()) {
            status = top->atk_equiv_o ? IbexTestStatus::Success : IbexTestStatus::Fail;
            break;
        }

        top->clk = 1;
        top->eval();
        if (top->finished_o || context->gotFinish()) {
            status = top->atk_equiv_o ? IbexTestStatus::Success : IbexTestStatus::Fail;
            break;
        }
    }

    top->final();
    delete top;
    current_case = nullptr;
    return status;
}

const char* contract_ibex_status_name(IbexTestStatus status) {
    switch (status) {
        case IbexTestStatus::Success:
            return "SUCCESS";
        case IbexTestStatus::Fail:
            return "FAIL";
        case IbexTestStatus::Timeout:
            return "TIMEOUT";
        case IbexTestStatus::Error:
        default:
            return "ERROR";
    }
}

void contract_ibex_load_legacy_dat_files(IbexTestCaseImage& test_case, const std::string& directory) {
    test_case.program1.fill(kIbexTestNop);
    test_case.program2.fill(kIbexTestNop);
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
