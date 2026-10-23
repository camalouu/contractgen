// Exercise the same extraction code compiled into the public Spike library.
#define main contract_spike_cli_main
#include "contract-spike-diff.cc"
#undef main
#include <cassert>

std::vector<sample> samples(const std::vector<program_insn>& program) {
  std::vector<sample> trace(INIT_COUNT + program.size());
  for (auto& s : trace) s.instr = NOP;
  for (size_t i = 0; i < program.size(); ++i) trace[INIT_COUNT + i].instr = encode(program[i]);
  return trace;
}

int main() {
  for (const std::string producer : {"ADD", "ADDI", "LB", "LBU", "LH", "LHU", "LW", "MUL", "DIV", "REM"}) {
    const bool immediate = producer == "ADDI" || producer[0] == 'L';
    for (int distance = 1; distance <= 4; ++distance) {
      for (const std::string relation : {"RAW_RS1", "RAW_RS2", "WAW"}) {
        program_insn writer{producer, 20, 2, immediate ? std::nullopt : std::optional<int64_t>(3),
                            immediate ? std::optional<int64_t>(0) : std::nullopt};
        std::vector<program_insn> left{writer}, right{writer};
        right[0].rd = 1;
        for (int i = 1; i < distance; ++i) {
          left.push_back({"ADDI", 0, 0, {}, 0});
          right.push_back(left.back());
        }
        program_insn reader{"ADD", relation == "WAW" ? 20 : 21,
                             relation == "RAW_RS1" ? 20 : 22,
                             relation == "RAW_RS2" ? 20 : 23, {}};
        left.push_back(reader); right.push_back(reader);
        auto evidence = extract_evidence(samples(left), samples(right));
        atom expected{producer, relation + "_" + std::to_string(distance)};
        assert(evidence.atoms.count(expected));
        assert(evidence.atoms.at(expected) == INIT_COUNT + distance + 1);
        auto different_consumer = left;
        different_consumer.back().type = "SUB";
        auto opcode_only = extract_evidence(samples(left), samples(different_consumer));
        assert(!opcode_only.atoms.count(expected));
        auto identical = extract_evidence(samples(left), samples(left));
        assert(identical.atoms.empty());
      }
    }
  }
  // Both sides retain RAW, but producer-specific boolean predicates differ.
  auto lw_mul = samples({{"LW",20,0,{},0},{"MUL",21,20,23,{}}});
  auto add_mul = samples({{"ADD",20,2,3,{}},{"MUL",21,20,23,{}}});
  auto producer_swap = extract_evidence(lw_mul, add_mul);
  assert(producer_swap.atoms.count(atom{"LW","RAW_RS1_1"}));
  assert(producer_swap.atoms.count(atom{"ADD","RAW_RS1_1"}));
  auto lw_add = samples({{"LW",20,0,{},0},{"ADD",21,20,23,{}}});
  auto consumer_swap = extract_evidence(lw_mul, lw_add);
  assert(!consumer_swap.atoms.count(atom{"LW","RAW_RS1_1"}));
  assert(dependency_atoms(lw_mul, lw_mul.size()-1).size() == 1);
  assert(dependency_atoms(lw_add, lw_add.size()-1).count(atom{"LW","RAW_RS1_1"}));
  // Merely having RD/RS fields on one side is not a true dependency.
  auto unrelated = samples({{"LW",1,0,{},0},{"MUL",21,20,23,{}}});
  auto no_writer = samples({{"SW",{},0,2,0},{"MUL",21,20,23,{}}});
  for (const auto& [a, _] : extract_evidence(unrelated,no_writer).atoms)
    assert(a.observation.find("RAW_") != 0 && a.observation.find("WAW_") != 0);
  // x0 writes and immediate shift bits are never register dependencies.
  auto zero = samples({{"ADD",0,2,3,{}},{"ADD",21,0,23,{}}});
  assert(dependency_atoms(zero, zero.size()-1).empty());
  auto shift = samples({{"ADD",20,2,3,{}},{"SLLI",21,22,20,{}}});
  assert(dependency_atoms(shift, shift.size()-1).empty());
  // An intervening write shadows the earlier RAW source, even if values match.
  auto shadow = samples({{"LW",20,0,{},0},{"ADD",20,2,3,{}},{"MUL",21,20,23,{}}});
  auto shadow_atoms = dependency_atoms(shadow, shadow.size()-1);
  assert(!shadow_atoms.count(atom{"LW","RAW_RS1_2"}));
  assert(shadow_atoms.count(atom{"ADD","RAW_RS1_1"}));
  // Public JSON attributes dependencies to the producer, with a distinct schema.
  std::ostringstream out;
  write_atoms(out, producer_swap.atoms);
  assert(out.str().find("\"type\":\"LW\"") != std::string::npos);
  assert(out.str().find("\"producer\"") == std::string::npos);
  std::ostringstream batch;
  write_results(batch, {});
  assert(batch.str().find("\"atom_schema\":\"producer-attributed-dependencies-v1\"") != std::string::npos);
  spike_runner runner("RV32IM");
  test_case tc;
  tc.max_instruction_count=3;
  tc.program1={{"LW",20,0,{},0},{"MUL",21,20,23,{}}};
  tc.program2={{"LW",1,0,{},0},{"MUL",21,20,23,{}}};
  auto executed=run_case(tc,runner);
  assert(!executed.error && executed.atoms.count(atom{"LW","RAW_RS1_1"}));
  std::cout << "Producer-attributed dependency checks passed\n";
}
