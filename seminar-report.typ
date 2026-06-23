#import "@preview/timeliney:0.4.0"

#set page(paper: "a4", margin: 2.45cm)
#set text(font: "New Computer Modern", size: 11pt)
#set par(justify: true, leading: 0.72em, spacing: 0.62em)
#set heading(numbering: "1.")
#set list(spacing: 0.62em)
#set table(inset: 4pt)

#show heading.where(level: 1): it => block(
  above: 1.45em,
  below: 0.9em,
)[#it]

#show heading.where(level: 2): it => block(
  above: 1.2em,
  below: 0.72em,
)[#it]

#show heading.where(level: 3): it => block(
  above: 1.0em,
  below: 0.6em,
)[#it]

#align(center)[
  #text(size: 1.45em, weight: "bold")[
    Efficient Synthesis of Leakage Contracts for Open-Source RISC-V Cores
  ]

  #v(0.45em)
  #text(size: 1.05em)[Seminar Report]
]

#v(0.9em)

#pagebreak()

#outline(
  title: [Contents],
  depth: 2,
)

#pagebreak()

= Introduction

Programs are written for an instruction set architecture (ISA), while the processor implementation is free to choose many internal details. The ISA says which instructions exist, how registers and memory are updated, and which final architectural state a correct processor must produce. It deliberately hides many implementation details. Two processors can implement the same ISA while using different pipelines, caches, branch units, forwarding paths, multipliers, or memory systems. This abstraction is useful for portability, but it is not a complete security interface. Side-channel attacks exploit the difference between what the ISA specifies and what the actual microarchitecture reveals while executing a program.

This report presents the planned thesis work on efficient synthesis of hardware-software leakage contracts for open-source RISC-V processors. The work builds on "Synthesizing Hardware-Software Leakage Contracts for RISC-V Open-Source Processors" by Mohr, Guarnieri, and Reineke [1]. That paper proposes a semi-automatic methodology for deriving leakage contracts from RTL processor designs. It instantiates the methodology for RISC-V and applies it to Ibex [5] and CVA6 [6]. The thesis will keep the same high-level goal: derive processor-specific contracts that describe which ISA-level values a processor may leak through timing-observable microarchitectural behavior.

This thesis proposes a more efficient and more applicable workflow for synthesizing the same class of contracts. The baseline methodology is effective, but it spends substantial effort on many independent test cases, repeatedly rediscovers already known leakage patterns, and pays high fixed cost for each simulation run. This becomes a practical bottleneck when the goal is to cover a broader part of the RISC-V instruction space.

The thesis claim is therefore: contract synthesis can be made more applicable and more efficient by changing how tests are generated, ordered, executed, and reused as evidence. The planned work redesigns the evidence-generation loop so that each unit of simulation time contributes more information toward the final contract.

= Background

== Side Channels and Microarchitecture

A functional specification describes what a program computes. A side channel reveals information through some other observable property of the computation, such as execution time, power consumption, electromagnetic emission, or contention for shared hardware resources. In processor security, timing side channels are especially important because software can often measure timing directly, or can observe timing indirectly through shared resources.

The problem is that timing is heavily influenced by the microarchitecture. For example, a multiplication or division unit may have data-dependent latency. A memory access may hit or miss in a cache. A branch may be predicted correctly or incorrectly. A load may be delayed by an older store or a pipeline hazard. Even if these effects do not change the final architectural state, they can make two executions distinguishable to an attacker.

For secret-dependent software, this distinction matters. Suppose two program executions are architecturally equivalent from the public point of view, but one execution takes a different number of cycles because a secret value changes an operand, an address, or a branch outcome. An attacker who observes the timing behavior can distinguish the two executions and learn information about the secret. The ISA alone does not say whether this behavior is allowed, because the ISA does not specify microarchitectural timing.

== RISC-V Instruction Set Architecture

RISC-V is a modular open ISA [2]. A processor implements a base integer ISA such as RV32I or RV64I and may add extensions such as multiplication/division (M), compressed instructions (C), atomics (A), bit manipulation (B), floating point (F/D), or privileged/system behavior. This modularity is attractive for research because many open-source cores implement different subsets of the same ISA family. Its open and royalty-free nature is also important: researchers can study, modify, and publish processor designs without paying for a proprietary ISA license.

The base integer ISA contains arithmetic, logical, branch, jump, load, and store instructions. Integer registers are named `x0` through `x31`, with `x0` hardwired to zero. RISC-V instructions are grouped into formats such as R-type, I-type, S-type, B-type, U-type, and J-type, which describe where register fields, immediates, opcodes, and function bits are encoded.

The M extension adds multiplication, division, and remainder instructions. The C extension adds shorter 16-bit compressed encodings. The A extension adds atomic memory operations. The B extension adds bit-manipulation instructions. Because RISC-V extensions are optional, two RISC-V processors can both be valid RISC-V cores while supporting different instruction subsets.

== Hardware-Software Leakage Contracts

A hardware-software leakage contract is a processor-specific security interface. It states which ISA-level observations a processor is allowed to reveal through microarchitectural side channels. Examples of such observations include memory addresses, branch outcomes, register identifiers, operand values, result values, and dependency relations between nearby instructions. The contract gives software a processor-specific model of which architectural quantities must be treated as attacker-visible.

The basic unit of such a contract is a contract atom. A contract atom is a possible leakage rule, such as "the source register number leaks", "the value read from `rs1` leaks", "the memory address leaks", "the branch target leaks", or "a read-after-write dependency with a previous instruction leaks". A contract is then a set of selected atoms. The selected set forms an ISA-level leakage model for one processor.

The contract abstracts away from the physical cause of leakage. A timing difference may originate in a cache, memory alignment unit, bus interface, multiplier, divider, or pipeline hazard, but the contract records the corresponding ISA-level information that software must account for.

= Baseline Methodology

The paper by Mohr, Guarnieri, and Reineke provides the starting point for this thesis [1]. Its methodology takes two inputs: a contract template and an RTL processor implementation. The template defines the search space of possible leakage atoms. The RTL model is then tested to determine which atoms are needed to explain the attacker's observations. For a given ISA implementation, the method synthesizes a precise contract that is satisfied by the tested behavior of the microarchitecture.

The central idea is to generate paired ISA-level test programs. The two programs in a pair have controlled architectural differences. The framework runs the pair on the processor model and asks two questions.

- Are the two executions attacker-distinguishable? In the current setting, this is obtained from RTL simulation and cycle-level observations, such as retirement timing or equivalent attacker-visible signals.
- Which contract atoms differ between the two programs? This is atom distinguishability. It is determined by evaluating the contract template on the two ISA executions.

Each test case therefore produces an evidence record. A simplified record says: this pair was or was not attacker-distinguishable, and these are the atoms that differ between the two executions. If a pair differs in atoms `{A, B, C}` and the attacker can distinguish it, then at least one of `A`, `B`, or `C` must be included in the contract to explain the leak. If a pair differs in `{A, B, C}` and the attacker cannot distinguish it, then selecting these atoms may create false positives, because the contract would predict leakage where the tested processor behavior did not show it.

The final synthesis step is an integer linear programming (ILP) problem. The ILP must choose atoms that cover attacker-distinguishable test cases while minimizing false positives on attacker-indistinguishable test cases. In other words, the contract should explain observed leaks, but it should not over-approximate too much. This is the key precision goal.

The original implementation applies this methodology to open-source RISC-V cores, especially Ibex [5] and CVA6 [6]. This is a good research starting point because the RTL is available, the cores are practically relevant, and the RISC-V ISA gives a clear architectural vocabulary for contract atoms.

= Limitations of the Baseline Workflow

The baseline workflow is conceptually clean, but the practical evidence loop is expensive. It treats generated tests mostly as independent units. Each selected test pays setup, simulation, trace generation, extraction, and result-processing cost. This is acceptable for small experiments, but it becomes inefficient when the framework needs millions of tests or when the same workflow should be applied to several cores.

The first issue is the current implementation path. Each testcase is handled through a heavy simulation and trace-processing workflow: test inputs are materialized, Icarus Verilog is driven externally, traces are produced, and Java code parses the resulting output before the synthesis step can use it. This makes every testcase expensive even when the actual program fragment is small. It also makes large runs dependent on file-based simulator orchestration and trace parsing, which limits how quickly evidence can be collected.

The second issue is redundant positive evidence. If a previously tested pair with atom signature `{A, B}` is attacker-distinguishable, then a later attacker-distinguishable pair with `{A, B, C}` often adds little positive information. The later pair can still be explained by selecting `A` or `B`; it does not force the ILP to learn anything new unless the framework can isolate `C` or rule out the smaller explanation. This means that a purely static generator can spend many simulations on tests that repeat already sufficient leakage evidence.

The third issue is redundant negative evidence. If many tests with the same or closely related atom signatures are attacker-indistinguishable, then additional similar negative tests have diminishing value. They may increase confidence, but they may not be the best use of simulation time once the framework already has enough evidence for that region of the search space.

The fourth issue is ambiguity in generated tests. A test may target one atom but accidentally vary many other atoms through setup instructions, suffix instructions, dependencies, branch behavior, or derived values. For example, changing a source operand value may also change a producer instruction's immediate, a result value, or a later branch outcome. Sending large ambiguous atom sets directly to the ILP can reduce precision. The solver receives a valid constraint, but the constraint may be too coarse to identify the actual leakage cause.

These limitations motivate a workflow that separates cheap ISA-level analysis from expensive RTL execution, batches work to amortize fixed cost, and adapts future tests based on previous evidence.

= Planned Thesis Contribution

The thesis will pursue three directions: improve practical execution, get more information per test and per unit time, and increase applicability to more RISC-V cores and ISA features.

== Improve Practical Execution

The first direction is to make the RTL execution path cheaper. The planned implementation will use Verilator [4] to expose the processor model through a direct API. Testcases, instruction memories, data memories, and register inputs can then be fed into the model without launching a fresh external process for every small test.

In the proposed workflow, RTL simulation is mainly responsible for learning attacker distinguishability: the timing or attacker-visible behavior chosen for the experiment determines whether the two executions are distinguishable. The RTL side should therefore return a compact result for the program pair, not a large trace that must later be searched for all contract atoms.

The second practical change is to use Spike or another ISA-level execution path for atom distinguishability. Spike is the RISC-V ISA simulator used as a functional model for RISC-V programs [3]. Atom distinguishability is an ISA-level property of the paired programs and the contract template. It should not require waveform extraction from the RTL model. Separating these two tasks gives a cleaner division of labor: Spike or the ISA evaluator computes which atoms differ, while the Verilated RTL model answers whether the attacker can distinguish the pair.

The third practical change is batching. Many tests share a common setup structure, atom signature, or execution harness. If setup is expensive but executing one more block is cheap, then running repeated or related blocks in one batch can be much cheaper than handling each small test independently. Batching also fits an adaptive loop: run a batch, analyze the evidence, update priorities, and then choose the next batch.

== Get More Information Per Test Case

The second direction is to make test selection evidence-aware. An attacker-distinguishable testcase gives the strongest positive evidence when its atom signature is small, because then the leak is explained by only a few possible atoms. A testcase with signature `{A}` is much more informative than a testcase with `{A, B, C, D}`, since the ILP has less freedom to choose an unrelated explanation.

This also means that supersets of already known attacker-distinguishable signatures have low value. If `{A, B}` already leaked, then a later leaking testcase with `{A, B, C}` usually does not give a more precise explanation. The framework can skip or down-rank such candidates and spend simulation time on signatures that are smaller, different, or useful for separating an ambiguous case.

Attacker-indistinguishable tests have the opposite shape. A negative testcase with many differing atoms rules out a larger set of possible false positives at once. A negative testcase with `{A, B, C, D}` is therefore useful evidence that none of those differences were enough to affect the attacker observation in that context. Repeating the same small negative signature many times is less useful, so the framework should down-rank repeated negative subsets after enough evidence has been collected.

For ambiguous leaking cases, targeted follow-up tests can reduce the atom signature by removing random prefixes, random suffixes, or unnecessary setup while preserving the suspected target behavior.

Some observations cannot be fully separated. Memory address and address components are related: `MEM_ADDR` is computed from a base register and an immediate. A `LUI` result is directly determined by its immediate. In such cases, the goal is not perfect isolation. The goal is to produce tighter constraints, such as compensating tests that keep the final address constant while varying the components, or tests that vary the address while keeping one component fixed. These refinements still give the ILP more precise evidence than a single large ambiguous atom set.

The expected effect is that simulation time is focused on tests that can change the final contract, reduce ambiguity, or increase confidence in underexplored parts of the search space.

== Increase Applicability

The third direction is to apply the improved workflow to more RISC-V cores and a broader ISA space. Different cores have different pipelines, memories, branch behavior, multiplier/divider implementations, and verification interfaces, so each core needs its own contract-synthesis run.

For each core, the integration work has three main parts: a build path for the Verilated model, an API for feeding program pairs and initial state, and a small attacker-observation interface that reports attacker distinguishability. Atom distinguishability is handled at the ISA level, so the core-specific RTL side does not need to expose every contract atom.

The current repository already contains integrations or resource directories for Ibex, CVA6, Hazard3, Sodor 2/5, and DarkRISCV 2/3. These cores already exist in the baseline framework, but they still need to be adapted to the new workflow with full Verilator execution, batched testcase feeding, and ISA-level atom distinguishability. The other cores in the table describe the planned direction for extending processor coverage.

#table(
  columns: (1.15fr, 3fr),
  table.header([*Core*], [*Role in the thesis scope*]),
  [Ibex, CVA6, Hazard3, Sodor 2/5, DarkRISCV 2/3], [Existing baseline cores; adapt to the new workflow [5-9].],
  [CV32E40P/S], [Practical RV32 CORE-V targets [10].],
  [FWRISC], [Small RV32 in-order target [11].],
  [Piccolo], [RV32 BSV-based target [12].],
  [Flute], [RV64 in-order core with MMU support [13].],
  [Rocket], [RV64 in-order Chisel-generated core [14].],
  [C906], [RV64 in-order core with richer ISA variants [15].],
  [BOOM / RiscyOO / Toooba], [Out-of-order RV64 cores for reordering-sensitive leakage checks [16-18].],
  [XiangShan], [Wide RV64 out-of-order core for a high-complexity scalability target [19].],
)

For ISA coverage, the current implementation supports the RISC-V base integer subset and the multiplication/division subset, corresponding to RV32I-style base instructions and the M extension. The thesis will use these as the initial stable target. The planned investigation will then consider extensions when they are supported by the chosen cores and when the generator, ISA-level atom evaluator, and contract template can be extended consistently.

The most reasonable extensions to investigate are:

- CSR and system instructions, because control and counter state can affect timing and observability.
- A, atomic instructions, because they interact with memory ordering and bus behavior.
- C, compressed instructions, because it changes instruction encoding, fetch behavior, and program layout.
- B, bit manipulation, because it introduces data-processing instructions that may have value-dependent behavior.
- Selected RV64 support, where later cores require it, especially for Rocket, BOOM, or XiangShan.

For each extension, the thesis must update the instruction generator, ISA execution or atom evaluator, contract atoms, and tests that consume the new atoms.

= Evaluation Plan

The evaluation will compare the baseline workflow and the proposed workflow along runtime, sensitivity, and precision.

Runtime evaluation will report per-testcase execution time and total processing time for the same workload. These measurements quantify where time is spent in the pipeline and how much throughput improves after changing the execution path.

Sensitivity will be measured by how much leakage evidence the executed testcases reveal. The important quantities are the number of attacker-distinguishable cases discovered, the number of new leakage signatures reached, and how early those signatures appear during the run. This evaluates the impact of adaptive testcase selection on leakage discovery.

Precision will be measured through the quality of the synthesized contract. The contract should cover observed leakages while avoiding unnecessary false positives on evaluation testcases. The evaluation should also identify which selected atoms contribute most to false-positive behavior, because those atoms show where the contract is too broad or where the collected evidence was not specific enough.

= Work Plan

- Adapt Spike for atom distinguishability. The framework will execute each program pair at the ISA level, compute the differing contract atoms from the two architectural traces, and emit the atom signature in the same format expected by the synthesis pipeline.
- Implement the full Verilator API path. The Verilated core will be used through a direct interface that can load program pairs, initialize register and memory state, run the simulation, and return attacker distinguishability for the pair.
- Make the current workflow adaptive. The generator and evaluator will maintain evidence state across tests, including known leaking signatures, repeated negative signatures, and ambiguous signatures that should be reduced by follow-up tests.
- Add evidence prioritization and batching. Candidate tests will be ordered by expected usefulness, redundant candidates will be skipped or delayed, and related candidates will be grouped when they can be evaluated together.
- Extend the implementation to more cores and ISA extensions while evaluating continuously. Each new core or extension will be integrated into the same adaptive workflow and measured for leakage discovery speed, sensitivity over time, redundancy avoided, and final contract quality.
- Write the results. The thesis will describe the implemented workflow, the supported cores and extensions, the evaluation setup, the measured results, and the remaining limitations.

#v(0.5em)
#align(center)[#text(weight: "bold")[Planned Timeline]]

#v(0.25em)
#set text(size: 8.6pt)
#timeliney.timeline(
  show-grid: true,
  {
    import timeliney: *

    headerline(
      group(([*Month 1*], 1)),
      group(([*Month 2*], 1)),
      group(([*Month 3*], 1)),
      group(([*Month 4*], 1)),
      group(([*Month 5*], 1)),
      group(([*Month 6*], 1)),
    )

    taskgroup(title: [*Required*], {
      task("Spike atom distinguishability", (0, 0.8), style: (stroke: 5pt + rgb("#4f6f9f")))
      task("Adaptive workflow", (1.1, 2.8), style: (stroke: 5pt + rgb("#5b8f6a")))
      task("Verilator API + existing cores", (0.8, 3.8), style: (stroke: 5pt + rgb("#4f6f9f")))
      task("Evaluation", (1.2, 5.2), style: (stroke: 5pt + rgb("#8a6f45")))
      task("Writing", (3.2, 6.0), style: (stroke: 5pt + rgb("#8a6f45")))
    })

    taskgroup(title: [*Optional / stretch*], {
      task("Additional cores", (3.0, 5.4), style: (stroke: (paint: rgb("#8b8b8b"), thickness: 4pt, dash: "dashed")))
      task("Additional ISA extensions", (3.2, 5.4), style: (stroke: (paint: rgb("#8b8b8b"), thickness: 4pt, dash: "dashed")))
    })

    milestone(
      at: 2.8,
      style: (stroke: (paint: rgb("#9b4d4d"), dash: "dashed")),
      align(center)[Core framework usable],
    )
  },
)
#set text(size: 11pt)

= Summary

Hardware-software leakage contracts provide a way to describe the side-channel security interface of a specific processor at the ISA level. The prior methodology shows how to synthesize such contracts from generated tests and RTL simulation. This thesis will keep that contract-synthesis goal but make the workflow more efficient and more broadly applicable.

The planned work is to add full Verilator support, separate ISA-level atom distinguishability from RTL attacker distinguishability, batch repeated work, use positive and negative evidence to guide future tests, reduce ambiguous leaking testcases, and apply the improved workflow to several open-source RISC-V cores. The expected outcome is a toolchain that finds leakages faster, reaches higher sensitivity earlier, avoids many redundant simulations, and supports contract synthesis for a wider set of RISC-V processors.

#pagebreak()

= References

#set par(spacing: 0.45em)

[1] Gideon Mohr, Marco Guarnieri, and Jan Reineke. 2024. Synthesizing Hardware-Software Leakage Contracts for RISC-V Open-Source Processors. In Proceedings of the 27th Design, Automation and Test in Europe Conference and Exhibition (DATE). ACM/IEEE.

[2] RISC-V International. "RISC-V." https://riscv.org/

[3] riscv-software-src. "riscv-isa-sim: Spike, a RISC-V ISA Simulator." https://github.com/riscv-software-src/riscv-isa-sim

[4] Verilator Project. "Verilator Documentation." https://verilator.org/guide/latest/

[5] lowRISC. "Ibex: An embedded 32 bit RISC-V CPU core." https://github.com/lowRISC/ibex

[6] OpenHW Group. "CVA6: Application class RISC-V CPU core." https://github.com/openhwgroup/cva6

[7] Luke Wren. "Hazard3: A compact 3-stage RISC-V processor." https://github.com/Wren6991/Hazard3

[8] UCB-BAR. "riscv-sodor: Educational microarchitectures for the RISC-V ISA." https://github.com/ucb-bar/riscv-sodor

[9] darklife. "DarkRISCV: Open-source RISC-V CPU core." https://github.com/darklife/darkriscv

[10] OpenHW Group. "CORE-V cores." https://github.com/openhwgroup/core-v-cores

[11] Matthew Ballance. "FWRISC: Featherweight RISC-V RV32I implementation." https://github.com/mballance/fwrisc

[12] Bluespec, Inc. "Piccolo: RISC-V CPU, simple 3-stage pipeline." https://github.com/bluespec/Piccolo

[13] Bluespec, Inc. "Flute: RISC-V CPU, simple 5-stage in-order pipeline." https://github.com/bluespec/Flute

[14] Berkeley Architecture Research. "Rocket Chip Generator." https://bar.eecs.berkeley.edu/projects/rocket_chip.html

[15] T-Head Semiconductor. "OpenC906." https://github.com/T-head-Semi/openc906

[16] Berkeley Architecture Research. "BOOM: The Berkeley Out-of-Order RISC-V Processor." https://github.com/riscv-boom/riscv-boom

[17] MIT CSAIL CSG. "riscy-OOO." https://github.com/csail-csg/riscy-OOO

[18] Bluespec, Inc. "Toooba: Out-of-order RV64 processor." https://github.com/bluespec/Toooba

[19] OpenXiangShan. "XiangShan: Open-source high-performance RISC-V processor." https://github.com/OpenXiangShan/XiangShan
