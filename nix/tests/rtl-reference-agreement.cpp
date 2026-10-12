#define main contract_spike_cli_main
#include "contract-spike-diff.cc"
#undef main
#include <dlfcn.h>
#include <array>
#include <cassert>
#include <random>

int main(int argc, char** argv) {
  if (argc < 2 || argc > 4) throw std::runtime_error("Expected a harness library with contract_architectural_trace_v1");
  void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) throw std::runtime_error(dlerror());
  using trace_fn = int (*)(const uint32_t*, int, int, uint32_t*, uint32_t*);
  auto trace = reinterpret_cast<trace_fn>(dlsym(library, "contract_architectural_trace_v1"));
  if (!trace) throw std::runtime_error("Missing architectural conformance ABI");
  const std::string isa = argc > 2 ? argv[2] : "RV32IM";
  const bool has_m = isa == "RV32IM";
  spike_runner spike(isa);
  unsigned cases = 0;
  auto constant = [](int reg, uint32_t value) {
    return std::vector<program_insn>{{"LUI",reg,{},{},uint32_t(value + 0x800) & 0xfffff000u},
        {"ADDI",reg,reg,{},int32_t(sext(value & 4095,12))}};
  };
  auto check = [&](const std::vector<program_insn>& program, int count = 160) {
    auto words = words_for({}, program, count - 31, execution_model::rv32_v1);
    const auto reference = spike.run_side(words, count);
    std::vector<uint32_t> pcs(count);
    std::array<uint32_t,32> registers{};
    const int status = trace(words.data(), count, 30000, pcs.data(), registers.data());
    if(status != 0) throw std::runtime_error("RTL diagnostic failed in case " + std::to_string(cases) + ": " + std::to_string(status));
    std::array<uint32_t,32> expected{};
    for (size_t i=0; i<reference.size(); ++i) {
      if (pcs[i] != reference[i].pc)
        throw std::runtime_error("Retirement PC mismatch in case " + std::to_string(cases)
            + " at retirement " + std::to_string(i + 1) + " expected PC=" + std::to_string(reference[i].pc) + " RTL PC=" + std::to_string(pcs[i]));
      const auto decoded = decode(reference[i].instr);
      if (decoded.rd && *decoded.rd) expected[*decoded.rd] = uint32_t(reference[i].reg_rd);
    }
    for (unsigned reg=0;reg<32;++reg) {
      if (registers[reg] != expected[reg])
        std::cerr << "case " << cases << " x" << reg << " expected " << std::hex << expected[reg] << " got " << registers[reg] << std::dec << '\n';
      assert(registers[reg] == expected[reg]);
    }
    ++cases;
  };
  for (const std::string op : {"ADD","SUB","SLL","SLT","SLTU","XOR","SRL","SRA","OR","AND","MUL","MULH","MULHSU","MULHU","DIV","DIVU","REM","REMU"}) {
    if (has_m || op == "ADD" || op == "SUB" || op == "SLL" || op == "SLT" || op == "SLTU" || op == "XOR" || op == "SRL" || op == "SRA" || op == "OR" || op == "AND")
    for (uint32_t left : {0u,1u,0xffffffffu,0x80000000u,0x7fffffffu,0xffff0000u})
      for (uint32_t right : {0u,1u,0xffffffffu,31u,32u,0x80000000u}) {
        auto program = constant(1,left), operand = constant(2,right);
        program.insert(program.end(),operand.begin(),operand.end());
        program.push_back({op,3,1,2,{}}); program.push_back({"ADDI",4,3,{},1});
        check(program);
      }
  }
  for (const std::string op : {"ADDI","SLTI","SLTIU","XORI","ORI","ANDI"})
    for (uint32_t value : {0u,1u,0xffffffffu,0x80000000u,0x7fffffffu,0xffff0000u})
      for (int immediate : {-2048,-17,-1,0,1,17,2047}) {
        auto program = constant(1,value);
        program.push_back({op,2,1,{},immediate}); program.push_back({"ADDI",3,2,{},1});
        check(program);
      }
  for (const std::string op : {"SLLI","SRLI","SRAI"})
    for (uint32_t value : {0u,1u,0xffffffffu,0x80000000u,0x7fffffffu,0xffff0000u})
      for (int shift : {0,1,15,30,31}) {
        auto program = constant(1,value);
        program.push_back({op,2,1,shift,{}}); program.push_back({"ADDI",3,2,{},1});
        check(program);
      }
  check({{"AUIPC",1,{},{},0},{"JAL",2,{},{},8},{"ADDI",4,0,{},7},{"JALR",3,2,{},0}});
  for (const std::string op : {"BEQ","BNE","BLT","BGE","BLTU","BGEU"})
    for (int value : {-1,0,1,2})
      check({{"ADDI",1,0,{},value},{"ADDI",2,0,{},1},{op,{},1,2,8},{"ADDI",3,0,{},7},{"ADDI",4,0,{},9}});
  std::vector<program_insn> memory{{"ADDI",1,0,{},-128}};
  for(int lane=0;lane<4;++lane) memory.push_back({"SB",{},0,1,lane});
  for(int lane=0;lane<4;++lane) memory.push_back({"LB",2+lane,0,{},lane});
  memory.push_back({"SH",{},0,1,2});
  memory.push_back({"LH",6,0,{},2}); memory.push_back({"LHU",7,0,{},2});
  memory.push_back({"LW",8,0,{},0});
  for(int i=4;i<400;++i) memory.push_back({"SB",{},0,1,i});
  memory.push_back({"LBU",9,0,{},0}); check(memory,500);
  std::vector<program_insn> conflicts{{"ADDI",1,0,{},123}};
  for(int i=0;i<12;++i){conflicts.push_back({"LUI",2,{},{},i*4096});conflicts.push_back({"SW",{},2,1,0});}
  for(int i=0;i<12;++i){conflicts.push_back({"LUI",2,{},{},i*4096});conflicts.push_back({"LW",3+i,2,{},0});}
  check(conflicts);
  check({{"ADDI",1,0,{},-4},{"JALR",0,1,{},0}},100);
  // Address overlap, page boundaries, high addresses and byte lanes in both
  // halves of the 64-bit memory interface are exercised through dependent loads.
  for (uint32_t address : {0u,0x100u,4092u,4096u,0xfffffff8u}) {
    auto program = constant(1,address), value = constant(2,0x89abcdefu);
    program.insert(program.end(),value.begin(),value.end());
    for (int lane=0;lane<8;++lane) {
      program.push_back({"SB",{},1,2,lane});
      program.push_back({"LBU",3+lane,1,{},lane});
      program.push_back({"LB",11+lane,1,{},lane});
    }
    for (int lane : {0,2,4,6}) {
      program.push_back({"SH",{},1,2,lane});
      program.push_back({"LHU",19+lane,1,{},lane});
      program.push_back({"LH",20+lane,1,{},lane});
    }
    program.push_back({"SW",{},1,2,4}); program.push_back({"LW",28,1,{},4});
    program.push_back({"ADDI",0,28,{},123}); program.push_back({"ADDI",29,0,{},1});
    check(program);
  }
  // Mixed instructions repeatedly overwrite registers. A dependent rolling sum
  // retains intermediate results which final-register checks alone could lose.
  std::mt19937 random(0x52495343);
  std::vector<std::string> operations{"ADD","SUB","XOR","OR","AND","SLT","SLTU",
      "SLL","SRL","SRA","MUL","MULH","MULHSU","MULHU","DIV","DIVU","REM","REMU"};
  if(!has_m) operations.resize(10);
  for (int n=0;n<100;++n) {
    std::vector<program_insn> program;
    for (int reg=1;reg<=8;++reg) {
      auto value = constant(reg,random()); program.insert(program.end(),value.begin(),value.end());
    }
    for (int instruction=0;instruction<64;++instruction) {
      int rd=1+random()%8, rs1=random()%9, rs2=random()%9;
      program.push_back({operations[random()%operations.size()],rd,rs1,rs2,{}});
      program.push_back({"ADD",31,31,rd,{}});
    }
    check(program,240);
  }
  check({{"ADDI",1,0,{},123}},33);
  check({{"ADDI",1,0,{},-128},{"SB",{},0,1,3},{"LB",2,0,{},3}},35);
  check({{"ADDI",1,0,{},123},{"SW",{},0,1,0},{"LW",2,0,{},0}},35);
  if(has_m) check({{"ADDI",1,0,{},-17},{"ADDI",2,0,{},3},{"DIV",3,1,2,{}}},35);
  check({{"ADDI",1,0,{},0x78},{"JALR",0,1,{},0}},100);
  check({{"LW",1,0,{},0x100},{"ADDI",2,1,{},1}});
  check({{"ADDI",1,0,{},0x108},{"ADDI",2,0,{},123},{"SW",{},1,2,0},{"ADDI",3,0,{},7},{"LW",4,1,{},0}});
  if(argc > 3 && std::string(argv[3])=="misaligned")
    for(uint32_t address : {1u,2u,3u,4093u,4094u,4095u,0xfffffffdu,0xfffffffeu,0xffffffffu}) {
      auto program=constant(1,address),value=constant(2,0x80ff7e01u);
      program.insert(program.end(),value.begin(),value.end());
      program.push_back({"SW",{},1,2,0}); program.push_back({"LW",3,1,{},0});
      program.push_back({"LH",4,1,{},1}); program.push_back({"LHU",5,1,{},1});
      program.push_back({"SH",{},1,2,1}); program.push_back({"LW",6,1,{},0});
      check(program);
    }
  dlclose(library);
  std::cout << "Spike/RTL agreement passed for " << cases << " directed programs (every retirement PC and final architectural registers)\n";
}
