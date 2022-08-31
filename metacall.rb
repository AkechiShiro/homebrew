class Metacall < Formula
  desc "Ultimate polyglot programming experience"
  homepage "https://metacall.io"
  url "https://github.com/metacall/core/archive/refs/tags/v0.5.29.tar.gz"
  sha256 "6d2252f8d03ddfb8133544027ede7e81db31288e889ac7696d491667553f7464"
  license "Apache-2.0"
  head "https://github.com/metacall/core.git", branch: "develop"

  depends_on "cmake" => :build
  depends_on "node@14"
  depends_on "openjdk"
  depends_on "python@3.9"
  uses_from_macos "ruby"

  def install
    cmake_args = std_cmake_args + %W[
      -DOPTION_BUILD_SCRIPTS=OFF
      -DOPTION_FORK_SAFE=OFF
      -DOPTION_BUILD_TESTS=OFF
      -DOPTION_BUILD_EXAMPLES=OFF
      -DOPTION_BUILD_LOADERS_PY=ON
      -DOPTION_BUILD_LOADERS_NODE=ON
      -DNodeJS_INSTALL_PREFIX=#{buildpath}
      -DOPTION_BUILD_LOADERS_JAVA=ON
      -DOPTION_BUILD_LOADERS_JS=OFF
      -DOPTION_BUILD_LOADERS_C=OFF
      -DOPTION_BUILD_LOADERS_COB=OFF
      -DOPTION_BUILD_LOADERS_CS=OFF
      -DOPTION_BUILD_LOADERS_RB=ON
      -DOPTION_BUILD_LOADERS_TS=ON
      -DOPTION_BUILD_LOADERS_FILE=ON
      -DOPTION_BUILD_PORTS=ON
      -DOPTION_BUILD_PORTS_PY=ON
      -DOPTION_BUILD_PORTS_NODE=ON
    ]
    system "cmake", "-S", ".", "-B", "build", *cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    shebang = "\#!/usr/bin/env bash\n"
    # debug = "set -euxo pipefail\n"

    metacall_extra = [
      "LOC=#{prefix}\n",
      "LIB=#{lib}\n",
      "export LOADER_LIBRARY_PATH=\"$LIB\"\n",
      "export SERIAL_LIBRARY_PATH=\"$LIB\"\n",
      "export DETOUR_LIBRARY_PATH=\"$LIB\"\n",
      "export PORT_LIBRARY_PATH=\"$LIB\"\n",
      "export CONFIGURATION_PATH=\"$LOC/configurations/global.json\"\n",
    ]
    cmds = [shebang, *metacall_extra]
    cmds.append("export LOADER_SCRIPT_PATH=\"\${LOADER_SCRIPT_PATH:-\`pwd\`}\"\n")
    cmds.append("$LOC/metacallcli $@\n")

    File.open("metacall.sh", "w") do |f|
      f.write(*cmds)
    end

    chmod("u+x", "metacall.sh")
    bin.install "metacall.sh" => "metacall"
  end

  test do
    (testpath/"test.js").write <<~EOS
      console.log("Hello from NodeJS")
    EOS
    # TypeScript special test
    Dir.mkdir(testpath/"typescript")
    (testpath/"typescript/typedfunc.ts").write <<~EOS
      'use strict';
      export function typed_sum(left:number,right:number):number{return left+right}
      export async function typed_sum_async(left:number,right:number):Promise<number>{return left+right}
      export function build_name(first:string,last='Smith'){return`${first} ${last}`}
      export function object_pattern_ts({asd}){return asd}
      export function typed_array(a:number[]):number{return a[0]+a[1]+a[2]}
      export function object_record(a:Record<string, number>):number{return a.element}
    EOS
    (testpath/"testTypescript.sh").write <<~EOS
      #!/usr/bin/env bash
      cd typescript
      echo 'load ts typedfunc.ts\ninspect\ncall typed_sum(4, 5)\nexit' | #{bin}/metacall
    EOS
    chmod("u+x", testpath/"testTypescript.sh")
    (testpath/"test.py").write <<~EOS
      print("Hello from Python")
    EOS
    (testpath/"test.rb").write <<~EOS
      print("Hello from Ruby")
    EOS
    (testpath/"test.java").write <<~EOS
      public class HelloWorld{public static void main(String[]args)
      {System.err.println("Hello from Java!");System.out.println("Hello from Java!");
      System.out.println("Hello from Java!");System.out.println("Hello from Java!");}}
    EOS
    # Tests
    output_py = pipe_output("#{bin}/metacall test.py")

    assert_match "Hello from Python", output_py 
    refute_match(/error/, output_py)
    puts(output_py)
    
    output_rb = pipe_output("#{bin}/metacall test.rb")

    assert_match "Hello from Ruby", pipe_output("#{bin}/metacall test.rb")
    refute_match(/error/, output_rb)

    output_java = pipe_output("#{bin}/metacall test.java")

    refute_match(/error/, output_java)
    assert_match "Script (test.java) loaded correctly\n", output_java

    output_js = pipe_output("#{bin}/metacall test.js")

    refute_match(/error/, output_js)
    assert_match "Hello from NodeJS", output_js

    output_ts = pipe_output(testpath/"testTypescript.sh")

    refute_match(/error/, output_ts)
    assert_match "9.0", output_ts

  end
end
