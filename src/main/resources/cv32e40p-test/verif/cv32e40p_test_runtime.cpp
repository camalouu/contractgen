#include "contract_reference_trace.hpp"
#include "simple_test_runtime.hpp"
#include "Vcv32e40p_test_top.h"
#include "verilated.h"
#include <memory>

namespace { thread_local const SimpleTestCaseImage* current_case = nullptr; }

SimpleTestCaseImage::SimpleTestCaseImage() {
    program1.fill(kSimpleTestNop); program2.fill(kSimpleTestNop);
}
extern "C" int contract_simple_instr_word(int core_id, int word_index) {
    if (!current_case || word_index < 0 || word_index >= kSimpleTestMaxInstr)
        return static_cast<int>(kSimpleTestNop);
    const auto& program = core_id == 2 ? current_case->program2 : current_case->program1;
    return static_cast<int>(program[static_cast<size_t>(word_index)]);
}
extern "C" int contract_simple_max_instr_count() {
    return current_case ? current_case->max_instr_count : 0;
}
SimpleTestStatus contract_simple_run_case(const SimpleTestCaseImage& test_case, int max_cycles) {
    current_case = &test_case;
    auto context = std::make_unique<VerilatedContext>();
    auto top = std::make_unique<Vcv32e40p_test_top>(context.get());
    SimpleTestStatus status = SimpleTestStatus::Timeout;
    const int cycles = max_cycles > 0 ? max_cycles : 10000;
    // Honor the official RVFI monitor's delayed sampling and timed events.
    auto edge = [&](int value) {
        top->clk=value; top->eval();
        const uint64_t target=context->time()+5000;
        while(top->eventsPending() && top->nextTimeSlot()<=target) {
            context->time(top->nextTimeSlot()); top->eval();
        }
        context->time(target); top->eval();
    };
    top->rst_ni = 0;
    for (int i=0;i<10;i++) { edge(0); edge(1); }
    top->rst_ni = 1;
    for(int i=0;i<cycles;i++) {
        edge(0);
        if(top->finished_o || context->gotFinish()) { status=top->atk_equiv_o ? SimpleTestStatus::Success : SimpleTestStatus::Fail; break; }
        edge(1);
        if(top->finished_o || context->gotFinish()) { status=top->atk_equiv_o ? SimpleTestStatus::Success : SimpleTestStatus::Fail; break; }
    }
    top->final(); current_case = nullptr; return status;
}

extern "C" int contract_architectural_trace_v1(const uint32_t* words, int count, int max_cycles,
                                                  uint32_t* pcs, uint32_t* registers) {
    return contract_reference_trace::collect(words,count,max_cycles,pcs,registers,[&]() {
        SimpleTestCaseImage test; test.max_instr_count=count;
        std::copy(words,words+2048,test.program1.begin()); test.program2=test.program1;
        return static_cast<int>(contract_simple_run_case(test, max_cycles));
    },0);
}
