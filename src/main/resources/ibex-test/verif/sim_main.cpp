#include "Vtop.h"
#include "ibex_test_runtime.hpp"
#include "verilated.h"
#include <cstdio>
#include <exception>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    try {
        IbexTestCaseImage test_case;
        contract_ibex_load_legacy_dat_files(test_case, ".");
        IbexTestRunResult result = contract_ibex_run_case(test_case, 10000);
        std::printf("%s\n", contract_ibex_status_name(result.status));
        return result.status == IbexTestStatus::Error ? 1 : 0;
    } catch (const std::exception& e) {
        std::printf("ERROR: %s\n", e.what());
        return 1;
    }
}
