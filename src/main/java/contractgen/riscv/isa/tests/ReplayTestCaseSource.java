package contractgen.riscv.isa.tests;

import com.google.gson.*;
import contractgen.TestCase;
import contractgen.riscv.isa.tests.imported.isa.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;

/** Replay transport and streaming import of rewrite JSON lines. */
public final class ReplayTestCaseSource implements TestCaseSource {
    private final List<TestCase> cases;
    private final int batchSize;
    private int cursor;
    public ReplayTestCaseSource(List<TestCase> cases,int batchSize) {
        if(batchSize<1) throw new IllegalArgumentException("Replay batch size must be positive");
        this.cases=cases;this.batchSize=batchSize;
    }
    public List<TestCase> nextBatch(Context context) {
        int end=Math.min(cases.size(),cursor+batchSize);
        var result=List.copyOf(cases.subList(cursor,end));cursor=end;return result;
    }
    public static List<TestCase> readLines(Path path) throws IOException {
        List<TestCase> result=new ArrayList<>();
        try(var reader=Files.newBufferedReader(path)) {
            String line;int n=0;
            while((line=reader.readLine())!=null) {
                n++;if(line.isBlank())continue;
                try {
                    var o=JsonParser.parseString(line).getAsJsonObject();
                    boolean legacy=!o.has("format");
                    if(!legacy&&!o.get("format").getAsString().equals("contract-synthesis/testcases/2")) throw new IllegalArgumentException("Unsupported testcase format");
                    var tc=new contractgen.riscv.isa.tests.imported.testcase.TestCase(o.get("id").getAsLong(),
                        program(o.getAsJsonObject("first"),legacy),program(o.getAsJsonObject("second"),legacy),Optional.empty());
                    result.add(ImportedTestCaseSource.lower(tc,Math.toIntExact(tc.id()),false));
                } catch(RuntimeException e) {throw new IllegalArgumentException("Invalid replay testcase at line "+n,e);}
            }
        }
        return result;
    }
    private static Program program(JsonObject o,boolean legacy) {
        SortedMap<Integer,Long> registers=new TreeMap<>();
        for(var e:o.getAsJsonObject("registers").entrySet()) {
            long v=e.getValue().getAsLong();
            if(legacy) {
                if(v<0||v>=4096) throw new IllegalArgumentException("Invalid 12-bit register value");
                v=Instruction.signExtend12(v)&0xffffffffL;
            }
            registers.put(Integer.parseInt(e.getKey()),v);
        }
        List<Instruction> instructions=new ArrayList<>();
        for(var e:o.getAsJsonArray("instructions")) {
            String hex=e.getAsString();
            if(!hex.matches("[0-9a-fA-F]{8}")) throw new IllegalArgumentException("Invalid instruction: "+hex);
            instructions.add(Instruction.decode(Long.toBinaryString(Long.parseLong(hex,16))).orElseThrow());
        }
        return new Program(registers,instructions);
    }
    public static String digest(Path path) throws IOException {
        try {
            var md=java.security.MessageDigest.getInstance("SHA-256");
            try(var input=Files.newInputStream(path)) {byte[] b=new byte[65536];int n;while((n=input.read(b))!=-1)md.update(b,0,n);}
            return HexFormat.of().formatHex(md.digest());
        } catch(java.security.NoSuchAlgorithmException e){throw new IllegalStateException(e);}
    }
}
