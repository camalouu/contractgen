`ifndef RVFI_PKG_SV
`define RVFI_PKG_SV

// Copyright 2020 Thales DIS design services SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Original Author: Jean-Roch COULON - Thales

package rvfi_pkg;

typedef struct packed {
  `ifdef USEVERILATOR
    logic [config_pkg::NRET-1:0]                  valid;
    logic [config_pkg::NRET*64-1:0]               order;
    logic [config_pkg::NRET*config_pkg::ILEN-1:0] insn;
    logic [config_pkg::NRET-1:0]                  trap;
    logic [config_pkg::NRET*riscv::XLEN-1:0]      cause;
    logic [config_pkg::NRET-1:0]                  halt;
    logic [config_pkg::NRET-1:0]                  intr;
    logic [config_pkg::NRET*2-1:0]                mode;
    logic [config_pkg::NRET*2-1:0]                ixl;
    logic [config_pkg::NRET*5-1:0]                rs1_addr;
    logic [config_pkg::NRET*5-1:0]                rs2_addr;
    logic [config_pkg::NRET*riscv::XLEN-1:0]      rs1_rdata;
    logic [config_pkg::NRET*riscv::XLEN-1:0]      rs2_rdata;
    logic [config_pkg::NRET*5-1:0]                rd_addr;
    logic [config_pkg::NRET*riscv::XLEN-1:0]      rd_wdata;
    logic [config_pkg::NRET*riscv::XLEN-1:0]      pc_rdata;
    logic [config_pkg::NRET*riscv::XLEN-1:0]      pc_wdata;
    logic [config_pkg::NRET*32-1:0]      mem_addr; // TODO fix VLEN
    logic [config_pkg::NRET*34-1:0]      mem_paddr; // TODO fix PLEN
    logic [config_pkg::NRET*(riscv::XLEN/8)-1:0]  mem_rmask;
    logic [config_pkg::NRET*(riscv::XLEN/8)-1:0]  mem_wmask;
    logic [config_pkg::NRET*riscv::XLEN-1:0]      mem_rdata;
    logic [config_pkg::NRET*riscv::XLEN-1:0]      mem_wdata;
  `else
    logic [ariane_pkg::NRET-1:0]                  valid;
    logic [ariane_pkg::NRET*64-1:0]               order;
    logic [ariane_pkg::NRET*ariane_pkg::ILEN-1:0] insn;
    logic [ariane_pkg::NRET-1:0]                  trap;
    logic [ariane_pkg::NRET*riscv::XLEN-1:0]      cause;
    logic [ariane_pkg::NRET-1:0]                  halt;
    logic [ariane_pkg::NRET-1:0]                  intr;
    logic [ariane_pkg::NRET*2-1:0]                mode;
    logic [ariane_pkg::NRET*2-1:0]                ixl;
    logic [ariane_pkg::NRET*5-1:0]                rs1_addr;
    logic [ariane_pkg::NRET*5-1:0]                rs2_addr;
    logic [ariane_pkg::NRET*riscv::XLEN-1:0]      rs1_rdata;
    logic [ariane_pkg::NRET*riscv::XLEN-1:0]      rs2_rdata;
    logic [ariane_pkg::NRET*5-1:0]                rd_addr;
    logic [ariane_pkg::NRET*riscv::XLEN-1:0]      rd_wdata;
    logic [ariane_pkg::NRET*riscv::XLEN-1:0]      pc_rdata;
    logic [ariane_pkg::NRET*riscv::XLEN-1:0]      pc_wdata;
    logic [ariane_pkg::NRET*riscv::VLEN-1:0]      mem_addr;
    logic [ariane_pkg::NRET*riscv::PLEN-1:0]      mem_paddr;
    logic [ariane_pkg::NRET*(riscv::XLEN/8)-1:0]  mem_rmask;
    logic [ariane_pkg::NRET*(riscv::XLEN/8)-1:0]  mem_wmask;
    logic [ariane_pkg::NRET*riscv::XLEN-1:0]      mem_rdata;
    logic [ariane_pkg::NRET*riscv::XLEN-1:0]      mem_wdata;
  `endif
  } rvfi_instr_t;

endpackage

`endif // RVFI_PKG_SV