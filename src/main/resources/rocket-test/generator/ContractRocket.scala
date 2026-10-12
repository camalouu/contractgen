// Wrapper for Rocket Chip 55bcad0f59436de98ea510334121de8546b9e9d7.
package contractrocket

import chisel3._
import chisel3.util._
import org.chipsalliance.cde.config._
import org.chipsalliance.diplomacy.lazymodule._
import org.chipsalliance.diplomacy.bundlebridge._
import freechips.rocketchip.diplomacy.{AddressSet, RegionType, TransferSizes}
import freechips.rocketchip.tile._
import freechips.rocketchip.rocket._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.interrupts._
import freechips.rocketchip.util._

class ContractRocketConfig extends Config(
  new Config((site, here, up) => {
    case freechips.rocketchip.devices.debug.DebugModuleKey => None
  }) ++ new BaseSubsystemConfig)

class ContractRocket(implicit p: Parameters) extends LazyModule with freechips.rocketchip.resources.BindingScope {
  val params = RocketTileParams(
    core = RocketCoreParams(xLen = 32, pgLevels = 2, useVM = false,
      useDebug = false, useAtomics = false, useCompressed = false,
      nBreakpoints = 0, fpu = None, haveCease = false, haveSimTimeout = false,
      mulDiv = Some(MulDivParams(mulUnroll = 8, mulEarlyOut = true, divEarlyOut = true))),
    icache = Some(ICacheParams(nSets = 64, nWays = 4, rowBits = 64, blockBytes = 64)),
    dcache = Some(DCacheParams(nSets = 64, nWays = 4, rowBits = 64, blockBytes = 64, nMSHRs = 0)),
    btb = Some(BTBParams()))
  val tile = LazyModule(new RocketTile(params, RocketCrossingParams(), HartsWontDeduplicate(params)))
  val memory = TLManagerNode(Seq(TLManagerPortParameters(
    managers = Seq(TLManagerParameters(
      address = Seq(AddressSet(0, BigInt("ffffffff", 16))),
      regionType = RegionType.TRACKED, executable = true,
      supportsGet = TransferSizes(1, 64), supportsPutFull = TransferSizes(1, 64),
      supportsPutPartial = TransferSizes(1, 64),
      supportsAcquireT = TransferSizes(64, 64), supportsAcquireB = TransferSizes(64, 64),
      fifoId = Some(0))), beatBytes = 8, endSinkId = 1, minLatency = 1)))
  memory := tile.masterNode
  val hart = BundleBridgeSource(() => UInt(1.W))
  val vector = BundleBridgeSource(() => UInt(32.W))
  tile.hartIdNode := hart
  tile.resetVectorNode := vector
  val interrupts = IntSourceNode(IntSourcePortSimple(num = 4))
  tile.intInwardNode := interrupts
  val halt = IntSinkNode(IntSinkPortSimple())
  val cease = IntSinkNode(IntSinkPortSimple())
  val wfi = IntSinkNode(IntSinkPortSimple())
  halt := tile.haltNode
  cease := tile.ceaseNode
  wfi := tile.wfiNode
  val trace = tile.traceNode.makeSink()

  lazy val module = new LazyModuleImp(this) {
    val tl = IO(chiselTypeOf(memory.in.head._1))
    tl <> memory.in.head._1
    hart.bundle := 0.U
    vector.bundle := "h80".U
    interrupts.out.foreach { case (irq, _) => irq := 0.U.asTypeOf(irq) }
    val retire_valid = IO(Output(Bool()))
    val retire_pc = IO(Output(UInt(32.W)))
    val exception = IO(Output(Bool()))
    retire_valid := trace.bundle.insns.head.valid
    retire_pc := trace.bundle.insns.head.iaddr
    exception := trace.bundle.insns.head.exception
    // Diagnostic writeback includes delayed mul/div writes; it is not an attacker signal.
    val writeback_valid = IO(Output(Bool()))
    val writeback_rd = IO(Output(UInt(5.W)))
    val writeback_data = IO(Output(UInt(32.W)))
    writeback_valid := chisel3.util.experimental.BoringUtils.bore(tile.module.core.rocketImpl.rf_wen)
    writeback_rd := chisel3.util.experimental.BoringUtils.bore(tile.module.core.rocketImpl.rf_waddr)
    writeback_data := chisel3.util.experimental.BoringUtils.bore(tile.module.core.rocketImpl.rf_wdata)
    // Source classification is derived from negotiated client identities, never addresses.
    val instruction_source = IO(Output(Bool()))
    val edge = memory.in.head._2
    val clients = edge.client.clients
    println("CONTRACT_ROCKET_PARAMS " + params.toString)
    clients.foreach(c => println(s"CONTRACT_ROCKET_CLIENT ${c.name} ${c.sourceId.start} ${c.sourceId.end}"))
    val iClients = clients.filter(_.name.toLowerCase.contains("icache"))
    require(iClients.nonEmpty, "No negotiated I-cache client")
    instruction_source := iClients.map(c => tl.a.bits.source >= c.sourceId.start.U && tl.a.bits.source < c.sourceId.end.U).reduce(_ || _)
  }
}
