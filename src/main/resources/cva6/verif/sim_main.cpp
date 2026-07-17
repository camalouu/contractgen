#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cstdio>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    Vtop *top = new Vtop;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("sim.vcd");

    top->rst_ni = 0;

    int reset = 10;
    
    for (int i = 0; i < reset; i++) {
        top->clk = 0; top->eval();
        tfp->dump(i*2);
        top->clk = 1; top->eval();
        tfp->dump(i*2 + 1);
    }
    top->rst_ni = 1;

    int cycles = 10000;   // timeout after 10000 cycles

    for (int i = 0; i < cycles; i++) {
        top->clk = 0; top->eval();
        tfp->dump(i*2 + reset*2);
        if (Verilated::gotFinish()) {
            std::fflush(stdout);
            break;
        }
        top->clk = 1; top->eval();
        tfp->dump(i*2 + 1 + reset*2);
        if (Verilated::gotFinish()) {
            std::fflush(stdout);
            break;
        }
    }

    top->final();
    tfp->close();
    delete top;
    delete tfp;
    return 0;
}
