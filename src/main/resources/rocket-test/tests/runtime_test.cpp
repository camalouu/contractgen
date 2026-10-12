#include "rocket_test_runtime.hpp"
#include <cassert>
#include <future>
#include <iostream>
using namespace contract_rocket;
using Image = std::array<uint32_t, image_words>;
uint32_t addi(int rd,int rs,int imm) { return (uint32_t(imm)&4095)<<20 | rs<<15 | rd<<7 | 0x13; }
uint32_t store(int rs,int base,int imm,int size=2) { return ((uint32_t(imm)&0xfe0)<<20) | rs<<20 | base<<15 | size<<12 | (imm&31)<<7 | 0x23; }
uint32_t load(int rd,int base,int imm,int size=2) { return (uint32_t(imm)&4095)<<20 | base<<15 | size<<12 | rd<<7 | 3; }
Image program(std::initializer_list<uint32_t> words) {
    Image image; image.fill(nop);
    for (unsigned r=1; r<32; ++r) image[r-1] = addi(r,0,0);
    std::copy(words.begin(),words.end(),image.begin()+32); return image;
}
void equal(const Image& image, unsigned bound=80) {
    auto r=run(image.data(),image.data(),bound,10000,true);
    if(r.status != 0) std::cerr<<"status="<<r.status<<" retired="<<r.paired_retirements<<" cycles="<<r.cycles<<'\n';
    assert(r.status==0 && r.paired_retirements==bound);
    assert(r.pcs[0]==r.pcs[1] && r.pcs[0].front()==0x80);
}
int main() {
    auto arithmetic=program({addi(1,0,7),addi(2,0,-3),0x022081b3,0x0221c233,0x0221e2b3});
    auto r=run(arithmetic.data(),arithmetic.data(),80,10000,true);
    std::cerr<<"arithmetic status="<<r.status<<" retired="<<r.paired_retirements<<" cycles="<<r.cycles<<'\n';
    assert(r.status==0);
    assert(r.registers[0][3]==uint32_t(-21) && r.registers[0][4]==7 && r.registers[0][5]==0);
    auto lanes=program({addi(1,0,-128),store(1,0,2,1),load(2,0,2,1),load(3,0,2,5),addi(1,0,77),store(1,0,3,0),load(4,0,3,4)});
    r=run(lanes.data(),lanes.data(),80,10000,true);
    std::cerr<<"lanes status="<<r.status<<" retired="<<r.paired_retirements<<" x2="<<std::hex<<r.registers[0][2]<<" x3="<<r.registers[0][3]<<" x4="<<r.registers[0][4]<<std::dec<<" cycles="<<r.cycles<<"\n";
    assert(r.status==0 && r.registers[0][2]==uint32_t(-128) && r.registers[0][3]==0xff80 && r.registers[0][4]==77);
    auto flow=program({0x00000097,0x0080016f,nop,0x000101e7});
    r=run(flow.data(),flow.data(),80,10000,true);
    assert(r.status==0 && r.registers[0][1]==0x100 && r.registers[0][2]==0x108 && r.registers[0][3]==0x110);
    // More than 32 stored bytes, followed by a dependent load.
    auto persistent=program({addi(1,0,123)});
    for(int i=0;i<40;++i) persistent[33+i]=store(1,0,i,0);
    persistent[73]=load(2,0,0,4);
    r=run(persistent.data(),persistent.data(),100,10000,true);
    assert(r.status==0 && r.registers[0][2]==123);
    // Conflict 12 lines in a 4-way set, dirty evictions then reload each line.
    auto conflicts=program({addi(1,0,99)});
    unsigned pos=33;
    for(int i=0;i<12;++i){conflicts[pos++]=uint32_t(i)<<12|0x137;conflicts[pos++]=store(1,2,0);}
    for(int i=0;i<12;++i){conflicts[pos++]=uint32_t(i)<<12|0x137;conflicts[pos++]=load(3,2,0);}
    r=run(conflicts.data(),conflicts.data(),120,20000,true);
    assert(r.status==0 && r.registers[0][3]==99);
    auto invalid=program({0xffffffff});
    assert(run(invalid.data(),invalid.data(),80,10000).status==3);
    auto misaligned=program({load(2,0,1,1)});
    assert(run(misaligned.data(),misaligned.data(),80,10000).status==3);
    assert(run(arithmetic.data(),arithmetic.data(),80,1).status==2);
    for(int n=0;n<3;++n) equal(conflicts,120);
    auto task=[&]{equal(lanes);};
    auto a=std::async(std::launch::async,task),b=std::async(std::launch::async,task); a.get();b.get();
    auto branch1=program({addi(1,0,0),0x00008463,addi(2,0,7),addi(3,0,9)});
    auto branch2=branch1;branch2[32]=addi(1,0,1);
    assert(run(branch1.data(),branch2.data(),80,10000).status==1);
    auto cache1=program({load(1,0,0),load(2,0,0)});
    auto cache2=cache1;cache2[33]=load(2,0,64);
    assert(run(cache1.data(),cache2.data(),80,10000).status==1);
    // Division early-out depends on operands; include a dependent consumer.
    auto div1=program({0x800000b7,addi(2,0,3),0x0220d1b3,addi(4,3,1)});
    auto div2=div1;div2[33]=addi(2,0,-1);
    assert(run(div1.data(),div2.data(),100,10000).status==1);
    assert(run(div2.data(),div1.data(),100,10000).status==1);
    // A later trap must override an already-sticky timing divergence.
    branch1[60]=branch2[60]=0xffffffff;
    assert(run(branch1.data(),branch2.data(),80,10000).status==3);
    std::cout<<"Rocket native architecture, cache, timing and isolation checks passed\n";
}
