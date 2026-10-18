#include "axi_memory.hpp"
#include <cassert>
using namespace piccolo;
int main() {
    AxiMemory memory;
    // W may arrive before AW; byte lanes remain isolated.
    auto p=memory.outputs(); p.wvalid=true; p.wdata=0x8877665544332211ULL; p.wstrb=0xff; p.wlast=false;
    memory.tick(p); assert(!memory.outputs().bvalid);
    p=memory.outputs(); p.awvalid=true; p.awaddr=0x100; p.awid=7; p.awlen=1; p.awsize=3; p.awburst=1;
    memory.tick(p); assert(!memory.outputs().bvalid);
    p=memory.outputs(); p.wvalid=true; p.wdata=0xffffffffffffffffULL; p.wstrb=0x81; p.wlast=true;
    memory.tick(p); assert(memory.outputs().bvalid && memory.outputs().bid==7);
    assert(memory.load(0x100)==0x8877665544332211ULL && memory.load(0x108)==0xff000000000000ffULL);
    p=memory.outputs(); p.arvalid=true; p.araddr=0x100; p.arid=3; p.arlen=1; p.arsize=3; p.arburst=1;
    assert(!p.rvalid); memory.tick(p);
    p=memory.outputs(); assert(p.rvalid && p.rid==3 && !p.rlast && p.rdata==0x8877665544332211ULL);
    memory.tick(p); assert(memory.outputs().rdata==p.rdata); // backpressure
    p.rready=true; memory.tick(p); p=memory.outputs();
    assert(p.rlast && p.rdata==0xff000000000000ffULL); p.rready=true; memory.tick(p);
    assert(!memory.outputs().rvalid);
    p=memory.outputs(); p.bready=true; memory.tick(p); assert(!memory.outputs().bvalid);
    // AW first, fixed bursts and narrow byte writes.
    p=memory.outputs(); p.awvalid=true; p.awaddr=0x103; p.awid=2; p.awlen=1; p.awsize=0; p.awburst=0; memory.tick(p);
    for(int beat=0;beat<2;++beat) { p=memory.outputs(); p.wvalid=true; p.wdata=uint64_t(beat+1)<<24; p.wstrb=8; p.wlast=beat==1; memory.tick(p); }
    assert(memory.load(0x100)==0x8877665502332211ULL);
    // WRAP bursts preserve response ID and beat order.
    p=memory.outputs(); p.arvalid=true; p.araddr=0x108; p.arid=9; p.arlen=1; p.arsize=3; p.arburst=2; memory.tick(p);
    p=memory.outputs(); assert(p.rdata==0xff000000000000ffULL && p.rid==9); p.rready=true; memory.tick(p);
    assert(memory.outputs().rlast && memory.outputs().rdata==memory.load(0x100));
    // A held R beat retains its payload even if an independent write updates
    // the same address before the read consumer becomes ready.
    AxiMemory stalled;
    p=stalled.outputs(); p.arvalid=true; p.araddr=0; p.arsize=3; p.arburst=1; stalled.tick(p);
    p=stalled.outputs(); p.awvalid=true; p.awaddr=0; p.awsize=3; p.awburst=1;
    p.wvalid=true; p.wlast=true; p.wstrb=0xff; p.wdata=123; stalled.tick(p);
    assert(stalled.outputs().rvalid && stalled.outputs().rdata==0);
    assert(stalled.load(0)==123);
    bool failed=false;
    try { AxiMemory bad; p=bad.outputs(); p.arvalid=true; p.araddr=4095; p.arsize=3; bad.tick(p); }
    catch(const std::runtime_error&) { failed=true; }
    assert(failed);
}
