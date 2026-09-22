{ pkgs }:
(pkgs.maven.override { jdk_headless = pkgs.jdk21_headless; }).buildMavenPackage {
  pname = "contractgen-java";
  version = "1.0-SNAPSHOT";
  src = pkgs.lib.fileset.toSource {
    root = ../.;
    fileset = pkgs.lib.fileset.unions [ ../pom.xml ../src/main/java ../src/test/java ];
  };
  mvnHash = "sha256-8X5h84M8AkFQL3Bm4Q+rklnJ6Se+/V7pbvLMUKfTU/w=";
  mvnParameters = "";
  installPhase = ''
    mkdir -p $out/share/java
    cp target/contractgen-*.jar $out/share/java/contractgen.jar
    cp -r target/lib $out/share/java/lib
  '';
}
