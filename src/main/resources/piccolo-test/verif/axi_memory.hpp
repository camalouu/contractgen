#pragma once
#include <array>
#include <cstdint>
#include <deque>
#include <stdexcept>
#include <unordered_map>

namespace piccolo {
struct AxiPins {
    bool arvalid=false, arready=false, rvalid=false, rready=false, rlast=false;
    bool awvalid=false, awready=false, wvalid=false, wready=false, wlast=false;
    bool bvalid=false, bready=false;
    uint64_t araddr=0, awaddr=0, wdata=0, rdata=0;
    unsigned arid=0, arlen=0, arsize=0, arburst=0;
    unsigned awid=0, awlen=0, awsize=0, awburst=0, wstrb=0, rid=0, bid=0;
};
class AxiMemory {
    struct Burst {
        uint64_t address, start;
        unsigned id, remaining, size, kind, length;
        void advance() {
            if (kind==1) address += uint64_t(1)<<size;
            if (kind==2) {
                const uint64_t span=(uint64_t(1)<<size)*length;
                const uint64_t base=start & ~(span-1);
                address=base+((address+(uint64_t(1)<<size)-base)%span);
            }
            --remaining;
        }
    };
    struct Write { uint64_t data; unsigned strobes; bool last; };
    bool instruction_memory;
    std::unordered_map<uint32_t,uint8_t> bytes;
    std::deque<Write> writes;
    Burst read{}, write{};
    uint64_t read_data=0;
    bool reading=false, writing=false, response=false;
    unsigned response_id=0;
    static Burst burst(uint64_t addr, unsigned id, unsigned len, unsigned size, unsigned kind) {
        if(addr>UINT32_MAX || size>3 || kind>2 || (addr&((uint64_t(1)<<size)-1)) ||
           (kind==2 && len!=1 && len!=3 && len!=7 && len!=15) ||
           ((addr&4095)+(uint64_t(len)+1)*(uint64_t(1)<<size)>4096))
            throw std::runtime_error("Invalid Piccolo AXI burst");
        return {addr,addr,id,len+1,size,kind,len+1};
    }
public:
    explicit AxiMemory(bool instructions=false): instruction_memory(instructions) {}
    void store(uint32_t address, uint8_t value) { bytes[address]=value; }
    uint64_t load(uint64_t address) const {
        uint64_t result=0;
        for(unsigned lane=0;lane<8;++lane) {
            auto it=bytes.find(uint32_t((address&~uint64_t(7))+lane));
            const uint8_t byte=it!=bytes.end() ? it->second : (instruction_memory && lane%4==0 ? 0x13 : 0);
            result |= uint64_t(byte)<<(lane*8);
        }
        return result;
    }
    AxiPins outputs() const {
        AxiPins p;
        p.arready=!reading; p.awready=!writing && !response;
        p.wready=writes.size()<256;
        p.rvalid=reading; p.rdata=reading ? read_data:0;
        p.rid=read.id; p.rlast=reading && read.remaining==1;
        p.bvalid=response; p.bid=response_id;
        return p;
    }
    // Called only on an enabled core edge, using pre-edge handshake values.
    void tick(const AxiPins& p) {
        if(p.rvalid && p.rready) {
            read.advance();
            if(!read.remaining) reading=false;
            else read_data=load(read.address);
        }
        if(p.bvalid && p.bready) response=false;
        if(p.arvalid && p.arready) { read=burst(p.araddr,p.arid,p.arlen,p.arsize,p.arburst); read_data=load(read.address); reading=true; }
        if(p.awvalid && p.awready) { write=burst(p.awaddr,p.awid,p.awlen,p.awsize,p.awburst); writing=true; }
        if(p.wvalid && p.wready) writes.push_back({p.wdata,p.wstrb,p.wlast});
        if(writing && !writes.empty()) {
            auto w=writes.front(); writes.pop_front();
            if(w.last!=(write.remaining==1)) throw std::runtime_error("Invalid Piccolo AXI WLAST");
            unsigned allowed=((1u<<(1u<<write.size))-1u)<<(write.address&7);
            if(w.strobes & ~allowed) throw std::runtime_error("Invalid Piccolo AXI strobe");
            for(unsigned lane=0;lane<8;++lane) if(w.strobes&(1u<<lane))
                store(uint32_t((write.address&~uint64_t(7))+lane),uint8_t(w.data>>(lane*8)));
            write.advance();
            if(!write.remaining) { writing=false; response=true; response_id=write.id; }
        }
    }
};
}
