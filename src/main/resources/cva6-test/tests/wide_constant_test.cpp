#include "verilated.h"
#include <algorithm>
#include <cassert>
#include <iostream>
struct Buffer { WData value[535]; WData guard[528]; };
int main() {
 Buffer original{}, fixed{};
 std::fill_n(original.guard,528,0xdeadbeefU);
 std::fill_n(fixed.guard,528,0xdeadbeefU);
 VL_CONSTHI_W_6X(17111,16896,original.value,0x10000000,0x10000000,0x11000000,0x11400000,0x00400000,0x00200000);
 VL_CONSTHI_W_7X(17111,16896,fixed.value,0,0x10000000,0x10000000,0x11000000,0x11400000,0x00400000,0x00200000);
 assert(original.guard[527] == 0);
 assert(std::all_of(fixed.guard,fixed.guard+528,[](WData x){return x==0xdeadbeefU;}));
 for(int i=528;i<534;i++)assert(original.value[i]==fixed.value[i]);
 assert(fixed.value[534]==0);
 std::cout << "Pinned runtime overrun reproduced; explicit zero preserves all guard words\n";
}
