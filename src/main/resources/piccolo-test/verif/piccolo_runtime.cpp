#include "simple_test_runtime.hpp"
#include "contract_reference_trace.hpp"
#include "axi_memory.hpp"
#include "Vpiccolo_test_top.h"
#include "verilated.h"
#include <memory>
#include <stdexcept>

SimpleTestCaseImage::SimpleTestCaseImage() { program1.fill(kSimpleTestNop); program2.fill(kSimpleTestNop); }
extern "C" int contract_simple_instr_word(int, int) { return kSimpleTestNop; }
extern "C" int contract_simple_max_instr_count() { return 0; }

namespace {
thread_local std::vector<uint32_t>* retirement_cycles = nullptr;
#define AXI_FIELDS(F) F(arvalid) F(arready) F(araddr) F(arid) F(arlen) F(arsize) F(arburst) \
 F(rvalid) F(rready) F(rdata) F(rid) F(rlast) F(awvalid) F(awready) F(awaddr) F(awid) \
 F(awlen) F(awsize) F(awburst) F(wvalid) F(wready) F(wdata) F(wstrb) F(wlast) F(bvalid) F(bready) F(bid)
#define AXI_OUTPUTS(F) F(arready) F(rvalid) F(rdata) F(rid) F(rlast) F(awready) F(wready) F(bvalid) F(bid)
struct Side {
    std::unique_ptr<VerilatedContext> context=std::make_unique<VerilatedContext>();
    std::unique_ptr<Vpiccolo_test_top> top=std::make_unique<Vpiccolo_test_top>(context.get());
    piccolo::AxiMemory imem{true}, dmem;
    explicit Side(const std::array<uint32_t,2048>& program) {
        for(unsigned w=0;w<2048;++w) for(unsigned b=0;b<4;++b)
            imem.store(0x80+w*4+b,uint8_t(program[w]>>(b*8)));
        top->clk=0; top->rst_n=0; top->reset_request=0; top->reset_response=0;
        for(int n=0;n<5;++n) edge(false);
        top->rst_n=1; top->eval();
    }
    void drive() {
        auto i=imem.outputs(), d=dmem.outputs();
#define DRIVE_I(f) top->i_##f=i.f;
#define DRIVE_D(f) top->d_##f=d.f;
        AXI_OUTPUTS(DRIVE_I) AXI_OUTPUTS(DRIVE_D)
        top->i_rresp=top->i_bresp=top->d_rresp=top->d_bresp=0;
    }
    void edge(bool memory=true) {
        Verilated::threadContextp(context.get());
        piccolo::AxiPins i,d;
        if(memory) {
#define READ_I(f) i.f=top->i_##f;
#define READ_D(f) d.f=top->d_##f;
            AXI_FIELDS(READ_I) AXI_FIELDS(READ_D)
        }
        top->clk=1; top->eval(); context->timeInc(1);
        if(memory) { imem.tick(i); dmem.tick(d); }
        top->clk=0; drive(); top->eval(); context->timeInc(1);
        if(context->gotFinish()) throw std::runtime_error("Piccolo premature termination");
    }
    void reset(int budget) {
        bool sent=false;
        for(int cycle=0;cycle<budget;++cycle) {
            top->reset_request=!sent && top->reset_ready;
            top->reset_response=top->reset_done;
            top->eval();
            bool done=top->reset_done;
            sent |= top->reset_request;
            edge();
            if(done && sent) { top->reset_request=0; top->reset_response=0; top->eval(); return; }
        }
        throw std::runtime_error("Piccolo reset handshake timed out");
    }
    ~Side() {
        Verilated::threadContextp(context.get());
        top->final();
        top.reset();
    }
};
}
SimpleTestStatus contract_simple_run_case(const SimpleTestCaseImage& test, int max_cycles) {
    if(test.max_instr_count<31 || test.max_instr_count>2048 || max_cycles<=0)
        throw std::invalid_argument("Invalid Piccolo testcase bounds");
    Side sides[2]={Side(test.program1),Side(test.program2)};
    for(auto& side:sides) side.reset(max_cycles);
    int retired=0; bool equivalent=true;
    for(int cycle=0;cycle<max_cycles;++cycle) {
        auto& a=*sides[0].top; auto& b=*sides[1].top;
        if(a.trap || b.trap) throw std::runtime_error("Piccolo architectural trap");
        bool ra=a.retire, rb=b.retire;
        equivalent &= ra==rb;
        if(ra && rb) {
            if(retirement_cycles) retirement_cycles->push_back(uint32_t(cycle));
            contract_reference_retire(1,a.pc,a.instruction,a.rd,a.value,0);
            contract_reference_retire(2,b.pc,b.instruction,b.rd,b.value,0);
            if(++retired==test.max_instr_count)
                return equivalent ? SimpleTestStatus::Success : SimpleTestStatus::Fail;
        }
        // Same paired-retirement synchronization as clk_sync: hold the side
        // ready to retire until its peer reaches the same retirement boundary.
        if(ra==rb || !ra) sides[0].edge();
        if(ra==rb || !rb) sides[1].edge();
    }
    return SimpleTestStatus::Timeout;
}
extern "C" int contract_architectural_trace_v1(const uint32_t* words,int count,int cycles,uint32_t* pcs,uint32_t* regs) {
    return contract_reference_trace::collect(words,count,cycles,pcs,regs,[&]() {
        SimpleTestCaseImage test; test.max_instr_count=count;
        std::copy(words,words+2048,test.program1.begin()); test.program2=test.program1;
        return static_cast<int>(contract_simple_run_case(test,cycles));
    });
}

// Piccolo-only diagnostic: enabled retirement cycles of an identical pair.
extern "C" int contract_piccolo_retirement_cycles_v1(const uint32_t* words,int count,int cycles,uint32_t* captured) {
    if(!words || !captured || count<31 || count>2048 || cycles<=0 || retirement_cycles) return -1;
    std::vector<uint32_t> result;
    struct Scope {
        explicit Scope(std::vector<uint32_t>* result) { retirement_cycles=result; }
        ~Scope() { retirement_cycles=nullptr; }
    } scope(&result);
    try {
        SimpleTestCaseImage test; test.max_instr_count=count;
        std::copy(words,words+2048,test.program1.begin()); test.program2=test.program1;
        if(contract_simple_run_case(test,cycles)!=SimpleTestStatus::Success || int(result.size())!=count) return -2;
        std::copy(result.begin(),result.end(),captured);
        return 0;
    } catch(const std::exception&) { return -3; }
}
