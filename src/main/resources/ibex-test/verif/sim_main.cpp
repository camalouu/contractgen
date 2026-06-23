#include "Vtop.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    Vtop *top = new Vtop;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("sim.vcd");

    int cycles = 10000;   // timeout after 10000 cycles

    for (int i = 0; i < cycles; i++) {
        top->clk = 0; top->eval();
        tfp->dump(i*2);
        top->clk = 1; top->eval();
        tfp->dump(i*2 + 1);
    }

    top->final();
    tfp->close();
    delete top;
    delete tfp;
    return 0;
}
