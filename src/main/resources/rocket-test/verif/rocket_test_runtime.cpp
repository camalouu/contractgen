#include "rocket_test_runtime.hpp"
#include "VContractRocket.h"
#include "verilated.h"
#include <cstdio>
#include <memory>

namespace contract_rocket {
namespace {
Request sample(const VContractRocket& t) {
    Request r;
    r.a_valid = t.tl_a_valid; r.a_opcode = t.tl_a_bits_opcode;
    r.a_param = t.tl_a_bits_param; r.a_size = t.tl_a_bits_size;
    r.a_source = t.tl_a_bits_source; r.a_address = t.tl_a_bits_address;
    r.a_mask = t.tl_a_bits_mask; r.a_data = t.tl_a_bits_data;
    r.instruction = t.instruction_source;
    r.c_valid = t.tl_c_valid; r.c_opcode = t.tl_c_bits_opcode;
    r.c_param = t.tl_c_bits_param; r.c_size = t.tl_c_bits_size;
    r.c_source = t.tl_c_bits_source; r.c_address = t.tl_c_bits_address;
    r.c_data = t.tl_c_bits_data;
    r.d_ready = t.tl_d_ready; r.e_valid = t.tl_e_valid;
    return r;
}
void drive(VContractRocket& t, const Memory& memory) {
    const auto r = memory.drive(sample(t));
    t.tl_a_ready = r.a_ready; t.tl_c_ready = r.c_ready;
    t.tl_b_valid = 0; t.tl_b_bits_opcode = 0; t.tl_b_bits_param = 0;
    t.tl_b_bits_size = 0; t.tl_b_bits_source = 0; t.tl_b_bits_address = 0;
    t.tl_b_bits_mask = 0; t.tl_b_bits_data = 0; t.tl_b_bits_corrupt = 0;
    t.tl_d_valid = r.d_valid; t.tl_d_bits_opcode = r.opcode;
    t.tl_d_bits_param = r.param; t.tl_d_bits_size = r.size;
    t.tl_d_bits_source = r.source; t.tl_d_bits_sink = 0;
    t.tl_d_bits_denied = 0; t.tl_d_bits_corrupt = 0; t.tl_d_bits_data = r.data;
    t.tl_e_ready = r.e_ready;
}
}
Result run(const uint32_t* left, const uint32_t* right, int bound, int max_cycles, bool diagnostics) {
    Result result;
    if (!left || !right || bound < 31 || max_cycles <= 0) return result;
    auto context = std::make_unique<VerilatedContext>();
    const char* args[] = {"contract-rocket"};
    context->commandArgs(1, args);
    context->threads(1);
    context->randReset(0);
    context->randSeed(1);
    std::array<std::unique_ptr<VContractRocket>, 2> tiles{
        std::make_unique<VContractRocket>(context.get(), "left"),
        std::make_unique<VContractRocket>(context.get(), "right")};
    std::array<Memory, 2> memory{Memory(left), Memory(right)};
    for (int n=0; n<2; ++n) {
        auto& t = *tiles[n]; t.clock = 0; t.reset = 1;
        drive(t, memory[n]); t.eval();
        for (int cycle=0; cycle<10; ++cycle) {
            t.clock = 0; t.eval(); t.clock = 1; t.eval();
        }
        t.clock = 0; t.eval(); t.reset = 0; t.eval();
    }
    // Rocket's trace can announce an instruction before its RF write (including
    // delayed mul/div). Diagnostics associate actual writes by destination and
    // wait for the requested architectural prefix, without changing attacker runs.
    std::array<std::array<unsigned,32>,2> requested{}, applied{};
    std::array<std::array<std::deque<uint32_t>,32>,2> writes;
    auto resolve = [&](int n, unsigned rd) {
        while(applied[n][rd] < requested[n][rd] && !writes[n][rd].empty()) {
            result.registers[n][rd]=writes[n][rd].front();
            writes[n][rd].pop_front(); ++applied[n][rd];
        }
    };
    auto complete = [&]() { return applied==requested; };
    bool divergence = false;
    result.status = 2;
    try {
        for (int cycle=0; cycle<max_cycles; ++cycle) {
            result.cycles = cycle + 1;
            // Same half-edge hold rule as clk_sync: a retired faster tile holds
            // its clock level until the other retirement signal catches up.
            for (int edge=1; edge>=0; --edge) {
                const bool r0 = tiles[0]->retire_valid, r1 = tiles[1]->retire_valid;
                for (int n=0; n<2; ++n) {
                    auto& t = *tiles[n];
                    const bool hold = r0 != r1 && (n == 0 ? r0 : r1);
                    if (hold || t.clock == edge) continue;
                    const bool rising = edge == 1;
                    if (rising) {
                        if (diagnostics && t.writeback_valid && t.writeback_rd) {
                            if(n==0 && std::getenv("CONTRACT_TRACE_DEBUG")) std::fprintf(stderr,"write cycle=%d rd=%u data=%x pc=%x retire=%d\n",cycle,t.writeback_rd,t.writeback_data,t.retire_pc,t.retire_valid);
                            writes[n][t.writeback_rd].push_back(t.writeback_data);
                            resolve(n,t.writeback_rd);
                        }
                        memory[n].tick(sample(t));
                    }
                    t.clock = edge;
                    // Core consumes the pre-edge D response; publish newly
                    // registered responder state only after that core edge.
                    t.eval(); drive(t, memory[n]); t.eval();
                }
                if (tiles[0]->clock != tiles[1]->clock) divergence = true;
                if (tiles[0]->exception || tiles[1]->exception || context->gotFinish()) {
                    result.status = 3; goto done;
                }
                if (edge == 0 && tiles[0]->retire_valid && tiles[1]->retire_valid) {
                    if(result.paired_retirements < unsigned(bound)) {
                        ++result.paired_retirements;
                        if (diagnostics) for(int n=0;n<2;n++) {
                            const uint32_t pc=tiles[n]->retire_pc;
                            result.pcs[n].push_back(pc);
                            const uint32_t instruction=pc>=0x80 && pc<0x2080
                                ? (n==0 ? left : right)[(pc-0x80)/4] : 0x13;
                            const unsigned opcode=instruction&127,rd=(instruction>>7)&31;
                            if(rd && (opcode==0x03 || opcode==0x13 || opcode==0x17 || opcode==0x33
                                    || opcode==0x37 || opcode==0x67 || opcode==0x6f)) {
                                if(n==0 && std::getenv("CONTRACT_TRACE_DEBUG")) std::fprintf(stderr,"retire cycle=%d pc=%x rd=%u\n",cycle,pc,rd);
                                ++requested[n][rd]; resolve(n,rd);
                            }
                        }
                    }
                    if(result.paired_retirements==unsigned(bound) && (!diagnostics || complete())) {
                        result.status=divergence ? 1 : 0; goto done;
                    }
                }
            }
        }
    } catch (const std::exception& e) {
        std::fprintf(stderr, "ROCKET_TEST invalid execution: %s\n", e.what());
        result.status = 3;
    }
done:
    for (auto& tile : tiles) tile->final();
    return result;
}
}
extern "C" int contract_simple_attacker_batch_v1(
    int count, int cycles, const int* indices, const int* bounds,
    const uint32_t* left, const uint32_t* right, int* statuses) {
    if (count < 0 || (count && (!indices || !bounds || !left || !right || !statuses))) return -1;
    for (int i=0; i<count; ++i) {
        try {
            const size_t offset = size_t(i) * contract_rocket::image_words;
            statuses[i] = contract_rocket::run(left + offset, right + offset, bounds[i], cycles > 0 ? cycles : 10000).status;
        } catch (const std::exception&) { statuses[i] = 3; }
    }
    return 0;
}

// Optional conformance ABI, separate from attacker labels. The caller supplies
// bound PC slots and 32 register slots. Register results include writes observed
// by the stopping bound; directed checks pad dependent operations with NOPs.
extern "C" int contract_architectural_trace_v1(
    const uint32_t* words, int bound, int max_cycles, uint32_t* pcs, uint32_t* registers) {
    if (!words || !pcs || !registers || bound < 31 || max_cycles <= 0) return 3;
    try {
        const auto result = contract_rocket::run(words, words, bound, max_cycles, true);
        if (result.status != 0 || result.pcs[0].size() != unsigned(bound)) return result.status == 0 ? 3 : result.status;
        std::copy(result.pcs[0].begin(), result.pcs[0].end(), pcs);
        std::copy(result.registers[0].begin(), result.registers[0].end(), registers);
        return 0;
    } catch (const std::exception&) { return 3; }
}
