#pragma once
#include <array>
#include <algorithm>
#include <cstdint>
#include <stdexcept>
#include <unordered_map>

namespace contract_rocket {
constexpr unsigned image_words = 2048;
constexpr uint32_t nop = 0x13;

// One local-clock transaction at a time. C releases take priority over A requests.
// Input and output records make the responder independently testable.
struct Request {
    bool a_valid = false, c_valid = false, d_ready = false, e_valid = false;
    bool instruction = false;
    uint8_t a_opcode = 0, a_param = 0, a_size = 0, a_mask = 0;
    uint8_t c_opcode = 0, c_param = 0, c_size = 0;
    uint32_t a_source = 0, a_address = 0, c_source = 0, c_address = 0;
    uint64_t a_data = 0, c_data = 0;
};
struct Response {
    bool a_ready = false, c_ready = false, d_valid = false, e_ready = false;
    uint8_t opcode = 0, param = 0, size = 0;
    uint32_t source = 0;
    uint64_t data = 0;
};
class Memory {
    enum class State { idle, put, release, response, grant_ack };
    State state = State::idle;
    unsigned beat = 0, beats = 0;
    uint32_t address = 0;
    bool instruction = false, grant = false, grant_acked = false;
    Response reply;
    std::array<uint32_t, image_words> image;
    std::unordered_map<uint32_t, uint8_t> bytes;
    uint64_t read(uint32_t addr) const {
        uint64_t value = 0;
        for (unsigned i = 0; i < 8; ++i) {
            uint32_t key = addr + i;
            uint8_t b = 0;
            if (instruction) {
                uint32_t w = key >= 0x80 && key < 0x80 + image_words * 4
                    ? image[(key - 0x80) / 4] : nop;
                b = w >> ((key & 3) * 8);
            } else {
                auto it = bytes.find(key);
                if (it != bytes.end()) b = it->second;
            }
            value |= uint64_t(b) << (8 * i);
        }
        return value;
    }
    void write(uint32_t addr, uint64_t data, uint8_t mask) {
        for (unsigned i = 0; i < 8; ++i)
            if (mask & (1u << i)) bytes[addr + i] = data >> (8 * i);
    }
    void respond() { state = State::response; beat = 0; }
public:
    explicit Memory(const uint32_t* words) { std::copy_n(words, image_words, image.begin()); }
    Response drive(const Request& in) const {
        Response r = reply;
        r.a_ready = state == State::put || (state == State::idle && !in.c_valid);
        r.c_ready = state == State::idle || state == State::release;
        r.d_valid = state == State::response;
        r.e_ready = state == State::grant_ack || (state == State::response && grant && !grant_acked);
        if (r.d_valid && (r.opcode == 1 || r.opcode == 5)) r.data = read(address + beat * 8);
        return r;
    }
    void tick(const Request& in) {
        const auto out = drive(in); // values before this local rising edge
        // Rocket acknowledges a cached grant on its first D beat, and gates
        // D.ready with E.ready. Accept that acknowledgement without releasing
        // the transaction slot until the final D beat has completed.
        if (out.e_ready && in.e_valid) {
            grant_acked = true;
            if (state == State::grant_ack) { state = State::idle; return; }
        }
        if (out.d_valid && in.d_ready) {
            if (++beat == beats) state = grant && !grant_acked ? State::grant_ack : State::idle;
            return;
        }
        if (out.c_ready && in.c_valid) {
            if (state == State::idle) {
                if ((in.c_opcode != 6 && in.c_opcode != 7) || in.c_size != 6)
                    throw std::runtime_error("Unsupported TileLink release");
                address = in.c_address & ~63u;
                reply = {}; reply.opcode = 6; reply.source = in.c_source; reply.size = in.c_size;
                grant = false; instruction = false; beat = 0;
                beats = in.c_opcode == 7 ? 8 : 1;
                state = State::release;
            }
            if (in.c_opcode == 7) write(address + beat * 8, in.c_data, 0xff);
            if (++beat == beats) { beats = 1; respond(); }
            return;
        }
        if (out.a_ready && in.a_valid) {
            if (state == State::put) {
                write(address + beat * 8, in.a_data, in.a_mask);
                if (++beat == beats) { beats = 1; respond(); }
                return;
            }
            if (in.a_size > 6) throw std::runtime_error("TileLink transfer exceeds cache line");
            address = in.a_address & ~7u;
            instruction = in.instruction;
            grant = in.a_opcode == 6 || in.a_opcode == 7;
            grant_acked = false;
            reply = {}; reply.source = in.a_source; reply.size = in.a_size;
            beats = 1u << (in.a_size > 3 ? in.a_size - 3 : 0);
            beat = 0;
            if (in.a_opcode == 4) { // Get (instruction refills and uncached reads)
                reply.opcode = 1; respond();
            } else if (grant) {
                if (instruction || in.a_size != 6 || in.a_param > 2)
                    throw std::runtime_error("Invalid TileLink acquire");
                reply.opcode = in.a_opcode == 6 ? 5 : 4;
                // Grant B for NtoB, T for NtoT/BtoT. No external sharers exist.
                reply.param = in.a_param == 0 ? 1 : 0;
                if (in.a_opcode == 7) beats = 1;
                respond();
            } else if (in.a_opcode == 0 || in.a_opcode == 1) {
                if (instruction) throw std::runtime_error("Instruction client attempted a store");
                reply.opcode = 0;
                write(address, in.a_data, in.a_mask);
                beat = 1;
                if (beats == 1) respond(); else state = State::put;
            } else throw std::runtime_error("Unsupported TileLink A opcode");
        }
    }
};
}
