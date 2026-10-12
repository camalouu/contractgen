#pragma once
#include "tilelink_memory.hpp"
#include <array>
#include <vector>
namespace contract_rocket {
struct Result {
    int status = 3;
    unsigned paired_retirements = 0, cycles = 0;
    std::array<std::array<uint32_t, 32>, 2> registers{};
    std::array<std::vector<uint32_t>, 2> pcs;
};
// The bound includes the 31 initialization instructions, as in the shared ABI.
Result run(const uint32_t* left, const uint32_t* right, int retirements, int max_cycles, bool diagnostics = false);
}
