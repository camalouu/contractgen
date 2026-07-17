#include "cva6_test_runtime.hpp"

#include "verilated.h"

#include <iostream>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Cva6TestCaseImage test_case;
    contract_cva6_load_legacy_dat_files(test_case, ".");
    Cva6TestStatus status = contract_cva6_run_case(test_case, 10000);
    std::cout << contract_cva6_status_name(status) << std::endl;
    return 0;
}
