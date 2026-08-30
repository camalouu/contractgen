#include "hazard3_test_runtime.hpp"

#include "Vhazard3_test_top.h"
#include "verilated.h"

#include <memory>

namespace {
thread_local const Hazard3TestCaseImage* current_case = nullptr;
}

Hazard3TestCaseImage::Hazard3TestCaseImage() {
    program1.fill(kHazard3TestNop);
    program2.fill(kHazard3TestNop);
}

extern "C" int contract_hazard3_instr_word(int core_id, int word_index) {
    if (current_case == nullptr || word_index < 0 || word_index >= kHazard3TestMaxInstr) {
        return static_cast<int>(kHazard3TestNop);
    }
    const auto& program = core_id == 2 ? current_case->program2 : current_case->program1;
    return static_cast<int>(program[static_cast<size_t>(word_index)]);
}

extern "C" int contract_hazard3_max_instr_count() {
    return current_case == nullptr ? 0 : current_case->max_instr_count;
}

Hazard3TestStatus contract_hazard3_run_case(const Hazard3TestCaseImage& test_case, int max_cycles) {
    current_case = &test_case;
    auto context = std::make_unique<VerilatedContext>();
    auto top = std::make_unique<Vhazard3_test_top>(context.get());
    Hazard3TestStatus status = Hazard3TestStatus::Timeout;
    const int cycles = max_cycles > 0 ? max_cycles : 10000;

    top->rst_ni = 0;
    for (int i = 0; i < 10; i++) {
        top->clk = 0; top->eval();
        top->clk = 1; top->eval();
    }
    top->rst_ni = 1;

    for (int i = 0; i < cycles; i++) {
        top->clk = 0; top->eval();
        if (top->finished_o || context->gotFinish()) {
            status = top->atk_equiv_o ? Hazard3TestStatus::Success : Hazard3TestStatus::Fail;
            break;
        }
        top->clk = 1; top->eval();
        if (top->finished_o || context->gotFinish()) {
            status = top->atk_equiv_o ? Hazard3TestStatus::Success : Hazard3TestStatus::Fail;
            break;
        }
    }

    top->final();
    current_case = nullptr;
    return status;
}
