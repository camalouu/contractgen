package contractgen.riscv.isa;

import contractgen.TestResult;
import contractgen.Program;
import contractgen.TestCase;

/**
 * A RISC-V test case.
 */
public class RISCVTestCase extends TestCase {
    private contractgen.riscv.isa.tests.GenerationTarget generationTarget;
    public contractgen.riscv.isa.tests.GenerationTarget getGenerationTarget() { return generationTarget; }
    public void setGenerationTarget(contractgen.riscv.isa.tests.GenerationTarget target) { generationTarget=target; }
    private contractgen.riscv.isa.tests.SetupEvidence setupEvidence;
    public contractgen.riscv.isa.tests.SetupEvidence getSetupEvidence() { return setupEvidence; }
    public void setSetupEvidence(contractgen.riscv.isa.tests.SetupEvidence metadata) {
        if (metadata != null && (metadata.setupInstructions() > ((RISCVProgram)getProgram1()).getProgram().size()
                || metadata.setupInstructions() > ((RISCVProgram)getProgram2()).getProgram().size()
                || metadata.setupInstructions() > getMaxInstructionCount()))
            throw new IllegalArgumentException("Setup boundary exceeds program or retirement bound");
        setupEvidence=metadata;
    }


    /**
     * @param program1              The program to be executed on core 1.
     * @param program2              The program to be executed on core 2.
     * @param maxInstructionCount   The maximal number of instructions in the programs.
     * @param index                 The index of this test case.
     */
    public RISCVTestCase(Program program1, Program program2, int maxInstructionCount, int index) {
        super(program1, program2, maxInstructionCount, index);
    }

    /**
     * @param program1              The program to be executed on core 1.
     * @param program2              The program to be executed on core 2.
     * @param maxInstructionCount   The maximal number of instructions in the programs.
     * @param res                   A test result that would make the two programs distinguishable.
     * @param index                 The index of this test case.
     */
    public RISCVTestCase(Program program1, Program program2, int maxInstructionCount, TestResult res, int index) {
        super(program1, program2, maxInstructionCount, res, index);
    }
}
