// Generator : SpinalHDL v1.10.2a    git head : a348a60b7e8b6a455c72e1536ec3d74a2ea16935
// Component : ProteusContractCore

`timescale 1ns/1ps

module ProteusContractCore (
  input  wire          reset,
  output wire          retire,
  output wire          rvfi_valid,
  output wire [63:0]   rvfi_order,
  output wire [31:0]   rvfi_insn,
  output wire          rvfi_trap,
  output wire          ibus_cmd_valid,
  input  wire          ibus_cmd_ready,
  output wire [31:0]   ibus_cmd_payload_address,
  output wire [1:0]    ibus_cmd_payload_id,
  input  wire          ibus_rsp_valid,
  output wire          ibus_rsp_ready,
  input  wire [31:0]   ibus_rsp_payload_rdata,
  input  wire [1:0]    ibus_rsp_payload_id,
  output wire          dbus_cmd_valid,
  input  wire          dbus_cmd_ready,
  output wire [31:0]   dbus_cmd_payload_address,
  output wire [1:0]    dbus_cmd_payload_id,
  output wire          dbus_cmd_payload_write,
  output wire [31:0]   dbus_cmd_payload_wdata,
  output wire [3:0]    dbus_cmd_payload_wmask,
  input  wire          dbus_rsp_valid,
  output wire          dbus_rsp_ready,
  input  wire [31:0]   dbus_rsp_payload_rdata,
  input  wire [1:0]    dbus_rsp_payload_id,
  input  wire          clk
);
  localparam RegisterType_NONE = 1'd0;
  localparam RegisterType_GPR = 1'd1;
  localparam CsrOp_NONE = 2'd0;
  localparam CsrOp_RW = 2'd1;
  localparam CsrOp_RS = 2'd2;
  localparam CsrOp_RC = 2'd3;
  localparam ConditionOp_NONE = 2'd0;
  localparam ConditionOp_EQZ = 2'd1;
  localparam ConditionOp_NEZ = 2'd2;
  localparam LsuOperationType_NONE = 2'd0;
  localparam LsuOperationType_LOAD = 2'd1;
  localparam LsuOperationType_STORE = 2'd2;
  localparam BranchCondition_NONE = 3'd0;
  localparam BranchCondition_EQ = 3'd1;
  localparam BranchCondition_NE = 3'd2;
  localparam BranchCondition_LT = 3'd3;
  localparam BranchCondition_GE = 3'd4;
  localparam BranchCondition_LTU = 3'd5;
  localparam BranchCondition_GEU = 3'd6;
  localparam ShiftOp_NONE = 2'd0;
  localparam ShiftOp_SLL_1 = 2'd1;
  localparam ShiftOp_SRL_1 = 2'd2;
  localparam ShiftOp_SRA_1 = 2'd3;
  localparam Src1Select_RS1 = 1'd0;
  localparam Src1Select_PC = 1'd1;
  localparam AluOp_ADD = 3'd0;
  localparam AluOp_SUB = 3'd1;
  localparam AluOp_SLT = 3'd2;
  localparam AluOp_SLTU = 3'd3;
  localparam AluOp_XOR_1 = 3'd4;
  localparam AluOp_OR_1 = 3'd5;
  localparam AluOp_AND_1 = 3'd6;
  localparam AluOp_SRC2 = 3'd7;
  localparam Src2Select_RS2 = 1'd0;
  localparam Src2Select_IMM = 1'd1;
  localparam LsuAccessWidth_B = 2'd0;
  localparam LsuAccessWidth_H = 2'd1;
  localparam LsuAccessWidth_W = 2'd2;

  reg                 fetch_arbitration_isValid;
  wire                fetch_arbitration_isStalled;
  reg                 decode_arbitration_isValid;
  wire                decode_arbitration_isStalled;
  reg                 execute_arbitration_isValid;
  reg                 execute_arbitration_isStalled;
  reg        [31:0]   execute_in_RS2_DATA;
  reg        [31:0]   execute_in_RS1_DATA;
  reg                 memoryStage_arbitration_isValid;
  reg                 memoryStage_arbitration_isStalled;
  reg        [31:0]   memoryStage_in_RS2_DATA;
  reg        [31:0]   memoryStage_in_RS1_DATA;
  reg                 writeback_arbitration_isValid;
  wire                writeback_arbitration_isStalled;
  reg        [31:0]   writeback_in_RS1_DATA;
  reg        [31:0]   pipelineRegs_ID_1_in_RS2_DATA;
  reg                 pipelineRegs_ID_1_shift_RS2_DATA;
  reg        [31:0]   pipelineRegs_ID_1_in_RS1_DATA;
  reg                 pipelineRegs_ID_1_shift_RS1_DATA;
  reg        [31:0]   pipelineRegs_EX_1_in_RS2_DATA;
  reg                 pipelineRegs_EX_1_shift_RS2_DATA;
  reg        [31:0]   pipelineRegs_EX_1_in_RS1_DATA;
  reg                 pipelineRegs_EX_1_shift_RS1_DATA;
  reg        [31:0]   pipelineRegs_MEM_1_in_RS1_DATA;
  reg                 pipelineRegs_MEM_1_shift_RS1_DATA;
  wire                fetch_arbitration_isReady;
  wire                fetch_arbitration_isDone;
  wire                fetch_arbitration_rs1Needed;
  wire                fetch_arbitration_rs2Needed;
  wire                fetch_arbitration_jumpRequested;
  wire                fetch_arbitration_isAvailable;
  wire                fetch_Fetcher_ibus_cmd_valid;
  wire       [31:0]   fetch_Fetcher_ibus_cmd_payload_address;
  wire       [1:0]    fetch_Fetcher_ibus_cmd_payload_id;
  wire                fetch_Fetcher_ibus_rsp_ready;
  wire       [31:0]   fetch_out_NEXT_PC;
  wire       [31:0]   fetch_out_IR;
  wire       [31:0]   fetch_out_PREDICTED_PC;
  wire                fetch_out_HAS_TRAPPED;
  wire                fetch_out_TRAP_IS_INTERRUPT;
  wire       [3:0]    fetch_out_TRAP_CAUSE;
  wire       [31:0]   fetch_out_TRAP_VAL;
  wire       [31:0]   fetch_out_PC;
  wire                decode_arbitration_isReady;
  wire                decode_arbitration_isDone;
  wire                decode_arbitration_rs1Needed;
  wire                decode_arbitration_rs2Needed;
  wire                decode_arbitration_jumpRequested;
  wire                decode_arbitration_isAvailable;
  wire                decode_out_BU_IS_BRANCH;
  wire                decode_out_CSR_USE_IMM;
  wire                decode_out_MULDIV_RS2_SIGNED;
  wire       [31:0]   decode_out_IMM;
  wire                decode_out_BU_IGNORE_TARGET_LSB;
  wire                decode_out_EBREAK;
  wire                decode_out_MUL;
  wire                decode_out_RD_DATA_VALID;
  wire                decode_out_LSU_IS_EXTERNAL_OP;
  wire                decode_out_BU_WRITE_RET_ADDR_TO_RD;
  wire                decode_out_LSU_IS_UNSIGNED;
  wire       [1:0]    decode_out_CSR_OP;
  wire                decode_out_ECALL;
  wire                decode_out_MUL_HIGH;
  wire       [1:0]    decode_out_CONDITION_OP;
  wire                decode_out_REM;
  wire                decode_out_ALU_COMMIT_RESULT;
  wire       [1:0]    decode_out_LSU_OPERATION_TYPE;
  wire       [2:0]    decode_out_BU_CONDITION;
  wire       [1:0]    decode_out_SHIFT_OP;
  wire                decode_out_MRET;
  wire                decode_out_DIV;
  wire       [0:0]    decode_out_ALU_SRC1;
  wire                decode_out_MULDIV_RS1_SIGNED;
  wire       [4:0]    decode_out_RS1;
  wire       [4:0]    decode_out_RS2;
  wire       [4:0]    decode_out_RD;
  wire                decode_out_IMM_USED;
  wire       [0:0]    decode_out_RS1_TYPE;
  wire       [0:0]    decode_out_RS2_TYPE;
  wire       [0:0]    decode_out_RD_TYPE;
  wire       [2:0]    decode_out_ALU_OP;
  wire       [0:0]    decode_out_ALU_SRC2;
  wire                decode_out_LSU_TARGET_VALID;
  wire       [1:0]    decode_out_LSU_ACCESS_WIDTH;
  wire       [4:0]    decode_RegisterFileAccessor_regFileIo_rs1;
  wire       [4:0]    decode_RegisterFileAccessor_regFileIo_rs2;
  wire       [31:0]   decode_out_RS1_DATA;
  wire       [31:0]   decode_out_RS2_DATA;
  wire                decode_out_HAS_TRAPPED;
  wire                decode_out_TRAP_IS_INTERRUPT;
  wire       [3:0]    decode_out_TRAP_CAUSE;
  wire       [31:0]   decode_out_TRAP_VAL;
  wire       [31:0]   decode_out_PC;
  wire       [31:0]   decode_out_IR;
  wire       [31:0]   decode_out_NEXT_PC;
  wire       [31:0]   decode_out_PREDICTED_PC;
  wire                execute_arbitration_isReady;
  wire                execute_arbitration_isDone;
  wire                execute_arbitration_rs1Needed;
  wire                execute_arbitration_rs2Needed;
  wire                execute_arbitration_jumpRequested;
  wire                execute_arbitration_isAvailable;
  wire       [31:0]   execute_out_RD_DATA;
  wire                execute_out_RD_DATA_VALID;
  wire       [31:0]   execute_out_ALU_RESULT;
  wire       [31:0]   execute_out_NEXT_PC;
  wire       [31:0]   execute_out_PREDICTED_PC;
  wire                execute_out_HAS_TRAPPED;
  wire                execute_out_TRAP_IS_INTERRUPT;
  wire       [3:0]    execute_out_TRAP_CAUSE;
  wire       [31:0]   execute_out_TRAP_VAL;
  wire       [31:0]   execute_out_RS2_DATA;
  wire       [4:0]    execute_out_RS1;
  wire       [31:0]   execute_out_PC;
  wire                execute_out_MRET;
  wire       [0:0]    execute_out_RS2_TYPE;
  wire       [0:0]    execute_out_RD_TYPE;
  wire                execute_out_LSU_IS_UNSIGNED;
  wire       [4:0]    execute_out_RD;
  wire       [31:0]   execute_out_RS1_DATA;
  wire       [1:0]    execute_out_LSU_OPERATION_TYPE;
  wire       [1:0]    execute_out_LSU_ACCESS_WIDTH;
  wire       [1:0]    execute_out_CSR_OP;
  wire       [4:0]    execute_out_RS2;
  wire       [31:0]   execute_out_IR;
  wire       [0:0]    execute_out_RS1_TYPE;
  wire                execute_out_LSU_TARGET_VALID;
  wire                execute_out_CSR_USE_IMM;
  wire                memoryStage_arbitration_isReady;
  wire                memoryStage_arbitration_isDone;
  wire                memoryStage_arbitration_rs1Needed;
  wire                memoryStage_arbitration_rs2Needed;
  wire                memoryStage_arbitration_jumpRequested;
  wire                memoryStage_arbitration_isAvailable;
  wire       [31:0]   memoryStage_out_LSU_TARGET_ADDRESS;
  wire                memoryStage_out_LSU_TARGET_VALID;
  wire                memoryStage_StaticMemoryBackbone_dbus_cmd_valid;
  wire       [31:0]   memoryStage_StaticMemoryBackbone_dbus_cmd_payload_address;
  wire       [1:0]    memoryStage_StaticMemoryBackbone_dbus_cmd_payload_id;
  wire                memoryStage_StaticMemoryBackbone_dbus_cmd_payload_write;
  wire       [31:0]   memoryStage_StaticMemoryBackbone_dbus_cmd_payload_wdata;
  wire       [3:0]    memoryStage_StaticMemoryBackbone_dbus_cmd_payload_wmask;
  wire                memoryStage_StaticMemoryBackbone_dbus_rsp_ready;
  wire       [31:0]   memoryStage_out_RD_DATA;
  wire                memoryStage_out_RD_DATA_VALID;
  wire                memoryStage_out_HAS_TRAPPED;
  wire                memoryStage_out_TRAP_IS_INTERRUPT;
  wire       [3:0]    memoryStage_out_TRAP_CAUSE;
  wire       [31:0]   memoryStage_out_TRAP_VAL;
  wire       [4:0]    memoryStage_out_RS1;
  wire       [31:0]   memoryStage_out_PC;
  wire                memoryStage_out_MRET;
  wire       [0:0]    memoryStage_out_RS2_TYPE;
  wire       [0:0]    memoryStage_out_RD_TYPE;
  wire       [4:0]    memoryStage_out_RD;
  wire       [31:0]   memoryStage_out_RS1_DATA;
  wire       [1:0]    memoryStage_out_CSR_OP;
  wire       [4:0]    memoryStage_out_RS2;
  wire       [31:0]   memoryStage_out_IR;
  wire       [31:0]   memoryStage_out_NEXT_PC;
  wire       [0:0]    memoryStage_out_RS1_TYPE;
  wire                memoryStage_out_CSR_USE_IMM;
  wire                writeback_arbitration_isReady;
  wire                writeback_arbitration_isDone;
  wire                writeback_arbitration_rs1Needed;
  wire                writeback_arbitration_rs2Needed;
  wire                writeback_arbitration_jumpRequested;
  wire                writeback_arbitration_isAvailable;
  wire       [4:0]    writeback_out_RS1;
  wire       [0:0]    writeback_out_RS1_TYPE;
  wire       [4:0]    writeback_out_RS2;
  wire       [0:0]    writeback_out_RS2_TYPE;
  wire                writeback_out_RD_DATA_VALID;
  wire       [4:0]    writeback_out_RD;
  wire       [0:0]    writeback_out_RD_TYPE;
  wire       [4:0]    writeback_RegisterFileAccessor_regFileIo_rd;
  wire       [31:0]   writeback_RegisterFileAccessor_regFileIo_data;
  wire                writeback_RegisterFileAccessor_regFileIo_write;
  wire                writeback_out_HAS_TRAPPED;
  wire       [31:0]   writeback_out_IR;
  wire                writeback_out_TRAP_IS_INTERRUPT;
  wire       [11:0]   writeback_CsrFile_csrIo_rid;
  wire       [11:0]   writeback_CsrFile_csrIo_wid;
  wire       [31:0]   writeback_CsrFile_csrIo_wdata;
  wire                writeback_CsrFile_csrIo_read;
  wire                writeback_CsrFile_csrIo_write;
  wire       [31:0]   writeback_out_RD_DATA;
  wire       [3:0]    writeback_out_TRAP_CAUSE;
  wire       [31:0]   writeback_out_TRAP_VAL;
  wire       [31:0]   writeback_TrapHandler_mstatus_wdata;
  wire                writeback_TrapHandler_mstatus_write;
  wire       [31:0]   writeback_TrapHandler_mtvec_wdata;
  wire                writeback_TrapHandler_mtvec_write;
  wire       [31:0]   writeback_TrapHandler_mcause_wdata;
  wire                writeback_TrapHandler_mcause_write;
  wire       [31:0]   writeback_TrapHandler_mepc_wdata;
  wire                writeback_TrapHandler_mepc_write;
  wire       [31:0]   writeback_TrapHandler_mtval_wdata;
  wire                writeback_TrapHandler_mtval_write;
  wire       [31:0]   writeback_out_NEXT_PC;
  wire       [31:0]   writeback_out_PC;
  wire       [31:0]   pipelineRegs_IF_1_out_PC;
  wire       [3:0]    pipelineRegs_IF_1_out_TRAP_CAUSE;
  wire       [31:0]   pipelineRegs_IF_1_out_TRAP_VAL;
  wire                pipelineRegs_IF_1_out_HAS_TRAPPED;
  wire                pipelineRegs_IF_1_out_TRAP_IS_INTERRUPT;
  wire       [31:0]   pipelineRegs_IF_1_out_IR;
  wire       [31:0]   pipelineRegs_IF_1_out_NEXT_PC;
  wire       [31:0]   pipelineRegs_IF_1_out_PREDICTED_PC;
  wire                pipelineRegs_ID_1_out_MUL;
  wire       [31:0]   pipelineRegs_ID_1_out_RS2_DATA;
  wire       [4:0]    pipelineRegs_ID_1_out_RS1;
  wire                pipelineRegs_ID_1_out_BU_IS_BRANCH;
  wire       [31:0]   pipelineRegs_ID_1_out_PC;
  wire       [1:0]    pipelineRegs_ID_1_out_SHIFT_OP;
  wire                pipelineRegs_ID_1_out_ECALL;
  wire                pipelineRegs_ID_1_out_MULDIV_RS2_SIGNED;
  wire       [2:0]    pipelineRegs_ID_1_out_BU_CONDITION;
  wire                pipelineRegs_ID_1_out_RD_DATA_VALID;
  wire       [3:0]    pipelineRegs_ID_1_out_TRAP_CAUSE;
  wire                pipelineRegs_ID_1_out_MRET;
  wire       [0:0]    pipelineRegs_ID_1_out_RS2_TYPE;
  wire       [31:0]   pipelineRegs_ID_1_out_TRAP_VAL;
  wire       [0:0]    pipelineRegs_ID_1_out_RD_TYPE;
  wire                pipelineRegs_ID_1_out_LSU_IS_UNSIGNED;
  wire                pipelineRegs_ID_1_out_DIV;
  wire                pipelineRegs_ID_1_out_HAS_TRAPPED;
  wire                pipelineRegs_ID_1_out_TRAP_IS_INTERRUPT;
  wire       [4:0]    pipelineRegs_ID_1_out_RD;
  wire       [31:0]   pipelineRegs_ID_1_out_RS1_DATA;
  wire       [1:0]    pipelineRegs_ID_1_out_CONDITION_OP;
  wire                pipelineRegs_ID_1_out_REM;
  wire                pipelineRegs_ID_1_out_BU_WRITE_RET_ADDR_TO_RD;
  wire       [1:0]    pipelineRegs_ID_1_out_LSU_OPERATION_TYPE;
  wire       [1:0]    pipelineRegs_ID_1_out_LSU_ACCESS_WIDTH;
  wire       [1:0]    pipelineRegs_ID_1_out_CSR_OP;
  wire       [0:0]    pipelineRegs_ID_1_out_ALU_SRC1;
  wire       [4:0]    pipelineRegs_ID_1_out_RS2;
  wire       [2:0]    pipelineRegs_ID_1_out_ALU_OP;
  wire       [31:0]   pipelineRegs_ID_1_out_IMM;
  wire                pipelineRegs_ID_1_out_IMM_USED;
  wire       [31:0]   pipelineRegs_ID_1_out_IR;
  wire                pipelineRegs_ID_1_out_EBREAK;
  wire       [31:0]   pipelineRegs_ID_1_out_NEXT_PC;
  wire       [0:0]    pipelineRegs_ID_1_out_RS1_TYPE;
  wire       [0:0]    pipelineRegs_ID_1_out_ALU_SRC2;
  wire                pipelineRegs_ID_1_out_LSU_TARGET_VALID;
  wire                pipelineRegs_ID_1_out_MULDIV_RS1_SIGNED;
  wire                pipelineRegs_ID_1_out_ALU_COMMIT_RESULT;
  wire                pipelineRegs_ID_1_out_BU_IGNORE_TARGET_LSB;
  wire                pipelineRegs_ID_1_out_CSR_USE_IMM;
  wire       [31:0]   pipelineRegs_ID_1_out_PREDICTED_PC;
  wire                pipelineRegs_ID_1_out_MUL_HIGH;
  wire       [31:0]   pipelineRegs_EX_1_out_RS2_DATA;
  wire       [4:0]    pipelineRegs_EX_1_out_RS1;
  wire       [31:0]   pipelineRegs_EX_1_out_PC;
  wire                pipelineRegs_EX_1_out_RD_DATA_VALID;
  wire       [3:0]    pipelineRegs_EX_1_out_TRAP_CAUSE;
  wire                pipelineRegs_EX_1_out_MRET;
  wire       [0:0]    pipelineRegs_EX_1_out_RS2_TYPE;
  wire       [31:0]   pipelineRegs_EX_1_out_TRAP_VAL;
  wire       [31:0]   pipelineRegs_EX_1_out_RD_DATA;
  wire       [0:0]    pipelineRegs_EX_1_out_RD_TYPE;
  wire                pipelineRegs_EX_1_out_LSU_IS_UNSIGNED;
  wire                pipelineRegs_EX_1_out_HAS_TRAPPED;
  wire                pipelineRegs_EX_1_out_TRAP_IS_INTERRUPT;
  wire       [4:0]    pipelineRegs_EX_1_out_RD;
  wire       [31:0]   pipelineRegs_EX_1_out_RS1_DATA;
  wire       [1:0]    pipelineRegs_EX_1_out_LSU_OPERATION_TYPE;
  wire       [1:0]    pipelineRegs_EX_1_out_LSU_ACCESS_WIDTH;
  wire       [1:0]    pipelineRegs_EX_1_out_CSR_OP;
  wire       [4:0]    pipelineRegs_EX_1_out_RS2;
  wire       [31:0]   pipelineRegs_EX_1_out_IR;
  wire       [31:0]   pipelineRegs_EX_1_out_ALU_RESULT;
  wire       [31:0]   pipelineRegs_EX_1_out_NEXT_PC;
  wire       [0:0]    pipelineRegs_EX_1_out_RS1_TYPE;
  wire                pipelineRegs_EX_1_out_LSU_TARGET_VALID;
  wire                pipelineRegs_EX_1_out_CSR_USE_IMM;
  wire       [4:0]    pipelineRegs_MEM_1_out_RS1;
  wire       [31:0]   pipelineRegs_MEM_1_out_PC;
  wire                pipelineRegs_MEM_1_out_RD_DATA_VALID;
  wire       [3:0]    pipelineRegs_MEM_1_out_TRAP_CAUSE;
  wire                pipelineRegs_MEM_1_out_MRET;
  wire       [0:0]    pipelineRegs_MEM_1_out_RS2_TYPE;
  wire       [31:0]   pipelineRegs_MEM_1_out_TRAP_VAL;
  wire       [31:0]   pipelineRegs_MEM_1_out_RD_DATA;
  wire       [0:0]    pipelineRegs_MEM_1_out_RD_TYPE;
  wire                pipelineRegs_MEM_1_out_HAS_TRAPPED;
  wire                pipelineRegs_MEM_1_out_TRAP_IS_INTERRUPT;
  wire       [4:0]    pipelineRegs_MEM_1_out_RD;
  wire       [31:0]   pipelineRegs_MEM_1_out_RS1_DATA;
  wire       [1:0]    pipelineRegs_MEM_1_out_CSR_OP;
  wire       [4:0]    pipelineRegs_MEM_1_out_RS2;
  wire       [31:0]   pipelineRegs_MEM_1_out_IR;
  wire       [31:0]   pipelineRegs_MEM_1_out_NEXT_PC;
  wire       [0:0]    pipelineRegs_MEM_1_out_RS1_TYPE;
  wire                pipelineRegs_MEM_1_out_CSR_USE_IMM;
  wire       [31:0]   CsrFile_io_rdata;
  wire                CsrFile_io_error;
  wire                CsrFile_writeNotify_write;
  wire       [31:0]   CsrFile_io_768_rdata;
  wire       [31:0]   CsrFile_io_773_rdata;
  wire       [31:0]   CsrFile_io_834_rdata;
  wire       [31:0]   CsrFile_io_833_rdata;
  wire       [31:0]   CsrFile_io_835_rdata;
  wire       [31:0]   RegisterFileAccessor_readIo_rs1Data;
  wire       [31:0]   RegisterFileAccessor_readIo_rs2Data;
  wire                _zz_when;
  wire                PcManager_pcOverride_valid;
  wire       [31:0]   PcManager_pcOverride_payload;
  reg                 _zz_arbitration_isValid;
  wire                when_Scheduler_l42;
  reg                 _zz_arbitration_isValid_1;
  wire                when_Scheduler_l42_1;
  reg                 _zz_arbitration_isValid_2;
  wire                when_Scheduler_l42_2;
  reg                 _zz_arbitration_isValid_3;
  wire                when_Scheduler_l42_3;
  reg        [63:0]   ContractSignals_order;
  wire                when_TrapHandler_l33;
  wire                when_TrapHandler_l33_1;
  wire                when_TrapHandler_l33_2;
  wire                when_TrapHandler_l33_3;
  reg        [4:0]    DataHazardResolver_lastWrittenRd_id;
  reg                 DataHazardResolver_lastWrittenRd_valid;
  reg        [31:0]   DataHazardResolver_lastWrittenRd_data;
  wire                when_DataHazardResolver_l77;
  reg                 when_DataHazardResolver_l124;
  reg        [31:0]   _zz_in_RS1_DATA;
  wire                when_DataHazardResolver_l99;
  wire                when_DataHazardResolver_l100;
  wire                when_DataHazardResolver_l113;
  wire                when_DataHazardResolver_l113_1;
  reg                 when_DataHazardResolver_l124_1;
  reg        [31:0]   _zz_in_RS2_DATA;
  wire                when_DataHazardResolver_l99_1;
  wire                when_DataHazardResolver_l100_1;
  wire                when_DataHazardResolver_l113_2;
  wire                when_DataHazardResolver_l113_3;
  wire                when_DataHazardResolver_l150;
  reg                 when_DataHazardResolver_l124_2;
  reg        [31:0]   _zz_in_RS1_DATA_1;
  wire                when_DataHazardResolver_l99_2;
  wire                when_DataHazardResolver_l100_2;
  wire                when_DataHazardResolver_l113_4;
  reg                 when_DataHazardResolver_l124_3;
  reg        [31:0]   _zz_in_RS2_DATA_1;
  wire                when_DataHazardResolver_l99_3;
  wire                when_DataHazardResolver_l100_3;
  wire                when_DataHazardResolver_l113_5;
  wire                when_DataHazardResolver_l150_1;
  reg                 when_DataHazardResolver_l124_4;
  reg        [31:0]   _zz_in_RS1_DATA_2;
  wire                when_DataHazardResolver_l99_4;
  wire                when_DataHazardResolver_l100_4;
  wire                when_DataHazardResolver_l150_2;
  reg        [31:0]   PcManager_pc;
  wire                when_PcManager_l129;
  wire                when_PcManager_l129_1;

  assign _zz_when = 1'b0;
  Stage_IF fetch (
    .arbitration_isValid              (fetch_arbitration_isValid                   ), //i
    .arbitration_isStalled            (fetch_arbitration_isStalled                 ), //i
    .arbitration_isReady              (fetch_arbitration_isReady                   ), //o
    .arbitration_isDone               (fetch_arbitration_isDone                    ), //o
    .arbitration_rs1Needed            (fetch_arbitration_rs1Needed                 ), //o
    .arbitration_rs2Needed            (fetch_arbitration_rs2Needed                 ), //o
    .arbitration_jumpRequested        (fetch_arbitration_jumpRequested             ), //o
    .arbitration_isAvailable          (fetch_arbitration_isAvailable               ), //o
    .Fetcher_ibus_cmd_valid           (fetch_Fetcher_ibus_cmd_valid                ), //o
    .Fetcher_ibus_cmd_ready           (ibus_cmd_ready                              ), //i
    .Fetcher_ibus_cmd_payload_address (fetch_Fetcher_ibus_cmd_payload_address[31:0]), //o
    .Fetcher_ibus_cmd_payload_id      (fetch_Fetcher_ibus_cmd_payload_id[1:0]      ), //o
    .Fetcher_ibus_rsp_valid           (ibus_rsp_valid                              ), //i
    .Fetcher_ibus_rsp_ready           (fetch_Fetcher_ibus_rsp_ready                ), //o
    .Fetcher_ibus_rsp_payload_rdata   (ibus_rsp_payload_rdata[31:0]                ), //i
    .Fetcher_ibus_rsp_payload_id      (ibus_rsp_payload_id[1:0]                    ), //i
    .in_PC                            (PcManager_pc[31:0]                          ), //i
    .out_NEXT_PC                      (fetch_out_NEXT_PC[31:0]                     ), //o
    .out_IR                           (fetch_out_IR[31:0]                          ), //o
    .out_PREDICTED_PC                 (fetch_out_PREDICTED_PC[31:0]                ), //o
    .in_HAS_TRAPPED                   (1'b0                                        ), //i
    .out_HAS_TRAPPED                  (fetch_out_HAS_TRAPPED                       ), //o
    .out_TRAP_IS_INTERRUPT            (fetch_out_TRAP_IS_INTERRUPT                 ), //o
    .out_TRAP_CAUSE                   (fetch_out_TRAP_CAUSE[3:0]                   ), //o
    .out_TRAP_VAL                     (fetch_out_TRAP_VAL[31:0]                    ), //o
    .out_PC                           (fetch_out_PC[31:0]                          ), //o
    .clk                              (clk                                         ), //i
    .reset                            (reset                                       )  //i
  );
  Stage_ID decode (
    .arbitration_isValid                    (decode_arbitration_isValid                    ), //i
    .arbitration_isStalled                  (decode_arbitration_isStalled                  ), //i
    .arbitration_isReady                    (decode_arbitration_isReady                    ), //o
    .arbitration_isDone                     (decode_arbitration_isDone                     ), //o
    .arbitration_rs1Needed                  (decode_arbitration_rs1Needed                  ), //o
    .arbitration_rs2Needed                  (decode_arbitration_rs2Needed                  ), //o
    .arbitration_jumpRequested              (decode_arbitration_jumpRequested              ), //o
    .arbitration_isAvailable                (decode_arbitration_isAvailable                ), //o
    .out_BU_IS_BRANCH                       (decode_out_BU_IS_BRANCH                       ), //o
    .out_CSR_USE_IMM                        (decode_out_CSR_USE_IMM                        ), //o
    .out_MULDIV_RS2_SIGNED                  (decode_out_MULDIV_RS2_SIGNED                  ), //o
    .out_IMM                                (decode_out_IMM[31:0]                          ), //o
    .out_BU_IGNORE_TARGET_LSB               (decode_out_BU_IGNORE_TARGET_LSB               ), //o
    .out_EBREAK                             (decode_out_EBREAK                             ), //o
    .out_MUL                                (decode_out_MUL                                ), //o
    .out_RD_DATA_VALID                      (decode_out_RD_DATA_VALID                      ), //o
    .out_LSU_IS_EXTERNAL_OP                 (decode_out_LSU_IS_EXTERNAL_OP                 ), //o
    .out_BU_WRITE_RET_ADDR_TO_RD            (decode_out_BU_WRITE_RET_ADDR_TO_RD            ), //o
    .out_LSU_IS_UNSIGNED                    (decode_out_LSU_IS_UNSIGNED                    ), //o
    .out_CSR_OP                             (decode_out_CSR_OP[1:0]                        ), //o
    .out_ECALL                              (decode_out_ECALL                              ), //o
    .out_MUL_HIGH                           (decode_out_MUL_HIGH                           ), //o
    .out_CONDITION_OP                       (decode_out_CONDITION_OP[1:0]                  ), //o
    .out_REM                                (decode_out_REM                                ), //o
    .out_ALU_COMMIT_RESULT                  (decode_out_ALU_COMMIT_RESULT                  ), //o
    .out_LSU_OPERATION_TYPE                 (decode_out_LSU_OPERATION_TYPE[1:0]            ), //o
    .out_BU_CONDITION                       (decode_out_BU_CONDITION[2:0]                  ), //o
    .out_SHIFT_OP                           (decode_out_SHIFT_OP[1:0]                      ), //o
    .out_MRET                               (decode_out_MRET                               ), //o
    .out_DIV                                (decode_out_DIV                                ), //o
    .out_ALU_SRC1                           (decode_out_ALU_SRC1                           ), //o
    .out_MULDIV_RS1_SIGNED                  (decode_out_MULDIV_RS1_SIGNED                  ), //o
    .out_RS1                                (decode_out_RS1[4:0]                           ), //o
    .out_RS2                                (decode_out_RS2[4:0]                           ), //o
    .out_RD                                 (decode_out_RD[4:0]                            ), //o
    .out_IMM_USED                           (decode_out_IMM_USED                           ), //o
    .out_RS1_TYPE                           (decode_out_RS1_TYPE                           ), //o
    .out_RS2_TYPE                           (decode_out_RS2_TYPE                           ), //o
    .out_RD_TYPE                            (decode_out_RD_TYPE                            ), //o
    .out_ALU_OP                             (decode_out_ALU_OP[2:0]                        ), //o
    .out_ALU_SRC2                           (decode_out_ALU_SRC2                           ), //o
    .out_LSU_TARGET_VALID                   (decode_out_LSU_TARGET_VALID                   ), //o
    .out_LSU_ACCESS_WIDTH                   (decode_out_LSU_ACCESS_WIDTH[1:0]              ), //o
    .RegisterFileAccessor_regFileIo_rs1     (decode_RegisterFileAccessor_regFileIo_rs1[4:0]), //o
    .RegisterFileAccessor_regFileIo_rs2     (decode_RegisterFileAccessor_regFileIo_rs2[4:0]), //o
    .RegisterFileAccessor_regFileIo_rs1Data (RegisterFileAccessor_readIo_rs1Data[31:0]     ), //i
    .RegisterFileAccessor_regFileIo_rs2Data (RegisterFileAccessor_readIo_rs2Data[31:0]     ), //i
    .out_RS1_DATA                           (decode_out_RS1_DATA[31:0]                     ), //o
    .out_RS2_DATA                           (decode_out_RS2_DATA[31:0]                     ), //o
    .out_HAS_TRAPPED                        (decode_out_HAS_TRAPPED                        ), //o
    .out_TRAP_IS_INTERRUPT                  (decode_out_TRAP_IS_INTERRUPT                  ), //o
    .out_TRAP_CAUSE                         (decode_out_TRAP_CAUSE[3:0]                    ), //o
    .out_TRAP_VAL                           (decode_out_TRAP_VAL[31:0]                     ), //o
    .in_IR                                  (pipelineRegs_IF_1_out_IR[31:0]                ), //i
    .in_PC                                  (pipelineRegs_IF_1_out_PC[31:0]                ), //i
    .out_PC                                 (decode_out_PC[31:0]                           ), //o
    .in_TRAP_CAUSE                          (pipelineRegs_IF_1_out_TRAP_CAUSE[3:0]         ), //i
    .in_TRAP_VAL                            (pipelineRegs_IF_1_out_TRAP_VAL[31:0]          ), //i
    .in_HAS_TRAPPED                         (pipelineRegs_IF_1_out_HAS_TRAPPED             ), //i
    .in_TRAP_IS_INTERRUPT                   (pipelineRegs_IF_1_out_TRAP_IS_INTERRUPT       ), //i
    .out_IR                                 (decode_out_IR[31:0]                           ), //o
    .in_NEXT_PC                             (pipelineRegs_IF_1_out_NEXT_PC[31:0]           ), //i
    .out_NEXT_PC                            (decode_out_NEXT_PC[31:0]                      ), //o
    .in_PREDICTED_PC                        (pipelineRegs_IF_1_out_PREDICTED_PC[31:0]      ), //i
    .out_PREDICTED_PC                       (decode_out_PREDICTED_PC[31:0]                 )  //o
  );
  Stage_EX execute (
    .arbitration_isValid        (execute_arbitration_isValid                  ), //i
    .arbitration_isStalled      (execute_arbitration_isStalled                ), //i
    .arbitration_isReady        (execute_arbitration_isReady                  ), //o
    .arbitration_isDone         (execute_arbitration_isDone                   ), //o
    .arbitration_rs1Needed      (execute_arbitration_rs1Needed                ), //o
    .arbitration_rs2Needed      (execute_arbitration_rs2Needed                ), //o
    .arbitration_jumpRequested  (execute_arbitration_jumpRequested            ), //o
    .arbitration_isAvailable    (execute_arbitration_isAvailable              ), //o
    .out_RD_DATA                (execute_out_RD_DATA[31:0]                    ), //o
    .out_RD_DATA_VALID          (execute_out_RD_DATA_VALID                    ), //o
    .out_ALU_RESULT             (execute_out_ALU_RESULT[31:0]                 ), //o
    .out_NEXT_PC                (execute_out_NEXT_PC[31:0]                    ), //o
    .in_NEXT_PC                 (pipelineRegs_ID_1_out_NEXT_PC[31:0]          ), //i
    .out_PREDICTED_PC           (execute_out_PREDICTED_PC[31:0]               ), //o
    .out_HAS_TRAPPED            (execute_out_HAS_TRAPPED                      ), //o
    .out_TRAP_IS_INTERRUPT      (execute_out_TRAP_IS_INTERRUPT                ), //o
    .out_TRAP_CAUSE             (execute_out_TRAP_CAUSE[3:0]                  ), //o
    .out_TRAP_VAL               (execute_out_TRAP_VAL[31:0]                   ), //o
    .in_RS2_DATA                (execute_in_RS2_DATA[31:0]                    ), //i
    .in_MUL                     (pipelineRegs_ID_1_out_MUL                    ), //i
    .in_BU_IS_BRANCH            (pipelineRegs_ID_1_out_BU_IS_BRANCH           ), //i
    .in_PC                      (pipelineRegs_ID_1_out_PC[31:0]               ), //i
    .in_SHIFT_OP                (pipelineRegs_ID_1_out_SHIFT_OP[1:0]          ), //i
    .in_ECALL                   (pipelineRegs_ID_1_out_ECALL                  ), //i
    .in_MULDIV_RS2_SIGNED       (pipelineRegs_ID_1_out_MULDIV_RS2_SIGNED      ), //i
    .in_BU_CONDITION            (pipelineRegs_ID_1_out_BU_CONDITION[2:0]      ), //i
    .in_MRET                    (pipelineRegs_ID_1_out_MRET                   ), //i
    .in_DIV                     (pipelineRegs_ID_1_out_DIV                    ), //i
    .in_RS1_DATA                (execute_in_RS1_DATA[31:0]                    ), //i
    .in_CONDITION_OP            (pipelineRegs_ID_1_out_CONDITION_OP[1:0]      ), //i
    .in_REM                     (pipelineRegs_ID_1_out_REM                    ), //i
    .in_BU_WRITE_RET_ADDR_TO_RD (pipelineRegs_ID_1_out_BU_WRITE_RET_ADDR_TO_RD), //i
    .in_ALU_SRC1                (pipelineRegs_ID_1_out_ALU_SRC1               ), //i
    .in_ALU_OP                  (pipelineRegs_ID_1_out_ALU_OP[2:0]            ), //i
    .in_IMM_USED                (pipelineRegs_ID_1_out_IMM_USED               ), //i
    .in_IMM                     (pipelineRegs_ID_1_out_IMM[31:0]              ), //i
    .in_EBREAK                  (pipelineRegs_ID_1_out_EBREAK                 ), //i
    .in_ALU_SRC2                (pipelineRegs_ID_1_out_ALU_SRC2               ), //i
    .in_MULDIV_RS1_SIGNED       (pipelineRegs_ID_1_out_MULDIV_RS1_SIGNED      ), //i
    .in_BU_IGNORE_TARGET_LSB    (pipelineRegs_ID_1_out_BU_IGNORE_TARGET_LSB   ), //i
    .in_ALU_COMMIT_RESULT       (pipelineRegs_ID_1_out_ALU_COMMIT_RESULT      ), //i
    .in_MUL_HIGH                (pipelineRegs_ID_1_out_MUL_HIGH               ), //i
    .out_RS2_DATA               (execute_out_RS2_DATA[31:0]                   ), //o
    .in_RS1                     (pipelineRegs_ID_1_out_RS1[4:0]               ), //i
    .out_RS1                    (execute_out_RS1[4:0]                         ), //o
    .out_PC                     (execute_out_PC[31:0]                         ), //o
    .in_RD_DATA_VALID           (pipelineRegs_ID_1_out_RD_DATA_VALID          ), //i
    .in_TRAP_CAUSE              (pipelineRegs_ID_1_out_TRAP_CAUSE[3:0]        ), //i
    .out_MRET                   (execute_out_MRET                             ), //o
    .in_RS2_TYPE                (pipelineRegs_ID_1_out_RS2_TYPE               ), //i
    .out_RS2_TYPE               (execute_out_RS2_TYPE                         ), //o
    .in_TRAP_VAL                (pipelineRegs_ID_1_out_TRAP_VAL[31:0]         ), //i
    .in_RD_TYPE                 (pipelineRegs_ID_1_out_RD_TYPE                ), //i
    .out_RD_TYPE                (execute_out_RD_TYPE                          ), //o
    .in_LSU_IS_UNSIGNED         (pipelineRegs_ID_1_out_LSU_IS_UNSIGNED        ), //i
    .out_LSU_IS_UNSIGNED        (execute_out_LSU_IS_UNSIGNED                  ), //o
    .in_HAS_TRAPPED             (pipelineRegs_ID_1_out_HAS_TRAPPED            ), //i
    .in_TRAP_IS_INTERRUPT       (pipelineRegs_ID_1_out_TRAP_IS_INTERRUPT      ), //i
    .in_RD                      (pipelineRegs_ID_1_out_RD[4:0]                ), //i
    .out_RD                     (execute_out_RD[4:0]                          ), //o
    .out_RS1_DATA               (execute_out_RS1_DATA[31:0]                   ), //o
    .in_LSU_OPERATION_TYPE      (pipelineRegs_ID_1_out_LSU_OPERATION_TYPE[1:0]), //i
    .out_LSU_OPERATION_TYPE     (execute_out_LSU_OPERATION_TYPE[1:0]          ), //o
    .in_LSU_ACCESS_WIDTH        (pipelineRegs_ID_1_out_LSU_ACCESS_WIDTH[1:0]  ), //i
    .out_LSU_ACCESS_WIDTH       (execute_out_LSU_ACCESS_WIDTH[1:0]            ), //o
    .in_CSR_OP                  (pipelineRegs_ID_1_out_CSR_OP[1:0]            ), //i
    .out_CSR_OP                 (execute_out_CSR_OP[1:0]                      ), //o
    .in_RS2                     (pipelineRegs_ID_1_out_RS2[4:0]               ), //i
    .out_RS2                    (execute_out_RS2[4:0]                         ), //o
    .in_IR                      (pipelineRegs_ID_1_out_IR[31:0]               ), //i
    .out_IR                     (execute_out_IR[31:0]                         ), //o
    .in_RS1_TYPE                (pipelineRegs_ID_1_out_RS1_TYPE               ), //i
    .out_RS1_TYPE               (execute_out_RS1_TYPE                         ), //o
    .in_LSU_TARGET_VALID        (pipelineRegs_ID_1_out_LSU_TARGET_VALID       ), //i
    .out_LSU_TARGET_VALID       (execute_out_LSU_TARGET_VALID                 ), //o
    .in_CSR_USE_IMM             (pipelineRegs_ID_1_out_CSR_USE_IMM            ), //i
    .out_CSR_USE_IMM            (execute_out_CSR_USE_IMM                      ), //o
    .in_PREDICTED_PC            (pipelineRegs_ID_1_out_PREDICTED_PC[31:0]     ), //i
    .clk                        (clk                                          ), //i
    .reset                      (reset                                        )  //i
  );
  Stage_MEM memoryStage (
    .arbitration_isValid                           (memoryStage_arbitration_isValid                                ), //i
    .arbitration_isStalled                         (memoryStage_arbitration_isStalled                              ), //i
    .arbitration_isReady                           (memoryStage_arbitration_isReady                                ), //o
    .arbitration_isDone                            (memoryStage_arbitration_isDone                                 ), //o
    .arbitration_rs1Needed                         (memoryStage_arbitration_rs1Needed                              ), //o
    .arbitration_rs2Needed                         (memoryStage_arbitration_rs2Needed                              ), //o
    .arbitration_jumpRequested                     (memoryStage_arbitration_jumpRequested                          ), //o
    .arbitration_isAvailable                       (memoryStage_arbitration_isAvailable                            ), //o
    .out_LSU_TARGET_ADDRESS                        (memoryStage_out_LSU_TARGET_ADDRESS[31:0]                       ), //o
    .out_LSU_TARGET_VALID                          (memoryStage_out_LSU_TARGET_VALID                               ), //o
    .StaticMemoryBackbone_dbus_cmd_valid           (memoryStage_StaticMemoryBackbone_dbus_cmd_valid                ), //o
    .StaticMemoryBackbone_dbus_cmd_ready           (dbus_cmd_ready                                                 ), //i
    .StaticMemoryBackbone_dbus_cmd_payload_address (memoryStage_StaticMemoryBackbone_dbus_cmd_payload_address[31:0]), //o
    .StaticMemoryBackbone_dbus_cmd_payload_id      (memoryStage_StaticMemoryBackbone_dbus_cmd_payload_id[1:0]      ), //o
    .StaticMemoryBackbone_dbus_cmd_payload_write   (memoryStage_StaticMemoryBackbone_dbus_cmd_payload_write        ), //o
    .StaticMemoryBackbone_dbus_cmd_payload_wdata   (memoryStage_StaticMemoryBackbone_dbus_cmd_payload_wdata[31:0]  ), //o
    .StaticMemoryBackbone_dbus_cmd_payload_wmask   (memoryStage_StaticMemoryBackbone_dbus_cmd_payload_wmask[3:0]   ), //o
    .StaticMemoryBackbone_dbus_rsp_valid           (dbus_rsp_valid                                                 ), //i
    .StaticMemoryBackbone_dbus_rsp_ready           (memoryStage_StaticMemoryBackbone_dbus_rsp_ready                ), //o
    .StaticMemoryBackbone_dbus_rsp_payload_rdata   (dbus_rsp_payload_rdata[31:0]                                   ), //i
    .StaticMemoryBackbone_dbus_rsp_payload_id      (dbus_rsp_payload_id[1:0]                                       ), //i
    .out_RD_DATA                                   (memoryStage_out_RD_DATA[31:0]                                  ), //o
    .out_RD_DATA_VALID                             (memoryStage_out_RD_DATA_VALID                                  ), //o
    .out_HAS_TRAPPED                               (memoryStage_out_HAS_TRAPPED                                    ), //o
    .out_TRAP_IS_INTERRUPT                         (memoryStage_out_TRAP_IS_INTERRUPT                              ), //o
    .out_TRAP_CAUSE                                (memoryStage_out_TRAP_CAUSE[3:0]                                ), //o
    .out_TRAP_VAL                                  (memoryStage_out_TRAP_VAL[31:0]                                 ), //o
    .in_RS2_DATA                                   (memoryStage_in_RS2_DATA[31:0]                                  ), //i
    .in_LSU_IS_UNSIGNED                            (pipelineRegs_EX_1_out_LSU_IS_UNSIGNED                          ), //i
    .in_LSU_ACCESS_WIDTH                           (pipelineRegs_EX_1_out_LSU_ACCESS_WIDTH[1:0]                    ), //i
    .in_LSU_OPERATION_TYPE                         (pipelineRegs_EX_1_out_LSU_OPERATION_TYPE[1:0]                  ), //i
    .in_ALU_RESULT                                 (pipelineRegs_EX_1_out_ALU_RESULT[31:0]                         ), //i
    .in_RS1                                        (pipelineRegs_EX_1_out_RS1[4:0]                                 ), //i
    .out_RS1                                       (memoryStage_out_RS1[4:0]                                       ), //o
    .in_PC                                         (pipelineRegs_EX_1_out_PC[31:0]                                 ), //i
    .out_PC                                        (memoryStage_out_PC[31:0]                                       ), //o
    .in_RD_DATA_VALID                              (pipelineRegs_EX_1_out_RD_DATA_VALID                            ), //i
    .in_TRAP_CAUSE                                 (pipelineRegs_EX_1_out_TRAP_CAUSE[3:0]                          ), //i
    .in_MRET                                       (pipelineRegs_EX_1_out_MRET                                     ), //i
    .out_MRET                                      (memoryStage_out_MRET                                           ), //o
    .in_RS2_TYPE                                   (pipelineRegs_EX_1_out_RS2_TYPE                                 ), //i
    .out_RS2_TYPE                                  (memoryStage_out_RS2_TYPE                                       ), //o
    .in_TRAP_VAL                                   (pipelineRegs_EX_1_out_TRAP_VAL[31:0]                           ), //i
    .in_RD_DATA                                    (pipelineRegs_EX_1_out_RD_DATA[31:0]                            ), //i
    .in_RD_TYPE                                    (pipelineRegs_EX_1_out_RD_TYPE                                  ), //i
    .out_RD_TYPE                                   (memoryStage_out_RD_TYPE                                        ), //o
    .in_HAS_TRAPPED                                (pipelineRegs_EX_1_out_HAS_TRAPPED                              ), //i
    .in_TRAP_IS_INTERRUPT                          (pipelineRegs_EX_1_out_TRAP_IS_INTERRUPT                        ), //i
    .in_RD                                         (pipelineRegs_EX_1_out_RD[4:0]                                  ), //i
    .out_RD                                        (memoryStage_out_RD[4:0]                                        ), //o
    .in_RS1_DATA                                   (memoryStage_in_RS1_DATA[31:0]                                  ), //i
    .out_RS1_DATA                                  (memoryStage_out_RS1_DATA[31:0]                                 ), //o
    .in_CSR_OP                                     (pipelineRegs_EX_1_out_CSR_OP[1:0]                              ), //i
    .out_CSR_OP                                    (memoryStage_out_CSR_OP[1:0]                                    ), //o
    .in_RS2                                        (pipelineRegs_EX_1_out_RS2[4:0]                                 ), //i
    .out_RS2                                       (memoryStage_out_RS2[4:0]                                       ), //o
    .in_IR                                         (pipelineRegs_EX_1_out_IR[31:0]                                 ), //i
    .out_IR                                        (memoryStage_out_IR[31:0]                                       ), //o
    .in_NEXT_PC                                    (pipelineRegs_EX_1_out_NEXT_PC[31:0]                            ), //i
    .out_NEXT_PC                                   (memoryStage_out_NEXT_PC[31:0]                                  ), //o
    .in_RS1_TYPE                                   (pipelineRegs_EX_1_out_RS1_TYPE                                 ), //i
    .out_RS1_TYPE                                  (memoryStage_out_RS1_TYPE                                       ), //o
    .in_LSU_TARGET_VALID                           (pipelineRegs_EX_1_out_LSU_TARGET_VALID                         ), //i
    .in_CSR_USE_IMM                                (pipelineRegs_EX_1_out_CSR_USE_IMM                              ), //i
    .out_CSR_USE_IMM                               (memoryStage_out_CSR_USE_IMM                                    ), //o
    .clk                                           (clk                                                            ), //i
    .reset                                         (reset                                                          )  //i
  );
  Stage_WB writeback (
    .arbitration_isValid                  (writeback_arbitration_isValid                      ), //i
    .arbitration_isStalled                (writeback_arbitration_isStalled                    ), //i
    .arbitration_isReady                  (writeback_arbitration_isReady                      ), //o
    .arbitration_isDone                   (writeback_arbitration_isDone                       ), //o
    .arbitration_rs1Needed                (writeback_arbitration_rs1Needed                    ), //o
    .arbitration_rs2Needed                (writeback_arbitration_rs2Needed                    ), //o
    .arbitration_jumpRequested            (writeback_arbitration_jumpRequested                ), //o
    .arbitration_isAvailable              (writeback_arbitration_isAvailable                  ), //o
    .out_RS1                              (writeback_out_RS1[4:0]                             ), //o
    .out_RS1_TYPE                         (writeback_out_RS1_TYPE                             ), //o
    .out_RS2                              (writeback_out_RS2[4:0]                             ), //o
    .out_RS2_TYPE                         (writeback_out_RS2_TYPE                             ), //o
    .out_RD_DATA_VALID                    (writeback_out_RD_DATA_VALID                        ), //o
    .out_RD                               (writeback_out_RD[4:0]                              ), //o
    .out_RD_TYPE                          (writeback_out_RD_TYPE                              ), //o
    .RegisterFileAccessor_regFileIo_rd    (writeback_RegisterFileAccessor_regFileIo_rd[4:0]   ), //o
    .RegisterFileAccessor_regFileIo_data  (writeback_RegisterFileAccessor_regFileIo_data[31:0]), //o
    .RegisterFileAccessor_regFileIo_write (writeback_RegisterFileAccessor_regFileIo_write     ), //o
    .out_HAS_TRAPPED                      (writeback_out_HAS_TRAPPED                          ), //o
    .out_IR                               (writeback_out_IR[31:0]                             ), //o
    .out_TRAP_IS_INTERRUPT                (writeback_out_TRAP_IS_INTERRUPT                    ), //o
    .CsrFile_csrIo_rid                    (writeback_CsrFile_csrIo_rid[11:0]                  ), //o
    .CsrFile_csrIo_wid                    (writeback_CsrFile_csrIo_wid[11:0]                  ), //o
    .CsrFile_csrIo_rdata                  (CsrFile_io_rdata[31:0]                             ), //i
    .CsrFile_csrIo_wdata                  (writeback_CsrFile_csrIo_wdata[31:0]                ), //o
    .CsrFile_csrIo_read                   (writeback_CsrFile_csrIo_read                       ), //o
    .CsrFile_csrIo_write                  (writeback_CsrFile_csrIo_write                      ), //o
    .CsrFile_csrIo_error                  (CsrFile_io_error                                   ), //i
    .out_RD_DATA                          (writeback_out_RD_DATA[31:0]                        ), //o
    .out_TRAP_CAUSE                       (writeback_out_TRAP_CAUSE[3:0]                      ), //o
    .out_TRAP_VAL                         (writeback_out_TRAP_VAL[31:0]                       ), //o
    .TrapHandler_mstatus_rdata            (CsrFile_io_768_rdata[31:0]                         ), //i
    .TrapHandler_mstatus_wdata            (writeback_TrapHandler_mstatus_wdata[31:0]          ), //o
    .TrapHandler_mstatus_write            (writeback_TrapHandler_mstatus_write                ), //o
    .TrapHandler_mtvec_rdata              (CsrFile_io_773_rdata[31:0]                         ), //i
    .TrapHandler_mtvec_wdata              (writeback_TrapHandler_mtvec_wdata[31:0]            ), //o
    .TrapHandler_mtvec_write              (writeback_TrapHandler_mtvec_write                  ), //o
    .TrapHandler_mcause_rdata             (CsrFile_io_834_rdata[31:0]                         ), //i
    .TrapHandler_mcause_wdata             (writeback_TrapHandler_mcause_wdata[31:0]           ), //o
    .TrapHandler_mcause_write             (writeback_TrapHandler_mcause_write                 ), //o
    .TrapHandler_mepc_rdata               (CsrFile_io_833_rdata[31:0]                         ), //i
    .TrapHandler_mepc_wdata               (writeback_TrapHandler_mepc_wdata[31:0]             ), //o
    .TrapHandler_mepc_write               (writeback_TrapHandler_mepc_write                   ), //o
    .TrapHandler_mtval_rdata              (CsrFile_io_835_rdata[31:0]                         ), //i
    .TrapHandler_mtval_wdata              (writeback_TrapHandler_mtval_wdata[31:0]            ), //o
    .TrapHandler_mtval_write              (writeback_TrapHandler_mtval_write                  ), //o
    .out_NEXT_PC                          (writeback_out_NEXT_PC[31:0]                        ), //o
    .out_PC                               (writeback_out_PC[31:0]                             ), //o
    .in_MRET                              (pipelineRegs_MEM_1_out_MRET                        ), //i
    .in_RS1_DATA                          (writeback_in_RS1_DATA[31:0]                        ), //i
    .in_CSR_OP                            (pipelineRegs_MEM_1_out_CSR_OP[1:0]                 ), //i
    .in_CSR_USE_IMM                       (pipelineRegs_MEM_1_out_CSR_USE_IMM                 ), //i
    .in_RS1                               (pipelineRegs_MEM_1_out_RS1[4:0]                    ), //i
    .in_PC                                (pipelineRegs_MEM_1_out_PC[31:0]                    ), //i
    .in_RD_DATA_VALID                     (pipelineRegs_MEM_1_out_RD_DATA_VALID               ), //i
    .in_TRAP_CAUSE                        (pipelineRegs_MEM_1_out_TRAP_CAUSE[3:0]             ), //i
    .in_RS2_TYPE                          (pipelineRegs_MEM_1_out_RS2_TYPE                    ), //i
    .in_TRAP_VAL                          (pipelineRegs_MEM_1_out_TRAP_VAL[31:0]              ), //i
    .in_RD_DATA                           (pipelineRegs_MEM_1_out_RD_DATA[31:0]               ), //i
    .in_RD_TYPE                           (pipelineRegs_MEM_1_out_RD_TYPE                     ), //i
    .in_HAS_TRAPPED                       (pipelineRegs_MEM_1_out_HAS_TRAPPED                 ), //i
    .in_TRAP_IS_INTERRUPT                 (pipelineRegs_MEM_1_out_TRAP_IS_INTERRUPT           ), //i
    .in_RD                                (pipelineRegs_MEM_1_out_RD[4:0]                     ), //i
    .in_RS2                               (pipelineRegs_MEM_1_out_RS2[4:0]                    ), //i
    .in_IR                                (pipelineRegs_MEM_1_out_IR[31:0]                    ), //i
    .in_NEXT_PC                           (pipelineRegs_MEM_1_out_NEXT_PC[31:0]               ), //i
    .in_RS1_TYPE                          (pipelineRegs_MEM_1_out_RS1_TYPE                    )  //i
  );
  PipelineRegs_IF pipelineRegs_IF_1 (
    .shift                   (fetch_arbitration_isDone                ), //i
    .in_PC                   (fetch_out_PC[31:0]                      ), //i
    .out_PC                  (pipelineRegs_IF_1_out_PC[31:0]          ), //o
    .shift_PC                (1'b0                                    ), //i
    .in_TRAP_CAUSE           (fetch_out_TRAP_CAUSE[3:0]               ), //i
    .out_TRAP_CAUSE          (pipelineRegs_IF_1_out_TRAP_CAUSE[3:0]   ), //o
    .shift_TRAP_CAUSE        (1'b0                                    ), //i
    .in_TRAP_VAL             (fetch_out_TRAP_VAL[31:0]                ), //i
    .out_TRAP_VAL            (pipelineRegs_IF_1_out_TRAP_VAL[31:0]    ), //o
    .shift_TRAP_VAL          (1'b0                                    ), //i
    .in_HAS_TRAPPED          (fetch_out_HAS_TRAPPED                   ), //i
    .out_HAS_TRAPPED         (pipelineRegs_IF_1_out_HAS_TRAPPED       ), //o
    .shift_HAS_TRAPPED       (1'b0                                    ), //i
    .in_TRAP_IS_INTERRUPT    (fetch_out_TRAP_IS_INTERRUPT             ), //i
    .out_TRAP_IS_INTERRUPT   (pipelineRegs_IF_1_out_TRAP_IS_INTERRUPT ), //o
    .shift_TRAP_IS_INTERRUPT (1'b0                                    ), //i
    .in_IR                   (fetch_out_IR[31:0]                      ), //i
    .out_IR                  (pipelineRegs_IF_1_out_IR[31:0]          ), //o
    .shift_IR                (1'b0                                    ), //i
    .in_NEXT_PC              (fetch_out_NEXT_PC[31:0]                 ), //i
    .out_NEXT_PC             (pipelineRegs_IF_1_out_NEXT_PC[31:0]     ), //o
    .shift_NEXT_PC           (1'b0                                    ), //i
    .in_PREDICTED_PC         (fetch_out_PREDICTED_PC[31:0]            ), //i
    .out_PREDICTED_PC        (pipelineRegs_IF_1_out_PREDICTED_PC[31:0]), //o
    .shift_PREDICTED_PC      (1'b0                                    ), //i
    .clk                     (clk                                     ), //i
    .reset                   (reset                                   )  //i
  );
  PipelineRegs_ID pipelineRegs_ID_1 (
    .shift                         (decode_arbitration_isDone                    ), //i
    .in_MUL                        (decode_out_MUL                               ), //i
    .out_MUL                       (pipelineRegs_ID_1_out_MUL                    ), //o
    .shift_MUL                     (1'b0                                         ), //i
    .in_RS2_DATA                   (pipelineRegs_ID_1_in_RS2_DATA[31:0]          ), //i
    .out_RS2_DATA                  (pipelineRegs_ID_1_out_RS2_DATA[31:0]         ), //o
    .shift_RS2_DATA                (pipelineRegs_ID_1_shift_RS2_DATA             ), //i
    .in_RS1                        (decode_out_RS1[4:0]                          ), //i
    .out_RS1                       (pipelineRegs_ID_1_out_RS1[4:0]               ), //o
    .shift_RS1                     (1'b0                                         ), //i
    .in_BU_IS_BRANCH               (decode_out_BU_IS_BRANCH                      ), //i
    .out_BU_IS_BRANCH              (pipelineRegs_ID_1_out_BU_IS_BRANCH           ), //o
    .shift_BU_IS_BRANCH            (1'b0                                         ), //i
    .in_PC                         (decode_out_PC[31:0]                          ), //i
    .out_PC                        (pipelineRegs_ID_1_out_PC[31:0]               ), //o
    .shift_PC                      (1'b0                                         ), //i
    .in_SHIFT_OP                   (decode_out_SHIFT_OP[1:0]                     ), //i
    .out_SHIFT_OP                  (pipelineRegs_ID_1_out_SHIFT_OP[1:0]          ), //o
    .shift_SHIFT_OP                (1'b0                                         ), //i
    .in_ECALL                      (decode_out_ECALL                             ), //i
    .out_ECALL                     (pipelineRegs_ID_1_out_ECALL                  ), //o
    .shift_ECALL                   (1'b0                                         ), //i
    .in_MULDIV_RS2_SIGNED          (decode_out_MULDIV_RS2_SIGNED                 ), //i
    .out_MULDIV_RS2_SIGNED         (pipelineRegs_ID_1_out_MULDIV_RS2_SIGNED      ), //o
    .shift_MULDIV_RS2_SIGNED       (1'b0                                         ), //i
    .in_BU_CONDITION               (decode_out_BU_CONDITION[2:0]                 ), //i
    .out_BU_CONDITION              (pipelineRegs_ID_1_out_BU_CONDITION[2:0]      ), //o
    .shift_BU_CONDITION            (1'b0                                         ), //i
    .in_RD_DATA_VALID              (decode_out_RD_DATA_VALID                     ), //i
    .out_RD_DATA_VALID             (pipelineRegs_ID_1_out_RD_DATA_VALID          ), //o
    .shift_RD_DATA_VALID           (1'b0                                         ), //i
    .in_TRAP_CAUSE                 (decode_out_TRAP_CAUSE[3:0]                   ), //i
    .out_TRAP_CAUSE                (pipelineRegs_ID_1_out_TRAP_CAUSE[3:0]        ), //o
    .shift_TRAP_CAUSE              (1'b0                                         ), //i
    .in_MRET                       (decode_out_MRET                              ), //i
    .out_MRET                      (pipelineRegs_ID_1_out_MRET                   ), //o
    .shift_MRET                    (1'b0                                         ), //i
    .in_RS2_TYPE                   (decode_out_RS2_TYPE                          ), //i
    .out_RS2_TYPE                  (pipelineRegs_ID_1_out_RS2_TYPE               ), //o
    .shift_RS2_TYPE                (1'b0                                         ), //i
    .in_TRAP_VAL                   (decode_out_TRAP_VAL[31:0]                    ), //i
    .out_TRAP_VAL                  (pipelineRegs_ID_1_out_TRAP_VAL[31:0]         ), //o
    .shift_TRAP_VAL                (1'b0                                         ), //i
    .in_RD_TYPE                    (decode_out_RD_TYPE                           ), //i
    .out_RD_TYPE                   (pipelineRegs_ID_1_out_RD_TYPE                ), //o
    .shift_RD_TYPE                 (1'b0                                         ), //i
    .in_LSU_IS_UNSIGNED            (decode_out_LSU_IS_UNSIGNED                   ), //i
    .out_LSU_IS_UNSIGNED           (pipelineRegs_ID_1_out_LSU_IS_UNSIGNED        ), //o
    .shift_LSU_IS_UNSIGNED         (1'b0                                         ), //i
    .in_DIV                        (decode_out_DIV                               ), //i
    .out_DIV                       (pipelineRegs_ID_1_out_DIV                    ), //o
    .shift_DIV                     (1'b0                                         ), //i
    .in_HAS_TRAPPED                (decode_out_HAS_TRAPPED                       ), //i
    .out_HAS_TRAPPED               (pipelineRegs_ID_1_out_HAS_TRAPPED            ), //o
    .shift_HAS_TRAPPED             (1'b0                                         ), //i
    .in_TRAP_IS_INTERRUPT          (decode_out_TRAP_IS_INTERRUPT                 ), //i
    .out_TRAP_IS_INTERRUPT         (pipelineRegs_ID_1_out_TRAP_IS_INTERRUPT      ), //o
    .shift_TRAP_IS_INTERRUPT       (1'b0                                         ), //i
    .in_RD                         (decode_out_RD[4:0]                           ), //i
    .out_RD                        (pipelineRegs_ID_1_out_RD[4:0]                ), //o
    .shift_RD                      (1'b0                                         ), //i
    .in_RS1_DATA                   (pipelineRegs_ID_1_in_RS1_DATA[31:0]          ), //i
    .out_RS1_DATA                  (pipelineRegs_ID_1_out_RS1_DATA[31:0]         ), //o
    .shift_RS1_DATA                (pipelineRegs_ID_1_shift_RS1_DATA             ), //i
    .in_CONDITION_OP               (decode_out_CONDITION_OP[1:0]                 ), //i
    .out_CONDITION_OP              (pipelineRegs_ID_1_out_CONDITION_OP[1:0]      ), //o
    .shift_CONDITION_OP            (1'b0                                         ), //i
    .in_REM                        (decode_out_REM                               ), //i
    .out_REM                       (pipelineRegs_ID_1_out_REM                    ), //o
    .shift_REM                     (1'b0                                         ), //i
    .in_BU_WRITE_RET_ADDR_TO_RD    (decode_out_BU_WRITE_RET_ADDR_TO_RD           ), //i
    .out_BU_WRITE_RET_ADDR_TO_RD   (pipelineRegs_ID_1_out_BU_WRITE_RET_ADDR_TO_RD), //o
    .shift_BU_WRITE_RET_ADDR_TO_RD (1'b0                                         ), //i
    .in_LSU_OPERATION_TYPE         (decode_out_LSU_OPERATION_TYPE[1:0]           ), //i
    .out_LSU_OPERATION_TYPE        (pipelineRegs_ID_1_out_LSU_OPERATION_TYPE[1:0]), //o
    .shift_LSU_OPERATION_TYPE      (1'b0                                         ), //i
    .in_LSU_ACCESS_WIDTH           (decode_out_LSU_ACCESS_WIDTH[1:0]             ), //i
    .out_LSU_ACCESS_WIDTH          (pipelineRegs_ID_1_out_LSU_ACCESS_WIDTH[1:0]  ), //o
    .shift_LSU_ACCESS_WIDTH        (1'b0                                         ), //i
    .in_CSR_OP                     (decode_out_CSR_OP[1:0]                       ), //i
    .out_CSR_OP                    (pipelineRegs_ID_1_out_CSR_OP[1:0]            ), //o
    .shift_CSR_OP                  (1'b0                                         ), //i
    .in_ALU_SRC1                   (decode_out_ALU_SRC1                          ), //i
    .out_ALU_SRC1                  (pipelineRegs_ID_1_out_ALU_SRC1               ), //o
    .shift_ALU_SRC1                (1'b0                                         ), //i
    .in_RS2                        (decode_out_RS2[4:0]                          ), //i
    .out_RS2                       (pipelineRegs_ID_1_out_RS2[4:0]               ), //o
    .shift_RS2                     (1'b0                                         ), //i
    .in_ALU_OP                     (decode_out_ALU_OP[2:0]                       ), //i
    .out_ALU_OP                    (pipelineRegs_ID_1_out_ALU_OP[2:0]            ), //o
    .shift_ALU_OP                  (1'b0                                         ), //i
    .in_IMM                        (decode_out_IMM[31:0]                         ), //i
    .out_IMM                       (pipelineRegs_ID_1_out_IMM[31:0]              ), //o
    .shift_IMM                     (1'b0                                         ), //i
    .in_IMM_USED                   (decode_out_IMM_USED                          ), //i
    .out_IMM_USED                  (pipelineRegs_ID_1_out_IMM_USED               ), //o
    .shift_IMM_USED                (1'b0                                         ), //i
    .in_IR                         (decode_out_IR[31:0]                          ), //i
    .out_IR                        (pipelineRegs_ID_1_out_IR[31:0]               ), //o
    .shift_IR                      (1'b0                                         ), //i
    .in_EBREAK                     (decode_out_EBREAK                            ), //i
    .out_EBREAK                    (pipelineRegs_ID_1_out_EBREAK                 ), //o
    .shift_EBREAK                  (1'b0                                         ), //i
    .in_NEXT_PC                    (decode_out_NEXT_PC[31:0]                     ), //i
    .out_NEXT_PC                   (pipelineRegs_ID_1_out_NEXT_PC[31:0]          ), //o
    .shift_NEXT_PC                 (1'b0                                         ), //i
    .in_RS1_TYPE                   (decode_out_RS1_TYPE                          ), //i
    .out_RS1_TYPE                  (pipelineRegs_ID_1_out_RS1_TYPE               ), //o
    .shift_RS1_TYPE                (1'b0                                         ), //i
    .in_ALU_SRC2                   (decode_out_ALU_SRC2                          ), //i
    .out_ALU_SRC2                  (pipelineRegs_ID_1_out_ALU_SRC2               ), //o
    .shift_ALU_SRC2                (1'b0                                         ), //i
    .in_LSU_TARGET_VALID           (decode_out_LSU_TARGET_VALID                  ), //i
    .out_LSU_TARGET_VALID          (pipelineRegs_ID_1_out_LSU_TARGET_VALID       ), //o
    .shift_LSU_TARGET_VALID        (1'b0                                         ), //i
    .in_MULDIV_RS1_SIGNED          (decode_out_MULDIV_RS1_SIGNED                 ), //i
    .out_MULDIV_RS1_SIGNED         (pipelineRegs_ID_1_out_MULDIV_RS1_SIGNED      ), //o
    .shift_MULDIV_RS1_SIGNED       (1'b0                                         ), //i
    .in_ALU_COMMIT_RESULT          (decode_out_ALU_COMMIT_RESULT                 ), //i
    .out_ALU_COMMIT_RESULT         (pipelineRegs_ID_1_out_ALU_COMMIT_RESULT      ), //o
    .shift_ALU_COMMIT_RESULT       (1'b0                                         ), //i
    .in_BU_IGNORE_TARGET_LSB       (decode_out_BU_IGNORE_TARGET_LSB              ), //i
    .out_BU_IGNORE_TARGET_LSB      (pipelineRegs_ID_1_out_BU_IGNORE_TARGET_LSB   ), //o
    .shift_BU_IGNORE_TARGET_LSB    (1'b0                                         ), //i
    .in_CSR_USE_IMM                (decode_out_CSR_USE_IMM                       ), //i
    .out_CSR_USE_IMM               (pipelineRegs_ID_1_out_CSR_USE_IMM            ), //o
    .shift_CSR_USE_IMM             (1'b0                                         ), //i
    .in_PREDICTED_PC               (decode_out_PREDICTED_PC[31:0]                ), //i
    .out_PREDICTED_PC              (pipelineRegs_ID_1_out_PREDICTED_PC[31:0]     ), //o
    .shift_PREDICTED_PC            (1'b0                                         ), //i
    .in_MUL_HIGH                   (decode_out_MUL_HIGH                          ), //i
    .out_MUL_HIGH                  (pipelineRegs_ID_1_out_MUL_HIGH               ), //o
    .shift_MUL_HIGH                (1'b0                                         ), //i
    .clk                           (clk                                          ), //i
    .reset                         (reset                                        )  //i
  );
  PipelineRegs_EX pipelineRegs_EX_1 (
    .shift                    (execute_arbitration_isDone                   ), //i
    .in_RS2_DATA              (pipelineRegs_EX_1_in_RS2_DATA[31:0]          ), //i
    .out_RS2_DATA             (pipelineRegs_EX_1_out_RS2_DATA[31:0]         ), //o
    .shift_RS2_DATA           (pipelineRegs_EX_1_shift_RS2_DATA             ), //i
    .in_RS1                   (execute_out_RS1[4:0]                         ), //i
    .out_RS1                  (pipelineRegs_EX_1_out_RS1[4:0]               ), //o
    .shift_RS1                (1'b0                                         ), //i
    .in_PC                    (execute_out_PC[31:0]                         ), //i
    .out_PC                   (pipelineRegs_EX_1_out_PC[31:0]               ), //o
    .shift_PC                 (1'b0                                         ), //i
    .in_RD_DATA_VALID         (execute_out_RD_DATA_VALID                    ), //i
    .out_RD_DATA_VALID        (pipelineRegs_EX_1_out_RD_DATA_VALID          ), //o
    .shift_RD_DATA_VALID      (1'b0                                         ), //i
    .in_TRAP_CAUSE            (execute_out_TRAP_CAUSE[3:0]                  ), //i
    .out_TRAP_CAUSE           (pipelineRegs_EX_1_out_TRAP_CAUSE[3:0]        ), //o
    .shift_TRAP_CAUSE         (1'b0                                         ), //i
    .in_MRET                  (execute_out_MRET                             ), //i
    .out_MRET                 (pipelineRegs_EX_1_out_MRET                   ), //o
    .shift_MRET               (1'b0                                         ), //i
    .in_RS2_TYPE              (execute_out_RS2_TYPE                         ), //i
    .out_RS2_TYPE             (pipelineRegs_EX_1_out_RS2_TYPE               ), //o
    .shift_RS2_TYPE           (1'b0                                         ), //i
    .in_TRAP_VAL              (execute_out_TRAP_VAL[31:0]                   ), //i
    .out_TRAP_VAL             (pipelineRegs_EX_1_out_TRAP_VAL[31:0]         ), //o
    .shift_TRAP_VAL           (1'b0                                         ), //i
    .in_RD_DATA               (execute_out_RD_DATA[31:0]                    ), //i
    .out_RD_DATA              (pipelineRegs_EX_1_out_RD_DATA[31:0]          ), //o
    .shift_RD_DATA            (1'b0                                         ), //i
    .in_RD_TYPE               (execute_out_RD_TYPE                          ), //i
    .out_RD_TYPE              (pipelineRegs_EX_1_out_RD_TYPE                ), //o
    .shift_RD_TYPE            (1'b0                                         ), //i
    .in_LSU_IS_UNSIGNED       (execute_out_LSU_IS_UNSIGNED                  ), //i
    .out_LSU_IS_UNSIGNED      (pipelineRegs_EX_1_out_LSU_IS_UNSIGNED        ), //o
    .shift_LSU_IS_UNSIGNED    (1'b0                                         ), //i
    .in_HAS_TRAPPED           (execute_out_HAS_TRAPPED                      ), //i
    .out_HAS_TRAPPED          (pipelineRegs_EX_1_out_HAS_TRAPPED            ), //o
    .shift_HAS_TRAPPED        (1'b0                                         ), //i
    .in_TRAP_IS_INTERRUPT     (execute_out_TRAP_IS_INTERRUPT                ), //i
    .out_TRAP_IS_INTERRUPT    (pipelineRegs_EX_1_out_TRAP_IS_INTERRUPT      ), //o
    .shift_TRAP_IS_INTERRUPT  (1'b0                                         ), //i
    .in_RD                    (execute_out_RD[4:0]                          ), //i
    .out_RD                   (pipelineRegs_EX_1_out_RD[4:0]                ), //o
    .shift_RD                 (1'b0                                         ), //i
    .in_RS1_DATA              (pipelineRegs_EX_1_in_RS1_DATA[31:0]          ), //i
    .out_RS1_DATA             (pipelineRegs_EX_1_out_RS1_DATA[31:0]         ), //o
    .shift_RS1_DATA           (pipelineRegs_EX_1_shift_RS1_DATA             ), //i
    .in_LSU_OPERATION_TYPE    (execute_out_LSU_OPERATION_TYPE[1:0]          ), //i
    .out_LSU_OPERATION_TYPE   (pipelineRegs_EX_1_out_LSU_OPERATION_TYPE[1:0]), //o
    .shift_LSU_OPERATION_TYPE (1'b0                                         ), //i
    .in_LSU_ACCESS_WIDTH      (execute_out_LSU_ACCESS_WIDTH[1:0]            ), //i
    .out_LSU_ACCESS_WIDTH     (pipelineRegs_EX_1_out_LSU_ACCESS_WIDTH[1:0]  ), //o
    .shift_LSU_ACCESS_WIDTH   (1'b0                                         ), //i
    .in_CSR_OP                (execute_out_CSR_OP[1:0]                      ), //i
    .out_CSR_OP               (pipelineRegs_EX_1_out_CSR_OP[1:0]            ), //o
    .shift_CSR_OP             (1'b0                                         ), //i
    .in_RS2                   (execute_out_RS2[4:0]                         ), //i
    .out_RS2                  (pipelineRegs_EX_1_out_RS2[4:0]               ), //o
    .shift_RS2                (1'b0                                         ), //i
    .in_IR                    (execute_out_IR[31:0]                         ), //i
    .out_IR                   (pipelineRegs_EX_1_out_IR[31:0]               ), //o
    .shift_IR                 (1'b0                                         ), //i
    .in_ALU_RESULT            (execute_out_ALU_RESULT[31:0]                 ), //i
    .out_ALU_RESULT           (pipelineRegs_EX_1_out_ALU_RESULT[31:0]       ), //o
    .shift_ALU_RESULT         (1'b0                                         ), //i
    .in_NEXT_PC               (execute_out_NEXT_PC[31:0]                    ), //i
    .out_NEXT_PC              (pipelineRegs_EX_1_out_NEXT_PC[31:0]          ), //o
    .shift_NEXT_PC            (1'b0                                         ), //i
    .in_RS1_TYPE              (execute_out_RS1_TYPE                         ), //i
    .out_RS1_TYPE             (pipelineRegs_EX_1_out_RS1_TYPE               ), //o
    .shift_RS1_TYPE           (1'b0                                         ), //i
    .in_LSU_TARGET_VALID      (execute_out_LSU_TARGET_VALID                 ), //i
    .out_LSU_TARGET_VALID     (pipelineRegs_EX_1_out_LSU_TARGET_VALID       ), //o
    .shift_LSU_TARGET_VALID   (1'b0                                         ), //i
    .in_CSR_USE_IMM           (execute_out_CSR_USE_IMM                      ), //i
    .out_CSR_USE_IMM          (pipelineRegs_EX_1_out_CSR_USE_IMM            ), //o
    .shift_CSR_USE_IMM        (1'b0                                         ), //i
    .clk                      (clk                                          ), //i
    .reset                    (reset                                        )  //i
  );
  PipelineRegs_MEM pipelineRegs_MEM_1 (
    .shift                   (memoryStage_arbitration_isDone          ), //i
    .in_RS1                  (memoryStage_out_RS1[4:0]                ), //i
    .out_RS1                 (pipelineRegs_MEM_1_out_RS1[4:0]         ), //o
    .shift_RS1               (1'b0                                    ), //i
    .in_PC                   (memoryStage_out_PC[31:0]                ), //i
    .out_PC                  (pipelineRegs_MEM_1_out_PC[31:0]         ), //o
    .shift_PC                (1'b0                                    ), //i
    .in_RD_DATA_VALID        (memoryStage_out_RD_DATA_VALID           ), //i
    .out_RD_DATA_VALID       (pipelineRegs_MEM_1_out_RD_DATA_VALID    ), //o
    .shift_RD_DATA_VALID     (1'b0                                    ), //i
    .in_TRAP_CAUSE           (memoryStage_out_TRAP_CAUSE[3:0]         ), //i
    .out_TRAP_CAUSE          (pipelineRegs_MEM_1_out_TRAP_CAUSE[3:0]  ), //o
    .shift_TRAP_CAUSE        (1'b0                                    ), //i
    .in_MRET                 (memoryStage_out_MRET                    ), //i
    .out_MRET                (pipelineRegs_MEM_1_out_MRET             ), //o
    .shift_MRET              (1'b0                                    ), //i
    .in_RS2_TYPE             (memoryStage_out_RS2_TYPE                ), //i
    .out_RS2_TYPE            (pipelineRegs_MEM_1_out_RS2_TYPE         ), //o
    .shift_RS2_TYPE          (1'b0                                    ), //i
    .in_TRAP_VAL             (memoryStage_out_TRAP_VAL[31:0]          ), //i
    .out_TRAP_VAL            (pipelineRegs_MEM_1_out_TRAP_VAL[31:0]   ), //o
    .shift_TRAP_VAL          (1'b0                                    ), //i
    .in_RD_DATA              (memoryStage_out_RD_DATA[31:0]           ), //i
    .out_RD_DATA             (pipelineRegs_MEM_1_out_RD_DATA[31:0]    ), //o
    .shift_RD_DATA           (1'b0                                    ), //i
    .in_RD_TYPE              (memoryStage_out_RD_TYPE                 ), //i
    .out_RD_TYPE             (pipelineRegs_MEM_1_out_RD_TYPE          ), //o
    .shift_RD_TYPE           (1'b0                                    ), //i
    .in_HAS_TRAPPED          (memoryStage_out_HAS_TRAPPED             ), //i
    .out_HAS_TRAPPED         (pipelineRegs_MEM_1_out_HAS_TRAPPED      ), //o
    .shift_HAS_TRAPPED       (1'b0                                    ), //i
    .in_TRAP_IS_INTERRUPT    (memoryStage_out_TRAP_IS_INTERRUPT       ), //i
    .out_TRAP_IS_INTERRUPT   (pipelineRegs_MEM_1_out_TRAP_IS_INTERRUPT), //o
    .shift_TRAP_IS_INTERRUPT (1'b0                                    ), //i
    .in_RD                   (memoryStage_out_RD[4:0]                 ), //i
    .out_RD                  (pipelineRegs_MEM_1_out_RD[4:0]          ), //o
    .shift_RD                (1'b0                                    ), //i
    .in_RS1_DATA             (pipelineRegs_MEM_1_in_RS1_DATA[31:0]    ), //i
    .out_RS1_DATA            (pipelineRegs_MEM_1_out_RS1_DATA[31:0]   ), //o
    .shift_RS1_DATA          (pipelineRegs_MEM_1_shift_RS1_DATA       ), //i
    .in_CSR_OP               (memoryStage_out_CSR_OP[1:0]             ), //i
    .out_CSR_OP              (pipelineRegs_MEM_1_out_CSR_OP[1:0]      ), //o
    .shift_CSR_OP            (1'b0                                    ), //i
    .in_RS2                  (memoryStage_out_RS2[4:0]                ), //i
    .out_RS2                 (pipelineRegs_MEM_1_out_RS2[4:0]         ), //o
    .shift_RS2               (1'b0                                    ), //i
    .in_IR                   (memoryStage_out_IR[31:0]                ), //i
    .out_IR                  (pipelineRegs_MEM_1_out_IR[31:0]         ), //o
    .shift_IR                (1'b0                                    ), //i
    .in_NEXT_PC              (memoryStage_out_NEXT_PC[31:0]           ), //i
    .out_NEXT_PC             (pipelineRegs_MEM_1_out_NEXT_PC[31:0]    ), //o
    .shift_NEXT_PC           (1'b0                                    ), //i
    .in_RS1_TYPE             (memoryStage_out_RS1_TYPE                ), //i
    .out_RS1_TYPE            (pipelineRegs_MEM_1_out_RS1_TYPE         ), //o
    .shift_RS1_TYPE          (1'b0                                    ), //i
    .in_CSR_USE_IMM          (memoryStage_out_CSR_USE_IMM             ), //i
    .out_CSR_USE_IMM         (pipelineRegs_MEM_1_out_CSR_USE_IMM      ), //o
    .shift_CSR_USE_IMM       (1'b0                                    ), //i
    .clk                     (clk                                     ), //i
    .reset                   (reset                                   )  //i
  );
  CsrFile CsrFile (
    .io_rid            (writeback_CsrFile_csrIo_rid[11:0]        ), //i
    .io_wid            (writeback_CsrFile_csrIo_wid[11:0]        ), //i
    .io_rdata          (CsrFile_io_rdata[31:0]                   ), //o
    .io_wdata          (writeback_CsrFile_csrIo_wdata[31:0]      ), //i
    .io_read           (writeback_CsrFile_csrIo_read             ), //i
    .io_write          (writeback_CsrFile_csrIo_write            ), //i
    .io_error          (CsrFile_io_error                         ), //o
    .writeNotify_write (CsrFile_writeNotify_write                ), //o
    .io_768_rdata      (CsrFile_io_768_rdata[31:0]               ), //o
    .io_768_wdata      (writeback_TrapHandler_mstatus_wdata[31:0]), //i
    .io_768_write      (writeback_TrapHandler_mstatus_write      ), //i
    .io_773_rdata      (CsrFile_io_773_rdata[31:0]               ), //o
    .io_773_wdata      (writeback_TrapHandler_mtvec_wdata[31:0]  ), //i
    .io_773_write      (writeback_TrapHandler_mtvec_write        ), //i
    .io_834_rdata      (CsrFile_io_834_rdata[31:0]               ), //o
    .io_834_wdata      (writeback_TrapHandler_mcause_wdata[31:0] ), //i
    .io_834_write      (writeback_TrapHandler_mcause_write       ), //i
    .io_833_rdata      (CsrFile_io_833_rdata[31:0]               ), //o
    .io_833_wdata      (writeback_TrapHandler_mepc_wdata[31:0]   ), //i
    .io_833_write      (writeback_TrapHandler_mepc_write         ), //i
    .io_835_rdata      (CsrFile_io_835_rdata[31:0]               ), //o
    .io_835_wdata      (writeback_TrapHandler_mtval_wdata[31:0]  ), //i
    .io_835_write      (writeback_TrapHandler_mtval_write        ), //i
    .clk               (clk                                      ), //i
    .reset             (reset                                    )  //i
  );
  RegisterFile RegisterFileAccessor (
    .readIo_rs1     (decode_RegisterFileAccessor_regFileIo_rs1[4:0]     ), //i
    .readIo_rs2     (decode_RegisterFileAccessor_regFileIo_rs2[4:0]     ), //i
    .readIo_rs1Data (RegisterFileAccessor_readIo_rs1Data[31:0]          ), //o
    .readIo_rs2Data (RegisterFileAccessor_readIo_rs2Data[31:0]          ), //o
    .writeIo_rd     (writeback_RegisterFileAccessor_regFileIo_rd[4:0]   ), //i
    .writeIo_data   (writeback_RegisterFileAccessor_regFileIo_data[31:0]), //i
    .writeIo_write  (writeback_RegisterFileAccessor_regFileIo_write     ), //i
    .clk            (clk                                                ), //i
    .reset          (reset                                              )  //i
  );
  assign PcManager_pcOverride_valid = 1'b0;
  assign PcManager_pcOverride_payload = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    fetch_arbitration_isValid = (! reset);
    if(when_TrapHandler_l33) begin
      fetch_arbitration_isValid = 1'b0;
    end
    if(_zz_when) begin
      fetch_arbitration_isValid = 1'b0;
    end else begin
      if(when_PcManager_l129) begin
        fetch_arbitration_isValid = 1'b0;
      end
      if(when_PcManager_l129_1) begin
        fetch_arbitration_isValid = 1'b0;
      end
    end
  end

  assign fetch_arbitration_isStalled = (decode_arbitration_isStalled || (decode_arbitration_isValid && (! decode_arbitration_isReady)));
  assign decode_arbitration_isStalled = (execute_arbitration_isStalled || (execute_arbitration_isValid && (! execute_arbitration_isReady)));
  always @(*) begin
    execute_arbitration_isStalled = (memoryStage_arbitration_isStalled || (memoryStage_arbitration_isValid && (! memoryStage_arbitration_isReady)));
    if(execute_arbitration_isValid) begin
      if(when_DataHazardResolver_l99) begin
        if(when_DataHazardResolver_l113) begin
          if(!pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            if(execute_arbitration_rs1Needed) begin
              execute_arbitration_isStalled = 1'b1;
            end
          end
        end
        if(when_DataHazardResolver_l113_1) begin
          if(!pipelineRegs_EX_1_out_RD_DATA_VALID) begin
            if(execute_arbitration_rs1Needed) begin
              execute_arbitration_isStalled = 1'b1;
            end
          end
        end
      end
    end
    if(execute_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_1) begin
        if(when_DataHazardResolver_l113_2) begin
          if(!pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            if(execute_arbitration_rs2Needed) begin
              execute_arbitration_isStalled = 1'b1;
            end
          end
        end
        if(when_DataHazardResolver_l113_3) begin
          if(!pipelineRegs_EX_1_out_RD_DATA_VALID) begin
            if(execute_arbitration_rs2Needed) begin
              execute_arbitration_isStalled = 1'b1;
            end
          end
        end
      end
    end
  end

  always @(*) begin
    memoryStage_arbitration_isStalled = (writeback_arbitration_isStalled || (writeback_arbitration_isValid && (! writeback_arbitration_isReady)));
    if(memoryStage_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_2) begin
        if(when_DataHazardResolver_l113_4) begin
          if(!pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            if(memoryStage_arbitration_rs1Needed) begin
              memoryStage_arbitration_isStalled = 1'b1;
            end
          end
        end
      end
    end
    if(memoryStage_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_3) begin
        if(when_DataHazardResolver_l113_5) begin
          if(!pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            if(memoryStage_arbitration_rs2Needed) begin
              memoryStage_arbitration_isStalled = 1'b1;
            end
          end
        end
      end
    end
  end

  assign writeback_arbitration_isStalled = 1'b0;
  always @(*) begin
    decode_arbitration_isValid = _zz_arbitration_isValid;
    if(when_TrapHandler_l33_1) begin
      decode_arbitration_isValid = 1'b0;
    end
    if(_zz_when) begin
      decode_arbitration_isValid = 1'b0;
    end else begin
      if(when_PcManager_l129) begin
        decode_arbitration_isValid = 1'b0;
      end
      if(when_PcManager_l129_1) begin
        decode_arbitration_isValid = 1'b0;
      end
    end
  end

  assign when_Scheduler_l42 = (decode_arbitration_isDone || (! decode_arbitration_isValid));
  always @(*) begin
    execute_arbitration_isValid = _zz_arbitration_isValid_1;
    if(when_TrapHandler_l33_2) begin
      execute_arbitration_isValid = 1'b0;
    end
    if(_zz_when) begin
      execute_arbitration_isValid = 1'b0;
    end else begin
      if(when_PcManager_l129) begin
        execute_arbitration_isValid = 1'b0;
      end
    end
  end

  assign when_Scheduler_l42_1 = (execute_arbitration_isDone || (! execute_arbitration_isValid));
  always @(*) begin
    memoryStage_arbitration_isValid = _zz_arbitration_isValid_2;
    if(when_TrapHandler_l33_3) begin
      memoryStage_arbitration_isValid = 1'b0;
    end
    if(_zz_when) begin
      memoryStage_arbitration_isValid = 1'b0;
    end else begin
      if(when_PcManager_l129) begin
        memoryStage_arbitration_isValid = 1'b0;
      end
    end
  end

  assign when_Scheduler_l42_2 = (memoryStage_arbitration_isDone || (! memoryStage_arbitration_isValid));
  always @(*) begin
    writeback_arbitration_isValid = _zz_arbitration_isValid_3;
    if(_zz_when) begin
      writeback_arbitration_isValid = 1'b0;
    end
  end

  assign when_Scheduler_l42_3 = (writeback_arbitration_isDone || (! writeback_arbitration_isValid));
  assign retire = writeback_arbitration_isDone;
  assign rvfi_valid = retire;
  assign rvfi_order = ContractSignals_order;
  assign rvfi_insn = writeback_out_IR;
  assign rvfi_trap = (writeback_out_HAS_TRAPPED && (! writeback_out_TRAP_IS_INTERRUPT));
  assign when_TrapHandler_l33 = (|{(writeback_arbitration_isValid && writeback_out_HAS_TRAPPED),{(memoryStage_arbitration_isValid && memoryStage_out_HAS_TRAPPED),{(execute_arbitration_isValid && execute_out_HAS_TRAPPED),(decode_arbitration_isValid && decode_out_HAS_TRAPPED)}}});
  assign when_TrapHandler_l33_1 = (|{(writeback_arbitration_isValid && writeback_out_HAS_TRAPPED),{(memoryStage_arbitration_isValid && memoryStage_out_HAS_TRAPPED),(execute_arbitration_isValid && execute_out_HAS_TRAPPED)}});
  assign when_TrapHandler_l33_2 = (|{(writeback_arbitration_isValid && writeback_out_HAS_TRAPPED),(memoryStage_arbitration_isValid && memoryStage_out_HAS_TRAPPED)});
  assign when_TrapHandler_l33_3 = (|(writeback_arbitration_isValid && writeback_out_HAS_TRAPPED));
  always @(*) begin
    pipelineRegs_ID_1_shift_RS2_DATA = 1'b0;
    if(when_DataHazardResolver_l150) begin
      if(when_DataHazardResolver_l124_1) begin
        pipelineRegs_ID_1_shift_RS2_DATA = 1'b1;
      end
    end
  end

  always @(*) begin
    pipelineRegs_ID_1_in_RS2_DATA = decode_out_RS2_DATA;
    if(when_DataHazardResolver_l150) begin
      if(when_DataHazardResolver_l124_1) begin
        pipelineRegs_ID_1_in_RS2_DATA = _zz_in_RS2_DATA;
      end
    end
  end

  always @(*) begin
    execute_in_RS2_DATA = pipelineRegs_ID_1_out_RS2_DATA;
    if(execute_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_1) begin
        if(when_DataHazardResolver_l124_1) begin
          execute_in_RS2_DATA = _zz_in_RS2_DATA;
        end
      end
    end
  end

  always @(*) begin
    pipelineRegs_EX_1_shift_RS2_DATA = 1'b0;
    if(when_DataHazardResolver_l150_1) begin
      if(when_DataHazardResolver_l124_3) begin
        pipelineRegs_EX_1_shift_RS2_DATA = 1'b1;
      end
    end
  end

  always @(*) begin
    pipelineRegs_EX_1_in_RS2_DATA = execute_out_RS2_DATA;
    if(when_DataHazardResolver_l150_1) begin
      if(when_DataHazardResolver_l124_3) begin
        pipelineRegs_EX_1_in_RS2_DATA = _zz_in_RS2_DATA_1;
      end
    end
  end

  always @(*) begin
    memoryStage_in_RS2_DATA = pipelineRegs_EX_1_out_RS2_DATA;
    if(memoryStage_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_3) begin
        if(when_DataHazardResolver_l124_3) begin
          memoryStage_in_RS2_DATA = _zz_in_RS2_DATA_1;
        end
      end
    end
  end

  always @(*) begin
    pipelineRegs_ID_1_shift_RS1_DATA = 1'b0;
    if(when_DataHazardResolver_l150) begin
      if(when_DataHazardResolver_l124) begin
        pipelineRegs_ID_1_shift_RS1_DATA = 1'b1;
      end
    end
  end

  always @(*) begin
    pipelineRegs_ID_1_in_RS1_DATA = decode_out_RS1_DATA;
    if(when_DataHazardResolver_l150) begin
      if(when_DataHazardResolver_l124) begin
        pipelineRegs_ID_1_in_RS1_DATA = _zz_in_RS1_DATA;
      end
    end
  end

  always @(*) begin
    execute_in_RS1_DATA = pipelineRegs_ID_1_out_RS1_DATA;
    if(execute_arbitration_isValid) begin
      if(when_DataHazardResolver_l99) begin
        if(when_DataHazardResolver_l124) begin
          execute_in_RS1_DATA = _zz_in_RS1_DATA;
        end
      end
    end
  end

  always @(*) begin
    pipelineRegs_EX_1_shift_RS1_DATA = 1'b0;
    if(when_DataHazardResolver_l150_1) begin
      if(when_DataHazardResolver_l124_2) begin
        pipelineRegs_EX_1_shift_RS1_DATA = 1'b1;
      end
    end
  end

  always @(*) begin
    pipelineRegs_EX_1_in_RS1_DATA = execute_out_RS1_DATA;
    if(when_DataHazardResolver_l150_1) begin
      if(when_DataHazardResolver_l124_2) begin
        pipelineRegs_EX_1_in_RS1_DATA = _zz_in_RS1_DATA_1;
      end
    end
  end

  always @(*) begin
    memoryStage_in_RS1_DATA = pipelineRegs_EX_1_out_RS1_DATA;
    if(memoryStage_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_2) begin
        if(when_DataHazardResolver_l124_2) begin
          memoryStage_in_RS1_DATA = _zz_in_RS1_DATA_1;
        end
      end
    end
  end

  always @(*) begin
    pipelineRegs_MEM_1_shift_RS1_DATA = 1'b0;
    if(when_DataHazardResolver_l150_2) begin
      if(when_DataHazardResolver_l124_4) begin
        pipelineRegs_MEM_1_shift_RS1_DATA = 1'b1;
      end
    end
  end

  always @(*) begin
    pipelineRegs_MEM_1_in_RS1_DATA = memoryStage_out_RS1_DATA;
    if(when_DataHazardResolver_l150_2) begin
      if(when_DataHazardResolver_l124_4) begin
        pipelineRegs_MEM_1_in_RS1_DATA = _zz_in_RS1_DATA_2;
      end
    end
  end

  always @(*) begin
    writeback_in_RS1_DATA = pipelineRegs_MEM_1_out_RS1_DATA;
    if(writeback_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_4) begin
        if(when_DataHazardResolver_l124_4) begin
          writeback_in_RS1_DATA = _zz_in_RS1_DATA_2;
        end
      end
    end
  end

  assign when_DataHazardResolver_l77 = (writeback_arbitration_isDone && (! writeback_out_HAS_TRAPPED));
  always @(*) begin
    when_DataHazardResolver_l124 = 1'b0;
    if(execute_arbitration_isValid) begin
      if(when_DataHazardResolver_l99) begin
        if(when_DataHazardResolver_l100) begin
          when_DataHazardResolver_l124 = 1'b1;
        end
        if(when_DataHazardResolver_l113) begin
          if(pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            when_DataHazardResolver_l124 = 1'b1;
          end else begin
            if(execute_arbitration_rs1Needed) begin
              when_DataHazardResolver_l124 = 1'b0;
            end
          end
        end
        if(when_DataHazardResolver_l113_1) begin
          if(pipelineRegs_EX_1_out_RD_DATA_VALID) begin
            when_DataHazardResolver_l124 = 1'b1;
          end else begin
            if(execute_arbitration_rs1Needed) begin
              when_DataHazardResolver_l124 = 1'b0;
            end
          end
        end
      end
    end
  end

  always @(*) begin
    _zz_in_RS1_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(execute_arbitration_isValid) begin
      if(when_DataHazardResolver_l99) begin
        if(when_DataHazardResolver_l100) begin
          _zz_in_RS1_DATA = DataHazardResolver_lastWrittenRd_data;
        end
        if(when_DataHazardResolver_l113) begin
          if(pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            _zz_in_RS1_DATA = pipelineRegs_MEM_1_out_RD_DATA;
          end
        end
        if(when_DataHazardResolver_l113_1) begin
          if(pipelineRegs_EX_1_out_RD_DATA_VALID) begin
            _zz_in_RS1_DATA = pipelineRegs_EX_1_out_RD_DATA;
          end
        end
      end
    end
  end

  assign when_DataHazardResolver_l99 = ((pipelineRegs_ID_1_out_RS1 != 5'h0) && (pipelineRegs_ID_1_out_RS1_TYPE == RegisterType_GPR));
  assign when_DataHazardResolver_l100 = (DataHazardResolver_lastWrittenRd_valid && (DataHazardResolver_lastWrittenRd_id == pipelineRegs_ID_1_out_RS1));
  assign when_DataHazardResolver_l113 = (((writeback_arbitration_isValid && (! writeback_out_HAS_TRAPPED)) && (pipelineRegs_MEM_1_out_RD_TYPE == RegisterType_GPR)) && (pipelineRegs_MEM_1_out_RD == pipelineRegs_ID_1_out_RS1));
  assign when_DataHazardResolver_l113_1 = (((memoryStage_arbitration_isValid && (! memoryStage_out_HAS_TRAPPED)) && (pipelineRegs_EX_1_out_RD_TYPE == RegisterType_GPR)) && (pipelineRegs_EX_1_out_RD == pipelineRegs_ID_1_out_RS1));
  always @(*) begin
    when_DataHazardResolver_l124_1 = 1'b0;
    if(execute_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_1) begin
        if(when_DataHazardResolver_l100_1) begin
          when_DataHazardResolver_l124_1 = 1'b1;
        end
        if(when_DataHazardResolver_l113_2) begin
          if(pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            when_DataHazardResolver_l124_1 = 1'b1;
          end else begin
            if(execute_arbitration_rs2Needed) begin
              when_DataHazardResolver_l124_1 = 1'b0;
            end
          end
        end
        if(when_DataHazardResolver_l113_3) begin
          if(pipelineRegs_EX_1_out_RD_DATA_VALID) begin
            when_DataHazardResolver_l124_1 = 1'b1;
          end else begin
            if(execute_arbitration_rs2Needed) begin
              when_DataHazardResolver_l124_1 = 1'b0;
            end
          end
        end
      end
    end
  end

  always @(*) begin
    _zz_in_RS2_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(execute_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_1) begin
        if(when_DataHazardResolver_l100_1) begin
          _zz_in_RS2_DATA = DataHazardResolver_lastWrittenRd_data;
        end
        if(when_DataHazardResolver_l113_2) begin
          if(pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            _zz_in_RS2_DATA = pipelineRegs_MEM_1_out_RD_DATA;
          end
        end
        if(when_DataHazardResolver_l113_3) begin
          if(pipelineRegs_EX_1_out_RD_DATA_VALID) begin
            _zz_in_RS2_DATA = pipelineRegs_EX_1_out_RD_DATA;
          end
        end
      end
    end
  end

  assign when_DataHazardResolver_l99_1 = ((pipelineRegs_ID_1_out_RS2 != 5'h0) && (pipelineRegs_ID_1_out_RS2_TYPE == RegisterType_GPR));
  assign when_DataHazardResolver_l100_1 = (DataHazardResolver_lastWrittenRd_valid && (DataHazardResolver_lastWrittenRd_id == pipelineRegs_ID_1_out_RS2));
  assign when_DataHazardResolver_l113_2 = (((writeback_arbitration_isValid && (! writeback_out_HAS_TRAPPED)) && (pipelineRegs_MEM_1_out_RD_TYPE == RegisterType_GPR)) && (pipelineRegs_MEM_1_out_RD == pipelineRegs_ID_1_out_RS2));
  assign when_DataHazardResolver_l113_3 = (((memoryStage_arbitration_isValid && (! memoryStage_out_HAS_TRAPPED)) && (pipelineRegs_EX_1_out_RD_TYPE == RegisterType_GPR)) && (pipelineRegs_EX_1_out_RD == pipelineRegs_ID_1_out_RS2));
  assign when_DataHazardResolver_l150 = (execute_arbitration_isStalled || (! execute_arbitration_isReady));
  always @(*) begin
    when_DataHazardResolver_l124_2 = 1'b0;
    if(memoryStage_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_2) begin
        if(when_DataHazardResolver_l100_2) begin
          when_DataHazardResolver_l124_2 = 1'b1;
        end
        if(when_DataHazardResolver_l113_4) begin
          if(pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            when_DataHazardResolver_l124_2 = 1'b1;
          end else begin
            if(memoryStage_arbitration_rs1Needed) begin
              when_DataHazardResolver_l124_2 = 1'b0;
            end
          end
        end
      end
    end
  end

  always @(*) begin
    _zz_in_RS1_DATA_1 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(memoryStage_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_2) begin
        if(when_DataHazardResolver_l100_2) begin
          _zz_in_RS1_DATA_1 = DataHazardResolver_lastWrittenRd_data;
        end
        if(when_DataHazardResolver_l113_4) begin
          if(pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            _zz_in_RS1_DATA_1 = pipelineRegs_MEM_1_out_RD_DATA;
          end
        end
      end
    end
  end

  assign when_DataHazardResolver_l99_2 = ((pipelineRegs_EX_1_out_RS1 != 5'h0) && (pipelineRegs_EX_1_out_RS1_TYPE == RegisterType_GPR));
  assign when_DataHazardResolver_l100_2 = (DataHazardResolver_lastWrittenRd_valid && (DataHazardResolver_lastWrittenRd_id == pipelineRegs_EX_1_out_RS1));
  assign when_DataHazardResolver_l113_4 = (((writeback_arbitration_isValid && (! writeback_out_HAS_TRAPPED)) && (pipelineRegs_MEM_1_out_RD_TYPE == RegisterType_GPR)) && (pipelineRegs_MEM_1_out_RD == pipelineRegs_EX_1_out_RS1));
  always @(*) begin
    when_DataHazardResolver_l124_3 = 1'b0;
    if(memoryStage_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_3) begin
        if(when_DataHazardResolver_l100_3) begin
          when_DataHazardResolver_l124_3 = 1'b1;
        end
        if(when_DataHazardResolver_l113_5) begin
          if(pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            when_DataHazardResolver_l124_3 = 1'b1;
          end else begin
            if(memoryStage_arbitration_rs2Needed) begin
              when_DataHazardResolver_l124_3 = 1'b0;
            end
          end
        end
      end
    end
  end

  always @(*) begin
    _zz_in_RS2_DATA_1 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(memoryStage_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_3) begin
        if(when_DataHazardResolver_l100_3) begin
          _zz_in_RS2_DATA_1 = DataHazardResolver_lastWrittenRd_data;
        end
        if(when_DataHazardResolver_l113_5) begin
          if(pipelineRegs_MEM_1_out_RD_DATA_VALID) begin
            _zz_in_RS2_DATA_1 = pipelineRegs_MEM_1_out_RD_DATA;
          end
        end
      end
    end
  end

  assign when_DataHazardResolver_l99_3 = ((pipelineRegs_EX_1_out_RS2 != 5'h0) && (pipelineRegs_EX_1_out_RS2_TYPE == RegisterType_GPR));
  assign when_DataHazardResolver_l100_3 = (DataHazardResolver_lastWrittenRd_valid && (DataHazardResolver_lastWrittenRd_id == pipelineRegs_EX_1_out_RS2));
  assign when_DataHazardResolver_l113_5 = (((writeback_arbitration_isValid && (! writeback_out_HAS_TRAPPED)) && (pipelineRegs_MEM_1_out_RD_TYPE == RegisterType_GPR)) && (pipelineRegs_MEM_1_out_RD == pipelineRegs_EX_1_out_RS2));
  assign when_DataHazardResolver_l150_1 = (memoryStage_arbitration_isStalled || (! memoryStage_arbitration_isReady));
  always @(*) begin
    when_DataHazardResolver_l124_4 = 1'b0;
    if(writeback_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_4) begin
        if(when_DataHazardResolver_l100_4) begin
          when_DataHazardResolver_l124_4 = 1'b1;
        end
      end
    end
  end

  always @(*) begin
    _zz_in_RS1_DATA_2 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(writeback_arbitration_isValid) begin
      if(when_DataHazardResolver_l99_4) begin
        if(when_DataHazardResolver_l100_4) begin
          _zz_in_RS1_DATA_2 = DataHazardResolver_lastWrittenRd_data;
        end
      end
    end
  end

  assign when_DataHazardResolver_l99_4 = ((pipelineRegs_MEM_1_out_RS1 != 5'h0) && (pipelineRegs_MEM_1_out_RS1_TYPE == RegisterType_GPR));
  assign when_DataHazardResolver_l100_4 = (DataHazardResolver_lastWrittenRd_valid && (DataHazardResolver_lastWrittenRd_id == pipelineRegs_MEM_1_out_RS1));
  assign when_DataHazardResolver_l150_2 = (writeback_arbitration_isStalled || (! writeback_arbitration_isReady));
  assign ibus_cmd_valid = fetch_Fetcher_ibus_cmd_valid;
  assign ibus_cmd_payload_address = fetch_Fetcher_ibus_cmd_payload_address;
  assign ibus_cmd_payload_id = fetch_Fetcher_ibus_cmd_payload_id;
  assign ibus_rsp_ready = fetch_Fetcher_ibus_rsp_ready;
  assign dbus_cmd_valid = memoryStage_StaticMemoryBackbone_dbus_cmd_valid;
  assign dbus_cmd_payload_address = memoryStage_StaticMemoryBackbone_dbus_cmd_payload_address;
  assign dbus_cmd_payload_id = memoryStage_StaticMemoryBackbone_dbus_cmd_payload_id;
  assign dbus_cmd_payload_write = memoryStage_StaticMemoryBackbone_dbus_cmd_payload_write;
  assign dbus_cmd_payload_wdata = memoryStage_StaticMemoryBackbone_dbus_cmd_payload_wdata;
  assign dbus_cmd_payload_wmask = memoryStage_StaticMemoryBackbone_dbus_cmd_payload_wmask;
  assign dbus_rsp_ready = memoryStage_StaticMemoryBackbone_dbus_rsp_ready;
  assign when_PcManager_l129 = (writeback_arbitration_isDone && writeback_arbitration_jumpRequested);
  assign when_PcManager_l129_1 = (execute_arbitration_isDone && execute_arbitration_jumpRequested);
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      _zz_arbitration_isValid <= 1'b0;
      _zz_arbitration_isValid_1 <= 1'b0;
      _zz_arbitration_isValid_2 <= 1'b0;
      _zz_arbitration_isValid_3 <= 1'b0;
      ContractSignals_order <= 64'h0;
      PcManager_pc <= 32'h00000080;
    end else begin
      if(when_Scheduler_l42) begin
        _zz_arbitration_isValid <= fetch_arbitration_isDone;
      end
      if(when_Scheduler_l42_1) begin
        _zz_arbitration_isValid_1 <= decode_arbitration_isDone;
      end
      if(when_Scheduler_l42_2) begin
        _zz_arbitration_isValid_2 <= execute_arbitration_isDone;
      end
      if(when_Scheduler_l42_3) begin
        _zz_arbitration_isValid_3 <= memoryStage_arbitration_isDone;
      end
      if(retire) begin
        ContractSignals_order <= (ContractSignals_order + 64'h0000000000000001);
      end
      if(fetch_arbitration_isDone) begin
        PcManager_pc <= fetch_out_NEXT_PC;
      end
      if(_zz_when) begin
        PcManager_pc <= 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
      end else begin
        if(when_PcManager_l129) begin
          PcManager_pc <= writeback_out_NEXT_PC;
        end
        if(when_PcManager_l129_1) begin
          PcManager_pc <= execute_out_NEXT_PC;
        end
      end
      if(PcManager_pcOverride_valid) begin
        PcManager_pc <= PcManager_pcOverride_payload;
      end
    end
  end

  always @(posedge clk) begin
    if(when_DataHazardResolver_l77) begin
      DataHazardResolver_lastWrittenRd_id <= writeback_out_RD;
      DataHazardResolver_lastWrittenRd_valid <= (writeback_out_RD_DATA_VALID && (writeback_out_RD_TYPE == RegisterType_GPR));
      DataHazardResolver_lastWrittenRd_data <= writeback_out_RD_DATA;
    end
  end


endmodule

module RegisterFile (
  input  wire [4:0]    readIo_rs1,
  input  wire [4:0]    readIo_rs2,
  output wire [31:0]   readIo_rs1Data,
  output wire [31:0]   readIo_rs2Data,
  input  wire [4:0]    writeIo_rd,
  input  wire [31:0]   writeIo_data,
  input  wire          writeIo_write,
  input  wire          clk,
  input  wire          reset
);

  wire       [31:0]   regs_spinal_port0;
  wire       [31:0]   regs_spinal_port1;
  wire       [31:0]   regs_spinal_port2;
  wire       [31:0]   regs_spinal_port3;
  wire       [31:0]   regs_spinal_port4;
  wire       [31:0]   regs_spinal_port5;
  wire       [31:0]   regs_spinal_port6;
  wire       [31:0]   regs_spinal_port7;
  wire       [31:0]   regs_spinal_port8;
  wire       [31:0]   regs_spinal_port9;
  wire       [31:0]   regs_spinal_port10;
  wire       [31:0]   regs_spinal_port11;
  wire       [31:0]   regs_spinal_port12;
  wire       [31:0]   regs_spinal_port13;
  wire       [31:0]   regs_spinal_port14;
  wire       [31:0]   regs_spinal_port15;
  wire       [31:0]   regs_spinal_port16;
  wire       [31:0]   regs_spinal_port17;
  wire       [31:0]   regs_spinal_port18;
  wire       [31:0]   regs_spinal_port19;
  wire       [31:0]   regs_spinal_port20;
  wire       [31:0]   regs_spinal_port21;
  wire       [31:0]   regs_spinal_port22;
  wire       [31:0]   regs_spinal_port23;
  wire       [31:0]   regs_spinal_port24;
  wire       [31:0]   regs_spinal_port25;
  wire       [31:0]   regs_spinal_port26;
  wire       [31:0]   regs_spinal_port27;
  wire       [31:0]   regs_spinal_port28;
  wire       [31:0]   regs_spinal_port29;
  wire       [31:0]   regs_spinal_port30;
  wire       [31:0]   regs_spinal_port31;
  wire       [31:0]   regs_spinal_port32;
  wire       [31:0]   regs_spinal_port33;
  wire       [4:0]    _zz_regs_port;
  wire       [4:0]    _zz_x0_zero;
  wire       [4:0]    _zz_regs_port_1;
  wire       [4:0]    _zz_x1_ra_1;
  wire       [4:0]    _zz_regs_port_2;
  wire       [4:0]    _zz_x2_sp_1;
  wire       [4:0]    _zz_regs_port_3;
  wire       [4:0]    _zz_x3_gp_1;
  wire       [4:0]    _zz_regs_port_4;
  wire       [4:0]    _zz_x4_tp_1;
  wire       [4:0]    _zz_regs_port_5;
  wire       [4:0]    _zz_x5_t0_1;
  wire       [4:0]    _zz_regs_port_6;
  wire       [4:0]    _zz_x6_t1_1;
  wire       [4:0]    _zz_regs_port_7;
  wire       [4:0]    _zz_x7_t2_1;
  wire       [4:0]    _zz_regs_port_8;
  wire       [4:0]    _zz_x8_s0_fp_1;
  wire       [4:0]    _zz_regs_port_9;
  wire       [4:0]    _zz_x9_s1_1;
  wire       [4:0]    _zz_regs_port_10;
  wire       [4:0]    _zz_x10_a0_1;
  wire       [4:0]    _zz_regs_port_11;
  wire       [4:0]    _zz_x11_a1_1;
  wire       [4:0]    _zz_regs_port_12;
  wire       [4:0]    _zz_x12_a2_1;
  wire       [4:0]    _zz_regs_port_13;
  wire       [4:0]    _zz_x13_a3_1;
  wire       [4:0]    _zz_regs_port_14;
  wire       [4:0]    _zz_x14_a4_1;
  wire       [4:0]    _zz_regs_port_15;
  wire       [4:0]    _zz_x15_a5_1;
  wire       [4:0]    _zz_regs_port_16;
  wire       [4:0]    _zz_x16_a6;
  wire       [4:0]    _zz_regs_port_17;
  wire       [4:0]    _zz_x17_a7;
  wire       [4:0]    _zz_regs_port_18;
  wire       [4:0]    _zz_x18_s2;
  wire       [4:0]    _zz_regs_port_19;
  wire       [4:0]    _zz_x19_s3;
  wire       [4:0]    _zz_regs_port_20;
  wire       [4:0]    _zz_x20_s4;
  wire       [4:0]    _zz_regs_port_21;
  wire       [4:0]    _zz_x21_s5;
  wire       [4:0]    _zz_regs_port_22;
  wire       [4:0]    _zz_x22_s6;
  wire       [4:0]    _zz_regs_port_23;
  wire       [4:0]    _zz_x23_s7;
  wire       [4:0]    _zz_regs_port_24;
  wire       [4:0]    _zz_x24_s8;
  wire       [4:0]    _zz_regs_port_25;
  wire       [4:0]    _zz_x25_s9;
  wire       [4:0]    _zz_regs_port_26;
  wire       [4:0]    _zz_x26_s10;
  wire       [4:0]    _zz_regs_port_27;
  wire       [4:0]    _zz_x27_s11;
  wire       [4:0]    _zz_regs_port_28;
  wire       [4:0]    _zz_x28_t3;
  wire       [4:0]    _zz_regs_port_29;
  wire       [4:0]    _zz_x29_t4;
  wire       [4:0]    _zz_regs_port_30;
  wire       [4:0]    _zz_x30_t5;
  wire       [4:0]    _zz_regs_port_31;
  wire       [4:0]    _zz_x31_t6;
  wire       [31:0]   _zz_regs_port_32;
  reg                 _zz_1;
  wire       [31:0]   x0_zero;
  wire       [31:0]   x1_ra;
  wire       [0:0]    _zz_x1_ra;
  wire       [31:0]   x2_sp;
  wire       [1:0]    _zz_x2_sp;
  wire       [31:0]   x3_gp;
  wire       [1:0]    _zz_x3_gp;
  wire       [31:0]   x4_tp;
  wire       [2:0]    _zz_x4_tp;
  wire       [31:0]   x5_t0;
  wire       [2:0]    _zz_x5_t0;
  wire       [31:0]   x6_t1;
  wire       [2:0]    _zz_x6_t1;
  wire       [31:0]   x7_t2;
  wire       [2:0]    _zz_x7_t2;
  wire       [31:0]   x8_s0_fp;
  wire       [3:0]    _zz_x8_s0_fp;
  wire       [31:0]   x9_s1;
  wire       [3:0]    _zz_x9_s1;
  wire       [31:0]   x10_a0;
  wire       [3:0]    _zz_x10_a0;
  wire       [31:0]   x11_a1;
  wire       [3:0]    _zz_x11_a1;
  wire       [31:0]   x12_a2;
  wire       [3:0]    _zz_x12_a2;
  wire       [31:0]   x13_a3;
  wire       [3:0]    _zz_x13_a3;
  wire       [31:0]   x14_a4;
  wire       [3:0]    _zz_x14_a4;
  wire       [31:0]   x15_a5;
  wire       [3:0]    _zz_x15_a5;
  wire       [31:0]   x16_a6;
  wire       [31:0]   x17_a7;
  wire       [31:0]   x18_s2;
  wire       [31:0]   x19_s3;
  wire       [31:0]   x20_s4;
  wire       [31:0]   x21_s5;
  wire       [31:0]   x22_s6;
  wire       [31:0]   x23_s7;
  wire       [31:0]   x24_s8;
  wire       [31:0]   x25_s9;
  wire       [31:0]   x26_s10;
  wire       [31:0]   x27_s11;
  wire       [31:0]   x28_t3;
  wire       [31:0]   x29_t4;
  wire       [31:0]   x30_t5;
  wire       [31:0]   x31_t6;
  reg        [31:0]   _zz_readIo_rs1Data;
  reg        [31:0]   _zz_readIo_rs2Data;
  wire                when_RegisterFile_l92;
  (* ram_style = "distributed" *) reg [31:0] regs [0:31];

  assign _zz_x1_ra_1 = {4'd0, _zz_x1_ra};
  assign _zz_x2_sp_1 = {3'd0, _zz_x2_sp};
  assign _zz_x3_gp_1 = {3'd0, _zz_x3_gp};
  assign _zz_x4_tp_1 = {2'd0, _zz_x4_tp};
  assign _zz_x5_t0_1 = {2'd0, _zz_x5_t0};
  assign _zz_x6_t1_1 = {2'd0, _zz_x6_t1};
  assign _zz_x7_t2_1 = {2'd0, _zz_x7_t2};
  assign _zz_x8_s0_fp_1 = {1'd0, _zz_x8_s0_fp};
  assign _zz_x9_s1_1 = {1'd0, _zz_x9_s1};
  assign _zz_x10_a0_1 = {1'd0, _zz_x10_a0};
  assign _zz_x11_a1_1 = {1'd0, _zz_x11_a1};
  assign _zz_x12_a2_1 = {1'd0, _zz_x12_a2};
  assign _zz_x13_a3_1 = {1'd0, _zz_x13_a3};
  assign _zz_x14_a4_1 = {1'd0, _zz_x14_a4};
  assign _zz_x15_a5_1 = {1'd0, _zz_x15_a5};
  assign _zz_x0_zero = 5'h0;
  assign _zz_x16_a6 = 5'h10;
  assign _zz_x17_a7 = 5'h11;
  assign _zz_x18_s2 = 5'h12;
  assign _zz_x19_s3 = 5'h13;
  assign _zz_x20_s4 = 5'h14;
  assign _zz_x21_s5 = 5'h15;
  assign _zz_x22_s6 = 5'h16;
  assign _zz_x23_s7 = 5'h17;
  assign _zz_x24_s8 = 5'h18;
  assign _zz_x25_s9 = 5'h19;
  assign _zz_x26_s10 = 5'h1a;
  assign _zz_x27_s11 = 5'h1b;
  assign _zz_x28_t3 = 5'h1c;
  assign _zz_x29_t4 = 5'h1d;
  assign _zz_x30_t5 = 5'h1e;
  assign _zz_x31_t6 = 5'h1f;
  assign _zz_regs_port_32 = writeIo_data;
  assign regs_spinal_port0 = regs[_zz_x0_zero];
  assign regs_spinal_port1 = regs[_zz_x1_ra_1];
  assign regs_spinal_port2 = regs[_zz_x2_sp_1];
  assign regs_spinal_port3 = regs[_zz_x3_gp_1];
  assign regs_spinal_port4 = regs[_zz_x4_tp_1];
  assign regs_spinal_port5 = regs[_zz_x5_t0_1];
  assign regs_spinal_port6 = regs[_zz_x6_t1_1];
  assign regs_spinal_port7 = regs[_zz_x7_t2_1];
  assign regs_spinal_port8 = regs[_zz_x8_s0_fp_1];
  assign regs_spinal_port9 = regs[_zz_x9_s1_1];
  assign regs_spinal_port10 = regs[_zz_x10_a0_1];
  assign regs_spinal_port11 = regs[_zz_x11_a1_1];
  assign regs_spinal_port12 = regs[_zz_x12_a2_1];
  assign regs_spinal_port13 = regs[_zz_x13_a3_1];
  assign regs_spinal_port14 = regs[_zz_x14_a4_1];
  assign regs_spinal_port15 = regs[_zz_x15_a5_1];
  assign regs_spinal_port16 = regs[_zz_x16_a6];
  assign regs_spinal_port17 = regs[_zz_x17_a7];
  assign regs_spinal_port18 = regs[_zz_x18_s2];
  assign regs_spinal_port19 = regs[_zz_x19_s3];
  assign regs_spinal_port20 = regs[_zz_x20_s4];
  assign regs_spinal_port21 = regs[_zz_x21_s5];
  assign regs_spinal_port22 = regs[_zz_x22_s6];
  assign regs_spinal_port23 = regs[_zz_x23_s7];
  assign regs_spinal_port24 = regs[_zz_x24_s8];
  assign regs_spinal_port25 = regs[_zz_x25_s9];
  assign regs_spinal_port26 = regs[_zz_x26_s10];
  assign regs_spinal_port27 = regs[_zz_x27_s11];
  assign regs_spinal_port28 = regs[_zz_x28_t3];
  assign regs_spinal_port29 = regs[_zz_x29_t4];
  assign regs_spinal_port30 = regs[_zz_x30_t5];
  assign regs_spinal_port31 = regs[_zz_x31_t6];
  assign regs_spinal_port32 = regs[readIo_rs1];
  assign regs_spinal_port33 = regs[readIo_rs2];
  always @(posedge clk) begin
    if(_zz_1) begin
      regs[writeIo_rd] <= _zz_regs_port_32;
    end
  end

  always @(*) begin
    _zz_1 = 1'b0;
    if(when_RegisterFile_l92) begin
      _zz_1 = 1'b1;
    end
  end

  assign x0_zero = regs_spinal_port0;
  assign _zz_x1_ra = 1'b1;
  assign x1_ra = regs_spinal_port1;
  assign _zz_x2_sp = 2'b10;
  assign x2_sp = regs_spinal_port2;
  assign _zz_x3_gp = 2'b11;
  assign x3_gp = regs_spinal_port3;
  assign _zz_x4_tp = 3'b100;
  assign x4_tp = regs_spinal_port4;
  assign _zz_x5_t0 = 3'b101;
  assign x5_t0 = regs_spinal_port5;
  assign _zz_x6_t1 = 3'b110;
  assign x6_t1 = regs_spinal_port6;
  assign _zz_x7_t2 = 3'b111;
  assign x7_t2 = regs_spinal_port7;
  assign _zz_x8_s0_fp = 4'b1000;
  assign x8_s0_fp = regs_spinal_port8;
  assign _zz_x9_s1 = 4'b1001;
  assign x9_s1 = regs_spinal_port9;
  assign _zz_x10_a0 = 4'b1010;
  assign x10_a0 = regs_spinal_port10;
  assign _zz_x11_a1 = 4'b1011;
  assign x11_a1 = regs_spinal_port11;
  assign _zz_x12_a2 = 4'b1100;
  assign x12_a2 = regs_spinal_port12;
  assign _zz_x13_a3 = 4'b1101;
  assign x13_a3 = regs_spinal_port13;
  assign _zz_x14_a4 = 4'b1110;
  assign x14_a4 = regs_spinal_port14;
  assign _zz_x15_a5 = 4'b1111;
  assign x15_a5 = regs_spinal_port15;
  assign x16_a6 = regs_spinal_port16;
  assign x17_a7 = regs_spinal_port17;
  assign x18_s2 = regs_spinal_port18;
  assign x19_s3 = regs_spinal_port19;
  assign x20_s4 = regs_spinal_port20;
  assign x21_s5 = regs_spinal_port21;
  assign x22_s6 = regs_spinal_port22;
  assign x23_s7 = regs_spinal_port23;
  assign x24_s8 = regs_spinal_port24;
  assign x25_s9 = regs_spinal_port25;
  assign x26_s10 = regs_spinal_port26;
  assign x27_s11 = regs_spinal_port27;
  assign x28_t3 = regs_spinal_port28;
  assign x29_t4 = regs_spinal_port29;
  assign x30_t5 = regs_spinal_port30;
  assign x31_t6 = regs_spinal_port31;
  always @(*) begin
    case(readIo_rs1)
      5'h0 : begin
        _zz_readIo_rs1Data = 32'h0;
      end
      default : begin
        _zz_readIo_rs1Data = regs_spinal_port32;
      end
    endcase
  end

  assign readIo_rs1Data = _zz_readIo_rs1Data;
  always @(*) begin
    case(readIo_rs2)
      5'h0 : begin
        _zz_readIo_rs2Data = 32'h0;
      end
      default : begin
        _zz_readIo_rs2Data = regs_spinal_port33;
      end
    endcase
  end

  assign readIo_rs2Data = _zz_readIo_rs2Data;
  assign when_RegisterFile_l92 = (writeIo_write && (writeIo_rd != 5'h0));

endmodule

module CsrFile (
  input  wire [11:0]   io_rid,
  input  wire [11:0]   io_wid,
  output reg  [31:0]   io_rdata,
  input  wire [31:0]   io_wdata,
  input  wire          io_read,
  input  wire          io_write,
  output reg           io_error,
  output reg           writeNotify_write,
  output wire [31:0]   io_768_rdata,
  input  wire [31:0]   io_768_wdata,
  input  wire          io_768_write,
  output wire [31:0]   io_773_rdata,
  input  wire [31:0]   io_773_wdata,
  input  wire          io_773_write,
  output wire [31:0]   io_834_rdata,
  input  wire [31:0]   io_834_wdata,
  input  wire          io_834_write,
  output wire [31:0]   io_833_rdata,
  input  wire [31:0]   io_833_wdata,
  input  wire          io_833_write,
  output wire [31:0]   io_835_rdata,
  input  wire [31:0]   io_835_wdata,
  input  wire          io_835_write,
  input  wire          clk,
  input  wire          reset
);

  wire       [18:0]   _zz_CsrFile_mstatus;
  wire       [0:0]    _zz_CsrFile_mie;
  wire       [0:0]    _zz_CsrFile_mpie;
  wire       [0:0]    _zz_CsrFile_mie_1;
  wire       [0:0]    _zz_CsrFile_mpie_1;
  wire                CsrFile_uie;
  wire                CsrFile_sie;
  reg                 CsrFile_mie;
  wire                CsrFile_upie;
  wire                CsrFile_spie;
  reg                 CsrFile_mpie;
  wire                CsrFile_spp;
  wire       [1:0]    CsrFile_mpp;
  wire       [1:0]    CsrFile_fs;
  wire       [1:0]    CsrFile_xs;
  wire                CsrFile_mprv;
  wire                CsrFile_sum;
  wire                CsrFile_mxr;
  wire                CsrFile_tvm;
  wire                CsrFile_tw;
  wire                CsrFile_tsr;
  wire                CsrFile_sd;
  wire       [31:0]   CsrFile_mstatus;
  wire       [1:0]    CsrFile_mxl;
  reg        [25:0]   CsrFile_extensions;
  wire       [3:0]    CsrFile_filling;
  wire       [31:0]   CsrFile_misa;
  reg        [31:0]   CsrFile_mtvec;
  wire       [31:0]   CsrFile_base;
  wire       [1:0]    CsrFile_mode;
  reg        [31:0]   CsrFile_scratch;
  reg        [29:0]   CsrFile_epc;
  reg                 CsrFile_interrupt;
  reg        [3:0]    CsrFile_cause;
  reg        [26:0]   _zz_CsrFile_mcause;
  wire       [31:0]   CsrFile_mcause;
  reg        [31:0]   CsrFile_tval;
  function [25:0] zz_CsrFile_extensions(input dummy);
    begin
      zz_CsrFile_extensions = 26'h0;
      zz_CsrFile_extensions[8] = 1'b1;
      zz_CsrFile_extensions[12] = 1'b1;
    end
  endfunction
  wire [25:0] _zz_1;
  function [26:0] zz__zz_CsrFile_mcause(input dummy);
    begin
      zz__zz_CsrFile_mcause[26] = 1'b0;
      zz__zz_CsrFile_mcause[25] = 1'b0;
      zz__zz_CsrFile_mcause[24] = 1'b0;
      zz__zz_CsrFile_mcause[23] = 1'b0;
      zz__zz_CsrFile_mcause[22] = 1'b0;
      zz__zz_CsrFile_mcause[21] = 1'b0;
      zz__zz_CsrFile_mcause[20] = 1'b0;
      zz__zz_CsrFile_mcause[19] = 1'b0;
      zz__zz_CsrFile_mcause[18] = 1'b0;
      zz__zz_CsrFile_mcause[17] = 1'b0;
      zz__zz_CsrFile_mcause[16] = 1'b0;
      zz__zz_CsrFile_mcause[15] = 1'b0;
      zz__zz_CsrFile_mcause[14] = 1'b0;
      zz__zz_CsrFile_mcause[13] = 1'b0;
      zz__zz_CsrFile_mcause[12] = 1'b0;
      zz__zz_CsrFile_mcause[11] = 1'b0;
      zz__zz_CsrFile_mcause[10] = 1'b0;
      zz__zz_CsrFile_mcause[9] = 1'b0;
      zz__zz_CsrFile_mcause[8] = 1'b0;
      zz__zz_CsrFile_mcause[7] = 1'b0;
      zz__zz_CsrFile_mcause[6] = 1'b0;
      zz__zz_CsrFile_mcause[5] = 1'b0;
      zz__zz_CsrFile_mcause[4] = 1'b0;
      zz__zz_CsrFile_mcause[3] = 1'b0;
      zz__zz_CsrFile_mcause[2] = 1'b0;
      zz__zz_CsrFile_mcause[1] = 1'b0;
      zz__zz_CsrFile_mcause[0] = 1'b0;
    end
  endfunction
  wire [26:0] _zz_2;

  assign _zz_CsrFile_mie = io_wdata[3 : 3];
  assign _zz_CsrFile_mpie = io_wdata[7 : 7];
  assign _zz_CsrFile_mie_1 = io_768_wdata[3 : 3];
  assign _zz_CsrFile_mpie_1 = io_768_wdata[7 : 7];
  assign _zz_CsrFile_mstatus = {{{{{{{{{CsrFile_sd,8'h0},CsrFile_tsr},CsrFile_tw},CsrFile_tvm},CsrFile_mxr},CsrFile_sum},CsrFile_mprv},CsrFile_xs},CsrFile_fs};
  assign CsrFile_uie = 1'b0;
  assign CsrFile_sie = 1'b0;
  assign CsrFile_upie = 1'b0;
  assign CsrFile_spie = 1'b0;
  assign CsrFile_spp = 1'b0;
  assign CsrFile_mpp = 2'b11;
  assign CsrFile_fs = 2'b00;
  assign CsrFile_xs = 2'b00;
  assign CsrFile_mprv = 1'b0;
  assign CsrFile_sum = 1'b0;
  assign CsrFile_mxr = 1'b0;
  assign CsrFile_tvm = 1'b0;
  assign CsrFile_tw = 1'b0;
  assign CsrFile_tsr = 1'b0;
  assign CsrFile_sd = 1'b0;
  assign CsrFile_mstatus = {{{{{{{{{{{_zz_CsrFile_mstatus,CsrFile_mpp},2'b00},CsrFile_spp},CsrFile_mpie},1'b0},CsrFile_spie},CsrFile_upie},CsrFile_mie},1'b0},CsrFile_sie},CsrFile_uie};
  assign CsrFile_mxl = 2'b01;
  assign _zz_1 = zz_CsrFile_extensions(1'b0);
  always @(*) CsrFile_extensions = _zz_1;
  assign CsrFile_filling = 4'b0000;
  assign CsrFile_misa = {{CsrFile_mxl,CsrFile_filling},CsrFile_extensions};
  assign CsrFile_base = ({2'd0,CsrFile_mtvec[31 : 2]} <<< 2'd2);
  assign CsrFile_mode = CsrFile_mtvec[1 : 0];
  assign _zz_2 = zz__zz_CsrFile_mcause(1'b0);
  always @(*) _zz_CsrFile_mcause = _zz_2;
  assign CsrFile_mcause = {CsrFile_interrupt,{_zz_CsrFile_mcause,CsrFile_cause}};
  always @(*) begin
    io_rdata = 32'h0;
    if(io_read) begin
      case(io_rid)
        12'h300 : begin
          io_rdata = CsrFile_mstatus;
        end
        12'hf11 : begin
          io_rdata = 32'h0;
        end
        12'hf14 : begin
          io_rdata = 32'h0;
        end
        12'h341 : begin
          io_rdata = ({2'd0,CsrFile_epc} <<< 2'd2);
        end
        12'h305 : begin
          io_rdata = CsrFile_mtvec;
        end
        12'h343 : begin
          io_rdata = CsrFile_tval;
        end
        12'hf13 : begin
          io_rdata = 32'h0;
        end
        12'h340 : begin
          io_rdata = CsrFile_scratch;
        end
        12'h301 : begin
          io_rdata = CsrFile_misa;
        end
        12'hf12 : begin
          io_rdata = 32'h00000020;
        end
        12'h342 : begin
          io_rdata = CsrFile_mcause;
        end
        default : begin
        end
      endcase
    end
  end

  always @(*) begin
    io_error = 1'b0;
    if(io_read) begin
      case(io_rid)
        12'h300 : begin
        end
        12'hf11 : begin
        end
        12'hf14 : begin
        end
        12'h341 : begin
        end
        12'h305 : begin
        end
        12'h343 : begin
        end
        12'hf13 : begin
        end
        12'h340 : begin
        end
        12'h301 : begin
        end
        12'hf12 : begin
        end
        12'h342 : begin
        end
        default : begin
          io_error = 1'b1;
        end
      endcase
    end
    if(io_write) begin
      case(io_wid)
        12'h300 : begin
        end
        12'hf11 : begin
          io_error = 1'b1;
        end
        12'hf14 : begin
          io_error = 1'b1;
        end
        12'h341 : begin
        end
        12'h305 : begin
        end
        12'h343 : begin
        end
        12'hf13 : begin
          io_error = 1'b1;
        end
        12'h340 : begin
        end
        12'h301 : begin
        end
        12'hf12 : begin
          io_error = 1'b1;
        end
        12'h342 : begin
        end
        default : begin
          io_error = 1'b1;
        end
      endcase
    end
  end

  always @(*) begin
    writeNotify_write = 1'b0;
    if(io_write) begin
      case(io_wid)
        12'h300 : begin
          writeNotify_write = 1'b1;
        end
        12'hf11 : begin
        end
        12'hf14 : begin
        end
        12'h341 : begin
          writeNotify_write = 1'b1;
        end
        12'h305 : begin
          writeNotify_write = 1'b1;
        end
        12'h343 : begin
          writeNotify_write = 1'b1;
        end
        12'hf13 : begin
        end
        12'h340 : begin
          writeNotify_write = 1'b1;
        end
        12'h301 : begin
          writeNotify_write = 1'b1;
        end
        12'hf12 : begin
        end
        12'h342 : begin
          writeNotify_write = 1'b1;
        end
        default : begin
        end
      endcase
    end
  end

  assign io_768_rdata = CsrFile_mstatus;
  assign io_773_rdata = CsrFile_mtvec;
  assign io_834_rdata = CsrFile_mcause;
  assign io_833_rdata = ({2'd0,CsrFile_epc} <<< 2'd2);
  assign io_835_rdata = CsrFile_tval;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      CsrFile_mie <= 1'b0;
      CsrFile_mpie <= 1'b0;
      CsrFile_interrupt <= 1'b0;
      CsrFile_cause <= 4'b0000;
    end else begin
      if(io_write) begin
        case(io_wid)
          12'h300 : begin
            CsrFile_mie <= _zz_CsrFile_mie[0];
            CsrFile_mpie <= _zz_CsrFile_mpie[0];
          end
          12'hf11 : begin
          end
          12'hf14 : begin
          end
          12'h341 : begin
          end
          12'h305 : begin
          end
          12'h343 : begin
          end
          12'hf13 : begin
          end
          12'h340 : begin
          end
          12'h301 : begin
          end
          12'hf12 : begin
          end
          12'h342 : begin
            CsrFile_interrupt <= io_wdata[31];
            CsrFile_cause <= io_wdata[3 : 0];
          end
          default : begin
          end
        endcase
      end
      if(io_768_write) begin
        CsrFile_mie <= _zz_CsrFile_mie_1[0];
        CsrFile_mpie <= _zz_CsrFile_mpie_1[0];
      end
      if(io_834_write) begin
        CsrFile_interrupt <= io_834_wdata[31];
        CsrFile_cause <= io_834_wdata[3 : 0];
      end
    end
  end

  always @(posedge clk) begin
    if(io_write) begin
      case(io_wid)
        12'h300 : begin
        end
        12'hf11 : begin
        end
        12'hf14 : begin
        end
        12'h341 : begin
          CsrFile_epc <= (io_wdata >>> 2'd2);
        end
        12'h305 : begin
          CsrFile_mtvec <= io_wdata;
        end
        12'h343 : begin
          CsrFile_tval <= io_wdata;
        end
        12'hf13 : begin
        end
        12'h340 : begin
          CsrFile_scratch <= io_wdata;
        end
        12'h301 : begin
        end
        12'hf12 : begin
        end
        12'h342 : begin
        end
        default : begin
        end
      endcase
    end
    if(io_773_write) begin
      CsrFile_mtvec <= io_773_wdata;
    end
    if(io_833_write) begin
      CsrFile_epc <= (io_833_wdata >>> 2'd2);
    end
    if(io_835_write) begin
      CsrFile_tval <= io_835_wdata;
    end
  end


endmodule

module PipelineRegs_MEM (
  input  wire          shift,
  input  wire [4:0]    in_RS1,
  output wire [4:0]    out_RS1,
  input  wire          shift_RS1,
  input  wire [31:0]   in_PC,
  output wire [31:0]   out_PC,
  input  wire          shift_PC,
  input  wire          in_RD_DATA_VALID,
  output wire          out_RD_DATA_VALID,
  input  wire          shift_RD_DATA_VALID,
  input  wire [3:0]    in_TRAP_CAUSE,
  output wire [3:0]    out_TRAP_CAUSE,
  input  wire          shift_TRAP_CAUSE,
  input  wire          in_MRET,
  output wire          out_MRET,
  input  wire          shift_MRET,
  input  wire [0:0]    in_RS2_TYPE,
  output wire [0:0]    out_RS2_TYPE,
  input  wire          shift_RS2_TYPE,
  input  wire [31:0]   in_TRAP_VAL,
  output wire [31:0]   out_TRAP_VAL,
  input  wire          shift_TRAP_VAL,
  input  wire [31:0]   in_RD_DATA,
  output wire [31:0]   out_RD_DATA,
  input  wire          shift_RD_DATA,
  input  wire [0:0]    in_RD_TYPE,
  output wire [0:0]    out_RD_TYPE,
  input  wire          shift_RD_TYPE,
  input  wire          in_HAS_TRAPPED,
  output wire          out_HAS_TRAPPED,
  input  wire          shift_HAS_TRAPPED,
  input  wire          in_TRAP_IS_INTERRUPT,
  output wire          out_TRAP_IS_INTERRUPT,
  input  wire          shift_TRAP_IS_INTERRUPT,
  input  wire [4:0]    in_RD,
  output wire [4:0]    out_RD,
  input  wire          shift_RD,
  input  wire [31:0]   in_RS1_DATA,
  output wire [31:0]   out_RS1_DATA,
  input  wire          shift_RS1_DATA,
  input  wire [1:0]    in_CSR_OP,
  output wire [1:0]    out_CSR_OP,
  input  wire          shift_CSR_OP,
  input  wire [4:0]    in_RS2,
  output wire [4:0]    out_RS2,
  input  wire          shift_RS2,
  input  wire [31:0]   in_IR,
  output wire [31:0]   out_IR,
  input  wire          shift_IR,
  input  wire [31:0]   in_NEXT_PC,
  output wire [31:0]   out_NEXT_PC,
  input  wire          shift_NEXT_PC,
  input  wire [0:0]    in_RS1_TYPE,
  output wire [0:0]    out_RS1_TYPE,
  input  wire          shift_RS1_TYPE,
  input  wire          in_CSR_USE_IMM,
  output wire          out_CSR_USE_IMM,
  input  wire          shift_CSR_USE_IMM,
  input  wire          clk,
  input  wire          reset
);
  localparam RegisterType_NONE = 1'd0;
  localparam RegisterType_GPR = 1'd1;
  localparam CsrOp_NONE = 2'd0;
  localparam CsrOp_RW = 2'd1;
  localparam CsrOp_RS = 2'd2;
  localparam CsrOp_RC = 2'd3;

  wire                when_PipelineRegs_l19;
  reg        [4:0]    reg_RS1;
  wire                when_PipelineRegs_l19_1;
  reg        [31:0]   reg_PC;
  wire                when_PipelineRegs_l19_2;
  reg                 reg_RD_DATA_VALID;
  wire                when_PipelineRegs_l19_3;
  reg        [3:0]    reg_TRAP_CAUSE;
  wire                when_PipelineRegs_l19_4;
  reg                 reg_MRET;
  wire                when_PipelineRegs_l19_5;
  reg        [0:0]    reg_RS2_TYPE;
  wire       [0:0]    _zz_reg_RS2_TYPE;
  wire       [0:0]    _zz_reg_RS2_TYPE_1;
  wire                when_PipelineRegs_l19_6;
  reg        [31:0]   reg_TRAP_VAL;
  wire                when_PipelineRegs_l19_7;
  reg        [31:0]   reg_RD_DATA;
  wire                when_PipelineRegs_l19_8;
  reg        [0:0]    reg_RD_TYPE;
  wire       [0:0]    _zz_reg_RD_TYPE;
  wire       [0:0]    _zz_reg_RD_TYPE_1;
  wire                when_PipelineRegs_l19_9;
  reg                 reg_HAS_TRAPPED;
  wire                when_PipelineRegs_l19_10;
  reg                 reg_TRAP_IS_INTERRUPT;
  wire                when_PipelineRegs_l19_11;
  reg        [4:0]    reg_RD;
  wire                when_PipelineRegs_l19_12;
  reg        [31:0]   reg_RS1_DATA;
  wire                when_PipelineRegs_l19_13;
  reg        [1:0]    reg_CSR_OP;
  wire       [1:0]    _zz_reg_CSR_OP;
  wire       [1:0]    _zz_reg_CSR_OP_1;
  wire                when_PipelineRegs_l19_14;
  reg        [4:0]    reg_RS2;
  wire                when_PipelineRegs_l19_15;
  reg        [31:0]   reg_IR;
  wire                when_PipelineRegs_l19_16;
  reg        [31:0]   reg_NEXT_PC;
  wire                when_PipelineRegs_l19_17;
  reg        [0:0]    reg_RS1_TYPE;
  wire       [0:0]    _zz_reg_RS1_TYPE;
  wire       [0:0]    _zz_reg_RS1_TYPE_1;
  wire                when_PipelineRegs_l19_18;
  reg                 reg_CSR_USE_IMM;
  `ifndef SYNTHESIS
  reg [31:0] in_RS2_TYPE_string;
  reg [31:0] out_RS2_TYPE_string;
  reg [31:0] reg_RS2_TYPE_string;
  reg [31:0] _zz_reg_RS2_TYPE_string;
  reg [31:0] _zz_reg_RS2_TYPE_1_string;
  reg [31:0] in_RD_TYPE_string;
  reg [31:0] out_RD_TYPE_string;
  reg [31:0] reg_RD_TYPE_string;
  reg [31:0] _zz_reg_RD_TYPE_string;
  reg [31:0] _zz_reg_RD_TYPE_1_string;
  reg [31:0] in_CSR_OP_string;
  reg [31:0] out_CSR_OP_string;
  reg [31:0] reg_CSR_OP_string;
  reg [31:0] _zz_reg_CSR_OP_string;
  reg [31:0] _zz_reg_CSR_OP_1_string;
  reg [31:0] in_RS1_TYPE_string;
  reg [31:0] out_RS1_TYPE_string;
  reg [31:0] reg_RS1_TYPE_string;
  reg [31:0] _zz_reg_RS1_TYPE_string;
  reg [31:0] _zz_reg_RS1_TYPE_1_string;
  `endif


  `ifndef SYNTHESIS
  always @(*) begin
    case(in_RS2_TYPE)
      RegisterType_NONE : in_RS2_TYPE_string = "NONE";
      RegisterType_GPR : in_RS2_TYPE_string = "GPR ";
      default : in_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS2_TYPE)
      RegisterType_NONE : out_RS2_TYPE_string = "NONE";
      RegisterType_GPR : out_RS2_TYPE_string = "GPR ";
      default : out_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RS2_TYPE)
      RegisterType_NONE : reg_RS2_TYPE_string = "NONE";
      RegisterType_GPR : reg_RS2_TYPE_string = "GPR ";
      default : reg_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS2_TYPE)
      RegisterType_NONE : _zz_reg_RS2_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RS2_TYPE_string = "GPR ";
      default : _zz_reg_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS2_TYPE_1)
      RegisterType_NONE : _zz_reg_RS2_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RS2_TYPE_1_string = "GPR ";
      default : _zz_reg_RS2_TYPE_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RD_TYPE)
      RegisterType_NONE : in_RD_TYPE_string = "NONE";
      RegisterType_GPR : in_RD_TYPE_string = "GPR ";
      default : in_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RD_TYPE)
      RegisterType_NONE : out_RD_TYPE_string = "NONE";
      RegisterType_GPR : out_RD_TYPE_string = "GPR ";
      default : out_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RD_TYPE)
      RegisterType_NONE : reg_RD_TYPE_string = "NONE";
      RegisterType_GPR : reg_RD_TYPE_string = "GPR ";
      default : reg_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RD_TYPE)
      RegisterType_NONE : _zz_reg_RD_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RD_TYPE_string = "GPR ";
      default : _zz_reg_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RD_TYPE_1)
      RegisterType_NONE : _zz_reg_RD_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RD_TYPE_1_string = "GPR ";
      default : _zz_reg_RD_TYPE_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_CSR_OP)
      CsrOp_NONE : in_CSR_OP_string = "NONE";
      CsrOp_RW : in_CSR_OP_string = "RW  ";
      CsrOp_RS : in_CSR_OP_string = "RS  ";
      CsrOp_RC : in_CSR_OP_string = "RC  ";
      default : in_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(out_CSR_OP)
      CsrOp_NONE : out_CSR_OP_string = "NONE";
      CsrOp_RW : out_CSR_OP_string = "RW  ";
      CsrOp_RS : out_CSR_OP_string = "RS  ";
      CsrOp_RC : out_CSR_OP_string = "RC  ";
      default : out_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_CSR_OP)
      CsrOp_NONE : reg_CSR_OP_string = "NONE";
      CsrOp_RW : reg_CSR_OP_string = "RW  ";
      CsrOp_RS : reg_CSR_OP_string = "RS  ";
      CsrOp_RC : reg_CSR_OP_string = "RC  ";
      default : reg_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_CSR_OP)
      CsrOp_NONE : _zz_reg_CSR_OP_string = "NONE";
      CsrOp_RW : _zz_reg_CSR_OP_string = "RW  ";
      CsrOp_RS : _zz_reg_CSR_OP_string = "RS  ";
      CsrOp_RC : _zz_reg_CSR_OP_string = "RC  ";
      default : _zz_reg_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_CSR_OP_1)
      CsrOp_NONE : _zz_reg_CSR_OP_1_string = "NONE";
      CsrOp_RW : _zz_reg_CSR_OP_1_string = "RW  ";
      CsrOp_RS : _zz_reg_CSR_OP_1_string = "RS  ";
      CsrOp_RC : _zz_reg_CSR_OP_1_string = "RC  ";
      default : _zz_reg_CSR_OP_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RS1_TYPE)
      RegisterType_NONE : in_RS1_TYPE_string = "NONE";
      RegisterType_GPR : in_RS1_TYPE_string = "GPR ";
      default : in_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS1_TYPE)
      RegisterType_NONE : out_RS1_TYPE_string = "NONE";
      RegisterType_GPR : out_RS1_TYPE_string = "GPR ";
      default : out_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RS1_TYPE)
      RegisterType_NONE : reg_RS1_TYPE_string = "NONE";
      RegisterType_GPR : reg_RS1_TYPE_string = "GPR ";
      default : reg_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS1_TYPE)
      RegisterType_NONE : _zz_reg_RS1_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RS1_TYPE_string = "GPR ";
      default : _zz_reg_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS1_TYPE_1)
      RegisterType_NONE : _zz_reg_RS1_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RS1_TYPE_1_string = "GPR ";
      default : _zz_reg_RS1_TYPE_1_string = "????";
    endcase
  end
  `endif

  assign when_PipelineRegs_l19 = (shift || shift_RS1);
  assign out_RS1 = reg_RS1;
  assign when_PipelineRegs_l19_1 = (shift || shift_PC);
  assign out_PC = reg_PC;
  assign when_PipelineRegs_l19_2 = (shift || shift_RD_DATA_VALID);
  assign out_RD_DATA_VALID = reg_RD_DATA_VALID;
  assign when_PipelineRegs_l19_3 = (shift || shift_TRAP_CAUSE);
  assign out_TRAP_CAUSE = reg_TRAP_CAUSE;
  assign when_PipelineRegs_l19_4 = (shift || shift_MRET);
  assign out_MRET = reg_MRET;
  assign when_PipelineRegs_l19_5 = (shift || shift_RS2_TYPE);
  assign _zz_reg_RS2_TYPE_1 = 1'b0;
  assign _zz_reg_RS2_TYPE = _zz_reg_RS2_TYPE_1;
  assign out_RS2_TYPE = reg_RS2_TYPE;
  assign when_PipelineRegs_l19_6 = (shift || shift_TRAP_VAL);
  assign out_TRAP_VAL = reg_TRAP_VAL;
  assign when_PipelineRegs_l19_7 = (shift || shift_RD_DATA);
  assign out_RD_DATA = reg_RD_DATA;
  assign when_PipelineRegs_l19_8 = (shift || shift_RD_TYPE);
  assign _zz_reg_RD_TYPE_1 = 1'b0;
  assign _zz_reg_RD_TYPE = _zz_reg_RD_TYPE_1;
  assign out_RD_TYPE = reg_RD_TYPE;
  assign when_PipelineRegs_l19_9 = (shift || shift_HAS_TRAPPED);
  assign out_HAS_TRAPPED = reg_HAS_TRAPPED;
  assign when_PipelineRegs_l19_10 = (shift || shift_TRAP_IS_INTERRUPT);
  assign out_TRAP_IS_INTERRUPT = reg_TRAP_IS_INTERRUPT;
  assign when_PipelineRegs_l19_11 = (shift || shift_RD);
  assign out_RD = reg_RD;
  assign when_PipelineRegs_l19_12 = (shift || shift_RS1_DATA);
  assign out_RS1_DATA = reg_RS1_DATA;
  assign when_PipelineRegs_l19_13 = (shift || shift_CSR_OP);
  assign _zz_reg_CSR_OP_1 = 2'b00;
  assign _zz_reg_CSR_OP = _zz_reg_CSR_OP_1;
  assign out_CSR_OP = reg_CSR_OP;
  assign when_PipelineRegs_l19_14 = (shift || shift_RS2);
  assign out_RS2 = reg_RS2;
  assign when_PipelineRegs_l19_15 = (shift || shift_IR);
  assign out_IR = reg_IR;
  assign when_PipelineRegs_l19_16 = (shift || shift_NEXT_PC);
  assign out_NEXT_PC = reg_NEXT_PC;
  assign when_PipelineRegs_l19_17 = (shift || shift_RS1_TYPE);
  assign _zz_reg_RS1_TYPE_1 = 1'b0;
  assign _zz_reg_RS1_TYPE = _zz_reg_RS1_TYPE_1;
  assign out_RS1_TYPE = reg_RS1_TYPE;
  assign when_PipelineRegs_l19_18 = (shift || shift_CSR_USE_IMM);
  assign out_CSR_USE_IMM = reg_CSR_USE_IMM;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      reg_RS1 <= 5'h0;
      reg_PC <= 32'h0;
      reg_RD_DATA_VALID <= 1'b0;
      reg_TRAP_CAUSE <= 4'b0000;
      reg_MRET <= 1'b0;
      reg_RS2_TYPE <= _zz_reg_RS2_TYPE;
      reg_TRAP_VAL <= 32'h0;
      reg_RD_DATA <= 32'h0;
      reg_RD_TYPE <= _zz_reg_RD_TYPE;
      reg_HAS_TRAPPED <= 1'b0;
      reg_TRAP_IS_INTERRUPT <= 1'b0;
      reg_RD <= 5'h0;
      reg_RS1_DATA <= 32'h0;
      reg_CSR_OP <= _zz_reg_CSR_OP;
      reg_RS2 <= 5'h0;
      reg_IR <= 32'h0;
      reg_NEXT_PC <= 32'h0;
      reg_RS1_TYPE <= _zz_reg_RS1_TYPE;
      reg_CSR_USE_IMM <= 1'b0;
    end else begin
      if(when_PipelineRegs_l19) begin
        reg_RS1 <= in_RS1;
      end
      if(when_PipelineRegs_l19_1) begin
        reg_PC <= in_PC;
      end
      if(when_PipelineRegs_l19_2) begin
        reg_RD_DATA_VALID <= in_RD_DATA_VALID;
      end
      if(when_PipelineRegs_l19_3) begin
        reg_TRAP_CAUSE <= in_TRAP_CAUSE;
      end
      if(when_PipelineRegs_l19_4) begin
        reg_MRET <= in_MRET;
      end
      if(when_PipelineRegs_l19_5) begin
        reg_RS2_TYPE <= in_RS2_TYPE;
      end
      if(when_PipelineRegs_l19_6) begin
        reg_TRAP_VAL <= in_TRAP_VAL;
      end
      if(when_PipelineRegs_l19_7) begin
        reg_RD_DATA <= in_RD_DATA;
      end
      if(when_PipelineRegs_l19_8) begin
        reg_RD_TYPE <= in_RD_TYPE;
      end
      if(when_PipelineRegs_l19_9) begin
        reg_HAS_TRAPPED <= in_HAS_TRAPPED;
      end
      if(when_PipelineRegs_l19_10) begin
        reg_TRAP_IS_INTERRUPT <= in_TRAP_IS_INTERRUPT;
      end
      if(when_PipelineRegs_l19_11) begin
        reg_RD <= in_RD;
      end
      if(when_PipelineRegs_l19_12) begin
        reg_RS1_DATA <= in_RS1_DATA;
      end
      if(when_PipelineRegs_l19_13) begin
        reg_CSR_OP <= in_CSR_OP;
      end
      if(when_PipelineRegs_l19_14) begin
        reg_RS2 <= in_RS2;
      end
      if(when_PipelineRegs_l19_15) begin
        reg_IR <= in_IR;
      end
      if(when_PipelineRegs_l19_16) begin
        reg_NEXT_PC <= in_NEXT_PC;
      end
      if(when_PipelineRegs_l19_17) begin
        reg_RS1_TYPE <= in_RS1_TYPE;
      end
      if(when_PipelineRegs_l19_18) begin
        reg_CSR_USE_IMM <= in_CSR_USE_IMM;
      end
    end
  end


endmodule

module PipelineRegs_EX (
  input  wire          shift,
  input  wire [31:0]   in_RS2_DATA,
  output wire [31:0]   out_RS2_DATA,
  input  wire          shift_RS2_DATA,
  input  wire [4:0]    in_RS1,
  output wire [4:0]    out_RS1,
  input  wire          shift_RS1,
  input  wire [31:0]   in_PC,
  output wire [31:0]   out_PC,
  input  wire          shift_PC,
  input  wire          in_RD_DATA_VALID,
  output wire          out_RD_DATA_VALID,
  input  wire          shift_RD_DATA_VALID,
  input  wire [3:0]    in_TRAP_CAUSE,
  output wire [3:0]    out_TRAP_CAUSE,
  input  wire          shift_TRAP_CAUSE,
  input  wire          in_MRET,
  output wire          out_MRET,
  input  wire          shift_MRET,
  input  wire [0:0]    in_RS2_TYPE,
  output wire [0:0]    out_RS2_TYPE,
  input  wire          shift_RS2_TYPE,
  input  wire [31:0]   in_TRAP_VAL,
  output wire [31:0]   out_TRAP_VAL,
  input  wire          shift_TRAP_VAL,
  input  wire [31:0]   in_RD_DATA,
  output wire [31:0]   out_RD_DATA,
  input  wire          shift_RD_DATA,
  input  wire [0:0]    in_RD_TYPE,
  output wire [0:0]    out_RD_TYPE,
  input  wire          shift_RD_TYPE,
  input  wire          in_LSU_IS_UNSIGNED,
  output wire          out_LSU_IS_UNSIGNED,
  input  wire          shift_LSU_IS_UNSIGNED,
  input  wire          in_HAS_TRAPPED,
  output wire          out_HAS_TRAPPED,
  input  wire          shift_HAS_TRAPPED,
  input  wire          in_TRAP_IS_INTERRUPT,
  output wire          out_TRAP_IS_INTERRUPT,
  input  wire          shift_TRAP_IS_INTERRUPT,
  input  wire [4:0]    in_RD,
  output wire [4:0]    out_RD,
  input  wire          shift_RD,
  input  wire [31:0]   in_RS1_DATA,
  output wire [31:0]   out_RS1_DATA,
  input  wire          shift_RS1_DATA,
  input  wire [1:0]    in_LSU_OPERATION_TYPE,
  output wire [1:0]    out_LSU_OPERATION_TYPE,
  input  wire          shift_LSU_OPERATION_TYPE,
  input  wire [1:0]    in_LSU_ACCESS_WIDTH,
  output wire [1:0]    out_LSU_ACCESS_WIDTH,
  input  wire          shift_LSU_ACCESS_WIDTH,
  input  wire [1:0]    in_CSR_OP,
  output wire [1:0]    out_CSR_OP,
  input  wire          shift_CSR_OP,
  input  wire [4:0]    in_RS2,
  output wire [4:0]    out_RS2,
  input  wire          shift_RS2,
  input  wire [31:0]   in_IR,
  output wire [31:0]   out_IR,
  input  wire          shift_IR,
  input  wire [31:0]   in_ALU_RESULT,
  output wire [31:0]   out_ALU_RESULT,
  input  wire          shift_ALU_RESULT,
  input  wire [31:0]   in_NEXT_PC,
  output wire [31:0]   out_NEXT_PC,
  input  wire          shift_NEXT_PC,
  input  wire [0:0]    in_RS1_TYPE,
  output wire [0:0]    out_RS1_TYPE,
  input  wire          shift_RS1_TYPE,
  input  wire          in_LSU_TARGET_VALID,
  output wire          out_LSU_TARGET_VALID,
  input  wire          shift_LSU_TARGET_VALID,
  input  wire          in_CSR_USE_IMM,
  output wire          out_CSR_USE_IMM,
  input  wire          shift_CSR_USE_IMM,
  input  wire          clk,
  input  wire          reset
);
  localparam RegisterType_NONE = 1'd0;
  localparam RegisterType_GPR = 1'd1;
  localparam LsuOperationType_NONE = 2'd0;
  localparam LsuOperationType_LOAD = 2'd1;
  localparam LsuOperationType_STORE = 2'd2;
  localparam LsuAccessWidth_B = 2'd0;
  localparam LsuAccessWidth_H = 2'd1;
  localparam LsuAccessWidth_W = 2'd2;
  localparam CsrOp_NONE = 2'd0;
  localparam CsrOp_RW = 2'd1;
  localparam CsrOp_RS = 2'd2;
  localparam CsrOp_RC = 2'd3;

  wire                when_PipelineRegs_l19;
  reg        [31:0]   reg_RS2_DATA;
  wire                when_PipelineRegs_l19_1;
  reg        [4:0]    reg_RS1;
  wire                when_PipelineRegs_l19_2;
  reg        [31:0]   reg_PC;
  wire                when_PipelineRegs_l19_3;
  reg                 reg_RD_DATA_VALID;
  wire                when_PipelineRegs_l19_4;
  reg        [3:0]    reg_TRAP_CAUSE;
  wire                when_PipelineRegs_l19_5;
  reg                 reg_MRET;
  wire                when_PipelineRegs_l19_6;
  reg        [0:0]    reg_RS2_TYPE;
  wire       [0:0]    _zz_reg_RS2_TYPE;
  wire       [0:0]    _zz_reg_RS2_TYPE_1;
  wire                when_PipelineRegs_l19_7;
  reg        [31:0]   reg_TRAP_VAL;
  wire                when_PipelineRegs_l19_8;
  reg        [31:0]   reg_RD_DATA;
  wire                when_PipelineRegs_l19_9;
  reg        [0:0]    reg_RD_TYPE;
  wire       [0:0]    _zz_reg_RD_TYPE;
  wire       [0:0]    _zz_reg_RD_TYPE_1;
  wire                when_PipelineRegs_l19_10;
  reg                 reg_LSU_IS_UNSIGNED;
  wire                when_PipelineRegs_l19_11;
  reg                 reg_HAS_TRAPPED;
  wire                when_PipelineRegs_l19_12;
  reg                 reg_TRAP_IS_INTERRUPT;
  wire                when_PipelineRegs_l19_13;
  reg        [4:0]    reg_RD;
  wire                when_PipelineRegs_l19_14;
  reg        [31:0]   reg_RS1_DATA;
  wire                when_PipelineRegs_l19_15;
  reg        [1:0]    reg_LSU_OPERATION_TYPE;
  wire       [1:0]    _zz_reg_LSU_OPERATION_TYPE;
  wire       [1:0]    _zz_reg_LSU_OPERATION_TYPE_1;
  wire                when_PipelineRegs_l19_16;
  reg        [1:0]    reg_LSU_ACCESS_WIDTH;
  wire       [1:0]    _zz_reg_LSU_ACCESS_WIDTH;
  wire       [1:0]    _zz_reg_LSU_ACCESS_WIDTH_1;
  wire                when_PipelineRegs_l19_17;
  reg        [1:0]    reg_CSR_OP;
  wire       [1:0]    _zz_reg_CSR_OP;
  wire       [1:0]    _zz_reg_CSR_OP_1;
  wire                when_PipelineRegs_l19_18;
  reg        [4:0]    reg_RS2;
  wire                when_PipelineRegs_l19_19;
  reg        [31:0]   reg_IR;
  wire                when_PipelineRegs_l19_20;
  reg        [31:0]   reg_ALU_RESULT;
  wire                when_PipelineRegs_l19_21;
  reg        [31:0]   reg_NEXT_PC;
  wire                when_PipelineRegs_l19_22;
  reg        [0:0]    reg_RS1_TYPE;
  wire       [0:0]    _zz_reg_RS1_TYPE;
  wire       [0:0]    _zz_reg_RS1_TYPE_1;
  wire                when_PipelineRegs_l19_23;
  reg                 reg_LSU_TARGET_VALID;
  wire                when_PipelineRegs_l19_24;
  reg                 reg_CSR_USE_IMM;
  `ifndef SYNTHESIS
  reg [31:0] in_RS2_TYPE_string;
  reg [31:0] out_RS2_TYPE_string;
  reg [31:0] reg_RS2_TYPE_string;
  reg [31:0] _zz_reg_RS2_TYPE_string;
  reg [31:0] _zz_reg_RS2_TYPE_1_string;
  reg [31:0] in_RD_TYPE_string;
  reg [31:0] out_RD_TYPE_string;
  reg [31:0] reg_RD_TYPE_string;
  reg [31:0] _zz_reg_RD_TYPE_string;
  reg [31:0] _zz_reg_RD_TYPE_1_string;
  reg [39:0] in_LSU_OPERATION_TYPE_string;
  reg [39:0] out_LSU_OPERATION_TYPE_string;
  reg [39:0] reg_LSU_OPERATION_TYPE_string;
  reg [39:0] _zz_reg_LSU_OPERATION_TYPE_string;
  reg [39:0] _zz_reg_LSU_OPERATION_TYPE_1_string;
  reg [7:0] in_LSU_ACCESS_WIDTH_string;
  reg [7:0] out_LSU_ACCESS_WIDTH_string;
  reg [7:0] reg_LSU_ACCESS_WIDTH_string;
  reg [7:0] _zz_reg_LSU_ACCESS_WIDTH_string;
  reg [7:0] _zz_reg_LSU_ACCESS_WIDTH_1_string;
  reg [31:0] in_CSR_OP_string;
  reg [31:0] out_CSR_OP_string;
  reg [31:0] reg_CSR_OP_string;
  reg [31:0] _zz_reg_CSR_OP_string;
  reg [31:0] _zz_reg_CSR_OP_1_string;
  reg [31:0] in_RS1_TYPE_string;
  reg [31:0] out_RS1_TYPE_string;
  reg [31:0] reg_RS1_TYPE_string;
  reg [31:0] _zz_reg_RS1_TYPE_string;
  reg [31:0] _zz_reg_RS1_TYPE_1_string;
  `endif


  `ifndef SYNTHESIS
  always @(*) begin
    case(in_RS2_TYPE)
      RegisterType_NONE : in_RS2_TYPE_string = "NONE";
      RegisterType_GPR : in_RS2_TYPE_string = "GPR ";
      default : in_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS2_TYPE)
      RegisterType_NONE : out_RS2_TYPE_string = "NONE";
      RegisterType_GPR : out_RS2_TYPE_string = "GPR ";
      default : out_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RS2_TYPE)
      RegisterType_NONE : reg_RS2_TYPE_string = "NONE";
      RegisterType_GPR : reg_RS2_TYPE_string = "GPR ";
      default : reg_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS2_TYPE)
      RegisterType_NONE : _zz_reg_RS2_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RS2_TYPE_string = "GPR ";
      default : _zz_reg_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS2_TYPE_1)
      RegisterType_NONE : _zz_reg_RS2_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RS2_TYPE_1_string = "GPR ";
      default : _zz_reg_RS2_TYPE_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RD_TYPE)
      RegisterType_NONE : in_RD_TYPE_string = "NONE";
      RegisterType_GPR : in_RD_TYPE_string = "GPR ";
      default : in_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RD_TYPE)
      RegisterType_NONE : out_RD_TYPE_string = "NONE";
      RegisterType_GPR : out_RD_TYPE_string = "GPR ";
      default : out_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RD_TYPE)
      RegisterType_NONE : reg_RD_TYPE_string = "NONE";
      RegisterType_GPR : reg_RD_TYPE_string = "GPR ";
      default : reg_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RD_TYPE)
      RegisterType_NONE : _zz_reg_RD_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RD_TYPE_string = "GPR ";
      default : _zz_reg_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RD_TYPE_1)
      RegisterType_NONE : _zz_reg_RD_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RD_TYPE_1_string = "GPR ";
      default : _zz_reg_RD_TYPE_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : in_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : in_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : in_LSU_OPERATION_TYPE_string = "STORE";
      default : in_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(out_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : out_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : out_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : out_LSU_OPERATION_TYPE_string = "STORE";
      default : out_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(reg_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : reg_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : reg_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : reg_LSU_OPERATION_TYPE_string = "STORE";
      default : reg_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : _zz_reg_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : _zz_reg_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : _zz_reg_LSU_OPERATION_TYPE_string = "STORE";
      default : _zz_reg_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_LSU_OPERATION_TYPE_1)
      LsuOperationType_NONE : _zz_reg_LSU_OPERATION_TYPE_1_string = "NONE ";
      LsuOperationType_LOAD : _zz_reg_LSU_OPERATION_TYPE_1_string = "LOAD ";
      LsuOperationType_STORE : _zz_reg_LSU_OPERATION_TYPE_1_string = "STORE";
      default : _zz_reg_LSU_OPERATION_TYPE_1_string = "?????";
    endcase
  end
  always @(*) begin
    case(in_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : in_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : in_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : in_LSU_ACCESS_WIDTH_string = "W";
      default : in_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(out_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : out_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : out_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : out_LSU_ACCESS_WIDTH_string = "W";
      default : out_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(reg_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : reg_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : reg_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : reg_LSU_ACCESS_WIDTH_string = "W";
      default : reg_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(_zz_reg_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : _zz_reg_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : _zz_reg_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : _zz_reg_LSU_ACCESS_WIDTH_string = "W";
      default : _zz_reg_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(_zz_reg_LSU_ACCESS_WIDTH_1)
      LsuAccessWidth_B : _zz_reg_LSU_ACCESS_WIDTH_1_string = "B";
      LsuAccessWidth_H : _zz_reg_LSU_ACCESS_WIDTH_1_string = "H";
      LsuAccessWidth_W : _zz_reg_LSU_ACCESS_WIDTH_1_string = "W";
      default : _zz_reg_LSU_ACCESS_WIDTH_1_string = "?";
    endcase
  end
  always @(*) begin
    case(in_CSR_OP)
      CsrOp_NONE : in_CSR_OP_string = "NONE";
      CsrOp_RW : in_CSR_OP_string = "RW  ";
      CsrOp_RS : in_CSR_OP_string = "RS  ";
      CsrOp_RC : in_CSR_OP_string = "RC  ";
      default : in_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(out_CSR_OP)
      CsrOp_NONE : out_CSR_OP_string = "NONE";
      CsrOp_RW : out_CSR_OP_string = "RW  ";
      CsrOp_RS : out_CSR_OP_string = "RS  ";
      CsrOp_RC : out_CSR_OP_string = "RC  ";
      default : out_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_CSR_OP)
      CsrOp_NONE : reg_CSR_OP_string = "NONE";
      CsrOp_RW : reg_CSR_OP_string = "RW  ";
      CsrOp_RS : reg_CSR_OP_string = "RS  ";
      CsrOp_RC : reg_CSR_OP_string = "RC  ";
      default : reg_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_CSR_OP)
      CsrOp_NONE : _zz_reg_CSR_OP_string = "NONE";
      CsrOp_RW : _zz_reg_CSR_OP_string = "RW  ";
      CsrOp_RS : _zz_reg_CSR_OP_string = "RS  ";
      CsrOp_RC : _zz_reg_CSR_OP_string = "RC  ";
      default : _zz_reg_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_CSR_OP_1)
      CsrOp_NONE : _zz_reg_CSR_OP_1_string = "NONE";
      CsrOp_RW : _zz_reg_CSR_OP_1_string = "RW  ";
      CsrOp_RS : _zz_reg_CSR_OP_1_string = "RS  ";
      CsrOp_RC : _zz_reg_CSR_OP_1_string = "RC  ";
      default : _zz_reg_CSR_OP_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RS1_TYPE)
      RegisterType_NONE : in_RS1_TYPE_string = "NONE";
      RegisterType_GPR : in_RS1_TYPE_string = "GPR ";
      default : in_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS1_TYPE)
      RegisterType_NONE : out_RS1_TYPE_string = "NONE";
      RegisterType_GPR : out_RS1_TYPE_string = "GPR ";
      default : out_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RS1_TYPE)
      RegisterType_NONE : reg_RS1_TYPE_string = "NONE";
      RegisterType_GPR : reg_RS1_TYPE_string = "GPR ";
      default : reg_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS1_TYPE)
      RegisterType_NONE : _zz_reg_RS1_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RS1_TYPE_string = "GPR ";
      default : _zz_reg_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS1_TYPE_1)
      RegisterType_NONE : _zz_reg_RS1_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RS1_TYPE_1_string = "GPR ";
      default : _zz_reg_RS1_TYPE_1_string = "????";
    endcase
  end
  `endif

  assign when_PipelineRegs_l19 = (shift || shift_RS2_DATA);
  assign out_RS2_DATA = reg_RS2_DATA;
  assign when_PipelineRegs_l19_1 = (shift || shift_RS1);
  assign out_RS1 = reg_RS1;
  assign when_PipelineRegs_l19_2 = (shift || shift_PC);
  assign out_PC = reg_PC;
  assign when_PipelineRegs_l19_3 = (shift || shift_RD_DATA_VALID);
  assign out_RD_DATA_VALID = reg_RD_DATA_VALID;
  assign when_PipelineRegs_l19_4 = (shift || shift_TRAP_CAUSE);
  assign out_TRAP_CAUSE = reg_TRAP_CAUSE;
  assign when_PipelineRegs_l19_5 = (shift || shift_MRET);
  assign out_MRET = reg_MRET;
  assign when_PipelineRegs_l19_6 = (shift || shift_RS2_TYPE);
  assign _zz_reg_RS2_TYPE_1 = 1'b0;
  assign _zz_reg_RS2_TYPE = _zz_reg_RS2_TYPE_1;
  assign out_RS2_TYPE = reg_RS2_TYPE;
  assign when_PipelineRegs_l19_7 = (shift || shift_TRAP_VAL);
  assign out_TRAP_VAL = reg_TRAP_VAL;
  assign when_PipelineRegs_l19_8 = (shift || shift_RD_DATA);
  assign out_RD_DATA = reg_RD_DATA;
  assign when_PipelineRegs_l19_9 = (shift || shift_RD_TYPE);
  assign _zz_reg_RD_TYPE_1 = 1'b0;
  assign _zz_reg_RD_TYPE = _zz_reg_RD_TYPE_1;
  assign out_RD_TYPE = reg_RD_TYPE;
  assign when_PipelineRegs_l19_10 = (shift || shift_LSU_IS_UNSIGNED);
  assign out_LSU_IS_UNSIGNED = reg_LSU_IS_UNSIGNED;
  assign when_PipelineRegs_l19_11 = (shift || shift_HAS_TRAPPED);
  assign out_HAS_TRAPPED = reg_HAS_TRAPPED;
  assign when_PipelineRegs_l19_12 = (shift || shift_TRAP_IS_INTERRUPT);
  assign out_TRAP_IS_INTERRUPT = reg_TRAP_IS_INTERRUPT;
  assign when_PipelineRegs_l19_13 = (shift || shift_RD);
  assign out_RD = reg_RD;
  assign when_PipelineRegs_l19_14 = (shift || shift_RS1_DATA);
  assign out_RS1_DATA = reg_RS1_DATA;
  assign when_PipelineRegs_l19_15 = (shift || shift_LSU_OPERATION_TYPE);
  assign _zz_reg_LSU_OPERATION_TYPE_1 = 2'b00;
  assign _zz_reg_LSU_OPERATION_TYPE = _zz_reg_LSU_OPERATION_TYPE_1;
  assign out_LSU_OPERATION_TYPE = reg_LSU_OPERATION_TYPE;
  assign when_PipelineRegs_l19_16 = (shift || shift_LSU_ACCESS_WIDTH);
  assign _zz_reg_LSU_ACCESS_WIDTH_1 = 2'b00;
  assign _zz_reg_LSU_ACCESS_WIDTH = _zz_reg_LSU_ACCESS_WIDTH_1;
  assign out_LSU_ACCESS_WIDTH = reg_LSU_ACCESS_WIDTH;
  assign when_PipelineRegs_l19_17 = (shift || shift_CSR_OP);
  assign _zz_reg_CSR_OP_1 = 2'b00;
  assign _zz_reg_CSR_OP = _zz_reg_CSR_OP_1;
  assign out_CSR_OP = reg_CSR_OP;
  assign when_PipelineRegs_l19_18 = (shift || shift_RS2);
  assign out_RS2 = reg_RS2;
  assign when_PipelineRegs_l19_19 = (shift || shift_IR);
  assign out_IR = reg_IR;
  assign when_PipelineRegs_l19_20 = (shift || shift_ALU_RESULT);
  assign out_ALU_RESULT = reg_ALU_RESULT;
  assign when_PipelineRegs_l19_21 = (shift || shift_NEXT_PC);
  assign out_NEXT_PC = reg_NEXT_PC;
  assign when_PipelineRegs_l19_22 = (shift || shift_RS1_TYPE);
  assign _zz_reg_RS1_TYPE_1 = 1'b0;
  assign _zz_reg_RS1_TYPE = _zz_reg_RS1_TYPE_1;
  assign out_RS1_TYPE = reg_RS1_TYPE;
  assign when_PipelineRegs_l19_23 = (shift || shift_LSU_TARGET_VALID);
  assign out_LSU_TARGET_VALID = reg_LSU_TARGET_VALID;
  assign when_PipelineRegs_l19_24 = (shift || shift_CSR_USE_IMM);
  assign out_CSR_USE_IMM = reg_CSR_USE_IMM;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      reg_RS2_DATA <= 32'h0;
      reg_RS1 <= 5'h0;
      reg_PC <= 32'h0;
      reg_RD_DATA_VALID <= 1'b0;
      reg_TRAP_CAUSE <= 4'b0000;
      reg_MRET <= 1'b0;
      reg_RS2_TYPE <= _zz_reg_RS2_TYPE;
      reg_TRAP_VAL <= 32'h0;
      reg_RD_DATA <= 32'h0;
      reg_RD_TYPE <= _zz_reg_RD_TYPE;
      reg_LSU_IS_UNSIGNED <= 1'b0;
      reg_HAS_TRAPPED <= 1'b0;
      reg_TRAP_IS_INTERRUPT <= 1'b0;
      reg_RD <= 5'h0;
      reg_RS1_DATA <= 32'h0;
      reg_LSU_OPERATION_TYPE <= _zz_reg_LSU_OPERATION_TYPE;
      reg_LSU_ACCESS_WIDTH <= _zz_reg_LSU_ACCESS_WIDTH;
      reg_CSR_OP <= _zz_reg_CSR_OP;
      reg_RS2 <= 5'h0;
      reg_IR <= 32'h0;
      reg_ALU_RESULT <= 32'h0;
      reg_NEXT_PC <= 32'h0;
      reg_RS1_TYPE <= _zz_reg_RS1_TYPE;
      reg_LSU_TARGET_VALID <= 1'b0;
      reg_CSR_USE_IMM <= 1'b0;
    end else begin
      if(when_PipelineRegs_l19) begin
        reg_RS2_DATA <= in_RS2_DATA;
      end
      if(when_PipelineRegs_l19_1) begin
        reg_RS1 <= in_RS1;
      end
      if(when_PipelineRegs_l19_2) begin
        reg_PC <= in_PC;
      end
      if(when_PipelineRegs_l19_3) begin
        reg_RD_DATA_VALID <= in_RD_DATA_VALID;
      end
      if(when_PipelineRegs_l19_4) begin
        reg_TRAP_CAUSE <= in_TRAP_CAUSE;
      end
      if(when_PipelineRegs_l19_5) begin
        reg_MRET <= in_MRET;
      end
      if(when_PipelineRegs_l19_6) begin
        reg_RS2_TYPE <= in_RS2_TYPE;
      end
      if(when_PipelineRegs_l19_7) begin
        reg_TRAP_VAL <= in_TRAP_VAL;
      end
      if(when_PipelineRegs_l19_8) begin
        reg_RD_DATA <= in_RD_DATA;
      end
      if(when_PipelineRegs_l19_9) begin
        reg_RD_TYPE <= in_RD_TYPE;
      end
      if(when_PipelineRegs_l19_10) begin
        reg_LSU_IS_UNSIGNED <= in_LSU_IS_UNSIGNED;
      end
      if(when_PipelineRegs_l19_11) begin
        reg_HAS_TRAPPED <= in_HAS_TRAPPED;
      end
      if(when_PipelineRegs_l19_12) begin
        reg_TRAP_IS_INTERRUPT <= in_TRAP_IS_INTERRUPT;
      end
      if(when_PipelineRegs_l19_13) begin
        reg_RD <= in_RD;
      end
      if(when_PipelineRegs_l19_14) begin
        reg_RS1_DATA <= in_RS1_DATA;
      end
      if(when_PipelineRegs_l19_15) begin
        reg_LSU_OPERATION_TYPE <= in_LSU_OPERATION_TYPE;
      end
      if(when_PipelineRegs_l19_16) begin
        reg_LSU_ACCESS_WIDTH <= in_LSU_ACCESS_WIDTH;
      end
      if(when_PipelineRegs_l19_17) begin
        reg_CSR_OP <= in_CSR_OP;
      end
      if(when_PipelineRegs_l19_18) begin
        reg_RS2 <= in_RS2;
      end
      if(when_PipelineRegs_l19_19) begin
        reg_IR <= in_IR;
      end
      if(when_PipelineRegs_l19_20) begin
        reg_ALU_RESULT <= in_ALU_RESULT;
      end
      if(when_PipelineRegs_l19_21) begin
        reg_NEXT_PC <= in_NEXT_PC;
      end
      if(when_PipelineRegs_l19_22) begin
        reg_RS1_TYPE <= in_RS1_TYPE;
      end
      if(when_PipelineRegs_l19_23) begin
        reg_LSU_TARGET_VALID <= in_LSU_TARGET_VALID;
      end
      if(when_PipelineRegs_l19_24) begin
        reg_CSR_USE_IMM <= in_CSR_USE_IMM;
      end
    end
  end


endmodule

module PipelineRegs_ID (
  input  wire          shift,
  input  wire          in_MUL,
  output wire          out_MUL,
  input  wire          shift_MUL,
  input  wire [31:0]   in_RS2_DATA,
  output wire [31:0]   out_RS2_DATA,
  input  wire          shift_RS2_DATA,
  input  wire [4:0]    in_RS1,
  output wire [4:0]    out_RS1,
  input  wire          shift_RS1,
  input  wire          in_BU_IS_BRANCH,
  output wire          out_BU_IS_BRANCH,
  input  wire          shift_BU_IS_BRANCH,
  input  wire [31:0]   in_PC,
  output wire [31:0]   out_PC,
  input  wire          shift_PC,
  input  wire [1:0]    in_SHIFT_OP,
  output wire [1:0]    out_SHIFT_OP,
  input  wire          shift_SHIFT_OP,
  input  wire          in_ECALL,
  output wire          out_ECALL,
  input  wire          shift_ECALL,
  input  wire          in_MULDIV_RS2_SIGNED,
  output wire          out_MULDIV_RS2_SIGNED,
  input  wire          shift_MULDIV_RS2_SIGNED,
  input  wire [2:0]    in_BU_CONDITION,
  output wire [2:0]    out_BU_CONDITION,
  input  wire          shift_BU_CONDITION,
  input  wire          in_RD_DATA_VALID,
  output wire          out_RD_DATA_VALID,
  input  wire          shift_RD_DATA_VALID,
  input  wire [3:0]    in_TRAP_CAUSE,
  output wire [3:0]    out_TRAP_CAUSE,
  input  wire          shift_TRAP_CAUSE,
  input  wire          in_MRET,
  output wire          out_MRET,
  input  wire          shift_MRET,
  input  wire [0:0]    in_RS2_TYPE,
  output wire [0:0]    out_RS2_TYPE,
  input  wire          shift_RS2_TYPE,
  input  wire [31:0]   in_TRAP_VAL,
  output wire [31:0]   out_TRAP_VAL,
  input  wire          shift_TRAP_VAL,
  input  wire [0:0]    in_RD_TYPE,
  output wire [0:0]    out_RD_TYPE,
  input  wire          shift_RD_TYPE,
  input  wire          in_LSU_IS_UNSIGNED,
  output wire          out_LSU_IS_UNSIGNED,
  input  wire          shift_LSU_IS_UNSIGNED,
  input  wire          in_DIV,
  output wire          out_DIV,
  input  wire          shift_DIV,
  input  wire          in_HAS_TRAPPED,
  output wire          out_HAS_TRAPPED,
  input  wire          shift_HAS_TRAPPED,
  input  wire          in_TRAP_IS_INTERRUPT,
  output wire          out_TRAP_IS_INTERRUPT,
  input  wire          shift_TRAP_IS_INTERRUPT,
  input  wire [4:0]    in_RD,
  output wire [4:0]    out_RD,
  input  wire          shift_RD,
  input  wire [31:0]   in_RS1_DATA,
  output wire [31:0]   out_RS1_DATA,
  input  wire          shift_RS1_DATA,
  input  wire [1:0]    in_CONDITION_OP,
  output wire [1:0]    out_CONDITION_OP,
  input  wire          shift_CONDITION_OP,
  input  wire          in_REM,
  output wire          out_REM,
  input  wire          shift_REM,
  input  wire          in_BU_WRITE_RET_ADDR_TO_RD,
  output wire          out_BU_WRITE_RET_ADDR_TO_RD,
  input  wire          shift_BU_WRITE_RET_ADDR_TO_RD,
  input  wire [1:0]    in_LSU_OPERATION_TYPE,
  output wire [1:0]    out_LSU_OPERATION_TYPE,
  input  wire          shift_LSU_OPERATION_TYPE,
  input  wire [1:0]    in_LSU_ACCESS_WIDTH,
  output wire [1:0]    out_LSU_ACCESS_WIDTH,
  input  wire          shift_LSU_ACCESS_WIDTH,
  input  wire [1:0]    in_CSR_OP,
  output wire [1:0]    out_CSR_OP,
  input  wire          shift_CSR_OP,
  input  wire [0:0]    in_ALU_SRC1,
  output wire [0:0]    out_ALU_SRC1,
  input  wire          shift_ALU_SRC1,
  input  wire [4:0]    in_RS2,
  output wire [4:0]    out_RS2,
  input  wire          shift_RS2,
  input  wire [2:0]    in_ALU_OP,
  output wire [2:0]    out_ALU_OP,
  input  wire          shift_ALU_OP,
  input  wire [31:0]   in_IMM,
  output wire [31:0]   out_IMM,
  input  wire          shift_IMM,
  input  wire          in_IMM_USED,
  output wire          out_IMM_USED,
  input  wire          shift_IMM_USED,
  input  wire [31:0]   in_IR,
  output wire [31:0]   out_IR,
  input  wire          shift_IR,
  input  wire          in_EBREAK,
  output wire          out_EBREAK,
  input  wire          shift_EBREAK,
  input  wire [31:0]   in_NEXT_PC,
  output wire [31:0]   out_NEXT_PC,
  input  wire          shift_NEXT_PC,
  input  wire [0:0]    in_RS1_TYPE,
  output wire [0:0]    out_RS1_TYPE,
  input  wire          shift_RS1_TYPE,
  input  wire [0:0]    in_ALU_SRC2,
  output wire [0:0]    out_ALU_SRC2,
  input  wire          shift_ALU_SRC2,
  input  wire          in_LSU_TARGET_VALID,
  output wire          out_LSU_TARGET_VALID,
  input  wire          shift_LSU_TARGET_VALID,
  input  wire          in_MULDIV_RS1_SIGNED,
  output wire          out_MULDIV_RS1_SIGNED,
  input  wire          shift_MULDIV_RS1_SIGNED,
  input  wire          in_ALU_COMMIT_RESULT,
  output wire          out_ALU_COMMIT_RESULT,
  input  wire          shift_ALU_COMMIT_RESULT,
  input  wire          in_BU_IGNORE_TARGET_LSB,
  output wire          out_BU_IGNORE_TARGET_LSB,
  input  wire          shift_BU_IGNORE_TARGET_LSB,
  input  wire          in_CSR_USE_IMM,
  output wire          out_CSR_USE_IMM,
  input  wire          shift_CSR_USE_IMM,
  input  wire [31:0]   in_PREDICTED_PC,
  output wire [31:0]   out_PREDICTED_PC,
  input  wire          shift_PREDICTED_PC,
  input  wire          in_MUL_HIGH,
  output wire          out_MUL_HIGH,
  input  wire          shift_MUL_HIGH,
  input  wire          clk,
  input  wire          reset
);
  localparam ShiftOp_NONE = 2'd0;
  localparam ShiftOp_SLL_1 = 2'd1;
  localparam ShiftOp_SRL_1 = 2'd2;
  localparam ShiftOp_SRA_1 = 2'd3;
  localparam BranchCondition_NONE = 3'd0;
  localparam BranchCondition_EQ = 3'd1;
  localparam BranchCondition_NE = 3'd2;
  localparam BranchCondition_LT = 3'd3;
  localparam BranchCondition_GE = 3'd4;
  localparam BranchCondition_LTU = 3'd5;
  localparam BranchCondition_GEU = 3'd6;
  localparam RegisterType_NONE = 1'd0;
  localparam RegisterType_GPR = 1'd1;
  localparam ConditionOp_NONE = 2'd0;
  localparam ConditionOp_EQZ = 2'd1;
  localparam ConditionOp_NEZ = 2'd2;
  localparam LsuOperationType_NONE = 2'd0;
  localparam LsuOperationType_LOAD = 2'd1;
  localparam LsuOperationType_STORE = 2'd2;
  localparam LsuAccessWidth_B = 2'd0;
  localparam LsuAccessWidth_H = 2'd1;
  localparam LsuAccessWidth_W = 2'd2;
  localparam CsrOp_NONE = 2'd0;
  localparam CsrOp_RW = 2'd1;
  localparam CsrOp_RS = 2'd2;
  localparam CsrOp_RC = 2'd3;
  localparam Src1Select_RS1 = 1'd0;
  localparam Src1Select_PC = 1'd1;
  localparam AluOp_ADD = 3'd0;
  localparam AluOp_SUB = 3'd1;
  localparam AluOp_SLT = 3'd2;
  localparam AluOp_SLTU = 3'd3;
  localparam AluOp_XOR_1 = 3'd4;
  localparam AluOp_OR_1 = 3'd5;
  localparam AluOp_AND_1 = 3'd6;
  localparam AluOp_SRC2 = 3'd7;
  localparam Src2Select_RS2 = 1'd0;
  localparam Src2Select_IMM = 1'd1;

  wire                when_PipelineRegs_l19;
  reg                 reg_MUL;
  wire                when_PipelineRegs_l19_1;
  reg        [31:0]   reg_RS2_DATA;
  wire                when_PipelineRegs_l19_2;
  reg        [4:0]    reg_RS1;
  wire                when_PipelineRegs_l19_3;
  reg                 reg_BU_IS_BRANCH;
  wire                when_PipelineRegs_l19_4;
  reg        [31:0]   reg_PC;
  wire                when_PipelineRegs_l19_5;
  reg        [1:0]    reg_SHIFT_OP;
  wire       [1:0]    _zz_reg_SHIFT_OP;
  wire       [1:0]    _zz_reg_SHIFT_OP_1;
  wire                when_PipelineRegs_l19_6;
  reg                 reg_ECALL;
  wire                when_PipelineRegs_l19_7;
  reg                 reg_MULDIV_RS2_SIGNED;
  wire                when_PipelineRegs_l19_8;
  reg        [2:0]    reg_BU_CONDITION;
  wire       [2:0]    _zz_reg_BU_CONDITION;
  wire       [2:0]    _zz_reg_BU_CONDITION_1;
  wire                when_PipelineRegs_l19_9;
  reg                 reg_RD_DATA_VALID;
  wire                when_PipelineRegs_l19_10;
  reg        [3:0]    reg_TRAP_CAUSE;
  wire                when_PipelineRegs_l19_11;
  reg                 reg_MRET;
  wire                when_PipelineRegs_l19_12;
  reg        [0:0]    reg_RS2_TYPE;
  wire       [0:0]    _zz_reg_RS2_TYPE;
  wire       [0:0]    _zz_reg_RS2_TYPE_1;
  wire                when_PipelineRegs_l19_13;
  reg        [31:0]   reg_TRAP_VAL;
  wire                when_PipelineRegs_l19_14;
  reg        [0:0]    reg_RD_TYPE;
  wire       [0:0]    _zz_reg_RD_TYPE;
  wire       [0:0]    _zz_reg_RD_TYPE_1;
  wire                when_PipelineRegs_l19_15;
  reg                 reg_LSU_IS_UNSIGNED;
  wire                when_PipelineRegs_l19_16;
  reg                 reg_DIV;
  wire                when_PipelineRegs_l19_17;
  reg                 reg_HAS_TRAPPED;
  wire                when_PipelineRegs_l19_18;
  reg                 reg_TRAP_IS_INTERRUPT;
  wire                when_PipelineRegs_l19_19;
  reg        [4:0]    reg_RD;
  wire                when_PipelineRegs_l19_20;
  reg        [31:0]   reg_RS1_DATA;
  wire                when_PipelineRegs_l19_21;
  reg        [1:0]    reg_CONDITION_OP;
  wire       [1:0]    _zz_reg_CONDITION_OP;
  wire       [1:0]    _zz_reg_CONDITION_OP_1;
  wire                when_PipelineRegs_l19_22;
  reg                 reg_REM;
  wire                when_PipelineRegs_l19_23;
  reg                 reg_BU_WRITE_RET_ADDR_TO_RD;
  wire                when_PipelineRegs_l19_24;
  reg        [1:0]    reg_LSU_OPERATION_TYPE;
  wire       [1:0]    _zz_reg_LSU_OPERATION_TYPE;
  wire       [1:0]    _zz_reg_LSU_OPERATION_TYPE_1;
  wire                when_PipelineRegs_l19_25;
  reg        [1:0]    reg_LSU_ACCESS_WIDTH;
  wire       [1:0]    _zz_reg_LSU_ACCESS_WIDTH;
  wire       [1:0]    _zz_reg_LSU_ACCESS_WIDTH_1;
  wire                when_PipelineRegs_l19_26;
  reg        [1:0]    reg_CSR_OP;
  wire       [1:0]    _zz_reg_CSR_OP;
  wire       [1:0]    _zz_reg_CSR_OP_1;
  wire                when_PipelineRegs_l19_27;
  reg        [0:0]    reg_ALU_SRC1;
  wire       [0:0]    _zz_reg_ALU_SRC1;
  wire       [0:0]    _zz_reg_ALU_SRC1_1;
  wire                when_PipelineRegs_l19_28;
  reg        [4:0]    reg_RS2;
  wire                when_PipelineRegs_l19_29;
  reg        [2:0]    reg_ALU_OP;
  wire       [2:0]    _zz_reg_ALU_OP;
  wire       [2:0]    _zz_reg_ALU_OP_1;
  wire                when_PipelineRegs_l19_30;
  reg        [31:0]   reg_IMM;
  wire                when_PipelineRegs_l19_31;
  reg                 reg_IMM_USED;
  wire                when_PipelineRegs_l19_32;
  reg        [31:0]   reg_IR;
  wire                when_PipelineRegs_l19_33;
  reg                 reg_EBREAK;
  wire                when_PipelineRegs_l19_34;
  reg        [31:0]   reg_NEXT_PC;
  wire                when_PipelineRegs_l19_35;
  reg        [0:0]    reg_RS1_TYPE;
  wire       [0:0]    _zz_reg_RS1_TYPE;
  wire       [0:0]    _zz_reg_RS1_TYPE_1;
  wire                when_PipelineRegs_l19_36;
  reg        [0:0]    reg_ALU_SRC2;
  wire       [0:0]    _zz_reg_ALU_SRC2;
  wire       [0:0]    _zz_reg_ALU_SRC2_1;
  wire                when_PipelineRegs_l19_37;
  reg                 reg_LSU_TARGET_VALID;
  wire                when_PipelineRegs_l19_38;
  reg                 reg_MULDIV_RS1_SIGNED;
  wire                when_PipelineRegs_l19_39;
  reg                 reg_ALU_COMMIT_RESULT;
  wire                when_PipelineRegs_l19_40;
  reg                 reg_BU_IGNORE_TARGET_LSB;
  wire                when_PipelineRegs_l19_41;
  reg                 reg_CSR_USE_IMM;
  wire                when_PipelineRegs_l19_42;
  reg        [31:0]   reg_PREDICTED_PC;
  wire                when_PipelineRegs_l19_43;
  reg                 reg_MUL_HIGH;
  `ifndef SYNTHESIS
  reg [39:0] in_SHIFT_OP_string;
  reg [39:0] out_SHIFT_OP_string;
  reg [39:0] reg_SHIFT_OP_string;
  reg [39:0] _zz_reg_SHIFT_OP_string;
  reg [39:0] _zz_reg_SHIFT_OP_1_string;
  reg [31:0] in_BU_CONDITION_string;
  reg [31:0] out_BU_CONDITION_string;
  reg [31:0] reg_BU_CONDITION_string;
  reg [31:0] _zz_reg_BU_CONDITION_string;
  reg [31:0] _zz_reg_BU_CONDITION_1_string;
  reg [31:0] in_RS2_TYPE_string;
  reg [31:0] out_RS2_TYPE_string;
  reg [31:0] reg_RS2_TYPE_string;
  reg [31:0] _zz_reg_RS2_TYPE_string;
  reg [31:0] _zz_reg_RS2_TYPE_1_string;
  reg [31:0] in_RD_TYPE_string;
  reg [31:0] out_RD_TYPE_string;
  reg [31:0] reg_RD_TYPE_string;
  reg [31:0] _zz_reg_RD_TYPE_string;
  reg [31:0] _zz_reg_RD_TYPE_1_string;
  reg [31:0] in_CONDITION_OP_string;
  reg [31:0] out_CONDITION_OP_string;
  reg [31:0] reg_CONDITION_OP_string;
  reg [31:0] _zz_reg_CONDITION_OP_string;
  reg [31:0] _zz_reg_CONDITION_OP_1_string;
  reg [39:0] in_LSU_OPERATION_TYPE_string;
  reg [39:0] out_LSU_OPERATION_TYPE_string;
  reg [39:0] reg_LSU_OPERATION_TYPE_string;
  reg [39:0] _zz_reg_LSU_OPERATION_TYPE_string;
  reg [39:0] _zz_reg_LSU_OPERATION_TYPE_1_string;
  reg [7:0] in_LSU_ACCESS_WIDTH_string;
  reg [7:0] out_LSU_ACCESS_WIDTH_string;
  reg [7:0] reg_LSU_ACCESS_WIDTH_string;
  reg [7:0] _zz_reg_LSU_ACCESS_WIDTH_string;
  reg [7:0] _zz_reg_LSU_ACCESS_WIDTH_1_string;
  reg [31:0] in_CSR_OP_string;
  reg [31:0] out_CSR_OP_string;
  reg [31:0] reg_CSR_OP_string;
  reg [31:0] _zz_reg_CSR_OP_string;
  reg [31:0] _zz_reg_CSR_OP_1_string;
  reg [23:0] in_ALU_SRC1_string;
  reg [23:0] out_ALU_SRC1_string;
  reg [23:0] reg_ALU_SRC1_string;
  reg [23:0] _zz_reg_ALU_SRC1_string;
  reg [23:0] _zz_reg_ALU_SRC1_1_string;
  reg [39:0] in_ALU_OP_string;
  reg [39:0] out_ALU_OP_string;
  reg [39:0] reg_ALU_OP_string;
  reg [39:0] _zz_reg_ALU_OP_string;
  reg [39:0] _zz_reg_ALU_OP_1_string;
  reg [31:0] in_RS1_TYPE_string;
  reg [31:0] out_RS1_TYPE_string;
  reg [31:0] reg_RS1_TYPE_string;
  reg [31:0] _zz_reg_RS1_TYPE_string;
  reg [31:0] _zz_reg_RS1_TYPE_1_string;
  reg [23:0] in_ALU_SRC2_string;
  reg [23:0] out_ALU_SRC2_string;
  reg [23:0] reg_ALU_SRC2_string;
  reg [23:0] _zz_reg_ALU_SRC2_string;
  reg [23:0] _zz_reg_ALU_SRC2_1_string;
  `endif


  `ifndef SYNTHESIS
  always @(*) begin
    case(in_SHIFT_OP)
      ShiftOp_NONE : in_SHIFT_OP_string = "NONE ";
      ShiftOp_SLL_1 : in_SHIFT_OP_string = "SLL_1";
      ShiftOp_SRL_1 : in_SHIFT_OP_string = "SRL_1";
      ShiftOp_SRA_1 : in_SHIFT_OP_string = "SRA_1";
      default : in_SHIFT_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(out_SHIFT_OP)
      ShiftOp_NONE : out_SHIFT_OP_string = "NONE ";
      ShiftOp_SLL_1 : out_SHIFT_OP_string = "SLL_1";
      ShiftOp_SRL_1 : out_SHIFT_OP_string = "SRL_1";
      ShiftOp_SRA_1 : out_SHIFT_OP_string = "SRA_1";
      default : out_SHIFT_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(reg_SHIFT_OP)
      ShiftOp_NONE : reg_SHIFT_OP_string = "NONE ";
      ShiftOp_SLL_1 : reg_SHIFT_OP_string = "SLL_1";
      ShiftOp_SRL_1 : reg_SHIFT_OP_string = "SRL_1";
      ShiftOp_SRA_1 : reg_SHIFT_OP_string = "SRA_1";
      default : reg_SHIFT_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_SHIFT_OP)
      ShiftOp_NONE : _zz_reg_SHIFT_OP_string = "NONE ";
      ShiftOp_SLL_1 : _zz_reg_SHIFT_OP_string = "SLL_1";
      ShiftOp_SRL_1 : _zz_reg_SHIFT_OP_string = "SRL_1";
      ShiftOp_SRA_1 : _zz_reg_SHIFT_OP_string = "SRA_1";
      default : _zz_reg_SHIFT_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_SHIFT_OP_1)
      ShiftOp_NONE : _zz_reg_SHIFT_OP_1_string = "NONE ";
      ShiftOp_SLL_1 : _zz_reg_SHIFT_OP_1_string = "SLL_1";
      ShiftOp_SRL_1 : _zz_reg_SHIFT_OP_1_string = "SRL_1";
      ShiftOp_SRA_1 : _zz_reg_SHIFT_OP_1_string = "SRA_1";
      default : _zz_reg_SHIFT_OP_1_string = "?????";
    endcase
  end
  always @(*) begin
    case(in_BU_CONDITION)
      BranchCondition_NONE : in_BU_CONDITION_string = "NONE";
      BranchCondition_EQ : in_BU_CONDITION_string = "EQ  ";
      BranchCondition_NE : in_BU_CONDITION_string = "NE  ";
      BranchCondition_LT : in_BU_CONDITION_string = "LT  ";
      BranchCondition_GE : in_BU_CONDITION_string = "GE  ";
      BranchCondition_LTU : in_BU_CONDITION_string = "LTU ";
      BranchCondition_GEU : in_BU_CONDITION_string = "GEU ";
      default : in_BU_CONDITION_string = "????";
    endcase
  end
  always @(*) begin
    case(out_BU_CONDITION)
      BranchCondition_NONE : out_BU_CONDITION_string = "NONE";
      BranchCondition_EQ : out_BU_CONDITION_string = "EQ  ";
      BranchCondition_NE : out_BU_CONDITION_string = "NE  ";
      BranchCondition_LT : out_BU_CONDITION_string = "LT  ";
      BranchCondition_GE : out_BU_CONDITION_string = "GE  ";
      BranchCondition_LTU : out_BU_CONDITION_string = "LTU ";
      BranchCondition_GEU : out_BU_CONDITION_string = "GEU ";
      default : out_BU_CONDITION_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_BU_CONDITION)
      BranchCondition_NONE : reg_BU_CONDITION_string = "NONE";
      BranchCondition_EQ : reg_BU_CONDITION_string = "EQ  ";
      BranchCondition_NE : reg_BU_CONDITION_string = "NE  ";
      BranchCondition_LT : reg_BU_CONDITION_string = "LT  ";
      BranchCondition_GE : reg_BU_CONDITION_string = "GE  ";
      BranchCondition_LTU : reg_BU_CONDITION_string = "LTU ";
      BranchCondition_GEU : reg_BU_CONDITION_string = "GEU ";
      default : reg_BU_CONDITION_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_BU_CONDITION)
      BranchCondition_NONE : _zz_reg_BU_CONDITION_string = "NONE";
      BranchCondition_EQ : _zz_reg_BU_CONDITION_string = "EQ  ";
      BranchCondition_NE : _zz_reg_BU_CONDITION_string = "NE  ";
      BranchCondition_LT : _zz_reg_BU_CONDITION_string = "LT  ";
      BranchCondition_GE : _zz_reg_BU_CONDITION_string = "GE  ";
      BranchCondition_LTU : _zz_reg_BU_CONDITION_string = "LTU ";
      BranchCondition_GEU : _zz_reg_BU_CONDITION_string = "GEU ";
      default : _zz_reg_BU_CONDITION_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_BU_CONDITION_1)
      BranchCondition_NONE : _zz_reg_BU_CONDITION_1_string = "NONE";
      BranchCondition_EQ : _zz_reg_BU_CONDITION_1_string = "EQ  ";
      BranchCondition_NE : _zz_reg_BU_CONDITION_1_string = "NE  ";
      BranchCondition_LT : _zz_reg_BU_CONDITION_1_string = "LT  ";
      BranchCondition_GE : _zz_reg_BU_CONDITION_1_string = "GE  ";
      BranchCondition_LTU : _zz_reg_BU_CONDITION_1_string = "LTU ";
      BranchCondition_GEU : _zz_reg_BU_CONDITION_1_string = "GEU ";
      default : _zz_reg_BU_CONDITION_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RS2_TYPE)
      RegisterType_NONE : in_RS2_TYPE_string = "NONE";
      RegisterType_GPR : in_RS2_TYPE_string = "GPR ";
      default : in_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS2_TYPE)
      RegisterType_NONE : out_RS2_TYPE_string = "NONE";
      RegisterType_GPR : out_RS2_TYPE_string = "GPR ";
      default : out_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RS2_TYPE)
      RegisterType_NONE : reg_RS2_TYPE_string = "NONE";
      RegisterType_GPR : reg_RS2_TYPE_string = "GPR ";
      default : reg_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS2_TYPE)
      RegisterType_NONE : _zz_reg_RS2_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RS2_TYPE_string = "GPR ";
      default : _zz_reg_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS2_TYPE_1)
      RegisterType_NONE : _zz_reg_RS2_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RS2_TYPE_1_string = "GPR ";
      default : _zz_reg_RS2_TYPE_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RD_TYPE)
      RegisterType_NONE : in_RD_TYPE_string = "NONE";
      RegisterType_GPR : in_RD_TYPE_string = "GPR ";
      default : in_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RD_TYPE)
      RegisterType_NONE : out_RD_TYPE_string = "NONE";
      RegisterType_GPR : out_RD_TYPE_string = "GPR ";
      default : out_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RD_TYPE)
      RegisterType_NONE : reg_RD_TYPE_string = "NONE";
      RegisterType_GPR : reg_RD_TYPE_string = "GPR ";
      default : reg_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RD_TYPE)
      RegisterType_NONE : _zz_reg_RD_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RD_TYPE_string = "GPR ";
      default : _zz_reg_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RD_TYPE_1)
      RegisterType_NONE : _zz_reg_RD_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RD_TYPE_1_string = "GPR ";
      default : _zz_reg_RD_TYPE_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_CONDITION_OP)
      ConditionOp_NONE : in_CONDITION_OP_string = "NONE";
      ConditionOp_EQZ : in_CONDITION_OP_string = "EQZ ";
      ConditionOp_NEZ : in_CONDITION_OP_string = "NEZ ";
      default : in_CONDITION_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(out_CONDITION_OP)
      ConditionOp_NONE : out_CONDITION_OP_string = "NONE";
      ConditionOp_EQZ : out_CONDITION_OP_string = "EQZ ";
      ConditionOp_NEZ : out_CONDITION_OP_string = "NEZ ";
      default : out_CONDITION_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_CONDITION_OP)
      ConditionOp_NONE : reg_CONDITION_OP_string = "NONE";
      ConditionOp_EQZ : reg_CONDITION_OP_string = "EQZ ";
      ConditionOp_NEZ : reg_CONDITION_OP_string = "NEZ ";
      default : reg_CONDITION_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_CONDITION_OP)
      ConditionOp_NONE : _zz_reg_CONDITION_OP_string = "NONE";
      ConditionOp_EQZ : _zz_reg_CONDITION_OP_string = "EQZ ";
      ConditionOp_NEZ : _zz_reg_CONDITION_OP_string = "NEZ ";
      default : _zz_reg_CONDITION_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_CONDITION_OP_1)
      ConditionOp_NONE : _zz_reg_CONDITION_OP_1_string = "NONE";
      ConditionOp_EQZ : _zz_reg_CONDITION_OP_1_string = "EQZ ";
      ConditionOp_NEZ : _zz_reg_CONDITION_OP_1_string = "NEZ ";
      default : _zz_reg_CONDITION_OP_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : in_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : in_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : in_LSU_OPERATION_TYPE_string = "STORE";
      default : in_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(out_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : out_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : out_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : out_LSU_OPERATION_TYPE_string = "STORE";
      default : out_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(reg_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : reg_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : reg_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : reg_LSU_OPERATION_TYPE_string = "STORE";
      default : reg_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : _zz_reg_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : _zz_reg_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : _zz_reg_LSU_OPERATION_TYPE_string = "STORE";
      default : _zz_reg_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_LSU_OPERATION_TYPE_1)
      LsuOperationType_NONE : _zz_reg_LSU_OPERATION_TYPE_1_string = "NONE ";
      LsuOperationType_LOAD : _zz_reg_LSU_OPERATION_TYPE_1_string = "LOAD ";
      LsuOperationType_STORE : _zz_reg_LSU_OPERATION_TYPE_1_string = "STORE";
      default : _zz_reg_LSU_OPERATION_TYPE_1_string = "?????";
    endcase
  end
  always @(*) begin
    case(in_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : in_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : in_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : in_LSU_ACCESS_WIDTH_string = "W";
      default : in_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(out_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : out_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : out_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : out_LSU_ACCESS_WIDTH_string = "W";
      default : out_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(reg_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : reg_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : reg_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : reg_LSU_ACCESS_WIDTH_string = "W";
      default : reg_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(_zz_reg_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : _zz_reg_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : _zz_reg_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : _zz_reg_LSU_ACCESS_WIDTH_string = "W";
      default : _zz_reg_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(_zz_reg_LSU_ACCESS_WIDTH_1)
      LsuAccessWidth_B : _zz_reg_LSU_ACCESS_WIDTH_1_string = "B";
      LsuAccessWidth_H : _zz_reg_LSU_ACCESS_WIDTH_1_string = "H";
      LsuAccessWidth_W : _zz_reg_LSU_ACCESS_WIDTH_1_string = "W";
      default : _zz_reg_LSU_ACCESS_WIDTH_1_string = "?";
    endcase
  end
  always @(*) begin
    case(in_CSR_OP)
      CsrOp_NONE : in_CSR_OP_string = "NONE";
      CsrOp_RW : in_CSR_OP_string = "RW  ";
      CsrOp_RS : in_CSR_OP_string = "RS  ";
      CsrOp_RC : in_CSR_OP_string = "RC  ";
      default : in_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(out_CSR_OP)
      CsrOp_NONE : out_CSR_OP_string = "NONE";
      CsrOp_RW : out_CSR_OP_string = "RW  ";
      CsrOp_RS : out_CSR_OP_string = "RS  ";
      CsrOp_RC : out_CSR_OP_string = "RC  ";
      default : out_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_CSR_OP)
      CsrOp_NONE : reg_CSR_OP_string = "NONE";
      CsrOp_RW : reg_CSR_OP_string = "RW  ";
      CsrOp_RS : reg_CSR_OP_string = "RS  ";
      CsrOp_RC : reg_CSR_OP_string = "RC  ";
      default : reg_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_CSR_OP)
      CsrOp_NONE : _zz_reg_CSR_OP_string = "NONE";
      CsrOp_RW : _zz_reg_CSR_OP_string = "RW  ";
      CsrOp_RS : _zz_reg_CSR_OP_string = "RS  ";
      CsrOp_RC : _zz_reg_CSR_OP_string = "RC  ";
      default : _zz_reg_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_CSR_OP_1)
      CsrOp_NONE : _zz_reg_CSR_OP_1_string = "NONE";
      CsrOp_RW : _zz_reg_CSR_OP_1_string = "RW  ";
      CsrOp_RS : _zz_reg_CSR_OP_1_string = "RS  ";
      CsrOp_RC : _zz_reg_CSR_OP_1_string = "RC  ";
      default : _zz_reg_CSR_OP_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_ALU_SRC1)
      Src1Select_RS1 : in_ALU_SRC1_string = "RS1";
      Src1Select_PC : in_ALU_SRC1_string = "PC ";
      default : in_ALU_SRC1_string = "???";
    endcase
  end
  always @(*) begin
    case(out_ALU_SRC1)
      Src1Select_RS1 : out_ALU_SRC1_string = "RS1";
      Src1Select_PC : out_ALU_SRC1_string = "PC ";
      default : out_ALU_SRC1_string = "???";
    endcase
  end
  always @(*) begin
    case(reg_ALU_SRC1)
      Src1Select_RS1 : reg_ALU_SRC1_string = "RS1";
      Src1Select_PC : reg_ALU_SRC1_string = "PC ";
      default : reg_ALU_SRC1_string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_reg_ALU_SRC1)
      Src1Select_RS1 : _zz_reg_ALU_SRC1_string = "RS1";
      Src1Select_PC : _zz_reg_ALU_SRC1_string = "PC ";
      default : _zz_reg_ALU_SRC1_string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_reg_ALU_SRC1_1)
      Src1Select_RS1 : _zz_reg_ALU_SRC1_1_string = "RS1";
      Src1Select_PC : _zz_reg_ALU_SRC1_1_string = "PC ";
      default : _zz_reg_ALU_SRC1_1_string = "???";
    endcase
  end
  always @(*) begin
    case(in_ALU_OP)
      AluOp_ADD : in_ALU_OP_string = "ADD  ";
      AluOp_SUB : in_ALU_OP_string = "SUB  ";
      AluOp_SLT : in_ALU_OP_string = "SLT  ";
      AluOp_SLTU : in_ALU_OP_string = "SLTU ";
      AluOp_XOR_1 : in_ALU_OP_string = "XOR_1";
      AluOp_OR_1 : in_ALU_OP_string = "OR_1 ";
      AluOp_AND_1 : in_ALU_OP_string = "AND_1";
      AluOp_SRC2 : in_ALU_OP_string = "SRC2 ";
      default : in_ALU_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(out_ALU_OP)
      AluOp_ADD : out_ALU_OP_string = "ADD  ";
      AluOp_SUB : out_ALU_OP_string = "SUB  ";
      AluOp_SLT : out_ALU_OP_string = "SLT  ";
      AluOp_SLTU : out_ALU_OP_string = "SLTU ";
      AluOp_XOR_1 : out_ALU_OP_string = "XOR_1";
      AluOp_OR_1 : out_ALU_OP_string = "OR_1 ";
      AluOp_AND_1 : out_ALU_OP_string = "AND_1";
      AluOp_SRC2 : out_ALU_OP_string = "SRC2 ";
      default : out_ALU_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(reg_ALU_OP)
      AluOp_ADD : reg_ALU_OP_string = "ADD  ";
      AluOp_SUB : reg_ALU_OP_string = "SUB  ";
      AluOp_SLT : reg_ALU_OP_string = "SLT  ";
      AluOp_SLTU : reg_ALU_OP_string = "SLTU ";
      AluOp_XOR_1 : reg_ALU_OP_string = "XOR_1";
      AluOp_OR_1 : reg_ALU_OP_string = "OR_1 ";
      AluOp_AND_1 : reg_ALU_OP_string = "AND_1";
      AluOp_SRC2 : reg_ALU_OP_string = "SRC2 ";
      default : reg_ALU_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_ALU_OP)
      AluOp_ADD : _zz_reg_ALU_OP_string = "ADD  ";
      AluOp_SUB : _zz_reg_ALU_OP_string = "SUB  ";
      AluOp_SLT : _zz_reg_ALU_OP_string = "SLT  ";
      AluOp_SLTU : _zz_reg_ALU_OP_string = "SLTU ";
      AluOp_XOR_1 : _zz_reg_ALU_OP_string = "XOR_1";
      AluOp_OR_1 : _zz_reg_ALU_OP_string = "OR_1 ";
      AluOp_AND_1 : _zz_reg_ALU_OP_string = "AND_1";
      AluOp_SRC2 : _zz_reg_ALU_OP_string = "SRC2 ";
      default : _zz_reg_ALU_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_ALU_OP_1)
      AluOp_ADD : _zz_reg_ALU_OP_1_string = "ADD  ";
      AluOp_SUB : _zz_reg_ALU_OP_1_string = "SUB  ";
      AluOp_SLT : _zz_reg_ALU_OP_1_string = "SLT  ";
      AluOp_SLTU : _zz_reg_ALU_OP_1_string = "SLTU ";
      AluOp_XOR_1 : _zz_reg_ALU_OP_1_string = "XOR_1";
      AluOp_OR_1 : _zz_reg_ALU_OP_1_string = "OR_1 ";
      AluOp_AND_1 : _zz_reg_ALU_OP_1_string = "AND_1";
      AluOp_SRC2 : _zz_reg_ALU_OP_1_string = "SRC2 ";
      default : _zz_reg_ALU_OP_1_string = "?????";
    endcase
  end
  always @(*) begin
    case(in_RS1_TYPE)
      RegisterType_NONE : in_RS1_TYPE_string = "NONE";
      RegisterType_GPR : in_RS1_TYPE_string = "GPR ";
      default : in_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS1_TYPE)
      RegisterType_NONE : out_RS1_TYPE_string = "NONE";
      RegisterType_GPR : out_RS1_TYPE_string = "GPR ";
      default : out_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(reg_RS1_TYPE)
      RegisterType_NONE : reg_RS1_TYPE_string = "NONE";
      RegisterType_GPR : reg_RS1_TYPE_string = "GPR ";
      default : reg_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS1_TYPE)
      RegisterType_NONE : _zz_reg_RS1_TYPE_string = "NONE";
      RegisterType_GPR : _zz_reg_RS1_TYPE_string = "GPR ";
      default : _zz_reg_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_reg_RS1_TYPE_1)
      RegisterType_NONE : _zz_reg_RS1_TYPE_1_string = "NONE";
      RegisterType_GPR : _zz_reg_RS1_TYPE_1_string = "GPR ";
      default : _zz_reg_RS1_TYPE_1_string = "????";
    endcase
  end
  always @(*) begin
    case(in_ALU_SRC2)
      Src2Select_RS2 : in_ALU_SRC2_string = "RS2";
      Src2Select_IMM : in_ALU_SRC2_string = "IMM";
      default : in_ALU_SRC2_string = "???";
    endcase
  end
  always @(*) begin
    case(out_ALU_SRC2)
      Src2Select_RS2 : out_ALU_SRC2_string = "RS2";
      Src2Select_IMM : out_ALU_SRC2_string = "IMM";
      default : out_ALU_SRC2_string = "???";
    endcase
  end
  always @(*) begin
    case(reg_ALU_SRC2)
      Src2Select_RS2 : reg_ALU_SRC2_string = "RS2";
      Src2Select_IMM : reg_ALU_SRC2_string = "IMM";
      default : reg_ALU_SRC2_string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_reg_ALU_SRC2)
      Src2Select_RS2 : _zz_reg_ALU_SRC2_string = "RS2";
      Src2Select_IMM : _zz_reg_ALU_SRC2_string = "IMM";
      default : _zz_reg_ALU_SRC2_string = "???";
    endcase
  end
  always @(*) begin
    case(_zz_reg_ALU_SRC2_1)
      Src2Select_RS2 : _zz_reg_ALU_SRC2_1_string = "RS2";
      Src2Select_IMM : _zz_reg_ALU_SRC2_1_string = "IMM";
      default : _zz_reg_ALU_SRC2_1_string = "???";
    endcase
  end
  `endif

  assign when_PipelineRegs_l19 = (shift || shift_MUL);
  assign out_MUL = reg_MUL;
  assign when_PipelineRegs_l19_1 = (shift || shift_RS2_DATA);
  assign out_RS2_DATA = reg_RS2_DATA;
  assign when_PipelineRegs_l19_2 = (shift || shift_RS1);
  assign out_RS1 = reg_RS1;
  assign when_PipelineRegs_l19_3 = (shift || shift_BU_IS_BRANCH);
  assign out_BU_IS_BRANCH = reg_BU_IS_BRANCH;
  assign when_PipelineRegs_l19_4 = (shift || shift_PC);
  assign out_PC = reg_PC;
  assign when_PipelineRegs_l19_5 = (shift || shift_SHIFT_OP);
  assign _zz_reg_SHIFT_OP_1 = 2'b00;
  assign _zz_reg_SHIFT_OP = _zz_reg_SHIFT_OP_1;
  assign out_SHIFT_OP = reg_SHIFT_OP;
  assign when_PipelineRegs_l19_6 = (shift || shift_ECALL);
  assign out_ECALL = reg_ECALL;
  assign when_PipelineRegs_l19_7 = (shift || shift_MULDIV_RS2_SIGNED);
  assign out_MULDIV_RS2_SIGNED = reg_MULDIV_RS2_SIGNED;
  assign when_PipelineRegs_l19_8 = (shift || shift_BU_CONDITION);
  assign _zz_reg_BU_CONDITION_1 = 3'b000;
  assign _zz_reg_BU_CONDITION = _zz_reg_BU_CONDITION_1;
  assign out_BU_CONDITION = reg_BU_CONDITION;
  assign when_PipelineRegs_l19_9 = (shift || shift_RD_DATA_VALID);
  assign out_RD_DATA_VALID = reg_RD_DATA_VALID;
  assign when_PipelineRegs_l19_10 = (shift || shift_TRAP_CAUSE);
  assign out_TRAP_CAUSE = reg_TRAP_CAUSE;
  assign when_PipelineRegs_l19_11 = (shift || shift_MRET);
  assign out_MRET = reg_MRET;
  assign when_PipelineRegs_l19_12 = (shift || shift_RS2_TYPE);
  assign _zz_reg_RS2_TYPE_1 = 1'b0;
  assign _zz_reg_RS2_TYPE = _zz_reg_RS2_TYPE_1;
  assign out_RS2_TYPE = reg_RS2_TYPE;
  assign when_PipelineRegs_l19_13 = (shift || shift_TRAP_VAL);
  assign out_TRAP_VAL = reg_TRAP_VAL;
  assign when_PipelineRegs_l19_14 = (shift || shift_RD_TYPE);
  assign _zz_reg_RD_TYPE_1 = 1'b0;
  assign _zz_reg_RD_TYPE = _zz_reg_RD_TYPE_1;
  assign out_RD_TYPE = reg_RD_TYPE;
  assign when_PipelineRegs_l19_15 = (shift || shift_LSU_IS_UNSIGNED);
  assign out_LSU_IS_UNSIGNED = reg_LSU_IS_UNSIGNED;
  assign when_PipelineRegs_l19_16 = (shift || shift_DIV);
  assign out_DIV = reg_DIV;
  assign when_PipelineRegs_l19_17 = (shift || shift_HAS_TRAPPED);
  assign out_HAS_TRAPPED = reg_HAS_TRAPPED;
  assign when_PipelineRegs_l19_18 = (shift || shift_TRAP_IS_INTERRUPT);
  assign out_TRAP_IS_INTERRUPT = reg_TRAP_IS_INTERRUPT;
  assign when_PipelineRegs_l19_19 = (shift || shift_RD);
  assign out_RD = reg_RD;
  assign when_PipelineRegs_l19_20 = (shift || shift_RS1_DATA);
  assign out_RS1_DATA = reg_RS1_DATA;
  assign when_PipelineRegs_l19_21 = (shift || shift_CONDITION_OP);
  assign _zz_reg_CONDITION_OP_1 = 2'b00;
  assign _zz_reg_CONDITION_OP = _zz_reg_CONDITION_OP_1;
  assign out_CONDITION_OP = reg_CONDITION_OP;
  assign when_PipelineRegs_l19_22 = (shift || shift_REM);
  assign out_REM = reg_REM;
  assign when_PipelineRegs_l19_23 = (shift || shift_BU_WRITE_RET_ADDR_TO_RD);
  assign out_BU_WRITE_RET_ADDR_TO_RD = reg_BU_WRITE_RET_ADDR_TO_RD;
  assign when_PipelineRegs_l19_24 = (shift || shift_LSU_OPERATION_TYPE);
  assign _zz_reg_LSU_OPERATION_TYPE_1 = 2'b00;
  assign _zz_reg_LSU_OPERATION_TYPE = _zz_reg_LSU_OPERATION_TYPE_1;
  assign out_LSU_OPERATION_TYPE = reg_LSU_OPERATION_TYPE;
  assign when_PipelineRegs_l19_25 = (shift || shift_LSU_ACCESS_WIDTH);
  assign _zz_reg_LSU_ACCESS_WIDTH_1 = 2'b00;
  assign _zz_reg_LSU_ACCESS_WIDTH = _zz_reg_LSU_ACCESS_WIDTH_1;
  assign out_LSU_ACCESS_WIDTH = reg_LSU_ACCESS_WIDTH;
  assign when_PipelineRegs_l19_26 = (shift || shift_CSR_OP);
  assign _zz_reg_CSR_OP_1 = 2'b00;
  assign _zz_reg_CSR_OP = _zz_reg_CSR_OP_1;
  assign out_CSR_OP = reg_CSR_OP;
  assign when_PipelineRegs_l19_27 = (shift || shift_ALU_SRC1);
  assign _zz_reg_ALU_SRC1_1 = 1'b0;
  assign _zz_reg_ALU_SRC1 = _zz_reg_ALU_SRC1_1;
  assign out_ALU_SRC1 = reg_ALU_SRC1;
  assign when_PipelineRegs_l19_28 = (shift || shift_RS2);
  assign out_RS2 = reg_RS2;
  assign when_PipelineRegs_l19_29 = (shift || shift_ALU_OP);
  assign _zz_reg_ALU_OP_1 = 3'b000;
  assign _zz_reg_ALU_OP = _zz_reg_ALU_OP_1;
  assign out_ALU_OP = reg_ALU_OP;
  assign when_PipelineRegs_l19_30 = (shift || shift_IMM);
  assign out_IMM = reg_IMM;
  assign when_PipelineRegs_l19_31 = (shift || shift_IMM_USED);
  assign out_IMM_USED = reg_IMM_USED;
  assign when_PipelineRegs_l19_32 = (shift || shift_IR);
  assign out_IR = reg_IR;
  assign when_PipelineRegs_l19_33 = (shift || shift_EBREAK);
  assign out_EBREAK = reg_EBREAK;
  assign when_PipelineRegs_l19_34 = (shift || shift_NEXT_PC);
  assign out_NEXT_PC = reg_NEXT_PC;
  assign when_PipelineRegs_l19_35 = (shift || shift_RS1_TYPE);
  assign _zz_reg_RS1_TYPE_1 = 1'b0;
  assign _zz_reg_RS1_TYPE = _zz_reg_RS1_TYPE_1;
  assign out_RS1_TYPE = reg_RS1_TYPE;
  assign when_PipelineRegs_l19_36 = (shift || shift_ALU_SRC2);
  assign _zz_reg_ALU_SRC2_1 = 1'b0;
  assign _zz_reg_ALU_SRC2 = _zz_reg_ALU_SRC2_1;
  assign out_ALU_SRC2 = reg_ALU_SRC2;
  assign when_PipelineRegs_l19_37 = (shift || shift_LSU_TARGET_VALID);
  assign out_LSU_TARGET_VALID = reg_LSU_TARGET_VALID;
  assign when_PipelineRegs_l19_38 = (shift || shift_MULDIV_RS1_SIGNED);
  assign out_MULDIV_RS1_SIGNED = reg_MULDIV_RS1_SIGNED;
  assign when_PipelineRegs_l19_39 = (shift || shift_ALU_COMMIT_RESULT);
  assign out_ALU_COMMIT_RESULT = reg_ALU_COMMIT_RESULT;
  assign when_PipelineRegs_l19_40 = (shift || shift_BU_IGNORE_TARGET_LSB);
  assign out_BU_IGNORE_TARGET_LSB = reg_BU_IGNORE_TARGET_LSB;
  assign when_PipelineRegs_l19_41 = (shift || shift_CSR_USE_IMM);
  assign out_CSR_USE_IMM = reg_CSR_USE_IMM;
  assign when_PipelineRegs_l19_42 = (shift || shift_PREDICTED_PC);
  assign out_PREDICTED_PC = reg_PREDICTED_PC;
  assign when_PipelineRegs_l19_43 = (shift || shift_MUL_HIGH);
  assign out_MUL_HIGH = reg_MUL_HIGH;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      reg_MUL <= 1'b0;
      reg_RS2_DATA <= 32'h0;
      reg_RS1 <= 5'h0;
      reg_BU_IS_BRANCH <= 1'b0;
      reg_PC <= 32'h0;
      reg_SHIFT_OP <= _zz_reg_SHIFT_OP;
      reg_ECALL <= 1'b0;
      reg_MULDIV_RS2_SIGNED <= 1'b0;
      reg_BU_CONDITION <= _zz_reg_BU_CONDITION;
      reg_RD_DATA_VALID <= 1'b0;
      reg_TRAP_CAUSE <= 4'b0000;
      reg_MRET <= 1'b0;
      reg_RS2_TYPE <= _zz_reg_RS2_TYPE;
      reg_TRAP_VAL <= 32'h0;
      reg_RD_TYPE <= _zz_reg_RD_TYPE;
      reg_LSU_IS_UNSIGNED <= 1'b0;
      reg_DIV <= 1'b0;
      reg_HAS_TRAPPED <= 1'b0;
      reg_TRAP_IS_INTERRUPT <= 1'b0;
      reg_RD <= 5'h0;
      reg_RS1_DATA <= 32'h0;
      reg_CONDITION_OP <= _zz_reg_CONDITION_OP;
      reg_REM <= 1'b0;
      reg_BU_WRITE_RET_ADDR_TO_RD <= 1'b0;
      reg_LSU_OPERATION_TYPE <= _zz_reg_LSU_OPERATION_TYPE;
      reg_LSU_ACCESS_WIDTH <= _zz_reg_LSU_ACCESS_WIDTH;
      reg_CSR_OP <= _zz_reg_CSR_OP;
      reg_ALU_SRC1 <= _zz_reg_ALU_SRC1;
      reg_RS2 <= 5'h0;
      reg_ALU_OP <= _zz_reg_ALU_OP;
      reg_IMM <= 32'h0;
      reg_IMM_USED <= 1'b0;
      reg_IR <= 32'h0;
      reg_EBREAK <= 1'b0;
      reg_NEXT_PC <= 32'h0;
      reg_RS1_TYPE <= _zz_reg_RS1_TYPE;
      reg_ALU_SRC2 <= _zz_reg_ALU_SRC2;
      reg_LSU_TARGET_VALID <= 1'b0;
      reg_MULDIV_RS1_SIGNED <= 1'b0;
      reg_ALU_COMMIT_RESULT <= 1'b0;
      reg_BU_IGNORE_TARGET_LSB <= 1'b0;
      reg_CSR_USE_IMM <= 1'b0;
      reg_PREDICTED_PC <= 32'h0;
      reg_MUL_HIGH <= 1'b0;
    end else begin
      if(when_PipelineRegs_l19) begin
        reg_MUL <= in_MUL;
      end
      if(when_PipelineRegs_l19_1) begin
        reg_RS2_DATA <= in_RS2_DATA;
      end
      if(when_PipelineRegs_l19_2) begin
        reg_RS1 <= in_RS1;
      end
      if(when_PipelineRegs_l19_3) begin
        reg_BU_IS_BRANCH <= in_BU_IS_BRANCH;
      end
      if(when_PipelineRegs_l19_4) begin
        reg_PC <= in_PC;
      end
      if(when_PipelineRegs_l19_5) begin
        reg_SHIFT_OP <= in_SHIFT_OP;
      end
      if(when_PipelineRegs_l19_6) begin
        reg_ECALL <= in_ECALL;
      end
      if(when_PipelineRegs_l19_7) begin
        reg_MULDIV_RS2_SIGNED <= in_MULDIV_RS2_SIGNED;
      end
      if(when_PipelineRegs_l19_8) begin
        reg_BU_CONDITION <= in_BU_CONDITION;
      end
      if(when_PipelineRegs_l19_9) begin
        reg_RD_DATA_VALID <= in_RD_DATA_VALID;
      end
      if(when_PipelineRegs_l19_10) begin
        reg_TRAP_CAUSE <= in_TRAP_CAUSE;
      end
      if(when_PipelineRegs_l19_11) begin
        reg_MRET <= in_MRET;
      end
      if(when_PipelineRegs_l19_12) begin
        reg_RS2_TYPE <= in_RS2_TYPE;
      end
      if(when_PipelineRegs_l19_13) begin
        reg_TRAP_VAL <= in_TRAP_VAL;
      end
      if(when_PipelineRegs_l19_14) begin
        reg_RD_TYPE <= in_RD_TYPE;
      end
      if(when_PipelineRegs_l19_15) begin
        reg_LSU_IS_UNSIGNED <= in_LSU_IS_UNSIGNED;
      end
      if(when_PipelineRegs_l19_16) begin
        reg_DIV <= in_DIV;
      end
      if(when_PipelineRegs_l19_17) begin
        reg_HAS_TRAPPED <= in_HAS_TRAPPED;
      end
      if(when_PipelineRegs_l19_18) begin
        reg_TRAP_IS_INTERRUPT <= in_TRAP_IS_INTERRUPT;
      end
      if(when_PipelineRegs_l19_19) begin
        reg_RD <= in_RD;
      end
      if(when_PipelineRegs_l19_20) begin
        reg_RS1_DATA <= in_RS1_DATA;
      end
      if(when_PipelineRegs_l19_21) begin
        reg_CONDITION_OP <= in_CONDITION_OP;
      end
      if(when_PipelineRegs_l19_22) begin
        reg_REM <= in_REM;
      end
      if(when_PipelineRegs_l19_23) begin
        reg_BU_WRITE_RET_ADDR_TO_RD <= in_BU_WRITE_RET_ADDR_TO_RD;
      end
      if(when_PipelineRegs_l19_24) begin
        reg_LSU_OPERATION_TYPE <= in_LSU_OPERATION_TYPE;
      end
      if(when_PipelineRegs_l19_25) begin
        reg_LSU_ACCESS_WIDTH <= in_LSU_ACCESS_WIDTH;
      end
      if(when_PipelineRegs_l19_26) begin
        reg_CSR_OP <= in_CSR_OP;
      end
      if(when_PipelineRegs_l19_27) begin
        reg_ALU_SRC1 <= in_ALU_SRC1;
      end
      if(when_PipelineRegs_l19_28) begin
        reg_RS2 <= in_RS2;
      end
      if(when_PipelineRegs_l19_29) begin
        reg_ALU_OP <= in_ALU_OP;
      end
      if(when_PipelineRegs_l19_30) begin
        reg_IMM <= in_IMM;
      end
      if(when_PipelineRegs_l19_31) begin
        reg_IMM_USED <= in_IMM_USED;
      end
      if(when_PipelineRegs_l19_32) begin
        reg_IR <= in_IR;
      end
      if(when_PipelineRegs_l19_33) begin
        reg_EBREAK <= in_EBREAK;
      end
      if(when_PipelineRegs_l19_34) begin
        reg_NEXT_PC <= in_NEXT_PC;
      end
      if(when_PipelineRegs_l19_35) begin
        reg_RS1_TYPE <= in_RS1_TYPE;
      end
      if(when_PipelineRegs_l19_36) begin
        reg_ALU_SRC2 <= in_ALU_SRC2;
      end
      if(when_PipelineRegs_l19_37) begin
        reg_LSU_TARGET_VALID <= in_LSU_TARGET_VALID;
      end
      if(when_PipelineRegs_l19_38) begin
        reg_MULDIV_RS1_SIGNED <= in_MULDIV_RS1_SIGNED;
      end
      if(when_PipelineRegs_l19_39) begin
        reg_ALU_COMMIT_RESULT <= in_ALU_COMMIT_RESULT;
      end
      if(when_PipelineRegs_l19_40) begin
        reg_BU_IGNORE_TARGET_LSB <= in_BU_IGNORE_TARGET_LSB;
      end
      if(when_PipelineRegs_l19_41) begin
        reg_CSR_USE_IMM <= in_CSR_USE_IMM;
      end
      if(when_PipelineRegs_l19_42) begin
        reg_PREDICTED_PC <= in_PREDICTED_PC;
      end
      if(when_PipelineRegs_l19_43) begin
        reg_MUL_HIGH <= in_MUL_HIGH;
      end
    end
  end


endmodule

module PipelineRegs_IF (
  input  wire          shift,
  input  wire [31:0]   in_PC,
  output wire [31:0]   out_PC,
  input  wire          shift_PC,
  input  wire [3:0]    in_TRAP_CAUSE,
  output wire [3:0]    out_TRAP_CAUSE,
  input  wire          shift_TRAP_CAUSE,
  input  wire [31:0]   in_TRAP_VAL,
  output wire [31:0]   out_TRAP_VAL,
  input  wire          shift_TRAP_VAL,
  input  wire          in_HAS_TRAPPED,
  output wire          out_HAS_TRAPPED,
  input  wire          shift_HAS_TRAPPED,
  input  wire          in_TRAP_IS_INTERRUPT,
  output wire          out_TRAP_IS_INTERRUPT,
  input  wire          shift_TRAP_IS_INTERRUPT,
  input  wire [31:0]   in_IR,
  output wire [31:0]   out_IR,
  input  wire          shift_IR,
  input  wire [31:0]   in_NEXT_PC,
  output wire [31:0]   out_NEXT_PC,
  input  wire          shift_NEXT_PC,
  input  wire [31:0]   in_PREDICTED_PC,
  output wire [31:0]   out_PREDICTED_PC,
  input  wire          shift_PREDICTED_PC,
  input  wire          clk,
  input  wire          reset
);

  wire                when_PipelineRegs_l19;
  reg        [31:0]   reg_PC;
  wire                when_PipelineRegs_l19_1;
  reg        [3:0]    reg_TRAP_CAUSE;
  wire                when_PipelineRegs_l19_2;
  reg        [31:0]   reg_TRAP_VAL;
  wire                when_PipelineRegs_l19_3;
  reg                 reg_HAS_TRAPPED;
  wire                when_PipelineRegs_l19_4;
  reg                 reg_TRAP_IS_INTERRUPT;
  wire                when_PipelineRegs_l19_5;
  reg        [31:0]   reg_IR;
  wire                when_PipelineRegs_l19_6;
  reg        [31:0]   reg_NEXT_PC;
  wire                when_PipelineRegs_l19_7;
  reg        [31:0]   reg_PREDICTED_PC;

  assign when_PipelineRegs_l19 = (shift || shift_PC);
  assign out_PC = reg_PC;
  assign when_PipelineRegs_l19_1 = (shift || shift_TRAP_CAUSE);
  assign out_TRAP_CAUSE = reg_TRAP_CAUSE;
  assign when_PipelineRegs_l19_2 = (shift || shift_TRAP_VAL);
  assign out_TRAP_VAL = reg_TRAP_VAL;
  assign when_PipelineRegs_l19_3 = (shift || shift_HAS_TRAPPED);
  assign out_HAS_TRAPPED = reg_HAS_TRAPPED;
  assign when_PipelineRegs_l19_4 = (shift || shift_TRAP_IS_INTERRUPT);
  assign out_TRAP_IS_INTERRUPT = reg_TRAP_IS_INTERRUPT;
  assign when_PipelineRegs_l19_5 = (shift || shift_IR);
  assign out_IR = reg_IR;
  assign when_PipelineRegs_l19_6 = (shift || shift_NEXT_PC);
  assign out_NEXT_PC = reg_NEXT_PC;
  assign when_PipelineRegs_l19_7 = (shift || shift_PREDICTED_PC);
  assign out_PREDICTED_PC = reg_PREDICTED_PC;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      reg_PC <= 32'h0;
      reg_TRAP_CAUSE <= 4'b0000;
      reg_TRAP_VAL <= 32'h0;
      reg_HAS_TRAPPED <= 1'b0;
      reg_TRAP_IS_INTERRUPT <= 1'b0;
      reg_IR <= 32'h0;
      reg_NEXT_PC <= 32'h0;
      reg_PREDICTED_PC <= 32'h0;
    end else begin
      if(when_PipelineRegs_l19) begin
        reg_PC <= in_PC;
      end
      if(when_PipelineRegs_l19_1) begin
        reg_TRAP_CAUSE <= in_TRAP_CAUSE;
      end
      if(when_PipelineRegs_l19_2) begin
        reg_TRAP_VAL <= in_TRAP_VAL;
      end
      if(when_PipelineRegs_l19_3) begin
        reg_HAS_TRAPPED <= in_HAS_TRAPPED;
      end
      if(when_PipelineRegs_l19_4) begin
        reg_TRAP_IS_INTERRUPT <= in_TRAP_IS_INTERRUPT;
      end
      if(when_PipelineRegs_l19_5) begin
        reg_IR <= in_IR;
      end
      if(when_PipelineRegs_l19_6) begin
        reg_NEXT_PC <= in_NEXT_PC;
      end
      if(when_PipelineRegs_l19_7) begin
        reg_PREDICTED_PC <= in_PREDICTED_PC;
      end
    end
  end


endmodule

module Stage_WB (
  input  wire          arbitration_isValid,
  input  wire          arbitration_isStalled,
  output wire          arbitration_isReady,
  output wire          arbitration_isDone,
  output reg           arbitration_rs1Needed,
  output wire          arbitration_rs2Needed,
  output reg           arbitration_jumpRequested,
  output wire          arbitration_isAvailable,
  output wire [4:0]    out_RS1,
  output wire [0:0]    out_RS1_TYPE,
  output wire [4:0]    out_RS2,
  output wire [0:0]    out_RS2_TYPE,
  output reg           out_RD_DATA_VALID,
  output wire [4:0]    out_RD,
  output wire [0:0]    out_RD_TYPE,
  output wire [4:0]    RegisterFileAccessor_regFileIo_rd,
  output wire [31:0]   RegisterFileAccessor_regFileIo_data,
  output wire          RegisterFileAccessor_regFileIo_write,
  output reg           out_HAS_TRAPPED,
  output wire [31:0]   out_IR,
  output reg           out_TRAP_IS_INTERRUPT,
  output reg  [11:0]   CsrFile_csrIo_rid,
  output reg  [11:0]   CsrFile_csrIo_wid,
  input  wire [31:0]   CsrFile_csrIo_rdata,
  output reg  [31:0]   CsrFile_csrIo_wdata,
  output reg           CsrFile_csrIo_read,
  output reg           CsrFile_csrIo_write,
  input  wire          CsrFile_csrIo_error,
  output reg  [31:0]   out_RD_DATA,
  output reg  [3:0]    out_TRAP_CAUSE,
  output reg  [31:0]   out_TRAP_VAL,
  input  wire [31:0]   TrapHandler_mstatus_rdata,
  output reg  [31:0]   TrapHandler_mstatus_wdata,
  output reg           TrapHandler_mstatus_write,
  input  wire [31:0]   TrapHandler_mtvec_rdata,
  output wire [31:0]   TrapHandler_mtvec_wdata,
  output wire          TrapHandler_mtvec_write,
  input  wire [31:0]   TrapHandler_mcause_rdata,
  output reg  [31:0]   TrapHandler_mcause_wdata,
  output reg           TrapHandler_mcause_write,
  input  wire [31:0]   TrapHandler_mepc_rdata,
  output reg  [31:0]   TrapHandler_mepc_wdata,
  output reg           TrapHandler_mepc_write,
  input  wire [31:0]   TrapHandler_mtval_rdata,
  output reg  [31:0]   TrapHandler_mtval_wdata,
  output reg           TrapHandler_mtval_write,
  output reg  [31:0]   out_NEXT_PC,
  output wire [31:0]   out_PC,
  input  wire          in_MRET,
  input  wire [31:0]   in_RS1_DATA,
  input  wire [1:0]    in_CSR_OP,
  input  wire          in_CSR_USE_IMM,
  input  wire [4:0]    in_RS1,
  input  wire [31:0]   in_PC,
  input  wire          in_RD_DATA_VALID,
  input  wire [3:0]    in_TRAP_CAUSE,
  input  wire [0:0]    in_RS2_TYPE,
  input  wire [31:0]   in_TRAP_VAL,
  input  wire [31:0]   in_RD_DATA,
  input  wire [0:0]    in_RD_TYPE,
  input  wire          in_HAS_TRAPPED,
  input  wire          in_TRAP_IS_INTERRUPT,
  input  wire [4:0]    in_RD,
  input  wire [4:0]    in_RS2,
  input  wire [31:0]   in_IR,
  input  wire [31:0]   in_NEXT_PC,
  input  wire [0:0]    in_RS1_TYPE
);
  localparam RegisterType_NONE = 1'd0;
  localparam RegisterType_GPR = 1'd1;
  localparam CsrOp_NONE = 2'd0;
  localparam CsrOp_RW = 2'd1;
  localparam CsrOp_RS = 2'd2;
  localparam CsrOp_RC = 2'd3;

  reg        [31:0]   _out_default_NEXT_PC;
  reg        [31:0]   _out_default_TRAP_VAL;
  reg        [3:0]    _out_default_TRAP_CAUSE;
  reg        [31:0]   _out_default_RD_DATA;
  reg                 _out_default_HAS_TRAPPED;
  wire                TrapHandler_interruptSignals_hasTrapped;
  wire       [3:0]    TrapHandler_interruptSignals_trapCause;
  wire       [31:0]   TrapHandler_interruptSignals_trapVal;
  reg                 TrapHandler_exceptionSignals_hasTrapped;
  reg        [3:0]    TrapHandler_exceptionSignals_trapCause;
  reg        [31:0]   TrapHandler_exceptionSignals_trapVal;
  reg        [4:0]    _out_default_RS1;
  reg        [0:0]    _out_default_RS1_TYPE;
  reg        [4:0]    _out_default_RS2;
  reg        [0:0]    _out_default_RS2_TYPE;
  reg                 _out_default_RD_DATA_VALID;
  reg        [4:0]    _out_default_RD;
  reg        [0:0]    _out_default_RD_TYPE;
  wire       [4:0]    value_RD;
  wire       [31:0]   value_RD_DATA;
  wire       [0:0]    value_RD_TYPE;
  reg        [31:0]   _out_default_IR;
  reg                 _out_default_TRAP_IS_INTERRUPT;
  wire       [1:0]    value_CSR_OP;
  wire                value_CSR_USE_IMM;
  wire       [4:0]    value_RS1;
  wire       [31:0]   value_IR;
  wire       [11:0]   CsrFile_csrId;
  wire                CsrFile_ignoreRead;
  wire                CsrFile_ignoreWrite;
  reg        [31:0]   CsrFile_src;
  reg        [26:0]   _zz_CsrFile_src;
  wire       [31:0]   value_RS1_DATA;
  wire                when_CsrFile_l204;
  wire                when_CsrFile_l207;
  wire                when_CsrFile_l218;
  wire                when_CsrFile_l227;
  reg                 TrapHandler_trapSignals_hasTrapped;
  reg        [3:0]    TrapHandler_trapSignals_trapCause;
  reg        [31:0]   TrapHandler_trapSignals_trapVal;
  reg                 TrapHandler_isInterrupt;
  wire                value_HAS_TRAPPED;
  wire                when_TrapHandler_l140;
  reg        [31:0]   _zz_TrapHandler_mstatus_wdata;
  reg        [31:0]   _zz_TrapHandler_mcause_wdata;
  wire                value_TRAP_IS_INTERRUPT;
  wire       [3:0]    value_TRAP_CAUSE;
  wire       [31:0]   value_PC;
  wire       [31:0]   value_TRAP_VAL;
  wire                value_MRET;
  wire                when_TrapHandler_l164;
  reg        [31:0]   _zz_TrapHandler_mstatus_wdata_1;
  reg        [31:0]   _out_default_PC;
  `ifndef SYNTHESIS
  reg [31:0] out_RS1_TYPE_string;
  reg [31:0] _out_default_RS1_TYPE_string;
  reg [31:0] out_RS2_TYPE_string;
  reg [31:0] _out_default_RS2_TYPE_string;
  reg [31:0] out_RD_TYPE_string;
  reg [31:0] _out_default_RD_TYPE_string;
  reg [31:0] value_RD_TYPE_string;
  reg [31:0] value_CSR_OP_string;
  reg [31:0] in_CSR_OP_string;
  reg [31:0] in_RS2_TYPE_string;
  reg [31:0] in_RD_TYPE_string;
  reg [31:0] in_RS1_TYPE_string;
  `endif

  function [26:0] zz__zz_CsrFile_src(input dummy);
    begin
      zz__zz_CsrFile_src[26] = 1'b0;
      zz__zz_CsrFile_src[25] = 1'b0;
      zz__zz_CsrFile_src[24] = 1'b0;
      zz__zz_CsrFile_src[23] = 1'b0;
      zz__zz_CsrFile_src[22] = 1'b0;
      zz__zz_CsrFile_src[21] = 1'b0;
      zz__zz_CsrFile_src[20] = 1'b0;
      zz__zz_CsrFile_src[19] = 1'b0;
      zz__zz_CsrFile_src[18] = 1'b0;
      zz__zz_CsrFile_src[17] = 1'b0;
      zz__zz_CsrFile_src[16] = 1'b0;
      zz__zz_CsrFile_src[15] = 1'b0;
      zz__zz_CsrFile_src[14] = 1'b0;
      zz__zz_CsrFile_src[13] = 1'b0;
      zz__zz_CsrFile_src[12] = 1'b0;
      zz__zz_CsrFile_src[11] = 1'b0;
      zz__zz_CsrFile_src[10] = 1'b0;
      zz__zz_CsrFile_src[9] = 1'b0;
      zz__zz_CsrFile_src[8] = 1'b0;
      zz__zz_CsrFile_src[7] = 1'b0;
      zz__zz_CsrFile_src[6] = 1'b0;
      zz__zz_CsrFile_src[5] = 1'b0;
      zz__zz_CsrFile_src[4] = 1'b0;
      zz__zz_CsrFile_src[3] = 1'b0;
      zz__zz_CsrFile_src[2] = 1'b0;
      zz__zz_CsrFile_src[1] = 1'b0;
      zz__zz_CsrFile_src[0] = 1'b0;
    end
  endfunction
  wire [26:0] _zz_1;

  `ifndef SYNTHESIS
  always @(*) begin
    case(out_RS1_TYPE)
      RegisterType_NONE : out_RS1_TYPE_string = "NONE";
      RegisterType_GPR : out_RS1_TYPE_string = "GPR ";
      default : out_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RS1_TYPE)
      RegisterType_NONE : _out_default_RS1_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RS1_TYPE_string = "GPR ";
      default : _out_default_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS2_TYPE)
      RegisterType_NONE : out_RS2_TYPE_string = "NONE";
      RegisterType_GPR : out_RS2_TYPE_string = "GPR ";
      default : out_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RS2_TYPE)
      RegisterType_NONE : _out_default_RS2_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RS2_TYPE_string = "GPR ";
      default : _out_default_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RD_TYPE)
      RegisterType_NONE : out_RD_TYPE_string = "NONE";
      RegisterType_GPR : out_RD_TYPE_string = "GPR ";
      default : out_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RD_TYPE)
      RegisterType_NONE : _out_default_RD_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RD_TYPE_string = "GPR ";
      default : _out_default_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(value_RD_TYPE)
      RegisterType_NONE : value_RD_TYPE_string = "NONE";
      RegisterType_GPR : value_RD_TYPE_string = "GPR ";
      default : value_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(value_CSR_OP)
      CsrOp_NONE : value_CSR_OP_string = "NONE";
      CsrOp_RW : value_CSR_OP_string = "RW  ";
      CsrOp_RS : value_CSR_OP_string = "RS  ";
      CsrOp_RC : value_CSR_OP_string = "RC  ";
      default : value_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(in_CSR_OP)
      CsrOp_NONE : in_CSR_OP_string = "NONE";
      CsrOp_RW : in_CSR_OP_string = "RW  ";
      CsrOp_RS : in_CSR_OP_string = "RS  ";
      CsrOp_RC : in_CSR_OP_string = "RC  ";
      default : in_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RS2_TYPE)
      RegisterType_NONE : in_RS2_TYPE_string = "NONE";
      RegisterType_GPR : in_RS2_TYPE_string = "GPR ";
      default : in_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RD_TYPE)
      RegisterType_NONE : in_RD_TYPE_string = "NONE";
      RegisterType_GPR : in_RD_TYPE_string = "GPR ";
      default : in_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RS1_TYPE)
      RegisterType_NONE : in_RS1_TYPE_string = "NONE";
      RegisterType_GPR : in_RS1_TYPE_string = "GPR ";
      default : in_RS1_TYPE_string = "????";
    endcase
  end
  `endif

  always @(*) begin
    _out_default_NEXT_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_NEXT_PC = in_NEXT_PC;
  end

  always @(*) begin
    out_NEXT_PC = _out_default_NEXT_PC;
    if(when_TrapHandler_l140) begin
      out_NEXT_PC = ({2'd0,TrapHandler_mtvec_rdata[31 : 2]} <<< 2'd2);
    end
    if(when_TrapHandler_l164) begin
      out_NEXT_PC = TrapHandler_mepc_rdata;
    end
  end

  always @(*) begin
    _out_default_TRAP_VAL = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_TRAP_VAL = in_TRAP_VAL;
  end

  always @(*) begin
    out_TRAP_VAL = _out_default_TRAP_VAL;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_VAL = TrapHandler_trapSignals_trapVal;
    end
  end

  always @(*) begin
    _out_default_TRAP_CAUSE = 4'bxxxx;
    _out_default_TRAP_CAUSE = in_TRAP_CAUSE;
  end

  always @(*) begin
    out_TRAP_CAUSE = _out_default_TRAP_CAUSE;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_CAUSE = TrapHandler_trapSignals_trapCause;
    end
  end

  always @(*) begin
    _out_default_RD_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_RD_DATA = in_RD_DATA;
  end

  always @(*) begin
    out_RD_DATA = _out_default_RD_DATA;
    if(when_CsrFile_l204) begin
      case(value_CSR_OP)
        CsrOp_RW : begin
          if(when_CsrFile_l207) begin
            out_RD_DATA = CsrFile_csrIo_rdata;
          end
        end
        CsrOp_RS : begin
          out_RD_DATA = CsrFile_csrIo_rdata;
        end
        CsrOp_RC : begin
          out_RD_DATA = CsrFile_csrIo_rdata;
        end
        default : begin
        end
      endcase
    end
  end

  always @(*) begin
    _out_default_HAS_TRAPPED = 1'bx;
    _out_default_HAS_TRAPPED = in_HAS_TRAPPED;
  end

  always @(*) begin
    out_HAS_TRAPPED = _out_default_HAS_TRAPPED;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_HAS_TRAPPED = 1'b1;
    end
  end

  assign arbitration_isAvailable = ((! arbitration_isValid) || arbitration_isDone);
  assign arbitration_isReady = 1'b1;
  always @(*) begin
    arbitration_rs1Needed = 1'b0;
    if(!value_CSR_USE_IMM) begin
      arbitration_rs1Needed = 1'b1;
    end
  end

  assign arbitration_rs2Needed = 1'b0;
  always @(*) begin
    arbitration_jumpRequested = 1'b0;
    if(when_TrapHandler_l140) begin
      arbitration_jumpRequested = 1'b1;
    end
    if(when_TrapHandler_l164) begin
      arbitration_jumpRequested = 1'b1;
    end
  end

  assign arbitration_isDone = ((arbitration_isValid && arbitration_isReady) && (! arbitration_isStalled));
  assign TrapHandler_interruptSignals_hasTrapped = 1'b0;
  assign TrapHandler_interruptSignals_trapCause = 4'bxxxx;
  assign TrapHandler_interruptSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    TrapHandler_exceptionSignals_hasTrapped = 1'b0;
    if(when_CsrFile_l204) begin
      if(CsrFile_csrIo_error) begin
        TrapHandler_exceptionSignals_hasTrapped = 1'b1;
      end
    end
  end

  always @(*) begin
    TrapHandler_exceptionSignals_trapCause = 4'bxxxx;
    if(when_CsrFile_l204) begin
      if(CsrFile_csrIo_error) begin
        TrapHandler_exceptionSignals_trapCause = 4'b0010;
      end
    end
  end

  always @(*) begin
    TrapHandler_exceptionSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(when_CsrFile_l204) begin
      if(CsrFile_csrIo_error) begin
        TrapHandler_exceptionSignals_trapVal = value_IR;
      end
    end
  end

  always @(*) begin
    _out_default_RS1 = 5'bxxxxx;
    _out_default_RS1 = in_RS1;
  end

  assign out_RS1 = _out_default_RS1;
  always @(*) begin
    _out_default_RS1_TYPE = (1'bx);
    _out_default_RS1_TYPE = in_RS1_TYPE;
  end

  assign out_RS1_TYPE = _out_default_RS1_TYPE;
  always @(*) begin
    _out_default_RS2 = 5'bxxxxx;
    _out_default_RS2 = in_RS2;
  end

  assign out_RS2 = _out_default_RS2;
  always @(*) begin
    _out_default_RS2_TYPE = (1'bx);
    _out_default_RS2_TYPE = in_RS2_TYPE;
  end

  assign out_RS2_TYPE = _out_default_RS2_TYPE;
  always @(*) begin
    _out_default_RD_DATA_VALID = 1'bx;
    _out_default_RD_DATA_VALID = in_RD_DATA_VALID;
  end

  always @(*) begin
    out_RD_DATA_VALID = _out_default_RD_DATA_VALID;
    if(when_CsrFile_l204) begin
      case(value_CSR_OP)
        CsrOp_RW : begin
          if(when_CsrFile_l207) begin
            out_RD_DATA_VALID = 1'b1;
          end
        end
        CsrOp_RS : begin
          out_RD_DATA_VALID = 1'b1;
        end
        CsrOp_RC : begin
          out_RD_DATA_VALID = 1'b1;
        end
        default : begin
        end
      endcase
    end
  end

  always @(*) begin
    _out_default_RD = 5'bxxxxx;
    _out_default_RD = in_RD;
  end

  assign out_RD = _out_default_RD;
  always @(*) begin
    _out_default_RD_TYPE = (1'bx);
    _out_default_RD_TYPE = in_RD_TYPE;
  end

  assign out_RD_TYPE = _out_default_RD_TYPE;
  assign RegisterFileAccessor_regFileIo_rd = value_RD;
  assign RegisterFileAccessor_regFileIo_data = value_RD_DATA;
  assign RegisterFileAccessor_regFileIo_write = (((value_RD_TYPE == RegisterType_GPR) && arbitration_isDone) && (! out_HAS_TRAPPED));
  always @(*) begin
    _out_default_IR = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_IR = in_IR;
  end

  assign out_IR = _out_default_IR;
  always @(*) begin
    _out_default_TRAP_IS_INTERRUPT = 1'bx;
    _out_default_TRAP_IS_INTERRUPT = in_TRAP_IS_INTERRUPT;
  end

  always @(*) begin
    out_TRAP_IS_INTERRUPT = _out_default_TRAP_IS_INTERRUPT;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_IS_INTERRUPT = TrapHandler_isInterrupt;
    end
  end

  always @(*) begin
    CsrFile_csrIo_rid = 12'h0;
    if(when_CsrFile_l204) begin
      case(value_CSR_OP)
        CsrOp_RW : begin
          if(when_CsrFile_l207) begin
            CsrFile_csrIo_rid = CsrFile_csrId;
          end
        end
        CsrOp_RS : begin
          CsrFile_csrIo_rid = CsrFile_csrId;
        end
        CsrOp_RC : begin
          CsrFile_csrIo_rid = CsrFile_csrId;
        end
        default : begin
        end
      endcase
    end
  end

  always @(*) begin
    CsrFile_csrIo_wid = 12'h0;
    if(when_CsrFile_l204) begin
      case(value_CSR_OP)
        CsrOp_RW : begin
          CsrFile_csrIo_wid = CsrFile_csrId;
        end
        CsrOp_RS : begin
          if(when_CsrFile_l218) begin
            CsrFile_csrIo_wid = CsrFile_csrId;
          end
        end
        CsrOp_RC : begin
          if(when_CsrFile_l227) begin
            CsrFile_csrIo_wid = CsrFile_csrId;
          end
        end
        default : begin
        end
      endcase
    end
  end

  always @(*) begin
    CsrFile_csrIo_read = 1'b0;
    if(when_CsrFile_l204) begin
      case(value_CSR_OP)
        CsrOp_RW : begin
          if(when_CsrFile_l207) begin
            CsrFile_csrIo_read = 1'b1;
          end
        end
        CsrOp_RS : begin
          CsrFile_csrIo_read = 1'b1;
        end
        CsrOp_RC : begin
          CsrFile_csrIo_read = 1'b1;
        end
        default : begin
        end
      endcase
    end
  end

  always @(*) begin
    CsrFile_csrIo_write = 1'b0;
    if(when_CsrFile_l204) begin
      case(value_CSR_OP)
        CsrOp_RW : begin
          CsrFile_csrIo_write = 1'b1;
        end
        CsrOp_RS : begin
          if(when_CsrFile_l218) begin
            CsrFile_csrIo_write = 1'b1;
          end
        end
        CsrOp_RC : begin
          if(when_CsrFile_l227) begin
            CsrFile_csrIo_write = 1'b1;
          end
        end
        default : begin
        end
      endcase
    end
  end

  always @(*) begin
    CsrFile_csrIo_wdata = 32'h0;
    if(when_CsrFile_l204) begin
      case(value_CSR_OP)
        CsrOp_RW : begin
          CsrFile_csrIo_wdata = CsrFile_src;
        end
        CsrOp_RS : begin
          if(when_CsrFile_l218) begin
            CsrFile_csrIo_wdata = (CsrFile_csrIo_rdata | CsrFile_src);
          end
        end
        CsrOp_RC : begin
          if(when_CsrFile_l227) begin
            CsrFile_csrIo_wdata = (CsrFile_csrIo_rdata & (~ CsrFile_src));
          end
        end
        default : begin
        end
      endcase
    end
  end

  assign CsrFile_csrId = value_IR[31 : 20];
  assign CsrFile_ignoreRead = (value_RD == 5'h0);
  assign CsrFile_ignoreWrite = (value_RS1 == 5'h0);
  assign _zz_1 = zz__zz_CsrFile_src(1'b0);
  always @(*) _zz_CsrFile_src = _zz_1;
  always @(*) begin
    if(value_CSR_USE_IMM) begin
      CsrFile_src = {_zz_CsrFile_src,value_RS1};
    end else begin
      CsrFile_src = value_RS1_DATA;
    end
  end

  assign when_CsrFile_l204 = (arbitration_isValid && (value_CSR_OP != CsrOp_NONE));
  assign when_CsrFile_l207 = (! CsrFile_ignoreRead);
  assign when_CsrFile_l218 = (! CsrFile_ignoreWrite);
  assign when_CsrFile_l227 = (! CsrFile_ignoreWrite);
  always @(*) begin
    TrapHandler_trapSignals_hasTrapped = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_interruptSignals_hasTrapped;
    end else begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_exceptionSignals_hasTrapped;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapCause = 4'bxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapCause = TrapHandler_interruptSignals_trapCause;
    end else begin
      TrapHandler_trapSignals_trapCause = TrapHandler_exceptionSignals_trapCause;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapVal = TrapHandler_interruptSignals_trapVal;
    end else begin
      TrapHandler_trapSignals_trapVal = TrapHandler_exceptionSignals_trapVal;
    end
  end

  always @(*) begin
    TrapHandler_isInterrupt = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_isInterrupt = 1'b1;
    end
  end

  always @(*) begin
    TrapHandler_mstatus_write = 1'b0;
    if(when_TrapHandler_l140) begin
      TrapHandler_mstatus_write = 1'b1;
    end
    if(when_TrapHandler_l164) begin
      TrapHandler_mstatus_write = 1'b1;
    end
  end

  always @(*) begin
    TrapHandler_mstatus_wdata = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(when_TrapHandler_l140) begin
      TrapHandler_mstatus_wdata = _zz_TrapHandler_mstatus_wdata;
    end
    if(when_TrapHandler_l164) begin
      TrapHandler_mstatus_wdata = _zz_TrapHandler_mstatus_wdata_1;
    end
  end

  assign TrapHandler_mtvec_write = 1'b0;
  assign TrapHandler_mtvec_wdata = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    TrapHandler_mcause_write = 1'b0;
    if(when_TrapHandler_l140) begin
      TrapHandler_mcause_write = 1'b1;
    end
  end

  always @(*) begin
    TrapHandler_mcause_wdata = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(when_TrapHandler_l140) begin
      TrapHandler_mcause_wdata = _zz_TrapHandler_mcause_wdata;
    end
  end

  always @(*) begin
    TrapHandler_mepc_write = 1'b0;
    if(when_TrapHandler_l140) begin
      TrapHandler_mepc_write = 1'b1;
    end
  end

  always @(*) begin
    TrapHandler_mepc_wdata = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(when_TrapHandler_l140) begin
      TrapHandler_mepc_wdata = value_PC;
    end
  end

  always @(*) begin
    TrapHandler_mtval_write = 1'b0;
    if(when_TrapHandler_l140) begin
      TrapHandler_mtval_write = 1'b1;
    end
  end

  always @(*) begin
    TrapHandler_mtval_wdata = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(when_TrapHandler_l140) begin
      TrapHandler_mtval_wdata = value_TRAP_VAL;
    end
  end

  assign when_TrapHandler_l140 = (arbitration_isValid && value_HAS_TRAPPED);
  always @(*) begin
    _zz_TrapHandler_mstatus_wdata = TrapHandler_mstatus_rdata;
    _zz_TrapHandler_mstatus_wdata[3] = 1'b0;
    _zz_TrapHandler_mstatus_wdata[7] = TrapHandler_mstatus_rdata[3];
  end

  always @(*) begin
    _zz_TrapHandler_mcause_wdata = 32'h0;
    _zz_TrapHandler_mcause_wdata[31] = value_TRAP_IS_INTERRUPT;
    _zz_TrapHandler_mcause_wdata[3 : 0] = value_TRAP_CAUSE;
  end

  assign when_TrapHandler_l164 = (arbitration_isValid && value_MRET);
  always @(*) begin
    _zz_TrapHandler_mstatus_wdata_1 = TrapHandler_mstatus_rdata;
    _zz_TrapHandler_mstatus_wdata_1[3] = TrapHandler_mstatus_rdata[7];
    _zz_TrapHandler_mstatus_wdata_1[7] = 1'b1;
  end

  always @(*) begin
    _out_default_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_PC = in_PC;
  end

  assign out_PC = _out_default_PC;
  assign value_RS1 = out_RS1;
  assign value_PC = out_PC;
  assign value_MRET = in_MRET;
  assign value_TRAP_CAUSE = out_TRAP_CAUSE;
  assign value_TRAP_VAL = out_TRAP_VAL;
  assign value_RD_DATA = out_RD_DATA;
  assign value_RD_TYPE = out_RD_TYPE;
  assign value_HAS_TRAPPED = out_HAS_TRAPPED;
  assign value_TRAP_IS_INTERRUPT = out_TRAP_IS_INTERRUPT;
  assign value_RD = out_RD;
  assign value_RS1_DATA = in_RS1_DATA;
  assign value_CSR_OP = in_CSR_OP;
  assign value_IR = out_IR;
  assign value_CSR_USE_IMM = in_CSR_USE_IMM;

endmodule

module Stage_MEM (
  input  wire          arbitration_isValid,
  input  wire          arbitration_isStalled,
  output reg           arbitration_isReady,
  output wire          arbitration_isDone,
  output wire          arbitration_rs1Needed,
  output reg           arbitration_rs2Needed,
  output wire          arbitration_jumpRequested,
  output wire          arbitration_isAvailable,
  output reg  [31:0]   out_LSU_TARGET_ADDRESS,
  output reg           out_LSU_TARGET_VALID,
  output reg           StaticMemoryBackbone_dbus_cmd_valid,
  input  wire          StaticMemoryBackbone_dbus_cmd_ready,
  output reg  [31:0]   StaticMemoryBackbone_dbus_cmd_payload_address,
  output wire [1:0]    StaticMemoryBackbone_dbus_cmd_payload_id,
  output reg           StaticMemoryBackbone_dbus_cmd_payload_write,
  output reg  [31:0]   StaticMemoryBackbone_dbus_cmd_payload_wdata,
  output reg  [3:0]    StaticMemoryBackbone_dbus_cmd_payload_wmask,
  input  wire          StaticMemoryBackbone_dbus_rsp_valid,
  output wire          StaticMemoryBackbone_dbus_rsp_ready,
  input  wire [31:0]   StaticMemoryBackbone_dbus_rsp_payload_rdata,
  input  wire [1:0]    StaticMemoryBackbone_dbus_rsp_payload_id,
  output reg  [31:0]   out_RD_DATA,
  output reg           out_RD_DATA_VALID,
  output reg           out_HAS_TRAPPED,
  output reg           out_TRAP_IS_INTERRUPT,
  output reg  [3:0]    out_TRAP_CAUSE,
  output reg  [31:0]   out_TRAP_VAL,
  input  wire [31:0]   in_RS2_DATA,
  input  wire          in_LSU_IS_UNSIGNED,
  input  wire [1:0]    in_LSU_ACCESS_WIDTH,
  input  wire [1:0]    in_LSU_OPERATION_TYPE,
  input  wire [31:0]   in_ALU_RESULT,
  input  wire [4:0]    in_RS1,
  output wire [4:0]    out_RS1,
  input  wire [31:0]   in_PC,
  output wire [31:0]   out_PC,
  input  wire          in_RD_DATA_VALID,
  input  wire [3:0]    in_TRAP_CAUSE,
  input  wire          in_MRET,
  output wire          out_MRET,
  input  wire [0:0]    in_RS2_TYPE,
  output wire [0:0]    out_RS2_TYPE,
  input  wire [31:0]   in_TRAP_VAL,
  input  wire [31:0]   in_RD_DATA,
  input  wire [0:0]    in_RD_TYPE,
  output wire [0:0]    out_RD_TYPE,
  input  wire          in_HAS_TRAPPED,
  input  wire          in_TRAP_IS_INTERRUPT,
  input  wire [4:0]    in_RD,
  output wire [4:0]    out_RD,
  input  wire [31:0]   in_RS1_DATA,
  output wire [31:0]   out_RS1_DATA,
  input  wire [1:0]    in_CSR_OP,
  output wire [1:0]    out_CSR_OP,
  input  wire [4:0]    in_RS2,
  output wire [4:0]    out_RS2,
  input  wire [31:0]   in_IR,
  output wire [31:0]   out_IR,
  input  wire [31:0]   in_NEXT_PC,
  output wire [31:0]   out_NEXT_PC,
  input  wire [0:0]    in_RS1_TYPE,
  output wire [0:0]    out_RS1_TYPE,
  input  wire          in_LSU_TARGET_VALID,
  input  wire          in_CSR_USE_IMM,
  output wire          out_CSR_USE_IMM,
  input  wire          clk,
  input  wire          reset
);
  localparam LsuOperationType_NONE = 2'd0;
  localparam LsuOperationType_LOAD = 2'd1;
  localparam LsuOperationType_STORE = 2'd2;
  localparam LsuAccessWidth_B = 2'd0;
  localparam LsuAccessWidth_H = 2'd1;
  localparam LsuAccessWidth_W = 2'd2;
  localparam RegisterType_NONE = 1'd0;
  localparam RegisterType_GPR = 1'd1;
  localparam CsrOp_NONE = 2'd0;
  localparam CsrOp_RW = 2'd1;
  localparam CsrOp_RS = 2'd2;
  localparam CsrOp_RC = 2'd3;

  wire       [29:0]   _zz_when_MemBus_l249;
  wire       [29:0]   _zz_when_MemBus_l249_1;
  wire       [31:0]   _zz__zz_out_RD_DATA_1;
  wire       [15:0]   _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata;
  wire       [23:0]   _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_1;
  wire       [4:0]    _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_3;
  reg        [31:0]   _out_default_TRAP_VAL;
  reg        [3:0]    _out_default_TRAP_CAUSE;
  reg                 _out_default_TRAP_IS_INTERRUPT;
  reg                 _out_default_HAS_TRAPPED;
  reg                 _out_default_RD_DATA_VALID;
  reg        [31:0]   _out_default_RD_DATA;
  reg                 _out_default_LSU_TARGET_VALID;
  wire       [31:0]   _out_default_LSU_TARGET_ADDRESS;
  wire       [31:0]   Lsu_externalAddress;
  wire                TrapHandler_interruptSignals_hasTrapped;
  wire       [3:0]    TrapHandler_interruptSignals_trapCause;
  wire       [31:0]   TrapHandler_interruptSignals_trapVal;
  reg                 TrapHandler_exceptionSignals_hasTrapped;
  reg        [3:0]    TrapHandler_exceptionSignals_trapCause;
  reg        [31:0]   TrapHandler_exceptionSignals_trapVal;
  wire       [1:0]    value_LSU_OPERATION_TYPE;
  wire       [1:0]    value_LSU_ACCESS_WIDTH;
  wire                value_LSU_IS_UNSIGNED;
  wire       [31:0]   value_ALU_RESULT;
  wire                when_Lsu_l240;
  wire       [31:0]   value_LSU_TARGET_ADDRESS;
  wire                value_LSU_TARGET_VALID;
  reg                 Lsu_dbusCtrl_currentCmd_valid;
  reg                 Lsu_dbusCtrl_currentCmd_ready;
  reg        [31:0]   Lsu_dbusCtrl_currentCmd_cmd_address;
  reg        [1:0]    Lsu_dbusCtrl_currentCmd_cmd_id;
  reg                 Lsu_dbusCtrl_currentCmd_cmd_write;
  reg        [31:0]   Lsu_dbusCtrl_currentCmd_cmd_wdata;
  reg        [3:0]    Lsu_dbusCtrl_currentCmd_cmd_wmask;
  wire                when_MemBus_l189;
  wire                Lsu_isActive;
  reg                 Lsu_misaligned;
  reg        [3:0]    Lsu_baseMask;
  wire       [3:0]    Lsu_mask;
  reg                 Lsu_busReady;
  reg                 Lsu_loadActive;
  wire                when_Lsu_l317;
  wire                when_Lsu_l325;
  wire       [31:0]   _zz_StaticMemoryBackbone_dbus_cmd_payload_address;
  reg                 when_Lsu_l340;
  reg        [31:0]   _zz_out_RD_DATA;
  wire                when_Lsu_l335;
  reg                 _zz_when_Lsu_l340;
  reg        [31:0]   _zz_out_RD_DATA_1;
  reg                 _zz_when_MemBus_l258;
  reg                 _zz_when_MemBus_l258_1;
  wire                when_MemBus_l246;
  wire                when_MemBus_l249;
  wire                when_MemBus_l258;
  reg        [31:0]   _zz_out_RD_DATA_2;
  wire       [15:0]   _zz_out_RD_DATA_3;
  reg        [15:0]   _zz_out_RD_DATA_4;
  wire                _zz_out_RD_DATA_5;
  reg        [15:0]   _zz_out_RD_DATA_6;
  wire       [7:0]    _zz_out_RD_DATA_7;
  reg        [23:0]   _zz_out_RD_DATA_8;
  wire                _zz_out_RD_DATA_9;
  reg        [23:0]   _zz_out_RD_DATA_10;
  wire       [31:0]   Lsu_busAddress;
  wire                Lsu_isActive_1;
  reg                 Lsu_misaligned_1;
  reg        [3:0]    Lsu_baseMask_1;
  wire       [3:0]    Lsu_mask_1;
  wire                when_Lsu_l405;
  wire                when_Lsu_l413;
  reg        [31:0]   _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata;
  wire       [15:0]   _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_1;
  wire                when_Lsu_l424;
  wire       [7:0]    _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_2;
  wire       [1:0]    switch_Lsu_l433;
  wire       [62:0]   _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_3;
  reg                 _zz_arbitration_isReady;
  reg                 _zz_when_MemBus_l290;
  reg                 _zz_when_MemBus_l290_1;
  wire                when_MemBus_l279;
  wire                when_MemBus_l282;
  wire                when_MemBus_l290;
  wire       [31:0]   value_RS2_DATA;
  reg                 TrapHandler_trapSignals_hasTrapped;
  reg        [3:0]    TrapHandler_trapSignals_trapCause;
  reg        [31:0]   TrapHandler_trapSignals_trapVal;
  reg                 TrapHandler_isInterrupt;
  reg        [4:0]    _out_default_RS1;
  reg        [31:0]   _out_default_PC;
  reg                 _out_default_MRET;
  reg        [0:0]    _out_default_RS2_TYPE;
  reg        [0:0]    _out_default_RD_TYPE;
  reg        [4:0]    _out_default_RD;
  reg        [31:0]   _out_default_RS1_DATA;
  reg        [1:0]    _out_default_CSR_OP;
  reg        [4:0]    _out_default_RS2;
  reg        [31:0]   _out_default_IR;
  reg        [31:0]   _out_default_NEXT_PC;
  reg        [0:0]    _out_default_RS1_TYPE;
  reg                 _out_default_CSR_USE_IMM;
  `ifndef SYNTHESIS
  reg [39:0] value_LSU_OPERATION_TYPE_string;
  reg [7:0] value_LSU_ACCESS_WIDTH_string;
  reg [7:0] in_LSU_ACCESS_WIDTH_string;
  reg [39:0] in_LSU_OPERATION_TYPE_string;
  reg [31:0] in_RS2_TYPE_string;
  reg [31:0] out_RS2_TYPE_string;
  reg [31:0] _out_default_RS2_TYPE_string;
  reg [31:0] in_RD_TYPE_string;
  reg [31:0] out_RD_TYPE_string;
  reg [31:0] _out_default_RD_TYPE_string;
  reg [31:0] in_CSR_OP_string;
  reg [31:0] out_CSR_OP_string;
  reg [31:0] _out_default_CSR_OP_string;
  reg [31:0] in_RS1_TYPE_string;
  reg [31:0] out_RS1_TYPE_string;
  reg [31:0] _out_default_RS1_TYPE_string;
  `endif

  function [15:0] zz__zz_out_RD_DATA_4(input dummy);
    begin
      zz__zz_out_RD_DATA_4[15] = 1'b0;
      zz__zz_out_RD_DATA_4[14] = 1'b0;
      zz__zz_out_RD_DATA_4[13] = 1'b0;
      zz__zz_out_RD_DATA_4[12] = 1'b0;
      zz__zz_out_RD_DATA_4[11] = 1'b0;
      zz__zz_out_RD_DATA_4[10] = 1'b0;
      zz__zz_out_RD_DATA_4[9] = 1'b0;
      zz__zz_out_RD_DATA_4[8] = 1'b0;
      zz__zz_out_RD_DATA_4[7] = 1'b0;
      zz__zz_out_RD_DATA_4[6] = 1'b0;
      zz__zz_out_RD_DATA_4[5] = 1'b0;
      zz__zz_out_RD_DATA_4[4] = 1'b0;
      zz__zz_out_RD_DATA_4[3] = 1'b0;
      zz__zz_out_RD_DATA_4[2] = 1'b0;
      zz__zz_out_RD_DATA_4[1] = 1'b0;
      zz__zz_out_RD_DATA_4[0] = 1'b0;
    end
  endfunction
  wire [15:0] _zz_1;
  function [23:0] zz__zz_out_RD_DATA_8(input dummy);
    begin
      zz__zz_out_RD_DATA_8[23] = 1'b0;
      zz__zz_out_RD_DATA_8[22] = 1'b0;
      zz__zz_out_RD_DATA_8[21] = 1'b0;
      zz__zz_out_RD_DATA_8[20] = 1'b0;
      zz__zz_out_RD_DATA_8[19] = 1'b0;
      zz__zz_out_RD_DATA_8[18] = 1'b0;
      zz__zz_out_RD_DATA_8[17] = 1'b0;
      zz__zz_out_RD_DATA_8[16] = 1'b0;
      zz__zz_out_RD_DATA_8[15] = 1'b0;
      zz__zz_out_RD_DATA_8[14] = 1'b0;
      zz__zz_out_RD_DATA_8[13] = 1'b0;
      zz__zz_out_RD_DATA_8[12] = 1'b0;
      zz__zz_out_RD_DATA_8[11] = 1'b0;
      zz__zz_out_RD_DATA_8[10] = 1'b0;
      zz__zz_out_RD_DATA_8[9] = 1'b0;
      zz__zz_out_RD_DATA_8[8] = 1'b0;
      zz__zz_out_RD_DATA_8[7] = 1'b0;
      zz__zz_out_RD_DATA_8[6] = 1'b0;
      zz__zz_out_RD_DATA_8[5] = 1'b0;
      zz__zz_out_RD_DATA_8[4] = 1'b0;
      zz__zz_out_RD_DATA_8[3] = 1'b0;
      zz__zz_out_RD_DATA_8[2] = 1'b0;
      zz__zz_out_RD_DATA_8[1] = 1'b0;
      zz__zz_out_RD_DATA_8[0] = 1'b0;
    end
  endfunction
  wire [23:0] _zz_2;

  assign _zz_when_MemBus_l249 = (Lsu_dbusCtrl_currentCmd_cmd_address >>> 2'd2);
  assign _zz_when_MemBus_l249_1 = (_zz_StaticMemoryBackbone_dbus_cmd_payload_address >>> 2'd2);
  assign _zz__zz_out_RD_DATA_1 = (StaticMemoryBackbone_dbus_rsp_payload_rdata >>> 5'h0);
  assign _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata = ({8'd0,_zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_2} <<< 4'd8);
  assign _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_1 = ({16'd0,_zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_2} <<< 5'd16);
  assign _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_3 = ({3'd0,Lsu_busAddress[1 : 0]} <<< 2'd3);
  `ifndef SYNTHESIS
  always @(*) begin
    case(value_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : value_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : value_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : value_LSU_OPERATION_TYPE_string = "STORE";
      default : value_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(value_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : value_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : value_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : value_LSU_ACCESS_WIDTH_string = "W";
      default : value_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(in_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : in_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : in_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : in_LSU_ACCESS_WIDTH_string = "W";
      default : in_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(in_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : in_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : in_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : in_LSU_OPERATION_TYPE_string = "STORE";
      default : in_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(in_RS2_TYPE)
      RegisterType_NONE : in_RS2_TYPE_string = "NONE";
      RegisterType_GPR : in_RS2_TYPE_string = "GPR ";
      default : in_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS2_TYPE)
      RegisterType_NONE : out_RS2_TYPE_string = "NONE";
      RegisterType_GPR : out_RS2_TYPE_string = "GPR ";
      default : out_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RS2_TYPE)
      RegisterType_NONE : _out_default_RS2_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RS2_TYPE_string = "GPR ";
      default : _out_default_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RD_TYPE)
      RegisterType_NONE : in_RD_TYPE_string = "NONE";
      RegisterType_GPR : in_RD_TYPE_string = "GPR ";
      default : in_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RD_TYPE)
      RegisterType_NONE : out_RD_TYPE_string = "NONE";
      RegisterType_GPR : out_RD_TYPE_string = "GPR ";
      default : out_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RD_TYPE)
      RegisterType_NONE : _out_default_RD_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RD_TYPE_string = "GPR ";
      default : _out_default_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(in_CSR_OP)
      CsrOp_NONE : in_CSR_OP_string = "NONE";
      CsrOp_RW : in_CSR_OP_string = "RW  ";
      CsrOp_RS : in_CSR_OP_string = "RS  ";
      CsrOp_RC : in_CSR_OP_string = "RC  ";
      default : in_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(out_CSR_OP)
      CsrOp_NONE : out_CSR_OP_string = "NONE";
      CsrOp_RW : out_CSR_OP_string = "RW  ";
      CsrOp_RS : out_CSR_OP_string = "RS  ";
      CsrOp_RC : out_CSR_OP_string = "RC  ";
      default : out_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_CSR_OP)
      CsrOp_NONE : _out_default_CSR_OP_string = "NONE";
      CsrOp_RW : _out_default_CSR_OP_string = "RW  ";
      CsrOp_RS : _out_default_CSR_OP_string = "RS  ";
      CsrOp_RC : _out_default_CSR_OP_string = "RC  ";
      default : _out_default_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RS1_TYPE)
      RegisterType_NONE : in_RS1_TYPE_string = "NONE";
      RegisterType_GPR : in_RS1_TYPE_string = "GPR ";
      default : in_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS1_TYPE)
      RegisterType_NONE : out_RS1_TYPE_string = "NONE";
      RegisterType_GPR : out_RS1_TYPE_string = "GPR ";
      default : out_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RS1_TYPE)
      RegisterType_NONE : _out_default_RS1_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RS1_TYPE_string = "GPR ";
      default : _out_default_RS1_TYPE_string = "????";
    endcase
  end
  `endif

  always @(*) begin
    _out_default_TRAP_VAL = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_TRAP_VAL = in_TRAP_VAL;
  end

  always @(*) begin
    out_TRAP_VAL = _out_default_TRAP_VAL;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_VAL = TrapHandler_trapSignals_trapVal;
    end
  end

  always @(*) begin
    _out_default_TRAP_CAUSE = 4'bxxxx;
    _out_default_TRAP_CAUSE = in_TRAP_CAUSE;
  end

  always @(*) begin
    out_TRAP_CAUSE = _out_default_TRAP_CAUSE;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_CAUSE = TrapHandler_trapSignals_trapCause;
    end
  end

  always @(*) begin
    _out_default_TRAP_IS_INTERRUPT = 1'bx;
    _out_default_TRAP_IS_INTERRUPT = in_TRAP_IS_INTERRUPT;
  end

  always @(*) begin
    out_TRAP_IS_INTERRUPT = _out_default_TRAP_IS_INTERRUPT;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_IS_INTERRUPT = TrapHandler_isInterrupt;
    end
  end

  always @(*) begin
    _out_default_HAS_TRAPPED = 1'bx;
    _out_default_HAS_TRAPPED = in_HAS_TRAPPED;
  end

  always @(*) begin
    out_HAS_TRAPPED = _out_default_HAS_TRAPPED;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_HAS_TRAPPED = 1'b1;
    end
  end

  always @(*) begin
    _out_default_RD_DATA_VALID = 1'bx;
    _out_default_RD_DATA_VALID = in_RD_DATA_VALID;
  end

  always @(*) begin
    out_RD_DATA_VALID = _out_default_RD_DATA_VALID;
    if(when_Lsu_l325) begin
      if(Lsu_isActive) begin
        out_RD_DATA_VALID = 1'b1;
      end
    end
  end

  always @(*) begin
    _out_default_RD_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_RD_DATA = in_RD_DATA;
  end

  always @(*) begin
    out_RD_DATA = _out_default_RD_DATA;
    if(when_Lsu_l325) begin
      if(Lsu_isActive) begin
        out_RD_DATA = _zz_out_RD_DATA_2;
      end
    end
  end

  always @(*) begin
    _out_default_LSU_TARGET_VALID = 1'bx;
    _out_default_LSU_TARGET_VALID = in_LSU_TARGET_VALID;
  end

  always @(*) begin
    out_LSU_TARGET_VALID = _out_default_LSU_TARGET_VALID;
    if(when_Lsu_l240) begin
      out_LSU_TARGET_VALID = 1'b1;
    end
  end

  assign _out_default_LSU_TARGET_ADDRESS = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_LSU_TARGET_ADDRESS = _out_default_LSU_TARGET_ADDRESS;
    out_LSU_TARGET_ADDRESS = value_ALU_RESULT;
  end

  assign arbitration_isAvailable = ((! arbitration_isValid) || arbitration_isDone);
  always @(*) begin
    arbitration_isReady = 1'b1;
    if(when_Lsu_l325) begin
      if(Lsu_isActive) begin
        arbitration_isReady = when_Lsu_l340;
      end
    end
    if(when_Lsu_l413) begin
      if(Lsu_isActive_1) begin
        arbitration_isReady = _zz_arbitration_isReady;
      end
    end
  end

  assign arbitration_rs1Needed = 1'b0;
  always @(*) begin
    arbitration_rs2Needed = 1'b0;
    if(when_Lsu_l413) begin
      if(Lsu_isActive_1) begin
        arbitration_rs2Needed = 1'b1;
      end
    end
  end

  assign arbitration_jumpRequested = 1'b0;
  assign arbitration_isDone = ((arbitration_isValid && arbitration_isReady) && (! arbitration_isStalled));
  assign Lsu_externalAddress = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  assign TrapHandler_interruptSignals_hasTrapped = 1'b0;
  assign TrapHandler_interruptSignals_trapCause = 4'bxxxx;
  assign TrapHandler_interruptSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    TrapHandler_exceptionSignals_hasTrapped = 1'b0;
    if(when_Lsu_l317) begin
      TrapHandler_exceptionSignals_hasTrapped = 1'b1;
    end
    if(when_Lsu_l405) begin
      TrapHandler_exceptionSignals_hasTrapped = 1'b1;
    end
  end

  always @(*) begin
    TrapHandler_exceptionSignals_trapCause = 4'bxxxx;
    if(when_Lsu_l317) begin
      TrapHandler_exceptionSignals_trapCause = 4'b0100;
    end
    if(when_Lsu_l405) begin
      TrapHandler_exceptionSignals_trapCause = 4'b0110;
    end
  end

  always @(*) begin
    TrapHandler_exceptionSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(when_Lsu_l317) begin
      TrapHandler_exceptionSignals_trapVal = value_LSU_TARGET_ADDRESS;
    end
    if(when_Lsu_l405) begin
      TrapHandler_exceptionSignals_trapVal = value_LSU_TARGET_ADDRESS;
    end
  end

  assign when_Lsu_l240 = ((value_LSU_OPERATION_TYPE == LsuOperationType_LOAD) || (value_LSU_OPERATION_TYPE == LsuOperationType_STORE));
  always @(*) begin
    StaticMemoryBackbone_dbus_cmd_valid = Lsu_dbusCtrl_currentCmd_valid;
    if(when_Lsu_l325) begin
      if(Lsu_isActive) begin
        if(when_Lsu_l335) begin
          if(when_MemBus_l246) begin
            StaticMemoryBackbone_dbus_cmd_valid = 1'b1;
          end
        end
      end
    end else begin
      StaticMemoryBackbone_dbus_cmd_valid = 1'b0;
    end
    if(when_Lsu_l413) begin
      if(Lsu_isActive_1) begin
        if(when_MemBus_l279) begin
          StaticMemoryBackbone_dbus_cmd_valid = 1'b1;
        end
      end
    end
  end

  assign StaticMemoryBackbone_dbus_cmd_payload_id = Lsu_dbusCtrl_currentCmd_cmd_id;
  always @(*) begin
    StaticMemoryBackbone_dbus_cmd_payload_address = Lsu_dbusCtrl_currentCmd_cmd_address;
    if(when_Lsu_l325) begin
      if(Lsu_isActive) begin
        if(when_Lsu_l335) begin
          if(when_MemBus_l246) begin
            StaticMemoryBackbone_dbus_cmd_payload_address = _zz_StaticMemoryBackbone_dbus_cmd_payload_address;
          end
        end
      end
    end
    if(when_Lsu_l413) begin
      if(Lsu_isActive_1) begin
        if(when_MemBus_l279) begin
          StaticMemoryBackbone_dbus_cmd_payload_address = Lsu_busAddress;
        end
      end
    end
  end

  always @(*) begin
    StaticMemoryBackbone_dbus_cmd_payload_write = Lsu_dbusCtrl_currentCmd_cmd_write;
    if(when_Lsu_l325) begin
      if(Lsu_isActive) begin
        if(when_Lsu_l335) begin
          if(when_MemBus_l246) begin
            StaticMemoryBackbone_dbus_cmd_payload_write = 1'b0;
          end
        end
      end
    end
    if(when_Lsu_l413) begin
      if(Lsu_isActive_1) begin
        if(when_MemBus_l279) begin
          StaticMemoryBackbone_dbus_cmd_payload_write = 1'b1;
        end
      end
    end
  end

  always @(*) begin
    StaticMemoryBackbone_dbus_cmd_payload_wdata = Lsu_dbusCtrl_currentCmd_cmd_wdata;
    if(when_Lsu_l413) begin
      if(Lsu_isActive_1) begin
        if(when_MemBus_l279) begin
          StaticMemoryBackbone_dbus_cmd_payload_wdata = _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_3[31:0];
        end
      end
    end
  end

  always @(*) begin
    StaticMemoryBackbone_dbus_cmd_payload_wmask = Lsu_dbusCtrl_currentCmd_cmd_wmask;
    if(when_Lsu_l413) begin
      if(Lsu_isActive_1) begin
        if(when_MemBus_l279) begin
          StaticMemoryBackbone_dbus_cmd_payload_wmask = Lsu_mask_1;
        end
      end
    end
  end

  assign StaticMemoryBackbone_dbus_rsp_ready = 1'b1;
  assign when_MemBus_l189 = (StaticMemoryBackbone_dbus_cmd_valid && StaticMemoryBackbone_dbus_cmd_ready);
  assign Lsu_isActive = (value_LSU_OPERATION_TYPE == LsuOperationType_LOAD);
  always @(*) begin
    case(value_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : begin
        Lsu_misaligned = 1'b0;
      end
      LsuAccessWidth_H : begin
        Lsu_misaligned = ((value_LSU_TARGET_ADDRESS & 32'h00000001) != 32'h0);
      end
      default : begin
        Lsu_misaligned = ((value_LSU_TARGET_ADDRESS & 32'h00000003) != 32'h0);
      end
    endcase
  end

  always @(*) begin
    case(value_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : begin
        Lsu_baseMask = 4'b0001;
      end
      LsuAccessWidth_H : begin
        Lsu_baseMask = 4'b0011;
      end
      default : begin
        Lsu_baseMask = 4'b1111;
      end
    endcase
  end

  assign Lsu_mask = (Lsu_baseMask <<< value_LSU_TARGET_ADDRESS[1 : 0]);
  always @(*) begin
    Lsu_busReady = 1'b0;
    if(when_Lsu_l325) begin
      if(Lsu_isActive) begin
        Lsu_busReady = (! (Lsu_dbusCtrl_currentCmd_valid || Lsu_dbusCtrl_currentCmd_ready));
      end
    end
  end

  assign when_Lsu_l317 = (Lsu_isActive && Lsu_misaligned);
  assign when_Lsu_l325 = (arbitration_isValid && (! Lsu_misaligned));
  assign _zz_StaticMemoryBackbone_dbus_cmd_payload_address = (value_LSU_TARGET_ADDRESS & 32'hfffffffc);
  always @(*) begin
    when_Lsu_l340 = 1'b0;
    if(when_Lsu_l335) begin
      when_Lsu_l340 = _zz_when_Lsu_l340;
    end
  end

  always @(*) begin
    _zz_out_RD_DATA = 32'h0;
    if(when_Lsu_l335) begin
      _zz_out_RD_DATA = _zz_out_RD_DATA_1;
    end
  end

  assign when_Lsu_l335 = (Lsu_busReady || Lsu_loadActive);
  always @(*) begin
    _zz_when_Lsu_l340 = 1'b0;
    if(StaticMemoryBackbone_dbus_rsp_valid) begin
      if(when_MemBus_l258) begin
        _zz_when_Lsu_l340 = 1'b1;
      end
    end
  end

  always @(*) begin
    _zz_out_RD_DATA_1 = 32'h0;
    if(StaticMemoryBackbone_dbus_rsp_valid) begin
      if(when_MemBus_l258) begin
        _zz_out_RD_DATA_1 = _zz__zz_out_RD_DATA_1[31 : 0];
      end
    end
  end

  always @(*) begin
    _zz_when_MemBus_l258 = 1'b0;
    if(!when_MemBus_l246) begin
      if(when_MemBus_l249) begin
        _zz_when_MemBus_l258 = 1'b1;
      end
    end
  end

  always @(*) begin
    _zz_when_MemBus_l258_1 = 1'b0;
    if(when_MemBus_l246) begin
      _zz_when_MemBus_l258_1 = 1'b1;
    end
  end

  assign when_MemBus_l246 = (! (Lsu_dbusCtrl_currentCmd_valid || Lsu_dbusCtrl_currentCmd_ready));
  assign when_MemBus_l249 = (_zz_when_MemBus_l249 != _zz_when_MemBus_l249_1);
  assign when_MemBus_l258 = (_zz_when_MemBus_l258_1 || ((! _zz_when_MemBus_l258) && (! Lsu_dbusCtrl_currentCmd_cmd_write)));
  always @(*) begin
    _zz_out_RD_DATA_2 = _zz_out_RD_DATA;
    case(value_LSU_ACCESS_WIDTH)
      LsuAccessWidth_H : begin
        if(value_LSU_IS_UNSIGNED) begin
          _zz_out_RD_DATA_2 = {_zz_out_RD_DATA_4,_zz_out_RD_DATA_3};
        end else begin
          _zz_out_RD_DATA_2 = {_zz_out_RD_DATA_6,_zz_out_RD_DATA_3};
        end
      end
      LsuAccessWidth_B : begin
        if(value_LSU_IS_UNSIGNED) begin
          _zz_out_RD_DATA_2 = {_zz_out_RD_DATA_8,_zz_out_RD_DATA_7};
        end else begin
          _zz_out_RD_DATA_2 = {_zz_out_RD_DATA_10,_zz_out_RD_DATA_7};
        end
      end
      default : begin
      end
    endcase
  end

  assign _zz_out_RD_DATA_3 = _zz_out_RD_DATA[{value_LSU_TARGET_ADDRESS[1],4'b0000} +: 16];
  assign _zz_1 = zz__zz_out_RD_DATA_4(1'b0);
  always @(*) _zz_out_RD_DATA_4 = _zz_1;
  assign _zz_out_RD_DATA_5 = _zz_out_RD_DATA_3[15];
  always @(*) begin
    _zz_out_RD_DATA_6[15] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[14] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[13] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[12] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[11] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[10] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[9] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[8] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[7] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[6] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[5] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[4] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[3] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[2] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[1] = _zz_out_RD_DATA_5;
    _zz_out_RD_DATA_6[0] = _zz_out_RD_DATA_5;
  end

  assign _zz_out_RD_DATA_7 = _zz_out_RD_DATA[{value_LSU_TARGET_ADDRESS[1 : 0],3'b000} +: 8];
  assign _zz_2 = zz__zz_out_RD_DATA_8(1'b0);
  always @(*) _zz_out_RD_DATA_8 = _zz_2;
  assign _zz_out_RD_DATA_9 = _zz_out_RD_DATA_7[7];
  always @(*) begin
    _zz_out_RD_DATA_10[23] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[22] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[21] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[20] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[19] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[18] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[17] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[16] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[15] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[14] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[13] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[12] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[11] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[10] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[9] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[8] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[7] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[6] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[5] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[4] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[3] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[2] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[1] = _zz_out_RD_DATA_9;
    _zz_out_RD_DATA_10[0] = _zz_out_RD_DATA_9;
  end

  assign Lsu_busAddress = (value_LSU_TARGET_ADDRESS & 32'hfffffffc);
  assign Lsu_isActive_1 = (value_LSU_OPERATION_TYPE == LsuOperationType_STORE);
  always @(*) begin
    case(value_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : begin
        Lsu_misaligned_1 = 1'b0;
      end
      LsuAccessWidth_H : begin
        Lsu_misaligned_1 = ((value_LSU_TARGET_ADDRESS & 32'h00000001) != 32'h0);
      end
      default : begin
        Lsu_misaligned_1 = ((value_LSU_TARGET_ADDRESS & 32'h00000003) != 32'h0);
      end
    endcase
  end

  always @(*) begin
    case(value_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : begin
        Lsu_baseMask_1 = 4'b0001;
      end
      LsuAccessWidth_H : begin
        Lsu_baseMask_1 = 4'b0011;
      end
      default : begin
        Lsu_baseMask_1 = 4'b1111;
      end
    endcase
  end

  assign Lsu_mask_1 = (Lsu_baseMask_1 <<< value_LSU_TARGET_ADDRESS[1 : 0]);
  assign when_Lsu_l405 = (Lsu_isActive_1 && Lsu_misaligned_1);
  assign when_Lsu_l413 = (arbitration_isValid && (! Lsu_misaligned_1));
  always @(*) begin
    _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata = value_RS2_DATA;
    case(value_LSU_ACCESS_WIDTH)
      LsuAccessWidth_H : begin
        if(when_Lsu_l424) begin
          _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata = ({16'd0,_zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_1} <<< 5'd16);
        end else begin
          _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata = {16'd0, _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_1};
        end
      end
      LsuAccessWidth_B : begin
        case(switch_Lsu_l433)
          2'b00 : begin
            _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata = {24'd0, _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_2};
          end
          2'b01 : begin
            _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata = {16'd0, _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata};
          end
          2'b10 : begin
            _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata = {8'd0, _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_1};
          end
          default : begin
            _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata = ({24'd0,_zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_2} <<< 5'd24);
          end
        endcase
      end
      default : begin
      end
    endcase
  end

  assign _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_1 = value_RS2_DATA[15 : 0];
  assign when_Lsu_l424 = value_LSU_TARGET_ADDRESS[1];
  assign _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_2 = value_RS2_DATA[7 : 0];
  assign switch_Lsu_l433 = value_LSU_TARGET_ADDRESS[1 : 0];
  assign _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_3 = ({31'd0,_zz_StaticMemoryBackbone_dbus_cmd_payload_wdata} <<< _zz__zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_3);
  always @(*) begin
    _zz_arbitration_isReady = 1'b0;
    if(StaticMemoryBackbone_dbus_cmd_ready) begin
      if(when_MemBus_l290) begin
        _zz_arbitration_isReady = 1'b1;
      end
    end
  end

  always @(*) begin
    _zz_when_MemBus_l290 = 1'b0;
    if(!when_MemBus_l279) begin
      if(when_MemBus_l282) begin
        _zz_when_MemBus_l290 = 1'b1;
      end
    end
  end

  always @(*) begin
    _zz_when_MemBus_l290_1 = 1'b0;
    if(when_MemBus_l279) begin
      _zz_when_MemBus_l290_1 = 1'b1;
    end
  end

  assign when_MemBus_l279 = (! (Lsu_dbusCtrl_currentCmd_valid || Lsu_dbusCtrl_currentCmd_ready));
  assign when_MemBus_l282 = (Lsu_dbusCtrl_currentCmd_cmd_address != Lsu_busAddress);
  assign when_MemBus_l290 = (_zz_when_MemBus_l290_1 || ((! _zz_when_MemBus_l290) && Lsu_dbusCtrl_currentCmd_cmd_write));
  always @(*) begin
    TrapHandler_trapSignals_hasTrapped = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_interruptSignals_hasTrapped;
    end else begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_exceptionSignals_hasTrapped;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapCause = 4'bxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapCause = TrapHandler_interruptSignals_trapCause;
    end else begin
      TrapHandler_trapSignals_trapCause = TrapHandler_exceptionSignals_trapCause;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapVal = TrapHandler_interruptSignals_trapVal;
    end else begin
      TrapHandler_trapSignals_trapVal = TrapHandler_exceptionSignals_trapVal;
    end
  end

  always @(*) begin
    TrapHandler_isInterrupt = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_isInterrupt = 1'b1;
    end
  end

  always @(*) begin
    _out_default_RS1 = 5'bxxxxx;
    _out_default_RS1 = in_RS1;
  end

  assign out_RS1 = _out_default_RS1;
  always @(*) begin
    _out_default_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_PC = in_PC;
  end

  assign out_PC = _out_default_PC;
  always @(*) begin
    _out_default_MRET = 1'bx;
    _out_default_MRET = in_MRET;
  end

  assign out_MRET = _out_default_MRET;
  always @(*) begin
    _out_default_RS2_TYPE = (1'bx);
    _out_default_RS2_TYPE = in_RS2_TYPE;
  end

  assign out_RS2_TYPE = _out_default_RS2_TYPE;
  always @(*) begin
    _out_default_RD_TYPE = (1'bx);
    _out_default_RD_TYPE = in_RD_TYPE;
  end

  assign out_RD_TYPE = _out_default_RD_TYPE;
  always @(*) begin
    _out_default_RD = 5'bxxxxx;
    _out_default_RD = in_RD;
  end

  assign out_RD = _out_default_RD;
  always @(*) begin
    _out_default_RS1_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_RS1_DATA = in_RS1_DATA;
  end

  assign out_RS1_DATA = _out_default_RS1_DATA;
  always @(*) begin
    _out_default_CSR_OP = (2'bxx);
    _out_default_CSR_OP = in_CSR_OP;
  end

  assign out_CSR_OP = _out_default_CSR_OP;
  always @(*) begin
    _out_default_RS2 = 5'bxxxxx;
    _out_default_RS2 = in_RS2;
  end

  assign out_RS2 = _out_default_RS2;
  always @(*) begin
    _out_default_IR = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_IR = in_IR;
  end

  assign out_IR = _out_default_IR;
  always @(*) begin
    _out_default_NEXT_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_NEXT_PC = in_NEXT_PC;
  end

  assign out_NEXT_PC = _out_default_NEXT_PC;
  always @(*) begin
    _out_default_RS1_TYPE = (1'bx);
    _out_default_RS1_TYPE = in_RS1_TYPE;
  end

  assign out_RS1_TYPE = _out_default_RS1_TYPE;
  always @(*) begin
    _out_default_CSR_USE_IMM = 1'bx;
    _out_default_CSR_USE_IMM = in_CSR_USE_IMM;
  end

  assign out_CSR_USE_IMM = _out_default_CSR_USE_IMM;
  assign value_RS2_DATA = in_RS2_DATA;
  assign value_LSU_IS_UNSIGNED = in_LSU_IS_UNSIGNED;
  assign value_LSU_ACCESS_WIDTH = in_LSU_ACCESS_WIDTH;
  assign value_LSU_OPERATION_TYPE = in_LSU_OPERATION_TYPE;
  assign value_ALU_RESULT = in_ALU_RESULT;
  assign value_LSU_TARGET_VALID = out_LSU_TARGET_VALID;
  assign value_LSU_TARGET_ADDRESS = out_LSU_TARGET_ADDRESS;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      Lsu_dbusCtrl_currentCmd_valid <= 1'b0;
      Lsu_dbusCtrl_currentCmd_ready <= 1'b0;
      Lsu_loadActive <= 1'b0;
    end else begin
      if(when_MemBus_l189) begin
        Lsu_dbusCtrl_currentCmd_ready <= 1'b1;
        Lsu_dbusCtrl_currentCmd_valid <= 1'b0;
      end
      if(StaticMemoryBackbone_dbus_rsp_valid) begin
        Lsu_dbusCtrl_currentCmd_ready <= 1'b0;
        Lsu_dbusCtrl_currentCmd_valid <= 1'b0;
      end
      if(when_Lsu_l325) begin
        if(Lsu_isActive) begin
          if(Lsu_busReady) begin
            Lsu_loadActive <= 1'b1;
          end
          if(when_Lsu_l335) begin
            if(when_MemBus_l246) begin
              if(StaticMemoryBackbone_dbus_cmd_ready) begin
                Lsu_dbusCtrl_currentCmd_valid <= 1'b0;
                Lsu_dbusCtrl_currentCmd_ready <= 1'b1;
              end else begin
                Lsu_dbusCtrl_currentCmd_valid <= 1'b1;
                Lsu_dbusCtrl_currentCmd_ready <= 1'b0;
              end
            end
            if(StaticMemoryBackbone_dbus_rsp_valid) begin
              Lsu_dbusCtrl_currentCmd_valid <= 1'b0;
              Lsu_dbusCtrl_currentCmd_ready <= 1'b0;
            end
          end
          if(when_Lsu_l340) begin
            Lsu_loadActive <= 1'b0;
          end
        end
      end else begin
        Lsu_loadActive <= 1'b0;
        Lsu_dbusCtrl_currentCmd_valid <= 1'b0;
        Lsu_dbusCtrl_currentCmd_ready <= 1'b0;
      end
      if(when_Lsu_l413) begin
        if(Lsu_isActive_1) begin
          if(when_MemBus_l279) begin
            if(StaticMemoryBackbone_dbus_cmd_ready) begin
              Lsu_dbusCtrl_currentCmd_valid <= 1'b0;
              Lsu_dbusCtrl_currentCmd_ready <= 1'b1;
            end else begin
              Lsu_dbusCtrl_currentCmd_valid <= 1'b1;
              Lsu_dbusCtrl_currentCmd_ready <= 1'b0;
            end
          end
          if(StaticMemoryBackbone_dbus_cmd_ready) begin
            Lsu_dbusCtrl_currentCmd_valid <= 1'b0;
            Lsu_dbusCtrl_currentCmd_ready <= 1'b0;
          end
        end
      end
    end
  end

  always @(posedge clk) begin
    Lsu_dbusCtrl_currentCmd_cmd_id <= 2'bxx;
    if(when_Lsu_l325) begin
      if(Lsu_isActive) begin
        if(when_Lsu_l335) begin
          if(when_MemBus_l246) begin
            Lsu_dbusCtrl_currentCmd_cmd_address <= _zz_StaticMemoryBackbone_dbus_cmd_payload_address;
            Lsu_dbusCtrl_currentCmd_cmd_write <= 1'b0;
          end
        end
      end
    end
    if(when_Lsu_l413) begin
      if(Lsu_isActive_1) begin
        if(when_MemBus_l279) begin
          Lsu_dbusCtrl_currentCmd_cmd_address <= Lsu_busAddress;
          Lsu_dbusCtrl_currentCmd_cmd_write <= 1'b1;
          Lsu_dbusCtrl_currentCmd_cmd_wdata <= _zz_StaticMemoryBackbone_dbus_cmd_payload_wdata_3[31:0];
          Lsu_dbusCtrl_currentCmd_cmd_wmask <= Lsu_mask_1;
        end
      end
    end
  end


endmodule

module Stage_EX (
  input  wire          arbitration_isValid,
  input  wire          arbitration_isStalled,
  output reg           arbitration_isReady,
  output wire          arbitration_isDone,
  output reg           arbitration_rs1Needed,
  output reg           arbitration_rs2Needed,
  output reg           arbitration_jumpRequested,
  output wire          arbitration_isAvailable,
  output reg  [31:0]   out_RD_DATA,
  output reg           out_RD_DATA_VALID,
  output reg  [31:0]   out_ALU_RESULT,
  output reg  [31:0]   out_NEXT_PC,
  input  wire [31:0]   in_NEXT_PC,
  output wire [31:0]   out_PREDICTED_PC,
  output reg           out_HAS_TRAPPED,
  output reg           out_TRAP_IS_INTERRUPT,
  output reg  [3:0]    out_TRAP_CAUSE,
  output reg  [31:0]   out_TRAP_VAL,
  input  wire [31:0]   in_RS2_DATA,
  input  wire          in_MUL,
  input  wire          in_BU_IS_BRANCH,
  input  wire [31:0]   in_PC,
  input  wire [1:0]    in_SHIFT_OP,
  input  wire          in_ECALL,
  input  wire          in_MULDIV_RS2_SIGNED,
  input  wire [2:0]    in_BU_CONDITION,
  input  wire          in_MRET,
  input  wire          in_DIV,
  input  wire [31:0]   in_RS1_DATA,
  input  wire [1:0]    in_CONDITION_OP,
  input  wire          in_REM,
  input  wire          in_BU_WRITE_RET_ADDR_TO_RD,
  input  wire [0:0]    in_ALU_SRC1,
  input  wire [2:0]    in_ALU_OP,
  input  wire          in_IMM_USED,
  input  wire [31:0]   in_IMM,
  input  wire          in_EBREAK,
  input  wire [0:0]    in_ALU_SRC2,
  input  wire          in_MULDIV_RS1_SIGNED,
  input  wire          in_BU_IGNORE_TARGET_LSB,
  input  wire          in_ALU_COMMIT_RESULT,
  input  wire          in_MUL_HIGH,
  output wire [31:0]   out_RS2_DATA,
  input  wire [4:0]    in_RS1,
  output wire [4:0]    out_RS1,
  output wire [31:0]   out_PC,
  input  wire          in_RD_DATA_VALID,
  input  wire [3:0]    in_TRAP_CAUSE,
  output wire          out_MRET,
  input  wire [0:0]    in_RS2_TYPE,
  output wire [0:0]    out_RS2_TYPE,
  input  wire [31:0]   in_TRAP_VAL,
  input  wire [0:0]    in_RD_TYPE,
  output wire [0:0]    out_RD_TYPE,
  input  wire          in_LSU_IS_UNSIGNED,
  output wire          out_LSU_IS_UNSIGNED,
  input  wire          in_HAS_TRAPPED,
  input  wire          in_TRAP_IS_INTERRUPT,
  input  wire [4:0]    in_RD,
  output wire [4:0]    out_RD,
  output wire [31:0]   out_RS1_DATA,
  input  wire [1:0]    in_LSU_OPERATION_TYPE,
  output wire [1:0]    out_LSU_OPERATION_TYPE,
  input  wire [1:0]    in_LSU_ACCESS_WIDTH,
  output wire [1:0]    out_LSU_ACCESS_WIDTH,
  input  wire [1:0]    in_CSR_OP,
  output wire [1:0]    out_CSR_OP,
  input  wire [4:0]    in_RS2,
  output wire [4:0]    out_RS2,
  input  wire [31:0]   in_IR,
  output wire [31:0]   out_IR,
  input  wire [0:0]    in_RS1_TYPE,
  output wire [0:0]    out_RS1_TYPE,
  input  wire          in_LSU_TARGET_VALID,
  output wire          out_LSU_TARGET_VALID,
  input  wire          in_CSR_USE_IMM,
  output wire          out_CSR_USE_IMM,
  input  wire [31:0]   in_PREDICTED_PC,
  input  wire          clk,
  input  wire          reset
);
  localparam AluOp_ADD = 3'd0;
  localparam AluOp_SUB = 3'd1;
  localparam AluOp_SLT = 3'd2;
  localparam AluOp_SLTU = 3'd3;
  localparam AluOp_XOR_1 = 3'd4;
  localparam AluOp_OR_1 = 3'd5;
  localparam AluOp_AND_1 = 3'd6;
  localparam AluOp_SRC2 = 3'd7;
  localparam Src1Select_RS1 = 1'd0;
  localparam Src1Select_PC = 1'd1;
  localparam Src2Select_RS2 = 1'd0;
  localparam Src2Select_IMM = 1'd1;
  localparam ShiftOp_NONE = 2'd0;
  localparam ShiftOp_SLL_1 = 2'd1;
  localparam ShiftOp_SRL_1 = 2'd2;
  localparam ShiftOp_SRA_1 = 2'd3;
  localparam ConditionOp_NONE = 2'd0;
  localparam ConditionOp_EQZ = 2'd1;
  localparam ConditionOp_NEZ = 2'd2;
  localparam BranchCondition_NONE = 3'd0;
  localparam BranchCondition_EQ = 3'd1;
  localparam BranchCondition_NE = 3'd2;
  localparam BranchCondition_LT = 3'd3;
  localparam BranchCondition_GE = 3'd4;
  localparam BranchCondition_LTU = 3'd5;
  localparam BranchCondition_GEU = 3'd6;
  localparam RegisterType_NONE = 1'd0;
  localparam RegisterType_GPR = 1'd1;
  localparam LsuOperationType_NONE = 2'd0;
  localparam LsuOperationType_LOAD = 2'd1;
  localparam LsuOperationType_STORE = 2'd2;
  localparam LsuAccessWidth_B = 2'd0;
  localparam LsuAccessWidth_H = 2'd1;
  localparam LsuAccessWidth_W = 2'd2;
  localparam CsrOp_NONE = 2'd0;
  localparam CsrOp_RW = 2'd1;
  localparam CsrOp_RS = 2'd2;
  localparam CsrOp_RC = 2'd3;

  wire       [0:0]    _zz_IntAlu_result;
  wire       [31:0]   _zz_IntAlu_result_1;
  wire       [31:0]   _zz_IntAlu_result_2;
  wire       [0:0]    _zz_IntAlu_result_3;
  wire       [31:0]   _zz_Shifter_result;
  wire       [31:0]   _zz_Shifter_result_1;
  wire       [31:0]   _zz_BranchUnit_lt;
  wire       [31:0]   _zz_BranchUnit_lt_1;
  wire       [5:0]    _zz_MulDiv_step_valueNext;
  wire       [0:0]    _zz_MulDiv_step_valueNext_1;
  wire       [31:0]   _zz_when_MulDiv_l119;
  wire       [31:0]   _zz_when_MulDiv_l163;
  wire       [31:0]   _zz_when_MulDiv_l163_1;
  wire       [32:0]   _zz__zz_MulDiv_product_3;
  wire       [31:0]   _zz__zz_MulDiv_product_3_1;
  wire       [32:0]   _zz__zz_MulDiv_product_3_2;
  wire       [31:0]   _zz__zz_MulDiv_product_3_3;
  wire       [31:0]   _zz_when_MulDiv_l165;
  wire       [5:0]    _zz_MulDiv_step_valueNext_1_1;
  wire       [0:0]    _zz_MulDiv_step_valueNext_1_2;
  wire       [31:0]   _zz_when_MulDiv_l230;
  wire       [31:0]   _zz__zz_when_MulDiv_l226;
  wire       [31:0]   _zz__zz_MulDiv_remainder;
  wire       [31:0]   _zz_MulDiv_quotient_1;
  reg        [31:0]   _out_default_TRAP_VAL;
  reg        [3:0]    _out_default_TRAP_CAUSE;
  reg                 _out_default_TRAP_IS_INTERRUPT;
  reg                 _out_default_HAS_TRAPPED;
  reg        [31:0]   _out_default_PREDICTED_PC;
  reg        [31:0]   _out_default_NEXT_PC;
  wire       [31:0]   _out_default_ALU_RESULT;
  reg                 _out_default_RD_DATA_VALID;
  wire       [31:0]   _out_default_RD_DATA;
  wire                TrapHandler_interruptSignals_hasTrapped;
  wire       [3:0]    TrapHandler_interruptSignals_trapCause;
  wire       [31:0]   TrapHandler_interruptSignals_trapVal;
  reg                 TrapHandler_exceptionSignals_hasTrapped;
  reg        [3:0]    TrapHandler_exceptionSignals_trapCause;
  reg        [31:0]   TrapHandler_exceptionSignals_trapVal;
  wire       [2:0]    value_ALU_OP;
  reg        [31:0]   IntAlu_src1;
  reg        [31:0]   IntAlu_src2;
  wire       [0:0]    value_ALU_SRC1;
  wire       [31:0]   value_RS1_DATA;
  wire       [31:0]   value_PC;
  wire       [0:0]    value_ALU_SRC2;
  wire       [31:0]   value_RS2_DATA;
  wire       [31:0]   value_IMM;
  reg        [31:0]   IntAlu_result;
  wire                value_ALU_COMMIT_RESULT;
  wire       [31:0]   Shifter_src;
  reg        [4:0]    Shifter_shamt;
  wire                value_IMM_USED;
  wire       [1:0]    value_SHIFT_OP;
  reg        [31:0]   Shifter_result;
  wire                when_Shifter_l73;
  wire       [31:0]   Conditional_src;
  wire       [31:0]   Conditional_cond;
  wire       [1:0]    value_CONDITION_OP;
  reg                 Conditional_moveZero;
  wire                when_Conditional_l62;
  reg        [31:0]   BranchUnit_target;
  wire       [31:0]   value_ALU_RESULT;
  wire                value_BU_IGNORE_TARGET_LSB;
  wire                BranchUnit_misaligned;
  wire       [31:0]   BranchUnit_src1;
  wire       [31:0]   BranchUnit_src2;
  wire                BranchUnit_eq;
  wire                BranchUnit_ne;
  wire                BranchUnit_lt;
  wire                BranchUnit_ltu;
  wire                BranchUnit_ge;
  wire                BranchUnit_geu;
  wire       [2:0]    value_BU_CONDITION;
  reg                 BranchUnit_branchTaken;
  wire                value_BU_IS_BRANCH;
  wire                when_BranchUnit_l134;
  wire                when_BranchUnit_l135;
  wire                when_BranchUnit_l153;
  wire                when_PcManager_l49;
  wire                value_BU_WRITE_RET_ADDR_TO_RD;
  wire                value_ECALL;
  wire                value_EBREAK;
  reg                 TrapHandler_trapSignals_hasTrapped;
  reg        [3:0]    TrapHandler_trapSignals_trapCause;
  reg        [31:0]   TrapHandler_trapSignals_trapVal;
  reg                 TrapHandler_isInterrupt;
  wire                value_HAS_TRAPPED;
  wire                value_TRAP_IS_INTERRUPT;
  wire       [3:0]    value_TRAP_CAUSE;
  wire       [31:0]   value_TRAP_VAL;
  wire                value_MRET;
  reg        [63:0]   MulDiv_product;
  wire       [31:0]   MulDiv_productH;
  wire       [31:0]   MulDiv_productL;
  reg                 MulDiv_initMul;
  reg                 MulDiv_step_willIncrement;
  reg                 MulDiv_step_willClear;
  reg        [5:0]    MulDiv_step_valueNext;
  reg        [5:0]    MulDiv_step_value;
  wire                MulDiv_step_willOverflowIfInc;
  wire                MulDiv_step_willOverflow;
  reg        [32:0]   MulDiv_multiplicand;
  reg        [31:0]   MulDiv_multiplier;
  wire                value_MUL;
  wire                when_MulDiv_l104;
  wire                when_MulDiv_l108;
  wire                when_MulDiv_l113;
  wire                when_MulDiv_l119;
  wire       [31:0]   _zz_MulDiv_multiplicand;
  wire       [0:0]    _zz_MulDiv_multiplicand_1;
  wire       [0:0]    _zz_MulDiv_multiplicand_2;
  wire       [0:0]    _zz_MulDiv_multiplicand_3;
  reg        [32:0]   _zz_MulDiv_product;
  wire                when_MulDiv_l151;
  wire       [0:0]    _zz_MulDiv_product_1;
  wire       [0:0]    _zz_MulDiv_product_2;
  reg        [32:0]   _zz_MulDiv_product_3;
  wire                when_MulDiv_l159;
  wire                when_MulDiv_l163;
  wire                when_MulDiv_l165;
  wire                value_MULDIV_RS2_SIGNED;
  wire                value_MULDIV_RS1_SIGNED;
  wire                value_MUL_HIGH;
  reg        [31:0]   MulDiv_quotient;
  reg        [31:0]   MulDiv_remainder;
  reg                 MulDiv_initDiv;
  reg                 MulDiv_step_willIncrement_1;
  reg                 MulDiv_step_willClear_1;
  reg        [5:0]    MulDiv_step_valueNext_1;
  reg        [5:0]    MulDiv_step_value_1;
  wire                MulDiv_step_willOverflowIfInc_1;
  wire                MulDiv_step_willOverflow_1;
  wire                value_DIV;
  wire                when_MulDiv_l191;
  wire                when_MulDiv_l195;
  wire                when_MulDiv_l200;
  wire                when_MulDiv_l230;
  wire                _zz_when_MulDiv_l226;
  wire       [31:0]   _zz_MulDiv_remainder;
  wire                when_MulDiv_l211;
  reg        [31:0]   _zz_out_RD_DATA;
  reg        [31:0]   _zz_out_RD_DATA_1;
  wire                when_MulDiv_l226;
  wire       [31:0]   _zz_MulDiv_remainder_1;
  reg                 _zz_MulDiv_quotient;
  wire                when_MulDiv_l244;
  wire                value_REM;
  reg        [31:0]   _out_default_RS2_DATA;
  reg        [4:0]    _out_default_RS1;
  reg        [31:0]   _out_default_PC;
  reg                 _out_default_MRET;
  reg        [0:0]    _out_default_RS2_TYPE;
  reg        [0:0]    _out_default_RD_TYPE;
  reg                 _out_default_LSU_IS_UNSIGNED;
  reg        [4:0]    _out_default_RD;
  reg        [31:0]   _out_default_RS1_DATA;
  reg        [1:0]    _out_default_LSU_OPERATION_TYPE;
  reg        [1:0]    _out_default_LSU_ACCESS_WIDTH;
  reg        [1:0]    _out_default_CSR_OP;
  reg        [4:0]    _out_default_RS2;
  reg        [31:0]   _out_default_IR;
  reg        [0:0]    _out_default_RS1_TYPE;
  reg                 _out_default_LSU_TARGET_VALID;
  reg                 _out_default_CSR_USE_IMM;
  `ifndef SYNTHESIS
  reg [39:0] value_ALU_OP_string;
  reg [23:0] value_ALU_SRC1_string;
  reg [23:0] value_ALU_SRC2_string;
  reg [39:0] value_SHIFT_OP_string;
  reg [31:0] value_CONDITION_OP_string;
  reg [31:0] value_BU_CONDITION_string;
  reg [39:0] in_SHIFT_OP_string;
  reg [31:0] in_BU_CONDITION_string;
  reg [31:0] in_CONDITION_OP_string;
  reg [23:0] in_ALU_SRC1_string;
  reg [39:0] in_ALU_OP_string;
  reg [23:0] in_ALU_SRC2_string;
  reg [31:0] in_RS2_TYPE_string;
  reg [31:0] out_RS2_TYPE_string;
  reg [31:0] _out_default_RS2_TYPE_string;
  reg [31:0] in_RD_TYPE_string;
  reg [31:0] out_RD_TYPE_string;
  reg [31:0] _out_default_RD_TYPE_string;
  reg [39:0] in_LSU_OPERATION_TYPE_string;
  reg [39:0] out_LSU_OPERATION_TYPE_string;
  reg [39:0] _out_default_LSU_OPERATION_TYPE_string;
  reg [7:0] in_LSU_ACCESS_WIDTH_string;
  reg [7:0] out_LSU_ACCESS_WIDTH_string;
  reg [7:0] _out_default_LSU_ACCESS_WIDTH_string;
  reg [31:0] in_CSR_OP_string;
  reg [31:0] out_CSR_OP_string;
  reg [31:0] _out_default_CSR_OP_string;
  reg [31:0] in_RS1_TYPE_string;
  reg [31:0] out_RS1_TYPE_string;
  reg [31:0] _out_default_RS1_TYPE_string;
  `endif


  assign _zz_IntAlu_result = ($signed(_zz_IntAlu_result_1) < $signed(_zz_IntAlu_result_2));
  assign _zz_IntAlu_result_1 = IntAlu_src1;
  assign _zz_IntAlu_result_2 = IntAlu_src2;
  assign _zz_IntAlu_result_3 = (IntAlu_src1 < IntAlu_src2);
  assign _zz_Shifter_result = ($signed(_zz_Shifter_result_1) >>> Shifter_shamt);
  assign _zz_Shifter_result_1 = Shifter_src;
  assign _zz_BranchUnit_lt = BranchUnit_src1;
  assign _zz_BranchUnit_lt_1 = BranchUnit_src2;
  assign _zz_MulDiv_step_valueNext_1 = MulDiv_step_willIncrement;
  assign _zz_MulDiv_step_valueNext = {5'd0, _zz_MulDiv_step_valueNext_1};
  assign _zz_when_MulDiv_l119 = value_RS2_DATA;
  assign _zz_when_MulDiv_l163 = value_RS1_DATA;
  assign _zz_when_MulDiv_l163_1 = value_RS2_DATA;
  assign _zz__zz_MulDiv_product_3_1 = MulDiv_multiplicand[31 : 0];
  assign _zz__zz_MulDiv_product_3 = {1'd0, _zz__zz_MulDiv_product_3_1};
  assign _zz__zz_MulDiv_product_3_3 = MulDiv_multiplicand[31 : 0];
  assign _zz__zz_MulDiv_product_3_2 = {1'd0, _zz__zz_MulDiv_product_3_3};
  assign _zz_when_MulDiv_l165 = value_RS1_DATA;
  assign _zz_MulDiv_step_valueNext_1_2 = MulDiv_step_willIncrement_1;
  assign _zz_MulDiv_step_valueNext_1_1 = {5'd0, _zz_MulDiv_step_valueNext_1_2};
  assign _zz_when_MulDiv_l230 = value_RS1_DATA;
  assign _zz__zz_when_MulDiv_l226 = value_RS2_DATA;
  assign _zz__zz_MulDiv_remainder = ((~ value_RS2_DATA) + 32'h00000001);
  assign _zz_MulDiv_quotient_1 = ((~ value_RS1_DATA) + 32'h00000001);
  `ifndef SYNTHESIS
  always @(*) begin
    case(value_ALU_OP)
      AluOp_ADD : value_ALU_OP_string = "ADD  ";
      AluOp_SUB : value_ALU_OP_string = "SUB  ";
      AluOp_SLT : value_ALU_OP_string = "SLT  ";
      AluOp_SLTU : value_ALU_OP_string = "SLTU ";
      AluOp_XOR_1 : value_ALU_OP_string = "XOR_1";
      AluOp_OR_1 : value_ALU_OP_string = "OR_1 ";
      AluOp_AND_1 : value_ALU_OP_string = "AND_1";
      AluOp_SRC2 : value_ALU_OP_string = "SRC2 ";
      default : value_ALU_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(value_ALU_SRC1)
      Src1Select_RS1 : value_ALU_SRC1_string = "RS1";
      Src1Select_PC : value_ALU_SRC1_string = "PC ";
      default : value_ALU_SRC1_string = "???";
    endcase
  end
  always @(*) begin
    case(value_ALU_SRC2)
      Src2Select_RS2 : value_ALU_SRC2_string = "RS2";
      Src2Select_IMM : value_ALU_SRC2_string = "IMM";
      default : value_ALU_SRC2_string = "???";
    endcase
  end
  always @(*) begin
    case(value_SHIFT_OP)
      ShiftOp_NONE : value_SHIFT_OP_string = "NONE ";
      ShiftOp_SLL_1 : value_SHIFT_OP_string = "SLL_1";
      ShiftOp_SRL_1 : value_SHIFT_OP_string = "SRL_1";
      ShiftOp_SRA_1 : value_SHIFT_OP_string = "SRA_1";
      default : value_SHIFT_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(value_CONDITION_OP)
      ConditionOp_NONE : value_CONDITION_OP_string = "NONE";
      ConditionOp_EQZ : value_CONDITION_OP_string = "EQZ ";
      ConditionOp_NEZ : value_CONDITION_OP_string = "NEZ ";
      default : value_CONDITION_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(value_BU_CONDITION)
      BranchCondition_NONE : value_BU_CONDITION_string = "NONE";
      BranchCondition_EQ : value_BU_CONDITION_string = "EQ  ";
      BranchCondition_NE : value_BU_CONDITION_string = "NE  ";
      BranchCondition_LT : value_BU_CONDITION_string = "LT  ";
      BranchCondition_GE : value_BU_CONDITION_string = "GE  ";
      BranchCondition_LTU : value_BU_CONDITION_string = "LTU ";
      BranchCondition_GEU : value_BU_CONDITION_string = "GEU ";
      default : value_BU_CONDITION_string = "????";
    endcase
  end
  always @(*) begin
    case(in_SHIFT_OP)
      ShiftOp_NONE : in_SHIFT_OP_string = "NONE ";
      ShiftOp_SLL_1 : in_SHIFT_OP_string = "SLL_1";
      ShiftOp_SRL_1 : in_SHIFT_OP_string = "SRL_1";
      ShiftOp_SRA_1 : in_SHIFT_OP_string = "SRA_1";
      default : in_SHIFT_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(in_BU_CONDITION)
      BranchCondition_NONE : in_BU_CONDITION_string = "NONE";
      BranchCondition_EQ : in_BU_CONDITION_string = "EQ  ";
      BranchCondition_NE : in_BU_CONDITION_string = "NE  ";
      BranchCondition_LT : in_BU_CONDITION_string = "LT  ";
      BranchCondition_GE : in_BU_CONDITION_string = "GE  ";
      BranchCondition_LTU : in_BU_CONDITION_string = "LTU ";
      BranchCondition_GEU : in_BU_CONDITION_string = "GEU ";
      default : in_BU_CONDITION_string = "????";
    endcase
  end
  always @(*) begin
    case(in_CONDITION_OP)
      ConditionOp_NONE : in_CONDITION_OP_string = "NONE";
      ConditionOp_EQZ : in_CONDITION_OP_string = "EQZ ";
      ConditionOp_NEZ : in_CONDITION_OP_string = "NEZ ";
      default : in_CONDITION_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(in_ALU_SRC1)
      Src1Select_RS1 : in_ALU_SRC1_string = "RS1";
      Src1Select_PC : in_ALU_SRC1_string = "PC ";
      default : in_ALU_SRC1_string = "???";
    endcase
  end
  always @(*) begin
    case(in_ALU_OP)
      AluOp_ADD : in_ALU_OP_string = "ADD  ";
      AluOp_SUB : in_ALU_OP_string = "SUB  ";
      AluOp_SLT : in_ALU_OP_string = "SLT  ";
      AluOp_SLTU : in_ALU_OP_string = "SLTU ";
      AluOp_XOR_1 : in_ALU_OP_string = "XOR_1";
      AluOp_OR_1 : in_ALU_OP_string = "OR_1 ";
      AluOp_AND_1 : in_ALU_OP_string = "AND_1";
      AluOp_SRC2 : in_ALU_OP_string = "SRC2 ";
      default : in_ALU_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(in_ALU_SRC2)
      Src2Select_RS2 : in_ALU_SRC2_string = "RS2";
      Src2Select_IMM : in_ALU_SRC2_string = "IMM";
      default : in_ALU_SRC2_string = "???";
    endcase
  end
  always @(*) begin
    case(in_RS2_TYPE)
      RegisterType_NONE : in_RS2_TYPE_string = "NONE";
      RegisterType_GPR : in_RS2_TYPE_string = "GPR ";
      default : in_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS2_TYPE)
      RegisterType_NONE : out_RS2_TYPE_string = "NONE";
      RegisterType_GPR : out_RS2_TYPE_string = "GPR ";
      default : out_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RS2_TYPE)
      RegisterType_NONE : _out_default_RS2_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RS2_TYPE_string = "GPR ";
      default : _out_default_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RD_TYPE)
      RegisterType_NONE : in_RD_TYPE_string = "NONE";
      RegisterType_GPR : in_RD_TYPE_string = "GPR ";
      default : in_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RD_TYPE)
      RegisterType_NONE : out_RD_TYPE_string = "NONE";
      RegisterType_GPR : out_RD_TYPE_string = "GPR ";
      default : out_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RD_TYPE)
      RegisterType_NONE : _out_default_RD_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RD_TYPE_string = "GPR ";
      default : _out_default_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(in_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : in_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : in_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : in_LSU_OPERATION_TYPE_string = "STORE";
      default : in_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(out_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : out_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : out_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : out_LSU_OPERATION_TYPE_string = "STORE";
      default : out_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(_out_default_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : _out_default_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : _out_default_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : _out_default_LSU_OPERATION_TYPE_string = "STORE";
      default : _out_default_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(in_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : in_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : in_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : in_LSU_ACCESS_WIDTH_string = "W";
      default : in_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(out_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : out_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : out_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : out_LSU_ACCESS_WIDTH_string = "W";
      default : out_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(_out_default_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : _out_default_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : _out_default_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : _out_default_LSU_ACCESS_WIDTH_string = "W";
      default : _out_default_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(in_CSR_OP)
      CsrOp_NONE : in_CSR_OP_string = "NONE";
      CsrOp_RW : in_CSR_OP_string = "RW  ";
      CsrOp_RS : in_CSR_OP_string = "RS  ";
      CsrOp_RC : in_CSR_OP_string = "RC  ";
      default : in_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(out_CSR_OP)
      CsrOp_NONE : out_CSR_OP_string = "NONE";
      CsrOp_RW : out_CSR_OP_string = "RW  ";
      CsrOp_RS : out_CSR_OP_string = "RS  ";
      CsrOp_RC : out_CSR_OP_string = "RC  ";
      default : out_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_CSR_OP)
      CsrOp_NONE : _out_default_CSR_OP_string = "NONE";
      CsrOp_RW : _out_default_CSR_OP_string = "RW  ";
      CsrOp_RS : _out_default_CSR_OP_string = "RS  ";
      CsrOp_RC : _out_default_CSR_OP_string = "RC  ";
      default : _out_default_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(in_RS1_TYPE)
      RegisterType_NONE : in_RS1_TYPE_string = "NONE";
      RegisterType_GPR : in_RS1_TYPE_string = "GPR ";
      default : in_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS1_TYPE)
      RegisterType_NONE : out_RS1_TYPE_string = "NONE";
      RegisterType_GPR : out_RS1_TYPE_string = "GPR ";
      default : out_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RS1_TYPE)
      RegisterType_NONE : _out_default_RS1_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RS1_TYPE_string = "GPR ";
      default : _out_default_RS1_TYPE_string = "????";
    endcase
  end
  `endif

  always @(*) begin
    _out_default_TRAP_VAL = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_TRAP_VAL = in_TRAP_VAL;
  end

  always @(*) begin
    out_TRAP_VAL = _out_default_TRAP_VAL;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_VAL = TrapHandler_trapSignals_trapVal;
    end
  end

  always @(*) begin
    _out_default_TRAP_CAUSE = 4'bxxxx;
    _out_default_TRAP_CAUSE = in_TRAP_CAUSE;
  end

  always @(*) begin
    out_TRAP_CAUSE = _out_default_TRAP_CAUSE;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_CAUSE = TrapHandler_trapSignals_trapCause;
    end
  end

  always @(*) begin
    _out_default_TRAP_IS_INTERRUPT = 1'bx;
    _out_default_TRAP_IS_INTERRUPT = in_TRAP_IS_INTERRUPT;
  end

  always @(*) begin
    out_TRAP_IS_INTERRUPT = _out_default_TRAP_IS_INTERRUPT;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_IS_INTERRUPT = TrapHandler_isInterrupt;
    end
  end

  always @(*) begin
    _out_default_HAS_TRAPPED = 1'bx;
    _out_default_HAS_TRAPPED = in_HAS_TRAPPED;
  end

  always @(*) begin
    out_HAS_TRAPPED = _out_default_HAS_TRAPPED;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_HAS_TRAPPED = 1'b1;
    end
  end

  always @(*) begin
    _out_default_PREDICTED_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_PREDICTED_PC = in_PREDICTED_PC;
  end

  assign out_PREDICTED_PC = _out_default_PREDICTED_PC;
  always @(*) begin
    _out_default_NEXT_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_NEXT_PC = in_NEXT_PC;
  end

  always @(*) begin
    out_NEXT_PC = _out_default_NEXT_PC;
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l153) begin
        if(!when_PcManager_l49) begin
          out_NEXT_PC = BranchUnit_target;
        end
      end
    end
  end

  assign _out_default_ALU_RESULT = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_ALU_RESULT = _out_default_ALU_RESULT;
    if(!value_ALU_COMMIT_RESULT) begin
      out_ALU_RESULT = IntAlu_result;
    end
  end

  always @(*) begin
    _out_default_RD_DATA_VALID = 1'bx;
    _out_default_RD_DATA_VALID = in_RD_DATA_VALID;
  end

  always @(*) begin
    out_RD_DATA_VALID = _out_default_RD_DATA_VALID;
    if(value_ALU_COMMIT_RESULT) begin
      out_RD_DATA_VALID = 1'b1;
    end
    if(when_Shifter_l73) begin
      out_RD_DATA_VALID = 1'b1;
    end
    if(when_Conditional_l62) begin
      out_RD_DATA_VALID = 1'b1;
    end
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l153) begin
        if(value_BU_WRITE_RET_ADDR_TO_RD) begin
          out_RD_DATA_VALID = 1'b1;
        end
      end
    end
    if(when_MulDiv_l113) begin
      if(!MulDiv_initMul) begin
        if(MulDiv_step_willOverflowIfInc) begin
          out_RD_DATA_VALID = 1'b1;
        end
      end
    end
    if(when_MulDiv_l200) begin
      if(when_MulDiv_l211) begin
        out_RD_DATA_VALID = 1'b1;
      end else begin
        if(!MulDiv_initDiv) begin
          if(MulDiv_step_willOverflowIfInc_1) begin
            out_RD_DATA_VALID = 1'b1;
          end
        end
      end
    end
  end

  assign _out_default_RD_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_RD_DATA = _out_default_RD_DATA;
    if(value_ALU_COMMIT_RESULT) begin
      out_RD_DATA = IntAlu_result;
    end
    if(when_Shifter_l73) begin
      out_RD_DATA = Shifter_result;
    end
    if(when_Conditional_l62) begin
      out_RD_DATA = (Conditional_moveZero ? 32'h0 : Conditional_src);
    end
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l153) begin
        if(value_BU_WRITE_RET_ADDR_TO_RD) begin
          out_RD_DATA = in_NEXT_PC;
        end
      end
    end
    if(when_MulDiv_l113) begin
      if(!MulDiv_initMul) begin
        if(MulDiv_step_willOverflowIfInc) begin
          out_RD_DATA = (value_MUL_HIGH ? MulDiv_productH : MulDiv_productL);
        end
      end
    end
    if(when_MulDiv_l200) begin
      if(when_MulDiv_l211) begin
        out_RD_DATA = (value_REM ? value_RS1_DATA : 32'hffffffff);
      end else begin
        if(!MulDiv_initDiv) begin
          if(MulDiv_step_willOverflowIfInc_1) begin
            out_RD_DATA = (value_REM ? _zz_out_RD_DATA_1 : _zz_out_RD_DATA);
          end
        end
      end
    end
  end

  assign arbitration_isAvailable = ((! arbitration_isValid) || arbitration_isDone);
  always @(*) begin
    arbitration_isReady = 1'b1;
    if(when_MulDiv_l113) begin
      arbitration_isReady = 1'b0;
      if(!MulDiv_initMul) begin
        if(MulDiv_step_willOverflowIfInc) begin
          arbitration_isReady = 1'b1;
        end
      end
    end
    if(when_MulDiv_l200) begin
      arbitration_isReady = 1'b0;
      if(when_MulDiv_l211) begin
        arbitration_isReady = 1'b1;
      end else begin
        if(!MulDiv_initDiv) begin
          if(MulDiv_step_willOverflowIfInc_1) begin
            arbitration_isReady = 1'b1;
          end
        end
      end
    end
  end

  always @(*) begin
    arbitration_rs1Needed = 1'b0;
    case(value_ALU_SRC1)
      Src1Select_RS1 : begin
        arbitration_rs1Needed = 1'b1;
      end
      default : begin
      end
    endcase
    if(when_Shifter_l73) begin
      arbitration_rs1Needed = 1'b1;
    end
    if(when_Conditional_l62) begin
      arbitration_rs1Needed = 1'b1;
    end
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l135) begin
        arbitration_rs1Needed = 1'b1;
      end
    end
    if(when_MulDiv_l108) begin
      arbitration_rs1Needed = 1'b1;
    end
    if(when_MulDiv_l195) begin
      arbitration_rs1Needed = 1'b1;
    end
  end

  always @(*) begin
    arbitration_rs2Needed = 1'b0;
    case(value_ALU_SRC2)
      Src2Select_RS2 : begin
        arbitration_rs2Needed = 1'b1;
      end
      default : begin
      end
    endcase
    if(when_Shifter_l73) begin
      arbitration_rs2Needed = (! value_IMM_USED);
    end
    if(when_Conditional_l62) begin
      arbitration_rs2Needed = 1'b1;
    end
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l135) begin
        arbitration_rs2Needed = 1'b1;
      end
    end
    if(when_MulDiv_l108) begin
      arbitration_rs2Needed = 1'b1;
    end
    if(when_MulDiv_l195) begin
      arbitration_rs2Needed = 1'b1;
    end
  end

  always @(*) begin
    arbitration_jumpRequested = 1'b0;
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l153) begin
        if(!when_PcManager_l49) begin
          arbitration_jumpRequested = 1'b1;
        end
      end
    end
  end

  assign arbitration_isDone = ((arbitration_isValid && arbitration_isReady) && (! arbitration_isStalled));
  assign TrapHandler_interruptSignals_hasTrapped = 1'b0;
  assign TrapHandler_interruptSignals_trapCause = 4'bxxxx;
  assign TrapHandler_interruptSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    TrapHandler_exceptionSignals_hasTrapped = 1'b0;
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l153) begin
        if(when_PcManager_l49) begin
          TrapHandler_exceptionSignals_hasTrapped = 1'b1;
        end
      end
    end
    if(arbitration_isValid) begin
      if(value_ECALL) begin
        TrapHandler_exceptionSignals_hasTrapped = 1'b1;
      end else begin
        if(value_EBREAK) begin
          TrapHandler_exceptionSignals_hasTrapped = 1'b1;
        end
      end
    end
  end

  always @(*) begin
    TrapHandler_exceptionSignals_trapCause = 4'bxxxx;
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l153) begin
        if(when_PcManager_l49) begin
          TrapHandler_exceptionSignals_trapCause = 4'b0000;
        end
      end
    end
    if(arbitration_isValid) begin
      if(value_ECALL) begin
        TrapHandler_exceptionSignals_trapCause = 4'b1011;
      end else begin
        if(value_EBREAK) begin
          TrapHandler_exceptionSignals_trapCause = 4'b0011;
        end
      end
    end
  end

  always @(*) begin
    TrapHandler_exceptionSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(when_BranchUnit_l134) begin
      if(when_BranchUnit_l153) begin
        if(when_PcManager_l49) begin
          TrapHandler_exceptionSignals_trapVal = BranchUnit_target;
        end
      end
    end
    if(arbitration_isValid) begin
      if(value_ECALL) begin
        TrapHandler_exceptionSignals_trapVal = 32'h0;
      end else begin
        if(value_EBREAK) begin
          TrapHandler_exceptionSignals_trapVal = 32'h0;
        end
      end
    end
  end

  always @(*) begin
    case(value_ALU_SRC1)
      Src1Select_RS1 : begin
        IntAlu_src1 = value_RS1_DATA;
      end
      default : begin
        IntAlu_src1 = value_PC;
      end
    endcase
  end

  always @(*) begin
    case(value_ALU_SRC2)
      Src2Select_RS2 : begin
        IntAlu_src2 = value_RS2_DATA;
      end
      default : begin
        IntAlu_src2 = value_IMM;
      end
    endcase
  end

  always @(*) begin
    case(value_ALU_OP)
      AluOp_ADD : begin
        IntAlu_result = (IntAlu_src1 + IntAlu_src2);
      end
      AluOp_SUB : begin
        IntAlu_result = (IntAlu_src1 - IntAlu_src2);
      end
      AluOp_SLT : begin
        IntAlu_result = {31'd0, _zz_IntAlu_result};
      end
      AluOp_SLTU : begin
        IntAlu_result = {31'd0, _zz_IntAlu_result_3};
      end
      AluOp_XOR_1 : begin
        IntAlu_result = (IntAlu_src1 ^ IntAlu_src2);
      end
      AluOp_OR_1 : begin
        IntAlu_result = (IntAlu_src1 | IntAlu_src2);
      end
      AluOp_AND_1 : begin
        IntAlu_result = (IntAlu_src1 & IntAlu_src2);
      end
      default : begin
        IntAlu_result = IntAlu_src2;
      end
    endcase
  end

  assign Shifter_src = value_RS1_DATA;
  always @(*) begin
    if(value_IMM_USED) begin
      Shifter_shamt = value_IMM[4 : 0];
    end else begin
      Shifter_shamt = value_RS2_DATA[4 : 0];
    end
  end

  always @(*) begin
    case(value_SHIFT_OP)
      ShiftOp_NONE : begin
        Shifter_result = 32'h0;
      end
      ShiftOp_SLL_1 : begin
        Shifter_result = (Shifter_src <<< Shifter_shamt);
      end
      ShiftOp_SRL_1 : begin
        Shifter_result = (Shifter_src >>> Shifter_shamt);
      end
      default : begin
        Shifter_result = _zz_Shifter_result;
      end
    endcase
  end

  assign when_Shifter_l73 = (arbitration_isValid && (value_SHIFT_OP != ShiftOp_NONE));
  assign Conditional_src = value_RS1_DATA;
  assign Conditional_cond = value_RS2_DATA;
  always @(*) begin
    case(value_CONDITION_OP)
      ConditionOp_NONE : begin
        Conditional_moveZero = 1'b1;
      end
      ConditionOp_EQZ : begin
        Conditional_moveZero = (Conditional_cond == 32'h0);
      end
      default : begin
        Conditional_moveZero = (Conditional_cond != 32'h0);
      end
    endcase
  end

  assign when_Conditional_l62 = (arbitration_isValid && (value_CONDITION_OP != ConditionOp_NONE));
  always @(*) begin
    BranchUnit_target = value_ALU_RESULT;
    if(value_BU_IGNORE_TARGET_LSB) begin
      BranchUnit_target[0] = 1'b0;
    end
  end

  assign BranchUnit_misaligned = (|BranchUnit_target[1 : 0]);
  assign BranchUnit_src1 = value_RS1_DATA;
  assign BranchUnit_src2 = value_RS2_DATA;
  assign BranchUnit_eq = (BranchUnit_src1 == BranchUnit_src2);
  assign BranchUnit_ne = (! BranchUnit_eq);
  assign BranchUnit_lt = ($signed(_zz_BranchUnit_lt) < $signed(_zz_BranchUnit_lt_1));
  assign BranchUnit_ltu = (BranchUnit_src1 < BranchUnit_src2);
  assign BranchUnit_ge = (! BranchUnit_lt);
  assign BranchUnit_geu = (! BranchUnit_ltu);
  always @(*) begin
    case(value_BU_CONDITION)
      BranchCondition_NONE : begin
        BranchUnit_branchTaken = 1'b1;
      end
      BranchCondition_EQ : begin
        BranchUnit_branchTaken = BranchUnit_eq;
      end
      BranchCondition_NE : begin
        BranchUnit_branchTaken = BranchUnit_ne;
      end
      BranchCondition_LT : begin
        BranchUnit_branchTaken = BranchUnit_lt;
      end
      BranchCondition_GE : begin
        BranchUnit_branchTaken = BranchUnit_ge;
      end
      BranchCondition_LTU : begin
        BranchUnit_branchTaken = BranchUnit_ltu;
      end
      default : begin
        BranchUnit_branchTaken = BranchUnit_geu;
      end
    endcase
  end

  assign when_BranchUnit_l134 = (arbitration_isValid && value_BU_IS_BRANCH);
  assign when_BranchUnit_l135 = (value_BU_CONDITION != BranchCondition_NONE);
  assign when_BranchUnit_l153 = (BranchUnit_branchTaken && (! arbitration_isStalled));
  assign when_PcManager_l49 = (BranchUnit_target[1 : 0] != 2'b00);
  always @(*) begin
    TrapHandler_trapSignals_hasTrapped = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_interruptSignals_hasTrapped;
    end else begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_exceptionSignals_hasTrapped;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapCause = 4'bxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapCause = TrapHandler_interruptSignals_trapCause;
    end else begin
      TrapHandler_trapSignals_trapCause = TrapHandler_exceptionSignals_trapCause;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapVal = TrapHandler_interruptSignals_trapVal;
    end else begin
      TrapHandler_trapSignals_trapVal = TrapHandler_exceptionSignals_trapVal;
    end
  end

  always @(*) begin
    TrapHandler_isInterrupt = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_isInterrupt = 1'b1;
    end
  end

  assign MulDiv_productH = MulDiv_product[63 : 32];
  assign MulDiv_productL = MulDiv_product[31 : 0];
  always @(*) begin
    MulDiv_step_willIncrement = 1'b0;
    if(when_MulDiv_l113) begin
      if(!MulDiv_initMul) begin
        if(MulDiv_step_willOverflowIfInc) begin
          MulDiv_step_willIncrement = 1'b1;
        end else begin
          MulDiv_step_willIncrement = 1'b1;
        end
      end
    end
  end

  always @(*) begin
    MulDiv_step_willClear = 1'b0;
    if(when_MulDiv_l113) begin
      if(MulDiv_initMul) begin
        MulDiv_step_willClear = 1'b1;
      end
    end
  end

  assign MulDiv_step_willOverflowIfInc = (MulDiv_step_value == 6'h20);
  assign MulDiv_step_willOverflow = (MulDiv_step_willOverflowIfInc && MulDiv_step_willIncrement);
  always @(*) begin
    if(MulDiv_step_willOverflow) begin
      MulDiv_step_valueNext = 6'h0;
    end else begin
      MulDiv_step_valueNext = (MulDiv_step_value + _zz_MulDiv_step_valueNext);
    end
    if(MulDiv_step_willClear) begin
      MulDiv_step_valueNext = 6'h0;
    end
  end

  always @(*) begin
    MulDiv_multiplicand = 33'h0;
    if(when_MulDiv_l113) begin
      if(when_MulDiv_l119) begin
        MulDiv_multiplicand = {_zz_MulDiv_multiplicand_1,_zz_MulDiv_multiplicand};
      end else begin
        if(value_MULDIV_RS1_SIGNED) begin
          MulDiv_multiplicand = {_zz_MulDiv_multiplicand_2,value_RS1_DATA};
        end else begin
          MulDiv_multiplicand = {_zz_MulDiv_multiplicand_3,value_RS1_DATA};
        end
      end
    end
  end

  always @(*) begin
    MulDiv_multiplier = 32'h0;
    if(when_MulDiv_l113) begin
      if(when_MulDiv_l119) begin
        MulDiv_multiplier = ((~ value_RS2_DATA) + 32'h00000001);
      end else begin
        MulDiv_multiplier = value_RS2_DATA;
      end
    end
  end

  assign when_MulDiv_l104 = ((! arbitration_isValid) || arbitration_isStalled);
  assign when_MulDiv_l108 = (arbitration_isValid && value_MUL);
  assign when_MulDiv_l113 = ((! ((! arbitration_isValid) || arbitration_isStalled)) && value_MUL);
  assign when_MulDiv_l119 = (value_MULDIV_RS2_SIGNED && ($signed(_zz_when_MulDiv_l119) < $signed(32'h0)));
  assign _zz_MulDiv_multiplicand = ((~ value_RS1_DATA) + 32'h00000001);
  assign _zz_MulDiv_multiplicand_1[0] = _zz_MulDiv_multiplicand[31];
  assign _zz_MulDiv_multiplicand_2[0] = value_RS1_DATA[31];
  assign _zz_MulDiv_multiplicand_3[0] = 1'b0;
  assign when_MulDiv_l151 = (value_MULDIV_RS1_SIGNED || value_MULDIV_RS2_SIGNED);
  assign _zz_MulDiv_product_1[0] = MulDiv_productH[31];
  always @(*) begin
    if(when_MulDiv_l151) begin
      _zz_MulDiv_product = {_zz_MulDiv_product_1,MulDiv_productH};
    end else begin
      _zz_MulDiv_product = {_zz_MulDiv_product_2,MulDiv_productH};
    end
  end

  assign _zz_MulDiv_product_2[0] = 1'b0;
  assign when_MulDiv_l159 = MulDiv_product[0];
  assign when_MulDiv_l163 = ((((value_MUL_HIGH && ($signed(_zz_when_MulDiv_l163) < $signed(32'h0))) && ($signed(_zz_when_MulDiv_l163_1) < $signed(32'h0))) && value_MULDIV_RS2_SIGNED) && value_MULDIV_RS1_SIGNED);
  always @(*) begin
    if(when_MulDiv_l159) begin
      if(when_MulDiv_l163) begin
        _zz_MulDiv_product_3 = (_zz_MulDiv_product + _zz__zz_MulDiv_product_3);
      end else begin
        if(when_MulDiv_l165) begin
          _zz_MulDiv_product_3 = (_zz_MulDiv_product + _zz__zz_MulDiv_product_3_2);
        end else begin
          _zz_MulDiv_product_3 = (_zz_MulDiv_product + MulDiv_multiplicand);
        end
      end
    end else begin
      _zz_MulDiv_product_3 = _zz_MulDiv_product;
    end
  end

  assign when_MulDiv_l165 = ((((MulDiv_step_value == 6'h1f) && ($signed(_zz_when_MulDiv_l165) < $signed(32'h0))) && value_MULDIV_RS2_SIGNED) && value_MULDIV_RS1_SIGNED);
  always @(*) begin
    MulDiv_step_willIncrement_1 = 1'b0;
    if(when_MulDiv_l200) begin
      if(!when_MulDiv_l211) begin
        if(!MulDiv_initDiv) begin
          if(MulDiv_step_willOverflowIfInc_1) begin
            MulDiv_step_willIncrement_1 = 1'b1;
          end else begin
            MulDiv_step_willIncrement_1 = 1'b1;
          end
        end
      end
    end
  end

  always @(*) begin
    MulDiv_step_willClear_1 = 1'b0;
    if(when_MulDiv_l200) begin
      if(!when_MulDiv_l211) begin
        if(MulDiv_initDiv) begin
          MulDiv_step_willClear_1 = 1'b1;
        end
      end
    end
  end

  assign MulDiv_step_willOverflowIfInc_1 = (MulDiv_step_value_1 == 6'h20);
  assign MulDiv_step_willOverflow_1 = (MulDiv_step_willOverflowIfInc_1 && MulDiv_step_willIncrement_1);
  always @(*) begin
    if(MulDiv_step_willOverflow_1) begin
      MulDiv_step_valueNext_1 = 6'h0;
    end else begin
      MulDiv_step_valueNext_1 = (MulDiv_step_value_1 + _zz_MulDiv_step_valueNext_1_1);
    end
    if(MulDiv_step_willClear_1) begin
      MulDiv_step_valueNext_1 = 6'h0;
    end
  end

  assign when_MulDiv_l191 = ((! arbitration_isValid) || arbitration_isStalled);
  assign when_MulDiv_l195 = (arbitration_isValid && value_DIV);
  assign when_MulDiv_l200 = ((! ((! arbitration_isValid) || arbitration_isStalled)) && value_DIV);
  assign when_MulDiv_l230 = (value_MULDIV_RS1_SIGNED && ($signed(_zz_when_MulDiv_l230) < $signed(32'h0)));
  assign _zz_when_MulDiv_l226 = (value_MULDIV_RS1_SIGNED && ($signed(_zz__zz_when_MulDiv_l226) < $signed(32'h0)));
  assign _zz_MulDiv_remainder = (_zz_when_MulDiv_l226 ? _zz__zz_MulDiv_remainder : value_RS2_DATA);
  assign when_MulDiv_l211 = (_zz_MulDiv_remainder == 32'h0);
  always @(*) begin
    _zz_out_RD_DATA = MulDiv_quotient;
    if(when_MulDiv_l226) begin
      _zz_out_RD_DATA = ((~ MulDiv_quotient) + 32'h00000001);
    end
  end

  always @(*) begin
    _zz_out_RD_DATA_1 = MulDiv_remainder;
    if(when_MulDiv_l230) begin
      _zz_out_RD_DATA_1 = ((~ MulDiv_remainder) + 32'h00000001);
    end
  end

  assign when_MulDiv_l226 = (when_MulDiv_l230 != _zz_when_MulDiv_l226);
  assign _zz_MulDiv_remainder_1 = {MulDiv_remainder[30 : 0],MulDiv_quotient[31]};
  assign when_MulDiv_l244 = (_zz_MulDiv_remainder <= _zz_MulDiv_remainder_1);
  always @(*) begin
    if(when_MulDiv_l244) begin
      _zz_MulDiv_quotient = 1'b1;
    end else begin
      _zz_MulDiv_quotient = 1'b0;
    end
  end

  always @(*) begin
    _out_default_RS2_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_RS2_DATA = in_RS2_DATA;
  end

  assign out_RS2_DATA = _out_default_RS2_DATA;
  always @(*) begin
    _out_default_RS1 = 5'bxxxxx;
    _out_default_RS1 = in_RS1;
  end

  assign out_RS1 = _out_default_RS1;
  always @(*) begin
    _out_default_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_PC = in_PC;
  end

  assign out_PC = _out_default_PC;
  always @(*) begin
    _out_default_MRET = 1'bx;
    _out_default_MRET = in_MRET;
  end

  assign out_MRET = _out_default_MRET;
  always @(*) begin
    _out_default_RS2_TYPE = (1'bx);
    _out_default_RS2_TYPE = in_RS2_TYPE;
  end

  assign out_RS2_TYPE = _out_default_RS2_TYPE;
  always @(*) begin
    _out_default_RD_TYPE = (1'bx);
    _out_default_RD_TYPE = in_RD_TYPE;
  end

  assign out_RD_TYPE = _out_default_RD_TYPE;
  always @(*) begin
    _out_default_LSU_IS_UNSIGNED = 1'bx;
    _out_default_LSU_IS_UNSIGNED = in_LSU_IS_UNSIGNED;
  end

  assign out_LSU_IS_UNSIGNED = _out_default_LSU_IS_UNSIGNED;
  always @(*) begin
    _out_default_RD = 5'bxxxxx;
    _out_default_RD = in_RD;
  end

  assign out_RD = _out_default_RD;
  always @(*) begin
    _out_default_RS1_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_RS1_DATA = in_RS1_DATA;
  end

  assign out_RS1_DATA = _out_default_RS1_DATA;
  always @(*) begin
    _out_default_LSU_OPERATION_TYPE = (2'bxx);
    _out_default_LSU_OPERATION_TYPE = in_LSU_OPERATION_TYPE;
  end

  assign out_LSU_OPERATION_TYPE = _out_default_LSU_OPERATION_TYPE;
  always @(*) begin
    _out_default_LSU_ACCESS_WIDTH = (2'bxx);
    _out_default_LSU_ACCESS_WIDTH = in_LSU_ACCESS_WIDTH;
  end

  assign out_LSU_ACCESS_WIDTH = _out_default_LSU_ACCESS_WIDTH;
  always @(*) begin
    _out_default_CSR_OP = (2'bxx);
    _out_default_CSR_OP = in_CSR_OP;
  end

  assign out_CSR_OP = _out_default_CSR_OP;
  always @(*) begin
    _out_default_RS2 = 5'bxxxxx;
    _out_default_RS2 = in_RS2;
  end

  assign out_RS2 = _out_default_RS2;
  always @(*) begin
    _out_default_IR = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_IR = in_IR;
  end

  assign out_IR = _out_default_IR;
  always @(*) begin
    _out_default_RS1_TYPE = (1'bx);
    _out_default_RS1_TYPE = in_RS1_TYPE;
  end

  assign out_RS1_TYPE = _out_default_RS1_TYPE;
  always @(*) begin
    _out_default_LSU_TARGET_VALID = 1'bx;
    _out_default_LSU_TARGET_VALID = in_LSU_TARGET_VALID;
  end

  assign out_LSU_TARGET_VALID = _out_default_LSU_TARGET_VALID;
  always @(*) begin
    _out_default_CSR_USE_IMM = 1'bx;
    _out_default_CSR_USE_IMM = in_CSR_USE_IMM;
  end

  assign out_CSR_USE_IMM = _out_default_CSR_USE_IMM;
  assign value_RS2_DATA = out_RS2_DATA;
  assign value_MUL = in_MUL;
  assign value_BU_IS_BRANCH = in_BU_IS_BRANCH;
  assign value_PC = out_PC;
  assign value_SHIFT_OP = in_SHIFT_OP;
  assign value_ECALL = in_ECALL;
  assign value_MULDIV_RS2_SIGNED = in_MULDIV_RS2_SIGNED;
  assign value_BU_CONDITION = in_BU_CONDITION;
  assign value_TRAP_CAUSE = out_TRAP_CAUSE;
  assign value_MRET = out_MRET;
  assign value_TRAP_VAL = out_TRAP_VAL;
  assign value_DIV = in_DIV;
  assign value_HAS_TRAPPED = out_HAS_TRAPPED;
  assign value_TRAP_IS_INTERRUPT = out_TRAP_IS_INTERRUPT;
  assign value_RS1_DATA = out_RS1_DATA;
  assign value_CONDITION_OP = in_CONDITION_OP;
  assign value_REM = in_REM;
  assign value_BU_WRITE_RET_ADDR_TO_RD = in_BU_WRITE_RET_ADDR_TO_RD;
  assign value_ALU_SRC1 = in_ALU_SRC1;
  assign value_ALU_OP = in_ALU_OP;
  assign value_IMM_USED = in_IMM_USED;
  assign value_IMM = in_IMM;
  assign value_ALU_RESULT = out_ALU_RESULT;
  assign value_EBREAK = in_EBREAK;
  assign value_ALU_SRC2 = in_ALU_SRC2;
  assign value_MULDIV_RS1_SIGNED = in_MULDIV_RS1_SIGNED;
  assign value_BU_IGNORE_TARGET_LSB = in_BU_IGNORE_TARGET_LSB;
  assign value_ALU_COMMIT_RESULT = in_ALU_COMMIT_RESULT;
  assign value_MUL_HIGH = in_MUL_HIGH;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      MulDiv_initMul <= 1'b1;
      MulDiv_step_value <= 6'h0;
      MulDiv_quotient <= 32'h0;
      MulDiv_remainder <= 32'h0;
      MulDiv_initDiv <= 1'b1;
      MulDiv_step_value_1 <= 6'h0;
    end else begin
      MulDiv_step_value <= MulDiv_step_valueNext;
      if(when_MulDiv_l104) begin
        MulDiv_initMul <= 1'b1;
      end
      if(when_MulDiv_l113) begin
        if(MulDiv_initMul) begin
          MulDiv_initMul <= 1'b0;
        end else begin
          if(MulDiv_step_willOverflowIfInc) begin
            MulDiv_initMul <= 1'b1;
          end
        end
      end
      MulDiv_step_value_1 <= MulDiv_step_valueNext_1;
      if(when_MulDiv_l191) begin
        MulDiv_initDiv <= 1'b1;
      end
      if(when_MulDiv_l200) begin
        if(!when_MulDiv_l211) begin
          if(MulDiv_initDiv) begin
            MulDiv_quotient <= (when_MulDiv_l230 ? _zz_MulDiv_quotient_1 : value_RS1_DATA);
            MulDiv_remainder <= 32'h0;
            MulDiv_initDiv <= 1'b0;
          end else begin
            if(MulDiv_step_willOverflowIfInc_1) begin
              MulDiv_initDiv <= 1'b1;
            end else begin
              if(when_MulDiv_l244) begin
                MulDiv_remainder <= (_zz_MulDiv_remainder_1 - _zz_MulDiv_remainder);
              end else begin
                MulDiv_remainder <= _zz_MulDiv_remainder_1;
              end
              MulDiv_quotient <= {MulDiv_quotient[30 : 0],_zz_MulDiv_quotient};
            end
          end
        end
      end
    end
  end

  always @(posedge clk) begin
    if(when_MulDiv_l113) begin
      if(MulDiv_initMul) begin
        MulDiv_product[63 : 32] <= 32'h0;
        MulDiv_product[31 : 0] <= MulDiv_multiplier;
      end else begin
        if(!MulDiv_step_willOverflowIfInc) begin
          MulDiv_product <= {_zz_MulDiv_product_3,MulDiv_product[31 : 1]};
        end
      end
    end
  end


endmodule

module Stage_ID (
  input  wire          arbitration_isValid,
  input  wire          arbitration_isStalled,
  output wire          arbitration_isReady,
  output wire          arbitration_isDone,
  output wire          arbitration_rs1Needed,
  output wire          arbitration_rs2Needed,
  output wire          arbitration_jumpRequested,
  output wire          arbitration_isAvailable,
  output reg           out_BU_IS_BRANCH,
  output reg           out_CSR_USE_IMM,
  output reg           out_MULDIV_RS2_SIGNED,
  output reg  [31:0]   out_IMM,
  output reg           out_BU_IGNORE_TARGET_LSB,
  output reg           out_EBREAK,
  output reg           out_MUL,
  output reg           out_RD_DATA_VALID,
  output reg           out_LSU_IS_EXTERNAL_OP,
  output reg           out_BU_WRITE_RET_ADDR_TO_RD,
  output reg           out_LSU_IS_UNSIGNED,
  output reg  [1:0]    out_CSR_OP,
  output reg           out_ECALL,
  output reg           out_MUL_HIGH,
  output reg  [1:0]    out_CONDITION_OP,
  output reg           out_REM,
  output reg           out_ALU_COMMIT_RESULT,
  output reg  [1:0]    out_LSU_OPERATION_TYPE,
  output reg  [2:0]    out_BU_CONDITION,
  output reg  [1:0]    out_SHIFT_OP,
  output reg           out_MRET,
  output reg           out_DIV,
  output reg  [0:0]    out_ALU_SRC1,
  output reg           out_MULDIV_RS1_SIGNED,
  output reg  [4:0]    out_RS1,
  output reg  [4:0]    out_RS2,
  output reg  [4:0]    out_RD,
  output reg           out_IMM_USED,
  output reg  [0:0]    out_RS1_TYPE,
  output reg  [0:0]    out_RS2_TYPE,
  output reg  [0:0]    out_RD_TYPE,
  output reg  [2:0]    out_ALU_OP,
  output reg  [0:0]    out_ALU_SRC2,
  output reg           out_LSU_TARGET_VALID,
  output reg  [1:0]    out_LSU_ACCESS_WIDTH,
  output wire [4:0]    RegisterFileAccessor_regFileIo_rs1,
  output wire [4:0]    RegisterFileAccessor_regFileIo_rs2,
  input  wire [31:0]   RegisterFileAccessor_regFileIo_rs1Data,
  input  wire [31:0]   RegisterFileAccessor_regFileIo_rs2Data,
  output reg  [31:0]   out_RS1_DATA,
  output reg  [31:0]   out_RS2_DATA,
  output reg           out_HAS_TRAPPED,
  output reg           out_TRAP_IS_INTERRUPT,
  output reg  [3:0]    out_TRAP_CAUSE,
  output reg  [31:0]   out_TRAP_VAL,
  input  wire [31:0]   in_IR,
  input  wire [31:0]   in_PC,
  output wire [31:0]   out_PC,
  input  wire [3:0]    in_TRAP_CAUSE,
  input  wire [31:0]   in_TRAP_VAL,
  input  wire          in_HAS_TRAPPED,
  input  wire          in_TRAP_IS_INTERRUPT,
  output wire [31:0]   out_IR,
  input  wire [31:0]   in_NEXT_PC,
  output wire [31:0]   out_NEXT_PC,
  input  wire [31:0]   in_PREDICTED_PC,
  output wire [31:0]   out_PREDICTED_PC
);
  localparam LsuAccessWidth_B = 2'd0;
  localparam LsuAccessWidth_H = 2'd1;
  localparam LsuAccessWidth_W = 2'd2;
  localparam Src2Select_RS2 = 1'd0;
  localparam Src2Select_IMM = 1'd1;
  localparam AluOp_ADD = 3'd0;
  localparam AluOp_SUB = 3'd1;
  localparam AluOp_SLT = 3'd2;
  localparam AluOp_SLTU = 3'd3;
  localparam AluOp_XOR_1 = 3'd4;
  localparam AluOp_OR_1 = 3'd5;
  localparam AluOp_AND_1 = 3'd6;
  localparam AluOp_SRC2 = 3'd7;
  localparam RegisterType_NONE = 1'd0;
  localparam RegisterType_GPR = 1'd1;
  localparam Src1Select_RS1 = 1'd0;
  localparam Src1Select_PC = 1'd1;
  localparam ShiftOp_NONE = 2'd0;
  localparam ShiftOp_SLL_1 = 2'd1;
  localparam ShiftOp_SRL_1 = 2'd2;
  localparam ShiftOp_SRA_1 = 2'd3;
  localparam BranchCondition_NONE = 3'd0;
  localparam BranchCondition_EQ = 3'd1;
  localparam BranchCondition_NE = 3'd2;
  localparam BranchCondition_LT = 3'd3;
  localparam BranchCondition_GE = 3'd4;
  localparam BranchCondition_LTU = 3'd5;
  localparam BranchCondition_GEU = 3'd6;
  localparam LsuOperationType_NONE = 2'd0;
  localparam LsuOperationType_LOAD = 2'd1;
  localparam LsuOperationType_STORE = 2'd2;
  localparam ConditionOp_NONE = 2'd0;
  localparam ConditionOp_EQZ = 2'd1;
  localparam ConditionOp_NEZ = 2'd2;
  localparam CsrOp_NONE = 2'd0;
  localparam CsrOp_RW = 2'd1;
  localparam CsrOp_RS = 2'd2;
  localparam CsrOp_RC = 2'd3;

  wire       [31:0]   _zz_out_IMM_103;
  wire       [31:0]   _zz_out_IMM_104;
  reg        [31:0]   _out_default_TRAP_VAL;
  reg        [3:0]    _out_default_TRAP_CAUSE;
  reg                 _out_default_TRAP_IS_INTERRUPT;
  reg                 _out_default_HAS_TRAPPED;
  wire       [31:0]   _out_default_RS2_DATA;
  wire       [31:0]   _out_default_RS1_DATA;
  wire       [1:0]    _out_default_LSU_ACCESS_WIDTH;
  wire                _out_default_LSU_TARGET_VALID;
  wire       [0:0]    _out_default_ALU_SRC2;
  wire       [2:0]    _out_default_ALU_OP;
  wire       [0:0]    _out_default_RD_TYPE;
  wire       [0:0]    _out_default_RS2_TYPE;
  wire       [0:0]    _out_default_RS1_TYPE;
  wire                _out_default_IMM_USED;
  wire       [4:0]    _out_default_RD;
  wire       [4:0]    _out_default_RS2;
  wire       [4:0]    _out_default_RS1;
  wire                _out_default_MULDIV_RS1_SIGNED;
  wire       [0:0]    _out_default_ALU_SRC1;
  wire                _out_default_DIV;
  wire                _out_default_MRET;
  wire       [1:0]    _out_default_SHIFT_OP;
  wire       [2:0]    _out_default_BU_CONDITION;
  wire       [1:0]    _out_default_LSU_OPERATION_TYPE;
  wire                _out_default_ALU_COMMIT_RESULT;
  wire                _out_default_REM;
  wire       [1:0]    _out_default_CONDITION_OP;
  wire                _out_default_MUL_HIGH;
  wire                _out_default_ECALL;
  wire       [1:0]    _out_default_CSR_OP;
  wire                _out_default_LSU_IS_UNSIGNED;
  wire                _out_default_BU_WRITE_RET_ADDR_TO_RD;
  wire                _out_default_LSU_IS_EXTERNAL_OP;
  wire                _out_default_RD_DATA_VALID;
  wire                _out_default_MUL;
  wire                _out_default_EBREAK;
  wire                _out_default_BU_IGNORE_TARGET_LSB;
  wire       [31:0]   _out_default_IMM;
  wire                _out_default_MULDIV_RS2_SIGNED;
  wire                _out_default_CSR_USE_IMM;
  wire                _out_default_BU_IS_BRANCH;
  wire                TrapHandler_interruptSignals_hasTrapped;
  wire       [3:0]    TrapHandler_interruptSignals_trapCause;
  wire       [31:0]   TrapHandler_interruptSignals_trapVal;
  reg                 TrapHandler_exceptionSignals_hasTrapped;
  reg        [3:0]    TrapHandler_exceptionSignals_trapCause;
  reg        [31:0]   TrapHandler_exceptionSignals_trapVal;
  wire       [31:0]   value_IR;
  wire       [31:0]   _zz_out_IMM;
  wire       [11:0]   _zz_out_IMM_1;
  wire                _zz_out_IMM_2;
  reg        [19:0]   _zz_out_IMM_3;
  wire       [11:0]   _zz_out_IMM_4;
  wire                _zz_out_IMM_5;
  reg        [19:0]   _zz_out_IMM_6;
  wire       [11:0]   _zz_out_IMM_7;
  wire                _zz_out_IMM_8;
  reg        [19:0]   _zz_out_IMM_9;
  wire       [11:0]   _zz_out_IMM_10;
  wire                _zz_out_IMM_11;
  reg        [19:0]   _zz_out_IMM_12;
  wire       [12:0]   _zz_out_IMM_13;
  wire                _zz_out_IMM_14;
  reg        [18:0]   _zz_out_IMM_15;
  wire       [11:0]   _zz_out_IMM_16;
  wire                _zz_out_IMM_17;
  reg        [19:0]   _zz_out_IMM_18;
  wire       [11:0]   _zz_out_IMM_19;
  wire                _zz_out_IMM_20;
  reg        [19:0]   _zz_out_IMM_21;
  wire       [12:0]   _zz_out_IMM_22;
  wire                _zz_out_IMM_23;
  reg        [18:0]   _zz_out_IMM_24;
  wire       [11:0]   _zz_out_IMM_25;
  wire                _zz_out_IMM_26;
  reg        [19:0]   _zz_out_IMM_27;
  wire       [11:0]   _zz_out_IMM_28;
  wire                _zz_out_IMM_29;
  reg        [19:0]   _zz_out_IMM_30;
  wire       [11:0]   _zz_out_IMM_31;
  wire                _zz_out_IMM_32;
  reg        [19:0]   _zz_out_IMM_33;
  wire       [11:0]   _zz_out_IMM_34;
  wire                _zz_out_IMM_35;
  reg        [19:0]   _zz_out_IMM_36;
  wire       [11:0]   _zz_out_IMM_37;
  wire                _zz_out_IMM_38;
  reg        [19:0]   _zz_out_IMM_39;
  wire       [12:0]   _zz_out_IMM_40;
  wire                _zz_out_IMM_41;
  reg        [18:0]   _zz_out_IMM_42;
  wire       [11:0]   _zz_out_IMM_43;
  wire                _zz_out_IMM_44;
  reg        [19:0]   _zz_out_IMM_45;
  wire       [11:0]   _zz_out_IMM_46;
  wire                _zz_out_IMM_47;
  reg        [19:0]   _zz_out_IMM_48;
  wire       [11:0]   _zz_out_IMM_49;
  wire                _zz_out_IMM_50;
  reg        [19:0]   _zz_out_IMM_51;
  wire       [12:0]   _zz_out_IMM_52;
  wire                _zz_out_IMM_53;
  reg        [18:0]   _zz_out_IMM_54;
  wire       [20:0]   _zz_out_IMM_55;
  wire                _zz_out_IMM_56;
  reg        [10:0]   _zz_out_IMM_57;
  wire       [11:0]   _zz_out_IMM_58;
  wire                _zz_out_IMM_59;
  reg        [19:0]   _zz_out_IMM_60;
  wire       [11:0]   _zz_out_IMM_61;
  wire                _zz_out_IMM_62;
  reg        [19:0]   _zz_out_IMM_63;
  wire       [11:0]   _zz_out_IMM_64;
  wire                _zz_out_IMM_65;
  reg        [19:0]   _zz_out_IMM_66;
  wire       [11:0]   _zz_out_IMM_67;
  wire                _zz_out_IMM_68;
  reg        [19:0]   _zz_out_IMM_69;
  wire       [12:0]   _zz_out_IMM_70;
  wire                _zz_out_IMM_71;
  reg        [18:0]   _zz_out_IMM_72;
  wire       [11:0]   _zz_out_IMM_73;
  wire                _zz_out_IMM_74;
  reg        [19:0]   _zz_out_IMM_75;
  wire       [11:0]   _zz_out_IMM_76;
  wire                _zz_out_IMM_77;
  reg        [19:0]   _zz_out_IMM_78;
  wire       [12:0]   _zz_out_IMM_79;
  wire                _zz_out_IMM_80;
  reg        [18:0]   _zz_out_IMM_81;
  wire       [11:0]   _zz_out_IMM_82;
  wire                _zz_out_IMM_83;
  reg        [19:0]   _zz_out_IMM_84;
  wire       [11:0]   _zz_out_IMM_85;
  wire                _zz_out_IMM_86;
  reg        [19:0]   _zz_out_IMM_87;
  wire       [11:0]   _zz_out_IMM_88;
  wire                _zz_out_IMM_89;
  reg        [19:0]   _zz_out_IMM_90;
  wire       [11:0]   _zz_out_IMM_91;
  wire                _zz_out_IMM_92;
  reg        [19:0]   _zz_out_IMM_93;
  wire       [11:0]   _zz_out_IMM_94;
  wire                _zz_out_IMM_95;
  reg        [19:0]   _zz_out_IMM_96;
  wire       [11:0]   _zz_out_IMM_97;
  wire                _zz_out_IMM_98;
  reg        [19:0]   _zz_out_IMM_99;
  wire       [11:0]   _zz_out_IMM_100;
  wire                _zz_out_IMM_101;
  reg        [19:0]   _zz_out_IMM_102;
  wire       [4:0]    value_RS1;
  wire       [4:0]    value_RS2;
  reg                 TrapHandler_trapSignals_hasTrapped;
  reg        [3:0]    TrapHandler_trapSignals_trapCause;
  reg        [31:0]   TrapHandler_trapSignals_trapVal;
  reg                 TrapHandler_isInterrupt;
  reg        [31:0]   _out_default_PC;
  reg        [31:0]   _out_default_IR;
  reg        [31:0]   _out_default_NEXT_PC;
  reg        [31:0]   _out_default_PREDICTED_PC;
  `ifndef SYNTHESIS
  reg [7:0] out_LSU_ACCESS_WIDTH_string;
  reg [7:0] _out_default_LSU_ACCESS_WIDTH_string;
  reg [23:0] out_ALU_SRC2_string;
  reg [23:0] _out_default_ALU_SRC2_string;
  reg [39:0] out_ALU_OP_string;
  reg [39:0] _out_default_ALU_OP_string;
  reg [31:0] out_RD_TYPE_string;
  reg [31:0] _out_default_RD_TYPE_string;
  reg [31:0] out_RS2_TYPE_string;
  reg [31:0] _out_default_RS2_TYPE_string;
  reg [31:0] out_RS1_TYPE_string;
  reg [31:0] _out_default_RS1_TYPE_string;
  reg [23:0] out_ALU_SRC1_string;
  reg [23:0] _out_default_ALU_SRC1_string;
  reg [39:0] out_SHIFT_OP_string;
  reg [39:0] _out_default_SHIFT_OP_string;
  reg [31:0] out_BU_CONDITION_string;
  reg [31:0] _out_default_BU_CONDITION_string;
  reg [39:0] out_LSU_OPERATION_TYPE_string;
  reg [39:0] _out_default_LSU_OPERATION_TYPE_string;
  reg [31:0] out_CONDITION_OP_string;
  reg [31:0] _out_default_CONDITION_OP_string;
  reg [31:0] out_CSR_OP_string;
  reg [31:0] _out_default_CSR_OP_string;
  `endif


  assign _zz_out_IMM_103 = ({12'd0,_zz_out_IMM[31 : 12]} <<< 4'd12);
  assign _zz_out_IMM_104 = ({12'd0,_zz_out_IMM[31 : 12]} <<< 4'd12);
  `ifndef SYNTHESIS
  always @(*) begin
    case(out_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : out_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : out_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : out_LSU_ACCESS_WIDTH_string = "W";
      default : out_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(_out_default_LSU_ACCESS_WIDTH)
      LsuAccessWidth_B : _out_default_LSU_ACCESS_WIDTH_string = "B";
      LsuAccessWidth_H : _out_default_LSU_ACCESS_WIDTH_string = "H";
      LsuAccessWidth_W : _out_default_LSU_ACCESS_WIDTH_string = "W";
      default : _out_default_LSU_ACCESS_WIDTH_string = "?";
    endcase
  end
  always @(*) begin
    case(out_ALU_SRC2)
      Src2Select_RS2 : out_ALU_SRC2_string = "RS2";
      Src2Select_IMM : out_ALU_SRC2_string = "IMM";
      default : out_ALU_SRC2_string = "???";
    endcase
  end
  always @(*) begin
    case(_out_default_ALU_SRC2)
      Src2Select_RS2 : _out_default_ALU_SRC2_string = "RS2";
      Src2Select_IMM : _out_default_ALU_SRC2_string = "IMM";
      default : _out_default_ALU_SRC2_string = "???";
    endcase
  end
  always @(*) begin
    case(out_ALU_OP)
      AluOp_ADD : out_ALU_OP_string = "ADD  ";
      AluOp_SUB : out_ALU_OP_string = "SUB  ";
      AluOp_SLT : out_ALU_OP_string = "SLT  ";
      AluOp_SLTU : out_ALU_OP_string = "SLTU ";
      AluOp_XOR_1 : out_ALU_OP_string = "XOR_1";
      AluOp_OR_1 : out_ALU_OP_string = "OR_1 ";
      AluOp_AND_1 : out_ALU_OP_string = "AND_1";
      AluOp_SRC2 : out_ALU_OP_string = "SRC2 ";
      default : out_ALU_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(_out_default_ALU_OP)
      AluOp_ADD : _out_default_ALU_OP_string = "ADD  ";
      AluOp_SUB : _out_default_ALU_OP_string = "SUB  ";
      AluOp_SLT : _out_default_ALU_OP_string = "SLT  ";
      AluOp_SLTU : _out_default_ALU_OP_string = "SLTU ";
      AluOp_XOR_1 : _out_default_ALU_OP_string = "XOR_1";
      AluOp_OR_1 : _out_default_ALU_OP_string = "OR_1 ";
      AluOp_AND_1 : _out_default_ALU_OP_string = "AND_1";
      AluOp_SRC2 : _out_default_ALU_OP_string = "SRC2 ";
      default : _out_default_ALU_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(out_RD_TYPE)
      RegisterType_NONE : out_RD_TYPE_string = "NONE";
      RegisterType_GPR : out_RD_TYPE_string = "GPR ";
      default : out_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RD_TYPE)
      RegisterType_NONE : _out_default_RD_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RD_TYPE_string = "GPR ";
      default : _out_default_RD_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS2_TYPE)
      RegisterType_NONE : out_RS2_TYPE_string = "NONE";
      RegisterType_GPR : out_RS2_TYPE_string = "GPR ";
      default : out_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RS2_TYPE)
      RegisterType_NONE : _out_default_RS2_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RS2_TYPE_string = "GPR ";
      default : _out_default_RS2_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_RS1_TYPE)
      RegisterType_NONE : out_RS1_TYPE_string = "NONE";
      RegisterType_GPR : out_RS1_TYPE_string = "GPR ";
      default : out_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_RS1_TYPE)
      RegisterType_NONE : _out_default_RS1_TYPE_string = "NONE";
      RegisterType_GPR : _out_default_RS1_TYPE_string = "GPR ";
      default : _out_default_RS1_TYPE_string = "????";
    endcase
  end
  always @(*) begin
    case(out_ALU_SRC1)
      Src1Select_RS1 : out_ALU_SRC1_string = "RS1";
      Src1Select_PC : out_ALU_SRC1_string = "PC ";
      default : out_ALU_SRC1_string = "???";
    endcase
  end
  always @(*) begin
    case(_out_default_ALU_SRC1)
      Src1Select_RS1 : _out_default_ALU_SRC1_string = "RS1";
      Src1Select_PC : _out_default_ALU_SRC1_string = "PC ";
      default : _out_default_ALU_SRC1_string = "???";
    endcase
  end
  always @(*) begin
    case(out_SHIFT_OP)
      ShiftOp_NONE : out_SHIFT_OP_string = "NONE ";
      ShiftOp_SLL_1 : out_SHIFT_OP_string = "SLL_1";
      ShiftOp_SRL_1 : out_SHIFT_OP_string = "SRL_1";
      ShiftOp_SRA_1 : out_SHIFT_OP_string = "SRA_1";
      default : out_SHIFT_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(_out_default_SHIFT_OP)
      ShiftOp_NONE : _out_default_SHIFT_OP_string = "NONE ";
      ShiftOp_SLL_1 : _out_default_SHIFT_OP_string = "SLL_1";
      ShiftOp_SRL_1 : _out_default_SHIFT_OP_string = "SRL_1";
      ShiftOp_SRA_1 : _out_default_SHIFT_OP_string = "SRA_1";
      default : _out_default_SHIFT_OP_string = "?????";
    endcase
  end
  always @(*) begin
    case(out_BU_CONDITION)
      BranchCondition_NONE : out_BU_CONDITION_string = "NONE";
      BranchCondition_EQ : out_BU_CONDITION_string = "EQ  ";
      BranchCondition_NE : out_BU_CONDITION_string = "NE  ";
      BranchCondition_LT : out_BU_CONDITION_string = "LT  ";
      BranchCondition_GE : out_BU_CONDITION_string = "GE  ";
      BranchCondition_LTU : out_BU_CONDITION_string = "LTU ";
      BranchCondition_GEU : out_BU_CONDITION_string = "GEU ";
      default : out_BU_CONDITION_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_BU_CONDITION)
      BranchCondition_NONE : _out_default_BU_CONDITION_string = "NONE";
      BranchCondition_EQ : _out_default_BU_CONDITION_string = "EQ  ";
      BranchCondition_NE : _out_default_BU_CONDITION_string = "NE  ";
      BranchCondition_LT : _out_default_BU_CONDITION_string = "LT  ";
      BranchCondition_GE : _out_default_BU_CONDITION_string = "GE  ";
      BranchCondition_LTU : _out_default_BU_CONDITION_string = "LTU ";
      BranchCondition_GEU : _out_default_BU_CONDITION_string = "GEU ";
      default : _out_default_BU_CONDITION_string = "????";
    endcase
  end
  always @(*) begin
    case(out_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : out_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : out_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : out_LSU_OPERATION_TYPE_string = "STORE";
      default : out_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(_out_default_LSU_OPERATION_TYPE)
      LsuOperationType_NONE : _out_default_LSU_OPERATION_TYPE_string = "NONE ";
      LsuOperationType_LOAD : _out_default_LSU_OPERATION_TYPE_string = "LOAD ";
      LsuOperationType_STORE : _out_default_LSU_OPERATION_TYPE_string = "STORE";
      default : _out_default_LSU_OPERATION_TYPE_string = "?????";
    endcase
  end
  always @(*) begin
    case(out_CONDITION_OP)
      ConditionOp_NONE : out_CONDITION_OP_string = "NONE";
      ConditionOp_EQZ : out_CONDITION_OP_string = "EQZ ";
      ConditionOp_NEZ : out_CONDITION_OP_string = "NEZ ";
      default : out_CONDITION_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_CONDITION_OP)
      ConditionOp_NONE : _out_default_CONDITION_OP_string = "NONE";
      ConditionOp_EQZ : _out_default_CONDITION_OP_string = "EQZ ";
      ConditionOp_NEZ : _out_default_CONDITION_OP_string = "NEZ ";
      default : _out_default_CONDITION_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(out_CSR_OP)
      CsrOp_NONE : out_CSR_OP_string = "NONE";
      CsrOp_RW : out_CSR_OP_string = "RW  ";
      CsrOp_RS : out_CSR_OP_string = "RS  ";
      CsrOp_RC : out_CSR_OP_string = "RC  ";
      default : out_CSR_OP_string = "????";
    endcase
  end
  always @(*) begin
    case(_out_default_CSR_OP)
      CsrOp_NONE : _out_default_CSR_OP_string = "NONE";
      CsrOp_RW : _out_default_CSR_OP_string = "RW  ";
      CsrOp_RS : _out_default_CSR_OP_string = "RS  ";
      CsrOp_RC : _out_default_CSR_OP_string = "RC  ";
      default : _out_default_CSR_OP_string = "????";
    endcase
  end
  `endif

  always @(*) begin
    _out_default_TRAP_VAL = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_TRAP_VAL = in_TRAP_VAL;
  end

  always @(*) begin
    out_TRAP_VAL = _out_default_TRAP_VAL;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_VAL = TrapHandler_trapSignals_trapVal;
    end
  end

  always @(*) begin
    _out_default_TRAP_CAUSE = 4'bxxxx;
    _out_default_TRAP_CAUSE = in_TRAP_CAUSE;
  end

  always @(*) begin
    out_TRAP_CAUSE = _out_default_TRAP_CAUSE;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_CAUSE = TrapHandler_trapSignals_trapCause;
    end
  end

  always @(*) begin
    _out_default_TRAP_IS_INTERRUPT = 1'bx;
    _out_default_TRAP_IS_INTERRUPT = in_TRAP_IS_INTERRUPT;
  end

  always @(*) begin
    out_TRAP_IS_INTERRUPT = _out_default_TRAP_IS_INTERRUPT;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_IS_INTERRUPT = TrapHandler_isInterrupt;
    end
  end

  always @(*) begin
    _out_default_HAS_TRAPPED = 1'bx;
    _out_default_HAS_TRAPPED = in_HAS_TRAPPED;
  end

  always @(*) begin
    out_HAS_TRAPPED = _out_default_HAS_TRAPPED;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_HAS_TRAPPED = 1'b1;
    end
  end

  assign _out_default_RS2_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_RS2_DATA = _out_default_RS2_DATA;
    out_RS2_DATA = RegisterFileAccessor_regFileIo_rs2Data;
  end

  assign _out_default_RS1_DATA = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_RS1_DATA = _out_default_RS1_DATA;
    out_RS1_DATA = RegisterFileAccessor_regFileIo_rs1Data;
  end

  assign _out_default_LSU_ACCESS_WIDTH = (2'bxx);
  always @(*) begin
    out_LSU_ACCESS_WIDTH = _out_default_LSU_ACCESS_WIDTH;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
        out_LSU_ACCESS_WIDTH = LsuAccessWidth_W;
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
        out_LSU_ACCESS_WIDTH = LsuAccessWidth_H;
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
        out_LSU_ACCESS_WIDTH = LsuAccessWidth_B;
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
        out_LSU_ACCESS_WIDTH = LsuAccessWidth_W;
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
        out_LSU_ACCESS_WIDTH = LsuAccessWidth_H;
      end
      32'b?????????????????000?????0100011 : begin
        out_LSU_ACCESS_WIDTH = LsuAccessWidth_B;
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
        out_LSU_ACCESS_WIDTH = LsuAccessWidth_H;
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
        out_LSU_ACCESS_WIDTH = LsuAccessWidth_B;
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_LSU_TARGET_VALID = 1'bx;
  always @(*) begin
    out_LSU_TARGET_VALID = _out_default_LSU_TARGET_VALID;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
        out_LSU_TARGET_VALID = 1'b0;
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
        out_LSU_TARGET_VALID = 1'b0;
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
        out_LSU_TARGET_VALID = 1'b0;
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
        out_LSU_TARGET_VALID = 1'b0;
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
        out_LSU_TARGET_VALID = 1'b0;
      end
      32'b?????????????????000?????0100011 : begin
        out_LSU_TARGET_VALID = 1'b0;
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
        out_LSU_TARGET_VALID = 1'b0;
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
        out_LSU_TARGET_VALID = 1'b0;
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_ALU_SRC2 = (1'bx);
  always @(*) begin
    out_ALU_SRC2 = _out_default_ALU_SRC2;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000000??????????111?????0110011 : begin
        out_ALU_SRC2 = Src2Select_RS2;
      end
      32'b?????????????????000?????0010011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000000??????????010?????0110011 : begin
        out_ALU_SRC2 = Src2Select_RS2;
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????011?????0010011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????101?????1100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????000?????0000011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????110?????0010011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????110?????1100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????100?????0010011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0100000??????????000?????0110011 : begin
        out_ALU_SRC2 = Src2Select_RS2;
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
        out_ALU_SRC2 = Src2Select_RS2;
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????????????1101111 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000000??????????011?????0110011 : begin
        out_ALU_SRC2 = Src2Select_RS2;
      end
      32'b?????????????????111?????0010011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????000?????0100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
        out_ALU_SRC2 = Src2Select_RS2;
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
        out_ALU_SRC2 = Src2Select_RS2;
      end
      32'b?????????????????001?????0100011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
        out_ALU_SRC2 = Src2Select_IMM;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_ALU_OP = (3'bxxx);
  always @(*) begin
    out_ALU_OP = _out_default_ALU_OP;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0000000??????????111?????0110011 : begin
        out_ALU_OP = AluOp_AND_1;
      end
      32'b?????????????????000?????0010011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0000000??????????010?????0110011 : begin
        out_ALU_OP = AluOp_SLT;
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????011?????0010011 : begin
        out_ALU_OP = AluOp_SLTU;
      end
      32'b?????????????????101?????1100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????000?????0000011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
        out_ALU_OP = AluOp_SRC2;
      end
      32'b?????????????????110?????0010011 : begin
        out_ALU_OP = AluOp_OR_1;
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????110?????1100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????100?????0010011 : begin
        out_ALU_OP = AluOp_XOR_1;
      end
      32'b0100000??????????000?????0110011 : begin
        out_ALU_OP = AluOp_SUB;
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????????????1101111 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0000000??????????011?????0110011 : begin
        out_ALU_OP = AluOp_SLTU;
      end
      32'b?????????????????111?????0010011 : begin
        out_ALU_OP = AluOp_AND_1;
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b?????????????????000?????0100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
        out_ALU_OP = AluOp_SLT;
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
        out_ALU_OP = AluOp_OR_1;
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
        out_ALU_OP = AluOp_XOR_1;
      end
      32'b?????????????????001?????0100011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
        out_ALU_OP = AluOp_ADD;
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
        out_ALU_OP = AluOp_ADD;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_RD_TYPE = (1'bx);
  always @(*) begin
    out_RD_TYPE = _out_default_RD_TYPE;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b00000000000000000000000001110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????????????0010111 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????111?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????010?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????101?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????0000011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????011?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????101?????1100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b0000111??????????111?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0100000??????????101?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????101?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????101?????0000011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????110?????1110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????1100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b?????????????????000?????0000011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????1110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????????????0110111 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????110?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000111??????????101?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????000?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b00000000000100000000000001110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????0100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b?????????????????110?????1100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b?????????????????100?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0100000??????????000?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????001?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????011?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????000?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????1110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????1100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b?????????????????????????1101111 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????011?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????1110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????0000011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????0100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b0000001??????????110?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????100?????1100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b0000001??????????001?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????101?????1110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????110?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????001?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????1100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b0000001??????????100?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b00110000001000000000000001110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????100?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????0100011 : begin
        out_RD_TYPE = RegisterType_NONE;
      end
      32'b0100000??????????101?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????011?????1110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????111?????0110011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????100?????0000011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????101?????0010011 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????1100111 : begin
        out_RD_TYPE = RegisterType_GPR;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_RS2_TYPE = (1'bx);
  always @(*) begin
    out_RS2_TYPE = _out_default_RS2_TYPE;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b00000000000000000000000001110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????????????0010111 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000000??????????111?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000000??????????010?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????101?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????0000011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????011?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????101?????1100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000111??????????111?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0100000??????????101?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????101?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????101?????0000011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????110?????1110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????000?????1100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????0000011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????001?????1110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????????????0110111 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????110?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000111??????????101?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????000?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b00000000000100000000000001110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????010?????0100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????110?????1100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????100?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0100000??????????000?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????001?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000001??????????011?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????000?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????1110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????001?????1100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????????????1101111 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000000??????????011?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????010?????1110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????001?????0000011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????000?????0100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????110?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????100?????1100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????001?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????101?????1110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000000??????????110?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????001?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????1100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????100?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b00110000001000000000000001110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000000??????????100?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????0100011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b0100000??????????101?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????011?????1110011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000001??????????111?????0110011 : begin
        out_RS2_TYPE = RegisterType_GPR;
      end
      32'b?????????????????100?????0000011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b0000000??????????101?????0010011 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      32'b?????????????????000?????1100111 : begin
        out_RS2_TYPE = RegisterType_NONE;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_RS1_TYPE = (1'bx);
  always @(*) begin
    out_RS1_TYPE = _out_default_RS1_TYPE;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b00000000000000000000000001110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????????????0010111 : begin
        out_RS1_TYPE = RegisterType_NONE;
      end
      32'b0000000??????????111?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????010?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????101?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????0000011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????011?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????101?????1100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000111??????????111?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0100000??????????101?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????101?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????101?????0000011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????110?????1110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????1100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????0000011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????1110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????????????0110111 : begin
        out_RS1_TYPE = RegisterType_NONE;
      end
      32'b?????????????????110?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000111??????????101?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????000?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b00000000000100000000000001110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????0100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????110?????1100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????100?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0100000??????????000?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????001?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????011?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????000?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????1110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????1100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????????????1101111 : begin
        out_RS1_TYPE = RegisterType_NONE;
      end
      32'b0000000??????????011?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????1110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????0000011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????0100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????110?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????100?????1100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????001?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????010?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????101?????1110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????110?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????001?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????111?????1100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????100?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b00110000001000000000000001110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????100?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????001?????0100011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0100000??????????101?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????011?????1110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000001??????????111?????0110011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????100?????0000011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b0000000??????????101?????0010011 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      32'b?????????????????000?????1100111 : begin
        out_RS1_TYPE = RegisterType_GPR;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_IMM_USED = 1'bx;
  always @(*) begin
    out_IMM_USED = _out_default_IMM_USED;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b00000000000000000000000001110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????????????0010111 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000000??????????111?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????000?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000000??????????010?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b0000001??????????101?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????010?????0000011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????011?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????101?????1100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000111??????????111?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b0100000??????????101?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b0000000??????????101?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????101?????0000011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????110?????1110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????000?????1100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????000?????0000011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????001?????1110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????????????0110111 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????110?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000111??????????101?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b0000001??????????000?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b00000000000100000000000001110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????010?????0100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????110?????1100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????100?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0100000??????????000?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b0000000??????????001?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000001??????????011?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b0000000??????????000?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????111?????1110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????001?????1100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????????????1101111 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000000??????????011?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????111?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????010?????1110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????001?????0000011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????000?????0100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000001??????????110?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????100?????1100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000001??????????001?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????010?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????101?????1110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000000??????????110?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b0000000??????????001?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????111?????1100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000001??????????100?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b00110000001000000000000001110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000000??????????100?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????001?????0100011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0100000??????????101?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????011?????1110011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000001??????????111?????0110011 : begin
        out_IMM_USED = 1'b0;
      end
      32'b?????????????????100?????0000011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b0000000??????????101?????0010011 : begin
        out_IMM_USED = 1'b1;
      end
      32'b?????????????????000?????1100111 : begin
        out_IMM_USED = 1'b1;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_RD = 5'bxxxxx;
  always @(*) begin
    out_RD = _out_default_RD;
    out_RD = value_IR[11 : 7];
  end

  assign _out_default_RS2 = 5'bxxxxx;
  always @(*) begin
    out_RS2 = _out_default_RS2;
    out_RS2 = value_IR[24 : 20];
  end

  assign _out_default_RS1 = 5'bxxxxx;
  always @(*) begin
    out_RS1 = _out_default_RS1;
    out_RS1 = value_IR[19 : 15];
  end

  assign _out_default_MULDIV_RS1_SIGNED = 1'bx;
  always @(*) begin
    out_MULDIV_RS1_SIGNED = _out_default_MULDIV_RS1_SIGNED;
    out_MULDIV_RS1_SIGNED = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_MULDIV_RS1_SIGNED = 1'b1;
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
        out_MULDIV_RS1_SIGNED = 1'b0;
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
        out_MULDIV_RS1_SIGNED = 1'b1;
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
        out_MULDIV_RS1_SIGNED = 1'b0;
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
        out_MULDIV_RS1_SIGNED = 1'b1;
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
        out_MULDIV_RS1_SIGNED = 1'b1;
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
        out_MULDIV_RS1_SIGNED = 1'b1;
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
        out_MULDIV_RS1_SIGNED = 1'b0;
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_ALU_SRC1 = (1'bx);
  always @(*) begin
    out_ALU_SRC1 = _out_default_ALU_SRC1;
    out_ALU_SRC1 = Src1Select_RS1;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
        out_ALU_SRC1 = Src1Select_PC;
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
        out_ALU_SRC1 = Src1Select_PC;
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
        out_ALU_SRC1 = Src1Select_PC;
      end
      32'b?????????????????000?????0000011 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      32'b?????????????????110?????1100011 : begin
        out_ALU_SRC1 = Src1Select_PC;
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
        out_ALU_SRC1 = Src1Select_PC;
      end
      32'b?????????????????????????1101111 : begin
        out_ALU_SRC1 = Src1Select_PC;
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      32'b?????????????????000?????0100011 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
        out_ALU_SRC1 = Src1Select_PC;
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
        out_ALU_SRC1 = Src1Select_PC;
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
        out_ALU_SRC1 = Src1Select_RS1;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_DIV = 1'bx;
  always @(*) begin
    out_DIV = _out_default_DIV;
    out_DIV = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
        out_DIV = 1'b1;
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
        out_DIV = 1'b1;
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
        out_DIV = 1'b1;
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
        out_DIV = 1'b1;
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_MRET = 1'bx;
  always @(*) begin
    out_MRET = _out_default_MRET;
    out_MRET = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
        out_MRET = 1'b1;
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_SHIFT_OP = (2'bxx);
  always @(*) begin
    out_SHIFT_OP = _out_default_SHIFT_OP;
    out_SHIFT_OP = ShiftOp_NONE;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
        out_SHIFT_OP = ShiftOp_SRA_1;
      end
      32'b0000000??????????101?????0110011 : begin
        out_SHIFT_OP = ShiftOp_SRL_1;
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
        out_SHIFT_OP = ShiftOp_SLL_1;
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
        out_SHIFT_OP = ShiftOp_SLL_1;
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
        out_SHIFT_OP = ShiftOp_SRA_1;
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
        out_SHIFT_OP = ShiftOp_SRL_1;
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_BU_CONDITION = (3'bxxx);
  always @(*) begin
    out_BU_CONDITION = _out_default_BU_CONDITION;
    out_BU_CONDITION = BranchCondition_NONE;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
        out_BU_CONDITION = BranchCondition_GE;
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
        out_BU_CONDITION = BranchCondition_EQ;
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
        out_BU_CONDITION = BranchCondition_LTU;
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
        out_BU_CONDITION = BranchCondition_NE;
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
        out_BU_CONDITION = BranchCondition_LT;
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
        out_BU_CONDITION = BranchCondition_GEU;
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_LSU_OPERATION_TYPE = (2'bxx);
  always @(*) begin
    out_LSU_OPERATION_TYPE = _out_default_LSU_OPERATION_TYPE;
    out_LSU_OPERATION_TYPE = LsuOperationType_NONE;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
        out_LSU_OPERATION_TYPE = LsuOperationType_LOAD;
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
        out_LSU_OPERATION_TYPE = LsuOperationType_LOAD;
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
        out_LSU_OPERATION_TYPE = LsuOperationType_LOAD;
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
        out_LSU_OPERATION_TYPE = LsuOperationType_STORE;
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
        out_LSU_OPERATION_TYPE = LsuOperationType_LOAD;
      end
      32'b?????????????????000?????0100011 : begin
        out_LSU_OPERATION_TYPE = LsuOperationType_STORE;
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
        out_LSU_OPERATION_TYPE = LsuOperationType_STORE;
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
        out_LSU_OPERATION_TYPE = LsuOperationType_LOAD;
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_ALU_COMMIT_RESULT = 1'bx;
  always @(*) begin
    out_ALU_COMMIT_RESULT = _out_default_ALU_COMMIT_RESULT;
    out_ALU_COMMIT_RESULT = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b0000000??????????111?????0110011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b?????????????????000?????0010011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b0000000??????????010?????0110011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b?????????????????110?????0010011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b0100000??????????000?????0110011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b?????????????????111?????0010011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
        out_ALU_COMMIT_RESULT = 1'b1;
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_REM = 1'bx;
  always @(*) begin
    out_REM = _out_default_REM;
    out_REM = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
        out_REM = 1'b0;
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
        out_REM = 1'b1;
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
        out_REM = 1'b0;
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
        out_REM = 1'b1;
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_CONDITION_OP = (2'bxx);
  always @(*) begin
    out_CONDITION_OP = _out_default_CONDITION_OP;
    out_CONDITION_OP = ConditionOp_NONE;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
        out_CONDITION_OP = ConditionOp_NEZ;
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
        out_CONDITION_OP = ConditionOp_EQZ;
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_MUL_HIGH = 1'bx;
  always @(*) begin
    out_MUL_HIGH = _out_default_MUL_HIGH;
    out_MUL_HIGH = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_MUL_HIGH = 1'b1;
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
        out_MUL_HIGH = 1'b0;
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
        out_MUL_HIGH = 1'b1;
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
        out_MUL_HIGH = 1'b1;
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_ECALL = 1'bx;
  always @(*) begin
    out_ECALL = _out_default_ECALL;
    out_ECALL = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
        out_ECALL = 1'b1;
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_CSR_OP = (2'bxx);
  always @(*) begin
    out_CSR_OP = _out_default_CSR_OP;
    out_CSR_OP = CsrOp_NONE;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
        out_CSR_OP = CsrOp_RS;
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
        out_CSR_OP = CsrOp_RW;
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
        out_CSR_OP = CsrOp_RC;
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
        out_CSR_OP = CsrOp_RS;
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
        out_CSR_OP = CsrOp_RW;
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
        out_CSR_OP = CsrOp_RC;
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_LSU_IS_UNSIGNED = 1'bx;
  always @(*) begin
    out_LSU_IS_UNSIGNED = _out_default_LSU_IS_UNSIGNED;
    out_LSU_IS_UNSIGNED = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
        out_LSU_IS_UNSIGNED = 1'b0;
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
        out_LSU_IS_UNSIGNED = 1'b1;
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
        out_LSU_IS_UNSIGNED = 1'b0;
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
        out_LSU_IS_UNSIGNED = 1'b0;
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
        out_LSU_IS_UNSIGNED = 1'b1;
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_BU_WRITE_RET_ADDR_TO_RD = 1'bx;
  always @(*) begin
    out_BU_WRITE_RET_ADDR_TO_RD = _out_default_BU_WRITE_RET_ADDR_TO_RD;
    out_BU_WRITE_RET_ADDR_TO_RD = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
        out_BU_WRITE_RET_ADDR_TO_RD = 1'b1;
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
        out_BU_WRITE_RET_ADDR_TO_RD = 1'b1;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_LSU_IS_EXTERNAL_OP = 1'bx;
  always @(*) begin
    out_LSU_IS_EXTERNAL_OP = _out_default_LSU_IS_EXTERNAL_OP;
    out_LSU_IS_EXTERNAL_OP = 1'b0;
  end

  assign _out_default_RD_DATA_VALID = 1'bx;
  always @(*) begin
    out_RD_DATA_VALID = _out_default_RD_DATA_VALID;
    out_RD_DATA_VALID = 1'b0;
  end

  assign _out_default_MUL = 1'bx;
  always @(*) begin
    out_MUL = _out_default_MUL;
    out_MUL = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_MUL = 1'b1;
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
        out_MUL = 1'b1;
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
        out_MUL = 1'b1;
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
        out_MUL = 1'b1;
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_EBREAK = 1'bx;
  always @(*) begin
    out_EBREAK = _out_default_EBREAK;
    out_EBREAK = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
        out_EBREAK = 1'b1;
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_BU_IGNORE_TARGET_LSB = 1'bx;
  always @(*) begin
    out_BU_IGNORE_TARGET_LSB = _out_default_BU_IGNORE_TARGET_LSB;
    out_BU_IGNORE_TARGET_LSB = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
        out_BU_IGNORE_TARGET_LSB = 1'b1;
      end
      default : begin
      end
    endcase
  end

  assign _out_default_IMM = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_IMM = _out_default_IMM;
    out_IMM = 32'h0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b00000000000000000000000001110011 : begin
        out_IMM = {_zz_out_IMM_3,_zz_out_IMM_1};
      end
      32'b?????????????????????????0010111 : begin
        out_IMM = _zz_out_IMM_103;
      end
      32'b0000000??????????111?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????000?????0010011 : begin
        out_IMM = {_zz_out_IMM_6,_zz_out_IMM_4};
      end
      32'b0000000??????????010?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b0000001??????????101?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????010?????0000011 : begin
        out_IMM = {_zz_out_IMM_9,_zz_out_IMM_7};
      end
      32'b?????????????????011?????0010011 : begin
        out_IMM = {_zz_out_IMM_12,_zz_out_IMM_10};
      end
      32'b?????????????????101?????1100011 : begin
        out_IMM = {_zz_out_IMM_15,_zz_out_IMM_13};
      end
      32'b0000111??????????111?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b0100000??????????101?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b0000000??????????101?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????101?????0000011 : begin
        out_IMM = {_zz_out_IMM_18,_zz_out_IMM_16};
      end
      32'b?????????????????110?????1110011 : begin
        out_IMM = {_zz_out_IMM_21,_zz_out_IMM_19};
      end
      32'b?????????????????000?????1100011 : begin
        out_IMM = {_zz_out_IMM_24,_zz_out_IMM_22};
      end
      32'b?????????????????000?????0000011 : begin
        out_IMM = {_zz_out_IMM_27,_zz_out_IMM_25};
      end
      32'b?????????????????001?????1110011 : begin
        out_IMM = {_zz_out_IMM_30,_zz_out_IMM_28};
      end
      32'b?????????????????????????0110111 : begin
        out_IMM = _zz_out_IMM_104;
      end
      32'b?????????????????110?????0010011 : begin
        out_IMM = {_zz_out_IMM_33,_zz_out_IMM_31};
      end
      32'b0000111??????????101?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b0000001??????????000?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b00000000000100000000000001110011 : begin
        out_IMM = {_zz_out_IMM_36,_zz_out_IMM_34};
      end
      32'b?????????????????010?????0100011 : begin
        out_IMM = {_zz_out_IMM_39,_zz_out_IMM_37};
      end
      32'b?????????????????110?????1100011 : begin
        out_IMM = {_zz_out_IMM_42,_zz_out_IMM_40};
      end
      32'b?????????????????100?????0010011 : begin
        out_IMM = {_zz_out_IMM_45,_zz_out_IMM_43};
      end
      32'b0100000??????????000?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b0000000??????????001?????0010011 : begin
        out_IMM = {_zz_out_IMM_48,_zz_out_IMM_46};
      end
      32'b0000001??????????011?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b0000000??????????000?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????111?????1110011 : begin
        out_IMM = {_zz_out_IMM_51,_zz_out_IMM_49};
      end
      32'b?????????????????001?????1100011 : begin
        out_IMM = {_zz_out_IMM_54,_zz_out_IMM_52};
      end
      32'b?????????????????????????1101111 : begin
        out_IMM = {_zz_out_IMM_57,_zz_out_IMM_55};
      end
      32'b0000000??????????011?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????111?????0010011 : begin
        out_IMM = {_zz_out_IMM_60,_zz_out_IMM_58};
      end
      32'b?????????????????010?????1110011 : begin
        out_IMM = {_zz_out_IMM_63,_zz_out_IMM_61};
      end
      32'b?????????????????001?????0000011 : begin
        out_IMM = {_zz_out_IMM_66,_zz_out_IMM_64};
      end
      32'b?????????????????000?????0100011 : begin
        out_IMM = {_zz_out_IMM_69,_zz_out_IMM_67};
      end
      32'b0000001??????????110?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????100?????1100011 : begin
        out_IMM = {_zz_out_IMM_72,_zz_out_IMM_70};
      end
      32'b0000001??????????001?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????010?????0010011 : begin
        out_IMM = {_zz_out_IMM_75,_zz_out_IMM_73};
      end
      32'b?????????????????101?????1110011 : begin
        out_IMM = {_zz_out_IMM_78,_zz_out_IMM_76};
      end
      32'b0000000??????????110?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b0000000??????????001?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????111?????1100011 : begin
        out_IMM = {_zz_out_IMM_81,_zz_out_IMM_79};
      end
      32'b0000001??????????100?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b00110000001000000000000001110011 : begin
        out_IMM = {_zz_out_IMM_84,_zz_out_IMM_82};
      end
      32'b0000000??????????100?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????001?????0100011 : begin
        out_IMM = {_zz_out_IMM_87,_zz_out_IMM_85};
      end
      32'b0100000??????????101?????0010011 : begin
        out_IMM = {_zz_out_IMM_90,_zz_out_IMM_88};
      end
      32'b?????????????????011?????1110011 : begin
        out_IMM = {_zz_out_IMM_93,_zz_out_IMM_91};
      end
      32'b0000001??????????111?????0110011 : begin
        out_IMM = 32'h0;
      end
      32'b?????????????????100?????0000011 : begin
        out_IMM = {_zz_out_IMM_96,_zz_out_IMM_94};
      end
      32'b0000000??????????101?????0010011 : begin
        out_IMM = {_zz_out_IMM_99,_zz_out_IMM_97};
      end
      32'b?????????????????000?????1100111 : begin
        out_IMM = {_zz_out_IMM_102,_zz_out_IMM_100};
      end
      default : begin
      end
    endcase
  end

  assign _out_default_MULDIV_RS2_SIGNED = 1'bx;
  always @(*) begin
    out_MULDIV_RS2_SIGNED = _out_default_MULDIV_RS2_SIGNED;
    out_MULDIV_RS2_SIGNED = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
        out_MULDIV_RS2_SIGNED = 1'b0;
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
        out_MULDIV_RS2_SIGNED = 1'b0;
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
        out_MULDIV_RS2_SIGNED = 1'b1;
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
        out_MULDIV_RS2_SIGNED = 1'b0;
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
        out_MULDIV_RS2_SIGNED = 1'b1;
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
        out_MULDIV_RS2_SIGNED = 1'b1;
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
        out_MULDIV_RS2_SIGNED = 1'b1;
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
        out_MULDIV_RS2_SIGNED = 1'b0;
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_CSR_USE_IMM = 1'bx;
  always @(*) begin
    out_CSR_USE_IMM = _out_default_CSR_USE_IMM;
    out_CSR_USE_IMM = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
        out_CSR_USE_IMM = 1'b1;
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
        out_CSR_USE_IMM = 1'b0;
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
        out_CSR_USE_IMM = 1'b1;
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
        out_CSR_USE_IMM = 1'b0;
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
        out_CSR_USE_IMM = 1'b1;
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
        out_CSR_USE_IMM = 1'b0;
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
      end
    endcase
  end

  assign _out_default_BU_IS_BRANCH = 1'bx;
  always @(*) begin
    out_BU_IS_BRANCH = _out_default_BU_IS_BRANCH;
    out_BU_IS_BRANCH = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
        out_BU_IS_BRANCH = 1'b1;
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
        out_BU_IS_BRANCH = 1'b1;
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
        out_BU_IS_BRANCH = 1'b1;
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
        out_BU_IS_BRANCH = 1'b1;
      end
      32'b?????????????????????????1101111 : begin
        out_BU_IS_BRANCH = 1'b1;
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
        out_BU_IS_BRANCH = 1'b1;
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
        out_BU_IS_BRANCH = 1'b1;
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
        out_BU_IS_BRANCH = 1'b1;
      end
      default : begin
      end
    endcase
  end

  assign arbitration_isAvailable = ((! arbitration_isValid) || arbitration_isDone);
  assign arbitration_isReady = 1'b1;
  assign arbitration_rs1Needed = 1'b0;
  assign arbitration_rs2Needed = 1'b0;
  assign arbitration_jumpRequested = 1'b0;
  assign arbitration_isDone = ((arbitration_isValid && arbitration_isReady) && (! arbitration_isStalled));
  assign TrapHandler_interruptSignals_hasTrapped = 1'b0;
  assign TrapHandler_interruptSignals_trapCause = 4'bxxxx;
  assign TrapHandler_interruptSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    TrapHandler_exceptionSignals_hasTrapped = 1'b0;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
        TrapHandler_exceptionSignals_hasTrapped = 1'b1;
      end
    endcase
  end

  always @(*) begin
    TrapHandler_exceptionSignals_trapCause = 4'bxxxx;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
        TrapHandler_exceptionSignals_trapCause = 4'b0010;
      end
    endcase
  end

  always @(*) begin
    TrapHandler_exceptionSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    casez(value_IR)
      32'b0000001??????????010?????0110011 : begin
      end
      32'b00000000000000000000000001110011 : begin
      end
      32'b?????????????????????????0010111 : begin
      end
      32'b0000000??????????111?????0110011 : begin
      end
      32'b?????????????????000?????0010011 : begin
      end
      32'b0000000??????????010?????0110011 : begin
      end
      32'b0000001??????????101?????0110011 : begin
      end
      32'b?????????????????010?????0000011 : begin
      end
      32'b?????????????????011?????0010011 : begin
      end
      32'b?????????????????101?????1100011 : begin
      end
      32'b0000111??????????111?????0110011 : begin
      end
      32'b0100000??????????101?????0110011 : begin
      end
      32'b0000000??????????101?????0110011 : begin
      end
      32'b?????????????????101?????0000011 : begin
      end
      32'b?????????????????110?????1110011 : begin
      end
      32'b?????????????????000?????1100011 : begin
      end
      32'b?????????????????000?????0000011 : begin
      end
      32'b?????????????????001?????1110011 : begin
      end
      32'b?????????????????????????0110111 : begin
      end
      32'b?????????????????110?????0010011 : begin
      end
      32'b0000111??????????101?????0110011 : begin
      end
      32'b0000001??????????000?????0110011 : begin
      end
      32'b00000000000100000000000001110011 : begin
      end
      32'b?????????????????010?????0100011 : begin
      end
      32'b?????????????????110?????1100011 : begin
      end
      32'b?????????????????100?????0010011 : begin
      end
      32'b0100000??????????000?????0110011 : begin
      end
      32'b0000000??????????001?????0010011 : begin
      end
      32'b0000001??????????011?????0110011 : begin
      end
      32'b0000000??????????000?????0110011 : begin
      end
      32'b?????????????????111?????1110011 : begin
      end
      32'b?????????????????001?????1100011 : begin
      end
      32'b?????????????????????????1101111 : begin
      end
      32'b0000000??????????011?????0110011 : begin
      end
      32'b?????????????????111?????0010011 : begin
      end
      32'b?????????????????010?????1110011 : begin
      end
      32'b?????????????????001?????0000011 : begin
      end
      32'b?????????????????000?????0100011 : begin
      end
      32'b0000001??????????110?????0110011 : begin
      end
      32'b?????????????????100?????1100011 : begin
      end
      32'b0000001??????????001?????0110011 : begin
      end
      32'b?????????????????010?????0010011 : begin
      end
      32'b?????????????????101?????1110011 : begin
      end
      32'b0000000??????????110?????0110011 : begin
      end
      32'b0000000??????????001?????0110011 : begin
      end
      32'b?????????????????111?????1100011 : begin
      end
      32'b0000001??????????100?????0110011 : begin
      end
      32'b00110000001000000000000001110011 : begin
      end
      32'b0000000??????????100?????0110011 : begin
      end
      32'b?????????????????001?????0100011 : begin
      end
      32'b0100000??????????101?????0010011 : begin
      end
      32'b?????????????????011?????1110011 : begin
      end
      32'b0000001??????????111?????0110011 : begin
      end
      32'b?????????????????100?????0000011 : begin
      end
      32'b0000000??????????101?????0010011 : begin
      end
      32'b?????????????????000?????1100111 : begin
      end
      default : begin
        TrapHandler_exceptionSignals_trapVal = value_IR;
      end
    endcase
  end

  assign _zz_out_IMM = value_IR;
  assign _zz_out_IMM_1 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_2 = _zz_out_IMM_1[11];
  always @(*) begin
    _zz_out_IMM_3[19] = _zz_out_IMM_2;
    _zz_out_IMM_3[18] = _zz_out_IMM_2;
    _zz_out_IMM_3[17] = _zz_out_IMM_2;
    _zz_out_IMM_3[16] = _zz_out_IMM_2;
    _zz_out_IMM_3[15] = _zz_out_IMM_2;
    _zz_out_IMM_3[14] = _zz_out_IMM_2;
    _zz_out_IMM_3[13] = _zz_out_IMM_2;
    _zz_out_IMM_3[12] = _zz_out_IMM_2;
    _zz_out_IMM_3[11] = _zz_out_IMM_2;
    _zz_out_IMM_3[10] = _zz_out_IMM_2;
    _zz_out_IMM_3[9] = _zz_out_IMM_2;
    _zz_out_IMM_3[8] = _zz_out_IMM_2;
    _zz_out_IMM_3[7] = _zz_out_IMM_2;
    _zz_out_IMM_3[6] = _zz_out_IMM_2;
    _zz_out_IMM_3[5] = _zz_out_IMM_2;
    _zz_out_IMM_3[4] = _zz_out_IMM_2;
    _zz_out_IMM_3[3] = _zz_out_IMM_2;
    _zz_out_IMM_3[2] = _zz_out_IMM_2;
    _zz_out_IMM_3[1] = _zz_out_IMM_2;
    _zz_out_IMM_3[0] = _zz_out_IMM_2;
  end

  assign _zz_out_IMM_4 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_5 = _zz_out_IMM_4[11];
  always @(*) begin
    _zz_out_IMM_6[19] = _zz_out_IMM_5;
    _zz_out_IMM_6[18] = _zz_out_IMM_5;
    _zz_out_IMM_6[17] = _zz_out_IMM_5;
    _zz_out_IMM_6[16] = _zz_out_IMM_5;
    _zz_out_IMM_6[15] = _zz_out_IMM_5;
    _zz_out_IMM_6[14] = _zz_out_IMM_5;
    _zz_out_IMM_6[13] = _zz_out_IMM_5;
    _zz_out_IMM_6[12] = _zz_out_IMM_5;
    _zz_out_IMM_6[11] = _zz_out_IMM_5;
    _zz_out_IMM_6[10] = _zz_out_IMM_5;
    _zz_out_IMM_6[9] = _zz_out_IMM_5;
    _zz_out_IMM_6[8] = _zz_out_IMM_5;
    _zz_out_IMM_6[7] = _zz_out_IMM_5;
    _zz_out_IMM_6[6] = _zz_out_IMM_5;
    _zz_out_IMM_6[5] = _zz_out_IMM_5;
    _zz_out_IMM_6[4] = _zz_out_IMM_5;
    _zz_out_IMM_6[3] = _zz_out_IMM_5;
    _zz_out_IMM_6[2] = _zz_out_IMM_5;
    _zz_out_IMM_6[1] = _zz_out_IMM_5;
    _zz_out_IMM_6[0] = _zz_out_IMM_5;
  end

  assign _zz_out_IMM_7 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_8 = _zz_out_IMM_7[11];
  always @(*) begin
    _zz_out_IMM_9[19] = _zz_out_IMM_8;
    _zz_out_IMM_9[18] = _zz_out_IMM_8;
    _zz_out_IMM_9[17] = _zz_out_IMM_8;
    _zz_out_IMM_9[16] = _zz_out_IMM_8;
    _zz_out_IMM_9[15] = _zz_out_IMM_8;
    _zz_out_IMM_9[14] = _zz_out_IMM_8;
    _zz_out_IMM_9[13] = _zz_out_IMM_8;
    _zz_out_IMM_9[12] = _zz_out_IMM_8;
    _zz_out_IMM_9[11] = _zz_out_IMM_8;
    _zz_out_IMM_9[10] = _zz_out_IMM_8;
    _zz_out_IMM_9[9] = _zz_out_IMM_8;
    _zz_out_IMM_9[8] = _zz_out_IMM_8;
    _zz_out_IMM_9[7] = _zz_out_IMM_8;
    _zz_out_IMM_9[6] = _zz_out_IMM_8;
    _zz_out_IMM_9[5] = _zz_out_IMM_8;
    _zz_out_IMM_9[4] = _zz_out_IMM_8;
    _zz_out_IMM_9[3] = _zz_out_IMM_8;
    _zz_out_IMM_9[2] = _zz_out_IMM_8;
    _zz_out_IMM_9[1] = _zz_out_IMM_8;
    _zz_out_IMM_9[0] = _zz_out_IMM_8;
  end

  assign _zz_out_IMM_10 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_11 = _zz_out_IMM_10[11];
  always @(*) begin
    _zz_out_IMM_12[19] = _zz_out_IMM_11;
    _zz_out_IMM_12[18] = _zz_out_IMM_11;
    _zz_out_IMM_12[17] = _zz_out_IMM_11;
    _zz_out_IMM_12[16] = _zz_out_IMM_11;
    _zz_out_IMM_12[15] = _zz_out_IMM_11;
    _zz_out_IMM_12[14] = _zz_out_IMM_11;
    _zz_out_IMM_12[13] = _zz_out_IMM_11;
    _zz_out_IMM_12[12] = _zz_out_IMM_11;
    _zz_out_IMM_12[11] = _zz_out_IMM_11;
    _zz_out_IMM_12[10] = _zz_out_IMM_11;
    _zz_out_IMM_12[9] = _zz_out_IMM_11;
    _zz_out_IMM_12[8] = _zz_out_IMM_11;
    _zz_out_IMM_12[7] = _zz_out_IMM_11;
    _zz_out_IMM_12[6] = _zz_out_IMM_11;
    _zz_out_IMM_12[5] = _zz_out_IMM_11;
    _zz_out_IMM_12[4] = _zz_out_IMM_11;
    _zz_out_IMM_12[3] = _zz_out_IMM_11;
    _zz_out_IMM_12[2] = _zz_out_IMM_11;
    _zz_out_IMM_12[1] = _zz_out_IMM_11;
    _zz_out_IMM_12[0] = _zz_out_IMM_11;
  end

  assign _zz_out_IMM_13 = {{{{_zz_out_IMM[31],_zz_out_IMM[7]},_zz_out_IMM[30 : 25]},_zz_out_IMM[11 : 8]},1'b0};
  assign _zz_out_IMM_14 = _zz_out_IMM_13[12];
  always @(*) begin
    _zz_out_IMM_15[18] = _zz_out_IMM_14;
    _zz_out_IMM_15[17] = _zz_out_IMM_14;
    _zz_out_IMM_15[16] = _zz_out_IMM_14;
    _zz_out_IMM_15[15] = _zz_out_IMM_14;
    _zz_out_IMM_15[14] = _zz_out_IMM_14;
    _zz_out_IMM_15[13] = _zz_out_IMM_14;
    _zz_out_IMM_15[12] = _zz_out_IMM_14;
    _zz_out_IMM_15[11] = _zz_out_IMM_14;
    _zz_out_IMM_15[10] = _zz_out_IMM_14;
    _zz_out_IMM_15[9] = _zz_out_IMM_14;
    _zz_out_IMM_15[8] = _zz_out_IMM_14;
    _zz_out_IMM_15[7] = _zz_out_IMM_14;
    _zz_out_IMM_15[6] = _zz_out_IMM_14;
    _zz_out_IMM_15[5] = _zz_out_IMM_14;
    _zz_out_IMM_15[4] = _zz_out_IMM_14;
    _zz_out_IMM_15[3] = _zz_out_IMM_14;
    _zz_out_IMM_15[2] = _zz_out_IMM_14;
    _zz_out_IMM_15[1] = _zz_out_IMM_14;
    _zz_out_IMM_15[0] = _zz_out_IMM_14;
  end

  assign _zz_out_IMM_16 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_17 = _zz_out_IMM_16[11];
  always @(*) begin
    _zz_out_IMM_18[19] = _zz_out_IMM_17;
    _zz_out_IMM_18[18] = _zz_out_IMM_17;
    _zz_out_IMM_18[17] = _zz_out_IMM_17;
    _zz_out_IMM_18[16] = _zz_out_IMM_17;
    _zz_out_IMM_18[15] = _zz_out_IMM_17;
    _zz_out_IMM_18[14] = _zz_out_IMM_17;
    _zz_out_IMM_18[13] = _zz_out_IMM_17;
    _zz_out_IMM_18[12] = _zz_out_IMM_17;
    _zz_out_IMM_18[11] = _zz_out_IMM_17;
    _zz_out_IMM_18[10] = _zz_out_IMM_17;
    _zz_out_IMM_18[9] = _zz_out_IMM_17;
    _zz_out_IMM_18[8] = _zz_out_IMM_17;
    _zz_out_IMM_18[7] = _zz_out_IMM_17;
    _zz_out_IMM_18[6] = _zz_out_IMM_17;
    _zz_out_IMM_18[5] = _zz_out_IMM_17;
    _zz_out_IMM_18[4] = _zz_out_IMM_17;
    _zz_out_IMM_18[3] = _zz_out_IMM_17;
    _zz_out_IMM_18[2] = _zz_out_IMM_17;
    _zz_out_IMM_18[1] = _zz_out_IMM_17;
    _zz_out_IMM_18[0] = _zz_out_IMM_17;
  end

  assign _zz_out_IMM_19 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_20 = _zz_out_IMM_19[11];
  always @(*) begin
    _zz_out_IMM_21[19] = _zz_out_IMM_20;
    _zz_out_IMM_21[18] = _zz_out_IMM_20;
    _zz_out_IMM_21[17] = _zz_out_IMM_20;
    _zz_out_IMM_21[16] = _zz_out_IMM_20;
    _zz_out_IMM_21[15] = _zz_out_IMM_20;
    _zz_out_IMM_21[14] = _zz_out_IMM_20;
    _zz_out_IMM_21[13] = _zz_out_IMM_20;
    _zz_out_IMM_21[12] = _zz_out_IMM_20;
    _zz_out_IMM_21[11] = _zz_out_IMM_20;
    _zz_out_IMM_21[10] = _zz_out_IMM_20;
    _zz_out_IMM_21[9] = _zz_out_IMM_20;
    _zz_out_IMM_21[8] = _zz_out_IMM_20;
    _zz_out_IMM_21[7] = _zz_out_IMM_20;
    _zz_out_IMM_21[6] = _zz_out_IMM_20;
    _zz_out_IMM_21[5] = _zz_out_IMM_20;
    _zz_out_IMM_21[4] = _zz_out_IMM_20;
    _zz_out_IMM_21[3] = _zz_out_IMM_20;
    _zz_out_IMM_21[2] = _zz_out_IMM_20;
    _zz_out_IMM_21[1] = _zz_out_IMM_20;
    _zz_out_IMM_21[0] = _zz_out_IMM_20;
  end

  assign _zz_out_IMM_22 = {{{{_zz_out_IMM[31],_zz_out_IMM[7]},_zz_out_IMM[30 : 25]},_zz_out_IMM[11 : 8]},1'b0};
  assign _zz_out_IMM_23 = _zz_out_IMM_22[12];
  always @(*) begin
    _zz_out_IMM_24[18] = _zz_out_IMM_23;
    _zz_out_IMM_24[17] = _zz_out_IMM_23;
    _zz_out_IMM_24[16] = _zz_out_IMM_23;
    _zz_out_IMM_24[15] = _zz_out_IMM_23;
    _zz_out_IMM_24[14] = _zz_out_IMM_23;
    _zz_out_IMM_24[13] = _zz_out_IMM_23;
    _zz_out_IMM_24[12] = _zz_out_IMM_23;
    _zz_out_IMM_24[11] = _zz_out_IMM_23;
    _zz_out_IMM_24[10] = _zz_out_IMM_23;
    _zz_out_IMM_24[9] = _zz_out_IMM_23;
    _zz_out_IMM_24[8] = _zz_out_IMM_23;
    _zz_out_IMM_24[7] = _zz_out_IMM_23;
    _zz_out_IMM_24[6] = _zz_out_IMM_23;
    _zz_out_IMM_24[5] = _zz_out_IMM_23;
    _zz_out_IMM_24[4] = _zz_out_IMM_23;
    _zz_out_IMM_24[3] = _zz_out_IMM_23;
    _zz_out_IMM_24[2] = _zz_out_IMM_23;
    _zz_out_IMM_24[1] = _zz_out_IMM_23;
    _zz_out_IMM_24[0] = _zz_out_IMM_23;
  end

  assign _zz_out_IMM_25 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_26 = _zz_out_IMM_25[11];
  always @(*) begin
    _zz_out_IMM_27[19] = _zz_out_IMM_26;
    _zz_out_IMM_27[18] = _zz_out_IMM_26;
    _zz_out_IMM_27[17] = _zz_out_IMM_26;
    _zz_out_IMM_27[16] = _zz_out_IMM_26;
    _zz_out_IMM_27[15] = _zz_out_IMM_26;
    _zz_out_IMM_27[14] = _zz_out_IMM_26;
    _zz_out_IMM_27[13] = _zz_out_IMM_26;
    _zz_out_IMM_27[12] = _zz_out_IMM_26;
    _zz_out_IMM_27[11] = _zz_out_IMM_26;
    _zz_out_IMM_27[10] = _zz_out_IMM_26;
    _zz_out_IMM_27[9] = _zz_out_IMM_26;
    _zz_out_IMM_27[8] = _zz_out_IMM_26;
    _zz_out_IMM_27[7] = _zz_out_IMM_26;
    _zz_out_IMM_27[6] = _zz_out_IMM_26;
    _zz_out_IMM_27[5] = _zz_out_IMM_26;
    _zz_out_IMM_27[4] = _zz_out_IMM_26;
    _zz_out_IMM_27[3] = _zz_out_IMM_26;
    _zz_out_IMM_27[2] = _zz_out_IMM_26;
    _zz_out_IMM_27[1] = _zz_out_IMM_26;
    _zz_out_IMM_27[0] = _zz_out_IMM_26;
  end

  assign _zz_out_IMM_28 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_29 = _zz_out_IMM_28[11];
  always @(*) begin
    _zz_out_IMM_30[19] = _zz_out_IMM_29;
    _zz_out_IMM_30[18] = _zz_out_IMM_29;
    _zz_out_IMM_30[17] = _zz_out_IMM_29;
    _zz_out_IMM_30[16] = _zz_out_IMM_29;
    _zz_out_IMM_30[15] = _zz_out_IMM_29;
    _zz_out_IMM_30[14] = _zz_out_IMM_29;
    _zz_out_IMM_30[13] = _zz_out_IMM_29;
    _zz_out_IMM_30[12] = _zz_out_IMM_29;
    _zz_out_IMM_30[11] = _zz_out_IMM_29;
    _zz_out_IMM_30[10] = _zz_out_IMM_29;
    _zz_out_IMM_30[9] = _zz_out_IMM_29;
    _zz_out_IMM_30[8] = _zz_out_IMM_29;
    _zz_out_IMM_30[7] = _zz_out_IMM_29;
    _zz_out_IMM_30[6] = _zz_out_IMM_29;
    _zz_out_IMM_30[5] = _zz_out_IMM_29;
    _zz_out_IMM_30[4] = _zz_out_IMM_29;
    _zz_out_IMM_30[3] = _zz_out_IMM_29;
    _zz_out_IMM_30[2] = _zz_out_IMM_29;
    _zz_out_IMM_30[1] = _zz_out_IMM_29;
    _zz_out_IMM_30[0] = _zz_out_IMM_29;
  end

  assign _zz_out_IMM_31 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_32 = _zz_out_IMM_31[11];
  always @(*) begin
    _zz_out_IMM_33[19] = _zz_out_IMM_32;
    _zz_out_IMM_33[18] = _zz_out_IMM_32;
    _zz_out_IMM_33[17] = _zz_out_IMM_32;
    _zz_out_IMM_33[16] = _zz_out_IMM_32;
    _zz_out_IMM_33[15] = _zz_out_IMM_32;
    _zz_out_IMM_33[14] = _zz_out_IMM_32;
    _zz_out_IMM_33[13] = _zz_out_IMM_32;
    _zz_out_IMM_33[12] = _zz_out_IMM_32;
    _zz_out_IMM_33[11] = _zz_out_IMM_32;
    _zz_out_IMM_33[10] = _zz_out_IMM_32;
    _zz_out_IMM_33[9] = _zz_out_IMM_32;
    _zz_out_IMM_33[8] = _zz_out_IMM_32;
    _zz_out_IMM_33[7] = _zz_out_IMM_32;
    _zz_out_IMM_33[6] = _zz_out_IMM_32;
    _zz_out_IMM_33[5] = _zz_out_IMM_32;
    _zz_out_IMM_33[4] = _zz_out_IMM_32;
    _zz_out_IMM_33[3] = _zz_out_IMM_32;
    _zz_out_IMM_33[2] = _zz_out_IMM_32;
    _zz_out_IMM_33[1] = _zz_out_IMM_32;
    _zz_out_IMM_33[0] = _zz_out_IMM_32;
  end

  assign _zz_out_IMM_34 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_35 = _zz_out_IMM_34[11];
  always @(*) begin
    _zz_out_IMM_36[19] = _zz_out_IMM_35;
    _zz_out_IMM_36[18] = _zz_out_IMM_35;
    _zz_out_IMM_36[17] = _zz_out_IMM_35;
    _zz_out_IMM_36[16] = _zz_out_IMM_35;
    _zz_out_IMM_36[15] = _zz_out_IMM_35;
    _zz_out_IMM_36[14] = _zz_out_IMM_35;
    _zz_out_IMM_36[13] = _zz_out_IMM_35;
    _zz_out_IMM_36[12] = _zz_out_IMM_35;
    _zz_out_IMM_36[11] = _zz_out_IMM_35;
    _zz_out_IMM_36[10] = _zz_out_IMM_35;
    _zz_out_IMM_36[9] = _zz_out_IMM_35;
    _zz_out_IMM_36[8] = _zz_out_IMM_35;
    _zz_out_IMM_36[7] = _zz_out_IMM_35;
    _zz_out_IMM_36[6] = _zz_out_IMM_35;
    _zz_out_IMM_36[5] = _zz_out_IMM_35;
    _zz_out_IMM_36[4] = _zz_out_IMM_35;
    _zz_out_IMM_36[3] = _zz_out_IMM_35;
    _zz_out_IMM_36[2] = _zz_out_IMM_35;
    _zz_out_IMM_36[1] = _zz_out_IMM_35;
    _zz_out_IMM_36[0] = _zz_out_IMM_35;
  end

  assign _zz_out_IMM_37 = {_zz_out_IMM[31 : 25],_zz_out_IMM[11 : 7]};
  assign _zz_out_IMM_38 = _zz_out_IMM_37[11];
  always @(*) begin
    _zz_out_IMM_39[19] = _zz_out_IMM_38;
    _zz_out_IMM_39[18] = _zz_out_IMM_38;
    _zz_out_IMM_39[17] = _zz_out_IMM_38;
    _zz_out_IMM_39[16] = _zz_out_IMM_38;
    _zz_out_IMM_39[15] = _zz_out_IMM_38;
    _zz_out_IMM_39[14] = _zz_out_IMM_38;
    _zz_out_IMM_39[13] = _zz_out_IMM_38;
    _zz_out_IMM_39[12] = _zz_out_IMM_38;
    _zz_out_IMM_39[11] = _zz_out_IMM_38;
    _zz_out_IMM_39[10] = _zz_out_IMM_38;
    _zz_out_IMM_39[9] = _zz_out_IMM_38;
    _zz_out_IMM_39[8] = _zz_out_IMM_38;
    _zz_out_IMM_39[7] = _zz_out_IMM_38;
    _zz_out_IMM_39[6] = _zz_out_IMM_38;
    _zz_out_IMM_39[5] = _zz_out_IMM_38;
    _zz_out_IMM_39[4] = _zz_out_IMM_38;
    _zz_out_IMM_39[3] = _zz_out_IMM_38;
    _zz_out_IMM_39[2] = _zz_out_IMM_38;
    _zz_out_IMM_39[1] = _zz_out_IMM_38;
    _zz_out_IMM_39[0] = _zz_out_IMM_38;
  end

  assign _zz_out_IMM_40 = {{{{_zz_out_IMM[31],_zz_out_IMM[7]},_zz_out_IMM[30 : 25]},_zz_out_IMM[11 : 8]},1'b0};
  assign _zz_out_IMM_41 = _zz_out_IMM_40[12];
  always @(*) begin
    _zz_out_IMM_42[18] = _zz_out_IMM_41;
    _zz_out_IMM_42[17] = _zz_out_IMM_41;
    _zz_out_IMM_42[16] = _zz_out_IMM_41;
    _zz_out_IMM_42[15] = _zz_out_IMM_41;
    _zz_out_IMM_42[14] = _zz_out_IMM_41;
    _zz_out_IMM_42[13] = _zz_out_IMM_41;
    _zz_out_IMM_42[12] = _zz_out_IMM_41;
    _zz_out_IMM_42[11] = _zz_out_IMM_41;
    _zz_out_IMM_42[10] = _zz_out_IMM_41;
    _zz_out_IMM_42[9] = _zz_out_IMM_41;
    _zz_out_IMM_42[8] = _zz_out_IMM_41;
    _zz_out_IMM_42[7] = _zz_out_IMM_41;
    _zz_out_IMM_42[6] = _zz_out_IMM_41;
    _zz_out_IMM_42[5] = _zz_out_IMM_41;
    _zz_out_IMM_42[4] = _zz_out_IMM_41;
    _zz_out_IMM_42[3] = _zz_out_IMM_41;
    _zz_out_IMM_42[2] = _zz_out_IMM_41;
    _zz_out_IMM_42[1] = _zz_out_IMM_41;
    _zz_out_IMM_42[0] = _zz_out_IMM_41;
  end

  assign _zz_out_IMM_43 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_44 = _zz_out_IMM_43[11];
  always @(*) begin
    _zz_out_IMM_45[19] = _zz_out_IMM_44;
    _zz_out_IMM_45[18] = _zz_out_IMM_44;
    _zz_out_IMM_45[17] = _zz_out_IMM_44;
    _zz_out_IMM_45[16] = _zz_out_IMM_44;
    _zz_out_IMM_45[15] = _zz_out_IMM_44;
    _zz_out_IMM_45[14] = _zz_out_IMM_44;
    _zz_out_IMM_45[13] = _zz_out_IMM_44;
    _zz_out_IMM_45[12] = _zz_out_IMM_44;
    _zz_out_IMM_45[11] = _zz_out_IMM_44;
    _zz_out_IMM_45[10] = _zz_out_IMM_44;
    _zz_out_IMM_45[9] = _zz_out_IMM_44;
    _zz_out_IMM_45[8] = _zz_out_IMM_44;
    _zz_out_IMM_45[7] = _zz_out_IMM_44;
    _zz_out_IMM_45[6] = _zz_out_IMM_44;
    _zz_out_IMM_45[5] = _zz_out_IMM_44;
    _zz_out_IMM_45[4] = _zz_out_IMM_44;
    _zz_out_IMM_45[3] = _zz_out_IMM_44;
    _zz_out_IMM_45[2] = _zz_out_IMM_44;
    _zz_out_IMM_45[1] = _zz_out_IMM_44;
    _zz_out_IMM_45[0] = _zz_out_IMM_44;
  end

  assign _zz_out_IMM_46 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_47 = _zz_out_IMM_46[11];
  always @(*) begin
    _zz_out_IMM_48[19] = _zz_out_IMM_47;
    _zz_out_IMM_48[18] = _zz_out_IMM_47;
    _zz_out_IMM_48[17] = _zz_out_IMM_47;
    _zz_out_IMM_48[16] = _zz_out_IMM_47;
    _zz_out_IMM_48[15] = _zz_out_IMM_47;
    _zz_out_IMM_48[14] = _zz_out_IMM_47;
    _zz_out_IMM_48[13] = _zz_out_IMM_47;
    _zz_out_IMM_48[12] = _zz_out_IMM_47;
    _zz_out_IMM_48[11] = _zz_out_IMM_47;
    _zz_out_IMM_48[10] = _zz_out_IMM_47;
    _zz_out_IMM_48[9] = _zz_out_IMM_47;
    _zz_out_IMM_48[8] = _zz_out_IMM_47;
    _zz_out_IMM_48[7] = _zz_out_IMM_47;
    _zz_out_IMM_48[6] = _zz_out_IMM_47;
    _zz_out_IMM_48[5] = _zz_out_IMM_47;
    _zz_out_IMM_48[4] = _zz_out_IMM_47;
    _zz_out_IMM_48[3] = _zz_out_IMM_47;
    _zz_out_IMM_48[2] = _zz_out_IMM_47;
    _zz_out_IMM_48[1] = _zz_out_IMM_47;
    _zz_out_IMM_48[0] = _zz_out_IMM_47;
  end

  assign _zz_out_IMM_49 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_50 = _zz_out_IMM_49[11];
  always @(*) begin
    _zz_out_IMM_51[19] = _zz_out_IMM_50;
    _zz_out_IMM_51[18] = _zz_out_IMM_50;
    _zz_out_IMM_51[17] = _zz_out_IMM_50;
    _zz_out_IMM_51[16] = _zz_out_IMM_50;
    _zz_out_IMM_51[15] = _zz_out_IMM_50;
    _zz_out_IMM_51[14] = _zz_out_IMM_50;
    _zz_out_IMM_51[13] = _zz_out_IMM_50;
    _zz_out_IMM_51[12] = _zz_out_IMM_50;
    _zz_out_IMM_51[11] = _zz_out_IMM_50;
    _zz_out_IMM_51[10] = _zz_out_IMM_50;
    _zz_out_IMM_51[9] = _zz_out_IMM_50;
    _zz_out_IMM_51[8] = _zz_out_IMM_50;
    _zz_out_IMM_51[7] = _zz_out_IMM_50;
    _zz_out_IMM_51[6] = _zz_out_IMM_50;
    _zz_out_IMM_51[5] = _zz_out_IMM_50;
    _zz_out_IMM_51[4] = _zz_out_IMM_50;
    _zz_out_IMM_51[3] = _zz_out_IMM_50;
    _zz_out_IMM_51[2] = _zz_out_IMM_50;
    _zz_out_IMM_51[1] = _zz_out_IMM_50;
    _zz_out_IMM_51[0] = _zz_out_IMM_50;
  end

  assign _zz_out_IMM_52 = {{{{_zz_out_IMM[31],_zz_out_IMM[7]},_zz_out_IMM[30 : 25]},_zz_out_IMM[11 : 8]},1'b0};
  assign _zz_out_IMM_53 = _zz_out_IMM_52[12];
  always @(*) begin
    _zz_out_IMM_54[18] = _zz_out_IMM_53;
    _zz_out_IMM_54[17] = _zz_out_IMM_53;
    _zz_out_IMM_54[16] = _zz_out_IMM_53;
    _zz_out_IMM_54[15] = _zz_out_IMM_53;
    _zz_out_IMM_54[14] = _zz_out_IMM_53;
    _zz_out_IMM_54[13] = _zz_out_IMM_53;
    _zz_out_IMM_54[12] = _zz_out_IMM_53;
    _zz_out_IMM_54[11] = _zz_out_IMM_53;
    _zz_out_IMM_54[10] = _zz_out_IMM_53;
    _zz_out_IMM_54[9] = _zz_out_IMM_53;
    _zz_out_IMM_54[8] = _zz_out_IMM_53;
    _zz_out_IMM_54[7] = _zz_out_IMM_53;
    _zz_out_IMM_54[6] = _zz_out_IMM_53;
    _zz_out_IMM_54[5] = _zz_out_IMM_53;
    _zz_out_IMM_54[4] = _zz_out_IMM_53;
    _zz_out_IMM_54[3] = _zz_out_IMM_53;
    _zz_out_IMM_54[2] = _zz_out_IMM_53;
    _zz_out_IMM_54[1] = _zz_out_IMM_53;
    _zz_out_IMM_54[0] = _zz_out_IMM_53;
  end

  assign _zz_out_IMM_55 = {{{{{_zz_out_IMM[31],_zz_out_IMM[19 : 12]},_zz_out_IMM[20]},_zz_out_IMM[30 : 25]},_zz_out_IMM[24 : 21]},1'b0};
  assign _zz_out_IMM_56 = _zz_out_IMM_55[20];
  always @(*) begin
    _zz_out_IMM_57[10] = _zz_out_IMM_56;
    _zz_out_IMM_57[9] = _zz_out_IMM_56;
    _zz_out_IMM_57[8] = _zz_out_IMM_56;
    _zz_out_IMM_57[7] = _zz_out_IMM_56;
    _zz_out_IMM_57[6] = _zz_out_IMM_56;
    _zz_out_IMM_57[5] = _zz_out_IMM_56;
    _zz_out_IMM_57[4] = _zz_out_IMM_56;
    _zz_out_IMM_57[3] = _zz_out_IMM_56;
    _zz_out_IMM_57[2] = _zz_out_IMM_56;
    _zz_out_IMM_57[1] = _zz_out_IMM_56;
    _zz_out_IMM_57[0] = _zz_out_IMM_56;
  end

  assign _zz_out_IMM_58 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_59 = _zz_out_IMM_58[11];
  always @(*) begin
    _zz_out_IMM_60[19] = _zz_out_IMM_59;
    _zz_out_IMM_60[18] = _zz_out_IMM_59;
    _zz_out_IMM_60[17] = _zz_out_IMM_59;
    _zz_out_IMM_60[16] = _zz_out_IMM_59;
    _zz_out_IMM_60[15] = _zz_out_IMM_59;
    _zz_out_IMM_60[14] = _zz_out_IMM_59;
    _zz_out_IMM_60[13] = _zz_out_IMM_59;
    _zz_out_IMM_60[12] = _zz_out_IMM_59;
    _zz_out_IMM_60[11] = _zz_out_IMM_59;
    _zz_out_IMM_60[10] = _zz_out_IMM_59;
    _zz_out_IMM_60[9] = _zz_out_IMM_59;
    _zz_out_IMM_60[8] = _zz_out_IMM_59;
    _zz_out_IMM_60[7] = _zz_out_IMM_59;
    _zz_out_IMM_60[6] = _zz_out_IMM_59;
    _zz_out_IMM_60[5] = _zz_out_IMM_59;
    _zz_out_IMM_60[4] = _zz_out_IMM_59;
    _zz_out_IMM_60[3] = _zz_out_IMM_59;
    _zz_out_IMM_60[2] = _zz_out_IMM_59;
    _zz_out_IMM_60[1] = _zz_out_IMM_59;
    _zz_out_IMM_60[0] = _zz_out_IMM_59;
  end

  assign _zz_out_IMM_61 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_62 = _zz_out_IMM_61[11];
  always @(*) begin
    _zz_out_IMM_63[19] = _zz_out_IMM_62;
    _zz_out_IMM_63[18] = _zz_out_IMM_62;
    _zz_out_IMM_63[17] = _zz_out_IMM_62;
    _zz_out_IMM_63[16] = _zz_out_IMM_62;
    _zz_out_IMM_63[15] = _zz_out_IMM_62;
    _zz_out_IMM_63[14] = _zz_out_IMM_62;
    _zz_out_IMM_63[13] = _zz_out_IMM_62;
    _zz_out_IMM_63[12] = _zz_out_IMM_62;
    _zz_out_IMM_63[11] = _zz_out_IMM_62;
    _zz_out_IMM_63[10] = _zz_out_IMM_62;
    _zz_out_IMM_63[9] = _zz_out_IMM_62;
    _zz_out_IMM_63[8] = _zz_out_IMM_62;
    _zz_out_IMM_63[7] = _zz_out_IMM_62;
    _zz_out_IMM_63[6] = _zz_out_IMM_62;
    _zz_out_IMM_63[5] = _zz_out_IMM_62;
    _zz_out_IMM_63[4] = _zz_out_IMM_62;
    _zz_out_IMM_63[3] = _zz_out_IMM_62;
    _zz_out_IMM_63[2] = _zz_out_IMM_62;
    _zz_out_IMM_63[1] = _zz_out_IMM_62;
    _zz_out_IMM_63[0] = _zz_out_IMM_62;
  end

  assign _zz_out_IMM_64 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_65 = _zz_out_IMM_64[11];
  always @(*) begin
    _zz_out_IMM_66[19] = _zz_out_IMM_65;
    _zz_out_IMM_66[18] = _zz_out_IMM_65;
    _zz_out_IMM_66[17] = _zz_out_IMM_65;
    _zz_out_IMM_66[16] = _zz_out_IMM_65;
    _zz_out_IMM_66[15] = _zz_out_IMM_65;
    _zz_out_IMM_66[14] = _zz_out_IMM_65;
    _zz_out_IMM_66[13] = _zz_out_IMM_65;
    _zz_out_IMM_66[12] = _zz_out_IMM_65;
    _zz_out_IMM_66[11] = _zz_out_IMM_65;
    _zz_out_IMM_66[10] = _zz_out_IMM_65;
    _zz_out_IMM_66[9] = _zz_out_IMM_65;
    _zz_out_IMM_66[8] = _zz_out_IMM_65;
    _zz_out_IMM_66[7] = _zz_out_IMM_65;
    _zz_out_IMM_66[6] = _zz_out_IMM_65;
    _zz_out_IMM_66[5] = _zz_out_IMM_65;
    _zz_out_IMM_66[4] = _zz_out_IMM_65;
    _zz_out_IMM_66[3] = _zz_out_IMM_65;
    _zz_out_IMM_66[2] = _zz_out_IMM_65;
    _zz_out_IMM_66[1] = _zz_out_IMM_65;
    _zz_out_IMM_66[0] = _zz_out_IMM_65;
  end

  assign _zz_out_IMM_67 = {_zz_out_IMM[31 : 25],_zz_out_IMM[11 : 7]};
  assign _zz_out_IMM_68 = _zz_out_IMM_67[11];
  always @(*) begin
    _zz_out_IMM_69[19] = _zz_out_IMM_68;
    _zz_out_IMM_69[18] = _zz_out_IMM_68;
    _zz_out_IMM_69[17] = _zz_out_IMM_68;
    _zz_out_IMM_69[16] = _zz_out_IMM_68;
    _zz_out_IMM_69[15] = _zz_out_IMM_68;
    _zz_out_IMM_69[14] = _zz_out_IMM_68;
    _zz_out_IMM_69[13] = _zz_out_IMM_68;
    _zz_out_IMM_69[12] = _zz_out_IMM_68;
    _zz_out_IMM_69[11] = _zz_out_IMM_68;
    _zz_out_IMM_69[10] = _zz_out_IMM_68;
    _zz_out_IMM_69[9] = _zz_out_IMM_68;
    _zz_out_IMM_69[8] = _zz_out_IMM_68;
    _zz_out_IMM_69[7] = _zz_out_IMM_68;
    _zz_out_IMM_69[6] = _zz_out_IMM_68;
    _zz_out_IMM_69[5] = _zz_out_IMM_68;
    _zz_out_IMM_69[4] = _zz_out_IMM_68;
    _zz_out_IMM_69[3] = _zz_out_IMM_68;
    _zz_out_IMM_69[2] = _zz_out_IMM_68;
    _zz_out_IMM_69[1] = _zz_out_IMM_68;
    _zz_out_IMM_69[0] = _zz_out_IMM_68;
  end

  assign _zz_out_IMM_70 = {{{{_zz_out_IMM[31],_zz_out_IMM[7]},_zz_out_IMM[30 : 25]},_zz_out_IMM[11 : 8]},1'b0};
  assign _zz_out_IMM_71 = _zz_out_IMM_70[12];
  always @(*) begin
    _zz_out_IMM_72[18] = _zz_out_IMM_71;
    _zz_out_IMM_72[17] = _zz_out_IMM_71;
    _zz_out_IMM_72[16] = _zz_out_IMM_71;
    _zz_out_IMM_72[15] = _zz_out_IMM_71;
    _zz_out_IMM_72[14] = _zz_out_IMM_71;
    _zz_out_IMM_72[13] = _zz_out_IMM_71;
    _zz_out_IMM_72[12] = _zz_out_IMM_71;
    _zz_out_IMM_72[11] = _zz_out_IMM_71;
    _zz_out_IMM_72[10] = _zz_out_IMM_71;
    _zz_out_IMM_72[9] = _zz_out_IMM_71;
    _zz_out_IMM_72[8] = _zz_out_IMM_71;
    _zz_out_IMM_72[7] = _zz_out_IMM_71;
    _zz_out_IMM_72[6] = _zz_out_IMM_71;
    _zz_out_IMM_72[5] = _zz_out_IMM_71;
    _zz_out_IMM_72[4] = _zz_out_IMM_71;
    _zz_out_IMM_72[3] = _zz_out_IMM_71;
    _zz_out_IMM_72[2] = _zz_out_IMM_71;
    _zz_out_IMM_72[1] = _zz_out_IMM_71;
    _zz_out_IMM_72[0] = _zz_out_IMM_71;
  end

  assign _zz_out_IMM_73 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_74 = _zz_out_IMM_73[11];
  always @(*) begin
    _zz_out_IMM_75[19] = _zz_out_IMM_74;
    _zz_out_IMM_75[18] = _zz_out_IMM_74;
    _zz_out_IMM_75[17] = _zz_out_IMM_74;
    _zz_out_IMM_75[16] = _zz_out_IMM_74;
    _zz_out_IMM_75[15] = _zz_out_IMM_74;
    _zz_out_IMM_75[14] = _zz_out_IMM_74;
    _zz_out_IMM_75[13] = _zz_out_IMM_74;
    _zz_out_IMM_75[12] = _zz_out_IMM_74;
    _zz_out_IMM_75[11] = _zz_out_IMM_74;
    _zz_out_IMM_75[10] = _zz_out_IMM_74;
    _zz_out_IMM_75[9] = _zz_out_IMM_74;
    _zz_out_IMM_75[8] = _zz_out_IMM_74;
    _zz_out_IMM_75[7] = _zz_out_IMM_74;
    _zz_out_IMM_75[6] = _zz_out_IMM_74;
    _zz_out_IMM_75[5] = _zz_out_IMM_74;
    _zz_out_IMM_75[4] = _zz_out_IMM_74;
    _zz_out_IMM_75[3] = _zz_out_IMM_74;
    _zz_out_IMM_75[2] = _zz_out_IMM_74;
    _zz_out_IMM_75[1] = _zz_out_IMM_74;
    _zz_out_IMM_75[0] = _zz_out_IMM_74;
  end

  assign _zz_out_IMM_76 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_77 = _zz_out_IMM_76[11];
  always @(*) begin
    _zz_out_IMM_78[19] = _zz_out_IMM_77;
    _zz_out_IMM_78[18] = _zz_out_IMM_77;
    _zz_out_IMM_78[17] = _zz_out_IMM_77;
    _zz_out_IMM_78[16] = _zz_out_IMM_77;
    _zz_out_IMM_78[15] = _zz_out_IMM_77;
    _zz_out_IMM_78[14] = _zz_out_IMM_77;
    _zz_out_IMM_78[13] = _zz_out_IMM_77;
    _zz_out_IMM_78[12] = _zz_out_IMM_77;
    _zz_out_IMM_78[11] = _zz_out_IMM_77;
    _zz_out_IMM_78[10] = _zz_out_IMM_77;
    _zz_out_IMM_78[9] = _zz_out_IMM_77;
    _zz_out_IMM_78[8] = _zz_out_IMM_77;
    _zz_out_IMM_78[7] = _zz_out_IMM_77;
    _zz_out_IMM_78[6] = _zz_out_IMM_77;
    _zz_out_IMM_78[5] = _zz_out_IMM_77;
    _zz_out_IMM_78[4] = _zz_out_IMM_77;
    _zz_out_IMM_78[3] = _zz_out_IMM_77;
    _zz_out_IMM_78[2] = _zz_out_IMM_77;
    _zz_out_IMM_78[1] = _zz_out_IMM_77;
    _zz_out_IMM_78[0] = _zz_out_IMM_77;
  end

  assign _zz_out_IMM_79 = {{{{_zz_out_IMM[31],_zz_out_IMM[7]},_zz_out_IMM[30 : 25]},_zz_out_IMM[11 : 8]},1'b0};
  assign _zz_out_IMM_80 = _zz_out_IMM_79[12];
  always @(*) begin
    _zz_out_IMM_81[18] = _zz_out_IMM_80;
    _zz_out_IMM_81[17] = _zz_out_IMM_80;
    _zz_out_IMM_81[16] = _zz_out_IMM_80;
    _zz_out_IMM_81[15] = _zz_out_IMM_80;
    _zz_out_IMM_81[14] = _zz_out_IMM_80;
    _zz_out_IMM_81[13] = _zz_out_IMM_80;
    _zz_out_IMM_81[12] = _zz_out_IMM_80;
    _zz_out_IMM_81[11] = _zz_out_IMM_80;
    _zz_out_IMM_81[10] = _zz_out_IMM_80;
    _zz_out_IMM_81[9] = _zz_out_IMM_80;
    _zz_out_IMM_81[8] = _zz_out_IMM_80;
    _zz_out_IMM_81[7] = _zz_out_IMM_80;
    _zz_out_IMM_81[6] = _zz_out_IMM_80;
    _zz_out_IMM_81[5] = _zz_out_IMM_80;
    _zz_out_IMM_81[4] = _zz_out_IMM_80;
    _zz_out_IMM_81[3] = _zz_out_IMM_80;
    _zz_out_IMM_81[2] = _zz_out_IMM_80;
    _zz_out_IMM_81[1] = _zz_out_IMM_80;
    _zz_out_IMM_81[0] = _zz_out_IMM_80;
  end

  assign _zz_out_IMM_82 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_83 = _zz_out_IMM_82[11];
  always @(*) begin
    _zz_out_IMM_84[19] = _zz_out_IMM_83;
    _zz_out_IMM_84[18] = _zz_out_IMM_83;
    _zz_out_IMM_84[17] = _zz_out_IMM_83;
    _zz_out_IMM_84[16] = _zz_out_IMM_83;
    _zz_out_IMM_84[15] = _zz_out_IMM_83;
    _zz_out_IMM_84[14] = _zz_out_IMM_83;
    _zz_out_IMM_84[13] = _zz_out_IMM_83;
    _zz_out_IMM_84[12] = _zz_out_IMM_83;
    _zz_out_IMM_84[11] = _zz_out_IMM_83;
    _zz_out_IMM_84[10] = _zz_out_IMM_83;
    _zz_out_IMM_84[9] = _zz_out_IMM_83;
    _zz_out_IMM_84[8] = _zz_out_IMM_83;
    _zz_out_IMM_84[7] = _zz_out_IMM_83;
    _zz_out_IMM_84[6] = _zz_out_IMM_83;
    _zz_out_IMM_84[5] = _zz_out_IMM_83;
    _zz_out_IMM_84[4] = _zz_out_IMM_83;
    _zz_out_IMM_84[3] = _zz_out_IMM_83;
    _zz_out_IMM_84[2] = _zz_out_IMM_83;
    _zz_out_IMM_84[1] = _zz_out_IMM_83;
    _zz_out_IMM_84[0] = _zz_out_IMM_83;
  end

  assign _zz_out_IMM_85 = {_zz_out_IMM[31 : 25],_zz_out_IMM[11 : 7]};
  assign _zz_out_IMM_86 = _zz_out_IMM_85[11];
  always @(*) begin
    _zz_out_IMM_87[19] = _zz_out_IMM_86;
    _zz_out_IMM_87[18] = _zz_out_IMM_86;
    _zz_out_IMM_87[17] = _zz_out_IMM_86;
    _zz_out_IMM_87[16] = _zz_out_IMM_86;
    _zz_out_IMM_87[15] = _zz_out_IMM_86;
    _zz_out_IMM_87[14] = _zz_out_IMM_86;
    _zz_out_IMM_87[13] = _zz_out_IMM_86;
    _zz_out_IMM_87[12] = _zz_out_IMM_86;
    _zz_out_IMM_87[11] = _zz_out_IMM_86;
    _zz_out_IMM_87[10] = _zz_out_IMM_86;
    _zz_out_IMM_87[9] = _zz_out_IMM_86;
    _zz_out_IMM_87[8] = _zz_out_IMM_86;
    _zz_out_IMM_87[7] = _zz_out_IMM_86;
    _zz_out_IMM_87[6] = _zz_out_IMM_86;
    _zz_out_IMM_87[5] = _zz_out_IMM_86;
    _zz_out_IMM_87[4] = _zz_out_IMM_86;
    _zz_out_IMM_87[3] = _zz_out_IMM_86;
    _zz_out_IMM_87[2] = _zz_out_IMM_86;
    _zz_out_IMM_87[1] = _zz_out_IMM_86;
    _zz_out_IMM_87[0] = _zz_out_IMM_86;
  end

  assign _zz_out_IMM_88 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_89 = _zz_out_IMM_88[11];
  always @(*) begin
    _zz_out_IMM_90[19] = _zz_out_IMM_89;
    _zz_out_IMM_90[18] = _zz_out_IMM_89;
    _zz_out_IMM_90[17] = _zz_out_IMM_89;
    _zz_out_IMM_90[16] = _zz_out_IMM_89;
    _zz_out_IMM_90[15] = _zz_out_IMM_89;
    _zz_out_IMM_90[14] = _zz_out_IMM_89;
    _zz_out_IMM_90[13] = _zz_out_IMM_89;
    _zz_out_IMM_90[12] = _zz_out_IMM_89;
    _zz_out_IMM_90[11] = _zz_out_IMM_89;
    _zz_out_IMM_90[10] = _zz_out_IMM_89;
    _zz_out_IMM_90[9] = _zz_out_IMM_89;
    _zz_out_IMM_90[8] = _zz_out_IMM_89;
    _zz_out_IMM_90[7] = _zz_out_IMM_89;
    _zz_out_IMM_90[6] = _zz_out_IMM_89;
    _zz_out_IMM_90[5] = _zz_out_IMM_89;
    _zz_out_IMM_90[4] = _zz_out_IMM_89;
    _zz_out_IMM_90[3] = _zz_out_IMM_89;
    _zz_out_IMM_90[2] = _zz_out_IMM_89;
    _zz_out_IMM_90[1] = _zz_out_IMM_89;
    _zz_out_IMM_90[0] = _zz_out_IMM_89;
  end

  assign _zz_out_IMM_91 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_92 = _zz_out_IMM_91[11];
  always @(*) begin
    _zz_out_IMM_93[19] = _zz_out_IMM_92;
    _zz_out_IMM_93[18] = _zz_out_IMM_92;
    _zz_out_IMM_93[17] = _zz_out_IMM_92;
    _zz_out_IMM_93[16] = _zz_out_IMM_92;
    _zz_out_IMM_93[15] = _zz_out_IMM_92;
    _zz_out_IMM_93[14] = _zz_out_IMM_92;
    _zz_out_IMM_93[13] = _zz_out_IMM_92;
    _zz_out_IMM_93[12] = _zz_out_IMM_92;
    _zz_out_IMM_93[11] = _zz_out_IMM_92;
    _zz_out_IMM_93[10] = _zz_out_IMM_92;
    _zz_out_IMM_93[9] = _zz_out_IMM_92;
    _zz_out_IMM_93[8] = _zz_out_IMM_92;
    _zz_out_IMM_93[7] = _zz_out_IMM_92;
    _zz_out_IMM_93[6] = _zz_out_IMM_92;
    _zz_out_IMM_93[5] = _zz_out_IMM_92;
    _zz_out_IMM_93[4] = _zz_out_IMM_92;
    _zz_out_IMM_93[3] = _zz_out_IMM_92;
    _zz_out_IMM_93[2] = _zz_out_IMM_92;
    _zz_out_IMM_93[1] = _zz_out_IMM_92;
    _zz_out_IMM_93[0] = _zz_out_IMM_92;
  end

  assign _zz_out_IMM_94 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_95 = _zz_out_IMM_94[11];
  always @(*) begin
    _zz_out_IMM_96[19] = _zz_out_IMM_95;
    _zz_out_IMM_96[18] = _zz_out_IMM_95;
    _zz_out_IMM_96[17] = _zz_out_IMM_95;
    _zz_out_IMM_96[16] = _zz_out_IMM_95;
    _zz_out_IMM_96[15] = _zz_out_IMM_95;
    _zz_out_IMM_96[14] = _zz_out_IMM_95;
    _zz_out_IMM_96[13] = _zz_out_IMM_95;
    _zz_out_IMM_96[12] = _zz_out_IMM_95;
    _zz_out_IMM_96[11] = _zz_out_IMM_95;
    _zz_out_IMM_96[10] = _zz_out_IMM_95;
    _zz_out_IMM_96[9] = _zz_out_IMM_95;
    _zz_out_IMM_96[8] = _zz_out_IMM_95;
    _zz_out_IMM_96[7] = _zz_out_IMM_95;
    _zz_out_IMM_96[6] = _zz_out_IMM_95;
    _zz_out_IMM_96[5] = _zz_out_IMM_95;
    _zz_out_IMM_96[4] = _zz_out_IMM_95;
    _zz_out_IMM_96[3] = _zz_out_IMM_95;
    _zz_out_IMM_96[2] = _zz_out_IMM_95;
    _zz_out_IMM_96[1] = _zz_out_IMM_95;
    _zz_out_IMM_96[0] = _zz_out_IMM_95;
  end

  assign _zz_out_IMM_97 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_98 = _zz_out_IMM_97[11];
  always @(*) begin
    _zz_out_IMM_99[19] = _zz_out_IMM_98;
    _zz_out_IMM_99[18] = _zz_out_IMM_98;
    _zz_out_IMM_99[17] = _zz_out_IMM_98;
    _zz_out_IMM_99[16] = _zz_out_IMM_98;
    _zz_out_IMM_99[15] = _zz_out_IMM_98;
    _zz_out_IMM_99[14] = _zz_out_IMM_98;
    _zz_out_IMM_99[13] = _zz_out_IMM_98;
    _zz_out_IMM_99[12] = _zz_out_IMM_98;
    _zz_out_IMM_99[11] = _zz_out_IMM_98;
    _zz_out_IMM_99[10] = _zz_out_IMM_98;
    _zz_out_IMM_99[9] = _zz_out_IMM_98;
    _zz_out_IMM_99[8] = _zz_out_IMM_98;
    _zz_out_IMM_99[7] = _zz_out_IMM_98;
    _zz_out_IMM_99[6] = _zz_out_IMM_98;
    _zz_out_IMM_99[5] = _zz_out_IMM_98;
    _zz_out_IMM_99[4] = _zz_out_IMM_98;
    _zz_out_IMM_99[3] = _zz_out_IMM_98;
    _zz_out_IMM_99[2] = _zz_out_IMM_98;
    _zz_out_IMM_99[1] = _zz_out_IMM_98;
    _zz_out_IMM_99[0] = _zz_out_IMM_98;
  end

  assign _zz_out_IMM_100 = _zz_out_IMM[31 : 20];
  assign _zz_out_IMM_101 = _zz_out_IMM_100[11];
  always @(*) begin
    _zz_out_IMM_102[19] = _zz_out_IMM_101;
    _zz_out_IMM_102[18] = _zz_out_IMM_101;
    _zz_out_IMM_102[17] = _zz_out_IMM_101;
    _zz_out_IMM_102[16] = _zz_out_IMM_101;
    _zz_out_IMM_102[15] = _zz_out_IMM_101;
    _zz_out_IMM_102[14] = _zz_out_IMM_101;
    _zz_out_IMM_102[13] = _zz_out_IMM_101;
    _zz_out_IMM_102[12] = _zz_out_IMM_101;
    _zz_out_IMM_102[11] = _zz_out_IMM_101;
    _zz_out_IMM_102[10] = _zz_out_IMM_101;
    _zz_out_IMM_102[9] = _zz_out_IMM_101;
    _zz_out_IMM_102[8] = _zz_out_IMM_101;
    _zz_out_IMM_102[7] = _zz_out_IMM_101;
    _zz_out_IMM_102[6] = _zz_out_IMM_101;
    _zz_out_IMM_102[5] = _zz_out_IMM_101;
    _zz_out_IMM_102[4] = _zz_out_IMM_101;
    _zz_out_IMM_102[3] = _zz_out_IMM_101;
    _zz_out_IMM_102[2] = _zz_out_IMM_101;
    _zz_out_IMM_102[1] = _zz_out_IMM_101;
    _zz_out_IMM_102[0] = _zz_out_IMM_101;
  end

  assign RegisterFileAccessor_regFileIo_rs1 = value_RS1;
  assign RegisterFileAccessor_regFileIo_rs2 = value_RS2;
  always @(*) begin
    TrapHandler_trapSignals_hasTrapped = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_interruptSignals_hasTrapped;
    end else begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_exceptionSignals_hasTrapped;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapCause = 4'bxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapCause = TrapHandler_interruptSignals_trapCause;
    end else begin
      TrapHandler_trapSignals_trapCause = TrapHandler_exceptionSignals_trapCause;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapVal = TrapHandler_interruptSignals_trapVal;
    end else begin
      TrapHandler_trapSignals_trapVal = TrapHandler_exceptionSignals_trapVal;
    end
  end

  always @(*) begin
    TrapHandler_isInterrupt = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_isInterrupt = 1'b1;
    end
  end

  always @(*) begin
    _out_default_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_PC = in_PC;
  end

  assign out_PC = _out_default_PC;
  always @(*) begin
    _out_default_IR = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_IR = in_IR;
  end

  assign out_IR = _out_default_IR;
  always @(*) begin
    _out_default_NEXT_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_NEXT_PC = in_NEXT_PC;
  end

  assign out_NEXT_PC = _out_default_NEXT_PC;
  always @(*) begin
    _out_default_PREDICTED_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_PREDICTED_PC = in_PREDICTED_PC;
  end

  assign out_PREDICTED_PC = _out_default_PREDICTED_PC;
  assign value_RS1 = out_RS1;
  assign value_RS2 = out_RS2;
  assign value_IR = out_IR;

endmodule

module Stage_IF (
  input  wire          arbitration_isValid,
  input  wire          arbitration_isStalled,
  output reg           arbitration_isReady,
  output wire          arbitration_isDone,
  output wire          arbitration_rs1Needed,
  output wire          arbitration_rs2Needed,
  output wire          arbitration_jumpRequested,
  output wire          arbitration_isAvailable,
  output reg           Fetcher_ibus_cmd_valid,
  input  wire          Fetcher_ibus_cmd_ready,
  output reg  [31:0]   Fetcher_ibus_cmd_payload_address,
  output reg  [1:0]    Fetcher_ibus_cmd_payload_id,
  input  wire          Fetcher_ibus_rsp_valid,
  output wire          Fetcher_ibus_rsp_ready,
  input  wire [31:0]   Fetcher_ibus_rsp_payload_rdata,
  input  wire [1:0]    Fetcher_ibus_rsp_payload_id,
  input  wire [31:0]   in_PC,
  output reg  [31:0]   out_NEXT_PC,
  output reg  [31:0]   out_IR,
  output reg  [31:0]   out_PREDICTED_PC,
  input  wire          in_HAS_TRAPPED,
  output reg           out_HAS_TRAPPED,
  output reg           out_TRAP_IS_INTERRUPT,
  output reg  [3:0]    out_TRAP_CAUSE,
  output reg  [31:0]   out_TRAP_VAL,
  output wire [31:0]   out_PC,
  input  wire          clk,
  input  wire          reset
);

  wire       [29:0]   _zz_when_MemBus_l249;
  wire       [29:0]   _zz_when_MemBus_l249_1;
  wire       [31:0]   _zz__zz_out_IR;
  wire       [31:0]   _out_default_TRAP_VAL;
  wire       [3:0]    _out_default_TRAP_CAUSE;
  wire                _out_default_TRAP_IS_INTERRUPT;
  reg                 _out_default_HAS_TRAPPED;
  wire       [31:0]   _out_default_PREDICTED_PC;
  wire       [31:0]   _out_default_IR;
  wire       [31:0]   _out_default_NEXT_PC;
  wire                TrapHandler_interruptSignals_hasTrapped;
  wire       [3:0]    TrapHandler_interruptSignals_trapCause;
  wire       [31:0]   TrapHandler_interruptSignals_trapVal;
  wire                TrapHandler_exceptionSignals_hasTrapped;
  wire       [3:0]    TrapHandler_exceptionSignals_trapCause;
  wire       [31:0]   TrapHandler_exceptionSignals_trapVal;
  reg                 Fetcher_ibusCtrl_currentCmd_valid;
  reg                 Fetcher_ibusCtrl_currentCmd_ready;
  reg        [31:0]   Fetcher_ibusCtrl_currentCmd_cmd_address;
  reg        [1:0]    Fetcher_ibusCtrl_currentCmd_cmd_id;
  wire                when_MemBus_l189;
  wire       [31:0]   Fetcher_nextPc;
  wire                when_Fetcher_l27;
  reg                 when_Fetcher_l31;
  reg        [31:0]   _zz_out_IR;
  reg                 _zz_when_MemBus_l258;
  reg                 _zz_when_MemBus_l258_1;
  wire                when_MemBus_l246;
  wire                when_MemBus_l249;
  wire                when_MemBus_l258;
  wire       [31:0]   value_NEXT_PC;
  reg                 TrapHandler_trapSignals_hasTrapped;
  reg        [3:0]    TrapHandler_trapSignals_trapCause;
  reg        [31:0]   TrapHandler_trapSignals_trapVal;
  reg                 TrapHandler_isInterrupt;
  reg        [31:0]   _out_default_PC;

  assign _zz_when_MemBus_l249 = (Fetcher_ibusCtrl_currentCmd_cmd_address >>> 2'd2);
  assign _zz_when_MemBus_l249_1 = (in_PC >>> 2'd2);
  assign _zz__zz_out_IR = (Fetcher_ibus_rsp_payload_rdata >>> 5'h0);
  assign _out_default_TRAP_VAL = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_TRAP_VAL = _out_default_TRAP_VAL;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_VAL = TrapHandler_trapSignals_trapVal;
    end
  end

  assign _out_default_TRAP_CAUSE = 4'bxxxx;
  always @(*) begin
    out_TRAP_CAUSE = _out_default_TRAP_CAUSE;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_CAUSE = TrapHandler_trapSignals_trapCause;
    end
  end

  assign _out_default_TRAP_IS_INTERRUPT = 1'bx;
  always @(*) begin
    out_TRAP_IS_INTERRUPT = _out_default_TRAP_IS_INTERRUPT;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_TRAP_IS_INTERRUPT = TrapHandler_isInterrupt;
    end
  end

  always @(*) begin
    _out_default_HAS_TRAPPED = 1'bx;
    _out_default_HAS_TRAPPED = in_HAS_TRAPPED;
  end

  always @(*) begin
    out_HAS_TRAPPED = _out_default_HAS_TRAPPED;
    if(TrapHandler_trapSignals_hasTrapped) begin
      out_HAS_TRAPPED = 1'b1;
    end
  end

  assign _out_default_PREDICTED_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_PREDICTED_PC = _out_default_PREDICTED_PC;
    out_PREDICTED_PC = value_NEXT_PC;
  end

  assign _out_default_IR = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_IR = _out_default_IR;
    if(when_Fetcher_l27) begin
      if(when_Fetcher_l31) begin
        out_IR = _zz_out_IR;
      end
    end
  end

  assign _out_default_NEXT_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    out_NEXT_PC = _out_default_NEXT_PC;
    if(when_Fetcher_l27) begin
      if(when_Fetcher_l31) begin
        out_NEXT_PC = Fetcher_nextPc;
      end
    end
  end

  assign arbitration_isAvailable = ((! arbitration_isValid) || arbitration_isDone);
  always @(*) begin
    arbitration_isReady = 1'b1;
    arbitration_isReady = 1'b0;
    if(when_Fetcher_l27) begin
      if(when_Fetcher_l31) begin
        arbitration_isReady = 1'b1;
      end
    end
  end

  assign arbitration_rs1Needed = 1'b0;
  assign arbitration_rs2Needed = 1'b0;
  assign arbitration_jumpRequested = 1'b0;
  assign arbitration_isDone = ((arbitration_isValid && arbitration_isReady) && (! arbitration_isStalled));
  assign TrapHandler_interruptSignals_hasTrapped = 1'b0;
  assign TrapHandler_interruptSignals_trapCause = 4'bxxxx;
  assign TrapHandler_interruptSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  assign TrapHandler_exceptionSignals_hasTrapped = 1'b0;
  assign TrapHandler_exceptionSignals_trapCause = 4'bxxxx;
  assign TrapHandler_exceptionSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
  always @(*) begin
    Fetcher_ibus_cmd_payload_id = 2'bxx;
    Fetcher_ibus_cmd_payload_id = Fetcher_ibusCtrl_currentCmd_cmd_id;
  end

  always @(*) begin
    Fetcher_ibus_cmd_valid = Fetcher_ibusCtrl_currentCmd_valid;
    if(when_Fetcher_l27) begin
      if(when_MemBus_l246) begin
        Fetcher_ibus_cmd_valid = 1'b1;
      end
    end
  end

  always @(*) begin
    Fetcher_ibus_cmd_payload_address = Fetcher_ibusCtrl_currentCmd_cmd_address;
    if(when_Fetcher_l27) begin
      if(when_MemBus_l246) begin
        Fetcher_ibus_cmd_payload_address = in_PC;
      end
    end
  end

  assign Fetcher_ibus_rsp_ready = 1'b1;
  assign when_MemBus_l189 = (Fetcher_ibus_cmd_valid && Fetcher_ibus_cmd_ready);
  assign Fetcher_nextPc = (in_PC + 32'h00000004);
  assign when_Fetcher_l27 = (! ((! arbitration_isValid) || arbitration_isStalled));
  always @(*) begin
    when_Fetcher_l31 = 1'b0;
    if(Fetcher_ibus_rsp_valid) begin
      if(when_MemBus_l258) begin
        when_Fetcher_l31 = 1'b1;
      end
    end
  end

  always @(*) begin
    _zz_out_IR = 32'h0;
    if(Fetcher_ibus_rsp_valid) begin
      if(when_MemBus_l258) begin
        _zz_out_IR = _zz__zz_out_IR[31 : 0];
      end
    end
  end

  always @(*) begin
    _zz_when_MemBus_l258 = 1'b0;
    if(!when_MemBus_l246) begin
      if(when_MemBus_l249) begin
        _zz_when_MemBus_l258 = 1'b1;
      end
    end
  end

  always @(*) begin
    _zz_when_MemBus_l258_1 = 1'b0;
    if(when_MemBus_l246) begin
      _zz_when_MemBus_l258_1 = 1'b1;
    end
  end

  assign when_MemBus_l246 = (! (Fetcher_ibusCtrl_currentCmd_valid || Fetcher_ibusCtrl_currentCmd_ready));
  assign when_MemBus_l249 = (_zz_when_MemBus_l249 != _zz_when_MemBus_l249_1);
  assign when_MemBus_l258 = (_zz_when_MemBus_l258_1 || ((! _zz_when_MemBus_l258) && (! 1'b0)));
  always @(*) begin
    TrapHandler_trapSignals_hasTrapped = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_interruptSignals_hasTrapped;
    end else begin
      TrapHandler_trapSignals_hasTrapped = TrapHandler_exceptionSignals_hasTrapped;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapCause = 4'bxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapCause = TrapHandler_interruptSignals_trapCause;
    end else begin
      TrapHandler_trapSignals_trapCause = TrapHandler_exceptionSignals_trapCause;
    end
  end

  always @(*) begin
    TrapHandler_trapSignals_trapVal = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_trapSignals_trapVal = TrapHandler_interruptSignals_trapVal;
    end else begin
      TrapHandler_trapSignals_trapVal = TrapHandler_exceptionSignals_trapVal;
    end
  end

  always @(*) begin
    TrapHandler_isInterrupt = 1'b0;
    if(TrapHandler_interruptSignals_hasTrapped) begin
      TrapHandler_isInterrupt = 1'b1;
    end
  end

  always @(*) begin
    _out_default_PC = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    _out_default_PC = in_PC;
  end

  assign out_PC = _out_default_PC;
  assign value_NEXT_PC = out_NEXT_PC;
  always @(posedge clk or posedge reset) begin
    if(reset) begin
      Fetcher_ibusCtrl_currentCmd_valid <= 1'b0;
      Fetcher_ibusCtrl_currentCmd_ready <= 1'b0;
    end else begin
      if(when_MemBus_l189) begin
        Fetcher_ibusCtrl_currentCmd_ready <= 1'b1;
        Fetcher_ibusCtrl_currentCmd_valid <= 1'b0;
      end
      if(Fetcher_ibus_rsp_valid) begin
        Fetcher_ibusCtrl_currentCmd_ready <= 1'b0;
        Fetcher_ibusCtrl_currentCmd_valid <= 1'b0;
      end
      if(when_Fetcher_l27) begin
        if(when_MemBus_l246) begin
          if(Fetcher_ibus_cmd_ready) begin
            Fetcher_ibusCtrl_currentCmd_valid <= 1'b0;
            Fetcher_ibusCtrl_currentCmd_ready <= 1'b1;
          end else begin
            Fetcher_ibusCtrl_currentCmd_valid <= 1'b1;
            Fetcher_ibusCtrl_currentCmd_ready <= 1'b0;
          end
        end
        if(Fetcher_ibus_rsp_valid) begin
          Fetcher_ibusCtrl_currentCmd_valid <= 1'b0;
          Fetcher_ibusCtrl_currentCmd_ready <= 1'b0;
        end
      end
    end
  end

  always @(posedge clk) begin
    Fetcher_ibusCtrl_currentCmd_cmd_id <= 2'bxx;
    if(when_Fetcher_l27) begin
      if(when_MemBus_l246) begin
        Fetcher_ibusCtrl_currentCmd_cmd_address <= in_PC;
      end
    end
  end


endmodule
