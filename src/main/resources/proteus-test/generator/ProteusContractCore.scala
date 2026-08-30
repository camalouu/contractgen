package contractgen.proteus

import riscv._
import riscv.plugins._
import riscv.plugins.memory
import riscv.plugins.scheduling.static
import spinal.core._

/** Minimal deterministic Proteus configuration used by the contract harness. */
object ProteusContractCoreGenerator {
  final class ContractSignals extends Plugin[Pipeline] with FormalService {
    override def lsuDefault(stage: Stage): Unit = {}
    override def lsuOnLoad(stage: Stage, addr: UInt, rmask: Bits, rdata: UInt): Unit = {}
    override def lsuOnStore(stage: Stage, addr: UInt, wmask: Bits, wdata: UInt): Unit = {}
    override def lsuOnMisaligned(stage: Stage): Unit = {}

    override def build(): Unit = {
      pipeline plug new Area {
        val retire = out(Bool()).setName("retire")
        val rvfi_valid = out(Bool()).setName("rvfi_valid")
        val rvfi_order = out(UInt(64 bits)).setName("rvfi_order")
        val rvfi_insn = out(UInt(32 bits)).setName("rvfi_insn")
        val rvfi_trap = out(Bool()).setName("rvfi_trap")
        val order = Reg(UInt(64 bits)).init(0)
        val stage = pipeline.retirementStage

        retire := stage.arbitration.isDone
        rvfi_valid := retire
        rvfi_order := order
        rvfi_insn := stage.output(pipeline.data.IR)
        rvfi_trap := pipeline.service[TrapService].hasException(stage)
        when(retire) { order := order + 1 }
      }
    }
  }

  def core()(implicit conf: Config): Component with StaticPipeline = {
    val pipeline = new Component with StaticPipeline {
      setDefinitionName("ProteusContractCore")

      val fetch = new Stage("IF")
      val decode = new Stage("ID")
      val execute = new Stage("EX")
      val memoryStage = new Stage("MEM")
      val writeback = new Stage("WB")

      override val stages = Seq(fetch, decode, execute, memoryStage, writeback)
      override val passThroughStage: Stage = execute
      override val config: Config = conf
      override val data: StandardPipelineData = new StandardPipelineData(conf)
      override val pipelineComponent: Component = this
    }

    val backbone = new memory.StaticMemoryBackbone
    pipeline.addPlugins(Seq(
      new static.Scheduler,
      new static.DataHazardResolver(firstRsReadStage = pipeline.execute),
      backbone,
      new memory.Fetcher(pipeline.fetch),
      new Decoder(pipeline.decode),
      new RegisterFileAccessor(pipeline.decode, pipeline.writeback),
      new IntAlu(Set(pipeline.execute)),
      new Shifter(Set(pipeline.execute)),
      new Conditional(Set(pipeline.execute)),
      new ContractSignals,
      new memory.Lsu(Set(pipeline.memoryStage), Seq(pipeline.memoryStage), pipeline.memoryStage),
      new BranchUnit(Set(pipeline.execute)),
      new static.PcManager(0x80L),
      new NoPredictionPredictor(pipeline.fetch, pipeline.execute),
      new CsrFile(pipeline.writeback, pipeline.writeback),
      new MachineMode(pipeline.execute),
      new TrapHandler(pipeline.writeback),
      new TrapStageInvalidator,
      new MulDiv(Set(pipeline.execute))
    ))
    pipeline.build()
    pipeline
  }

  def main(args: Array[String]): Unit = {
    implicit val config: Config = new Config(BaseIsa.RV32I, debug = false, stlSpec = false) {
      override def memBusWidth: Int = 32
    }
    val target = args.headOption.getOrElse("generated")
    SpinalConfig(targetDirectory = target).generateVerilog(core())
  }
}
