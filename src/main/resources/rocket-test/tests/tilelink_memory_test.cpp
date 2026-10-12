#include "tilelink_memory.hpp"
#include <cassert>
#include <iostream>
using namespace contract_rocket;
int main() {
    std::array<uint32_t, image_words> image;
    image.fill(nop); image[0] = 0x11223344; image[1] = 0x55667788;
    Memory memory(image.data());
    Request request;
    request.a_valid = true; request.a_opcode = 4; request.a_size = 6;
    request.a_address = 0x80; request.instruction = true;
    assert(!memory.drive(request).d_valid);
    memory.tick(request);
    auto r = memory.drive({});
    assert(r.d_valid && r.opcode == 1 && r.data == 0x5566778811223344ull);
    // Backpressure preserves the entire response without advancing a beat.
    for (int i=0; i<5; ++i) { memory.tick({}); assert(memory.drive({}).data == r.data); }
    Request ready; ready.d_ready = true;
    for (int i=0; i<8; ++i) memory.tick(ready);
    assert(!memory.drive({}).d_valid);
    // Dirty release wins over a simultaneous new instruction refill.
    request.c_valid = true; request.c_opcode = 7; request.c_size = 6;
    request.c_address = 0x80; request.c_source = 2; request.c_data = 0xdeadbeef;
    assert(!memory.drive(request).a_ready && memory.drive(request).c_ready);
    for (int i=0; i<8; ++i) { request.c_data = 0xdeadbeef + i; memory.tick(request); }
    assert(memory.drive({}).opcode == 6 && memory.drive({}).source == 2);
    memory.tick(ready);
    request = {}; request.a_valid = true; request.a_opcode = 6;
    request.a_size = 6; request.a_address = 0x80; request.a_param = 1;
    memory.tick(request);
    assert(memory.drive({}).opcode == 5 && memory.drive({}).param == 0);
    for (int i=0; i<8; ++i) {
        assert(memory.drive({}).data == 0xdeadbeefull + i); memory.tick(ready);
    }
    assert(!memory.drive({}).a_ready && memory.drive({}).e_ready);
    Request ack; ack.e_valid = true; memory.tick(ack);
    request.a_opcode = 7; request.a_param = 2; memory.tick(request);
    assert(memory.drive({}).opcode == 4); memory.tick(ready); memory.tick(ack);
    // Overlapping I/D addresses still read independent stores.
    request.a_opcode = 4; request.instruction = true; memory.tick(request);
    assert(memory.drive({}).data == 0x5566778811223344ull);
    for (int i=0; i<8; ++i) memory.tick(ready);
    request = {}; request.a_valid = true; request.a_opcode = 1; request.a_size = 0;
    request.a_address = 0x83; request.a_mask = 8; request.a_data = 0xa5000000;
    memory.tick(request); memory.tick(ready);
    request.a_opcode = 4; request.a_size = 3; request.a_address = 0x80;
    memory.tick(request);
    assert(memory.drive({}).data == 0xa5adbeef);
    memory.tick(ready);
    request.a_opcode = 6; request.a_size = 6; request.a_param = 1;
    memory.tick(request);
    assert(memory.drive({}).e_ready && memory.drive({}).d_valid);
    // The real D-cache requires E.ready on the first D beat.
    ready.e_valid = true; memory.tick(ready); ready.e_valid = false;
    assert(!memory.drive({}).a_ready);
    for (int i=1; i<8; ++i) memory.tick(ready);
    assert(memory.drive({}).a_ready && !memory.drive({}).d_valid);
    std::cout << "TileLink responder checks passed\n";
}
