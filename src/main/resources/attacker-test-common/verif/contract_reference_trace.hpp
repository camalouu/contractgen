#pragma once
// Diagnostic ABI only: observations come from RTL, never from Spike or a
// software instruction evaluator. Inactive during ordinary attacker batches.
#include <algorithm>
#include <array>
#include <cstdint>
#include <exception>
#include <cstdio>
#include <vector>
#include <deque>
namespace contract_reference_trace {
struct Capture {
    int bound, boot;
    const uint32_t* words;
    bool trapped = false;
    bool write_events = false;
    std::array<std::deque<uint32_t>,32> writes;
    std::array<unsigned,32> requested{};
    std::vector<uint32_t> pcs;
    std::array<uint32_t,32> registers{};
};
static thread_local Capture* active = nullptr;
template<class Run>
int collect(const uint32_t* words,int count,int cycles,uint32_t* pcs,uint32_t* regs,Run run,int boot=0,bool write_events=false) {
    if (!words || !pcs || !regs || count < 31 || cycles <= 0 || active) return -1;
    Capture capture{count,boot,words}; capture.write_events=write_events; capture.pcs.reserve(count);
    struct Scope { Scope(Capture* c) { active=c; } ~Scope() { active=nullptr; } } scope(&capture);
    try {
        const int status=run();
        for(unsigned rd=1;rd<32;++rd) if(capture.requested[rd]) capture.trapped=true;
        if (status != 0 || capture.trapped || int(capture.pcs.size())!=count) {
            std::fprintf(stderr,"RTL trace: status=%d trapped=%d captured=%zu requested=%d\n",status,capture.trapped,capture.pcs.size(),count);
            return -2;
        }
        std::copy(capture.pcs.begin(),capture.pcs.end(),pcs);
        std::copy(capture.registers.begin(),capture.registers.end(),regs);
        return 0;
    } catch (const std::exception&) { return -3; }
}
}
extern "C" void contract_reference_retire(int core_id,unsigned int pc,unsigned int instruction,int rd,unsigned int value,int trap) {
    auto* c=contract_reference_trace::active;
    if (!c || core_id!=1 || int(c->pcs.size())>=c->bound) return;
    if(c->boot) { --c->boot; return; }
    const uint32_t expected = pc>=0x80 && pc<0x2080 ? c->words[(pc-0x80)/4] : 0x13;
    if(instruction!=expected && !c->trapped) {
        std::fprintf(stderr,"RTL instruction mismatch pc=0x%x expected=0x%x actual=0x%x\n",pc,expected,instruction);
        c->trapped=true;
    }
    c->trapped |= trap!=0;
    c->pcs.push_back(pc);
    if(c->write_events) {
        const unsigned opcode=instruction&0x7f;
        const bool writer=opcode==0x03 || opcode==0x13 || opcode==0x17 || opcode==0x33 || opcode==0x37 || opcode==0x67 || opcode==0x6f;
        rd=writer ? (instruction>>7)&31 : 0;
        if(rd) {
            ++c->requested[rd];
            if(!c->writes[rd].empty()) {
                c->registers[rd]=c->writes[rd].front(); c->writes[rd].pop_front(); --c->requested[rd];
            }
        }
    } else if(rd>0 && rd<32) c->registers[rd]=value;
}

extern "C" void contract_reference_write(int core_id,int rd,unsigned int value) {
    auto* c=contract_reference_trace::active;
    if(!c || core_id!=1 || !c->write_events || rd<=0 || rd>=32) return;
    if(c->requested[rd]) { c->registers[rd]=value; --c->requested[rd]; }
    else c->writes[rd].push_back(value);
}
