#include "simple_test_runtime.hpp"

#include "Vsodor_test_top.h"
#include "verilated.h"

#include <memory>

namespace {
thread_local const SimpleTestCaseImage* current_case = nullptr;
}

SimpleTestCaseImage::SimpleTestCaseImage() {
    program1.fill(kSimpleTestNop);
    program2.fill(kSimpleTestNop);
}

extern "C" int contract_simple_instr_word(int core_id, int word_index) {
    if (current_case == nullptr || word_index < 0 || word_index >= kSimpleTestMaxInstr) {
        return static_cast<int>(kSimpleTestNop);
    }
    const auto& program = core_id == 2 ? current_case->program2 : current_case->program1;
    return static_cast<int>(program[static_cast<size_t>(word_index)]);
}

extern "C" int contract_simple_max_instr_count() {
    return current_case == nullptr ? 0 : current_case->max_instr_count;
}

SimpleTestStatus contract_simple_run_case(const SimpleTestCaseImage& test_case, int max_cycles) {
    current_case = &test_case;
    auto context = std::make_unique<VerilatedContext>();
    auto top = std::make_unique<Vsodor_test_top>(context.get());
    SimpleTestStatus status = SimpleTestStatus::Timeout;
    const int cycles = max_cycles > 0 ? max_cycles : 10000;

    top->reset = 1;
    for (int cycle = 0; cycle < 10; cycle++) {
        top->clk = 0; top->eval(); context->timeInc(1);
        top->clk = 1; top->eval(); context->timeInc(1);
    }
    top->reset = 0;

    for (int cycle = 0; cycle < cycles; cycle++) {
        top->clk = 0;
        top->eval();
        context->timeInc(1);
        if (top->finished_o || context->gotFinish()) {
            status = top->atk_equiv_o ? SimpleTestStatus::Success : SimpleTestStatus::Fail;
            break;
        }
        top->clk = 1;
        top->eval();
        context->timeInc(1);
        if (top->finished_o || context->gotFinish()) {
            status = top->atk_equiv_o ? SimpleTestStatus::Success : SimpleTestStatus::Fail;
            break;
        }
    }

    top->final();
    current_case = nullptr;
    return status;
}
