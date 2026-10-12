// Compare the paired clock-hold scheduler with two independently clocked tiles.
// This driver never holds a clock and records absolute retirement cycles.
#include "rocket_test_runtime.hpp"
#include "VContractRocket.h"
#include "verilated.h"
#include <cassert>
#include <iostream>
#include <memory>
#include <random>
using namespace contract_rocket;
using Image = std::array<uint32_t, image_words>;
struct Trace { std::vector<unsigned> cycles; std::vector<uint32_t> pcs; };

Request request(const VContractRocket& t) {
    Request r;
    r.a_valid=t.tl_a_valid; r.a_opcode=t.tl_a_bits_opcode; r.a_param=t.tl_a_bits_param;
    r.a_size=t.tl_a_bits_size; r.a_source=t.tl_a_bits_source; r.a_address=t.tl_a_bits_address;
    r.a_mask=t.tl_a_bits_mask; r.a_data=t.tl_a_bits_data; r.instruction=t.instruction_source;
    r.c_valid=t.tl_c_valid; r.c_opcode=t.tl_c_bits_opcode; r.c_param=t.tl_c_bits_param;
    r.c_size=t.tl_c_bits_size; r.c_source=t.tl_c_bits_source; r.c_address=t.tl_c_bits_address;
    r.c_data=t.tl_c_bits_data; r.d_ready=t.tl_d_ready; r.e_valid=t.tl_e_valid;
    return r;
}
void connect(VContractRocket& t, const Memory& memory) {
    const auto r=memory.drive(request(t));
    t.tl_a_ready=r.a_ready; t.tl_c_ready=r.c_ready; t.tl_e_ready=r.e_ready;
    t.tl_b_valid=0; t.tl_b_bits_opcode=0; t.tl_b_bits_param=0; t.tl_b_bits_size=0;
    t.tl_b_bits_source=0; t.tl_b_bits_address=0; t.tl_b_bits_mask=0;
    t.tl_b_bits_data=0; t.tl_b_bits_corrupt=0;
    t.tl_d_valid=r.d_valid; t.tl_d_bits_opcode=r.opcode; t.tl_d_bits_param=r.param;
    t.tl_d_bits_size=r.size; t.tl_d_bits_source=r.source; t.tl_d_bits_sink=0;
    t.tl_d_bits_denied=0; t.tl_d_bits_corrupt=0; t.tl_d_bits_data=r.data;
}
Trace independently(const Image& image, unsigned bound) {
    VerilatedContext context;
    context.threads(1); context.randReset(0); context.randSeed(1);
    const char* args[]={"independent-timing"}; context.commandArgs(1,args);
    auto tile=std::make_unique<VContractRocket>(&context,"independent");
    auto& t=*tile;
    Memory memory(image.data());
    t.clock=0; t.reset=1; connect(t,memory); t.eval();
    for (int cycle=0;cycle<10;++cycle) { t.clock=0;t.eval();t.clock=1;t.eval(); }
    t.clock=0;t.eval();t.reset=0;t.eval();
    Trace trace;
    for (unsigned cycle=1;cycle<=30000;++cycle) {
        memory.tick(request(t));
        t.clock=1;t.eval();connect(t,memory);t.eval();
        t.clock=0;t.eval();connect(t,memory);t.eval();
        assert(!t.exception && !context.gotFinish());
        if (t.retire_valid) {
            trace.cycles.push_back(cycle); trace.pcs.push_back(t.retire_pc);
            if (trace.cycles.size()==bound) { t.final();return trace; }
        }
    }
    throw std::runtime_error("Independent tile timed out");
}
uint32_t addi(int rd,int rs,int imm) { return (uint32_t(imm)&4095)<<20 | rs<<15 | rd<<7 | 0x13; }
uint32_t load(int rd,int imm) { return uint32_t(imm)<<20 | 2<<12 | rd<<7 | 3; }
Image program(std::initializer_list<uint32_t> words) {
    Image image;image.fill(nop);
    for (unsigned r=1;r<32;++r) image[r-1]=addi(r,0,0);
    std::copy(words.begin(),words.end(),image.begin()+32);return image;
}
int main() {
    unsigned cases=0,positive=0,negative=0;
    auto check=[&](const Image& left,const Image& right,unsigned bound=100) {
        auto l=independently(left,bound),r=independently(right,bound);
        int expected=l.cycles==r.cycles ? 0 : 1;
        auto pair=run(left.data(),right.data(),bound,30000,true);
        if (pair.status!=expected || pair.pcs[0]!=l.pcs || pair.pcs[1]!=r.pcs)
            throw std::runtime_error("Independent timing/retirement mismatch in case " + std::to_string(cases));
        ++cases; if(expected) ++positive;else ++negative;
    };
    auto arithmetic=program({addi(1,0,7),addi(2,0,-3),0x022081b3,0x0221c233});
    check(arithmetic,arithmetic);
    auto other=arithmetic;other[32]=addi(1,0,9);check(arithmetic,other);check(other,arithmetic);
    auto branch=program({addi(1,0,0),0x00008463,addi(2,0,7),addi(3,0,9)});
    other=branch;other[32]=addi(1,0,1);check(branch,other);check(other,branch);
    auto cache=program({load(1,0),load(2,0)});
    other=cache;other[33]=load(2,64);check(cache,other);check(other,cache);
    auto division=program({0x800000b7,addi(2,0,3),0x0220d1b3,addi(4,3,1)});
    other=division;other[33]=addi(2,0,-1);check(division,other);check(other,division);
    std::mt19937 random(0x54494d45);
    for (int n=0;n<100;++n) {
        auto left=program({}),right=left;
        for (unsigned i=32;i<64;++i) {
            // Mix dependent division, varying data-cache reuse and ALU values.
            switch (random()%3) {
                case 0:left[i]=load(1,64*(random()%8));right[i]=load(1,64*(random()%8));break;
                case 1:left[i]=addi(2,0,random()%31);right[i]=addi(2,0,random()%31);break;
                default:left[i]=right[i]=0x0220d1b3;break;
            }
        }
        check(left,right);check(right,left);
    }
    assert(positive && negative);
    std::cout<<"Independent timing oracle agreed on "<<cases<<" pairs ("<<positive
             <<" distinguishable, "<<negative<<" indistinguishable)\n";
}
