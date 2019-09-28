class LlvmToolchain < Formula
  desc "Next-gen compiler infrastructure"
  homepage "https://llvm.org/"

  stable do
    url "https://releases.llvm.org/9.0.0/llvm-9.0.0.src.tar.xz"
    sha256 "d6a0565cf21f22e9b4353b2eb92622e8365000a9e90a16b09b56f8157eabfe84"

    resource "clang" do
      url "https://releases.llvm.org/9.0.0/cfe-9.0.0.src.tar.xz"
      sha256 "7ba81eef7c22ca5da688fdf9d88c20934d2d6b40bfe150ffd338900890aa4610"
    end

    resource "clang-extra-tools" do
      url "https://releases.llvm.org/9.0.0/clang-tools-extra-9.0.0.src.tar.xz"
      sha256 "ea1c86ce352992d7b6f6649bc622f6a2707b9f8b7153e9f9181a35c76aa3ac10"
    end

    resource "compiler-rt" do
      url "https://releases.llvm.org/9.0.0/compiler-rt-9.0.0.src.tar.xz"
      sha256 "56e4cd96dd1d8c346b07b4d6b255f976570c6f2389697347a6c3dcb9e820d10e"
    end

    resource "libcxx" do
      url "https://releases.llvm.org/9.0.0/libcxx-9.0.0.src.tar.xz"
      sha256 "3c4162972b5d3204ba47ac384aa456855a17b5e97422723d4758251acf1ed28c"
    end

    resource "libunwind" do
      url "https://releases.llvm.org/9.0.0/libunwind-9.0.0.src.tar.xz"
      sha256 "976a8d09e1424fb843210eecec00a506b956e6c31adda3b0d199e945be0d0db2"
    end

    resource "lld" do
      url "https://releases.llvm.org/9.0.0/lld-9.0.0.src.tar.xz"
      sha256 "31c6748b235d09723fb73fea0c816ed5a3fab0f96b66f8fbc546a0fcc8688f91"
    end

    resource "lldb" do
      url "https://releases.llvm.org/9.0.0/lldb-9.0.0.src.tar.xz"
      sha256 "1e4c2f6a1f153f4b8afa2470d2e99dab493034c1ba8b7ffbbd7600de016d0794"
    end

    resource "openmp" do
      url "https://releases.llvm.org/9.0.0/openmp-9.0.0.src.tar.xz"
      sha256 "9979eb1133066376cc0be29d1682bc0b0e7fb541075b391061679111ae4d3b5b"
    end

    resource "polly" do
      url "https://releases.llvm.org/9.0.0/polly-9.0.0.src.tar.xz"
      sha256 "a4fa92283de725399323d07f18995911158c1c5838703f37862db815f513d433"
    end
  end

  bottle do
    cellar :any
    sha256 "ebc1c9a3dc80510c48d8886fd77b74d25a4c16727e5e575557c1e1540b9f4fd7" => :mojave
    sha256 "05d5806f19f7e382f032f135bf21216f677f3912b3712adf379960673da7a110" => :high_sierra
    sha256 "2439c1fb7cce8c4eab2960ef02ef3f7046834ef9b44e855c758b5578257dbac1" => :sierra
  end

  # Clang cannot find system headers if Xcode CLT is not installed
  pour_bottle? do
    reason "The bottle needs the Xcode CLT to be installed."
    satisfy { MacOS::CLT.installed? }
  end

  head do
    url "https://git.llvm.org/git/llvm.git"

    resource "clang" do
      url "https://git.llvm.org/git/clang.git"
    end

    resource "clang-extra-tools" do
      url "https://git.llvm.org/git/clang-tools-extra.git"
    end

    resource "compiler-rt" do
      url "https://git.llvm.org/git/compiler-rt.git"
    end

    resource "libcxx" do
      url "https://git.llvm.org/git/libcxx.git"
    end

    resource "libunwind" do
      url "https://git.llvm.org/git/libunwind.git"
    end

    resource "lld" do
      url "https://git.llvm.org/git/lld.git"
    end

    resource "lldb" do
      url "https://git.llvm.org/git/lldb.git"
    end

    resource "openmp" do
      url "https://git.llvm.org/git/openmp.git"
    end

    resource "polly" do
      url "https://git.llvm.org/git/polly.git"
    end
  end

  keg_only :provided_by_macos

  # https://llvm.org/docs/GettingStarted.html#requirement
  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "sphinx-doc" => :build
  depends_on :xcode => :build
  depends_on "libffi"
  depends_on "swig"

  def install
    # Apple's libstdc++ is too old to build LLVM
    ENV.libcxx if ENV.compiler == :clang

    (buildpath/"tools/clang").install resource("clang")
    (buildpath/"tools/clang/tools/extra").install resource("clang-extra-tools")
    (buildpath/"projects/openmp").install resource("openmp")
    (buildpath/"projects/libcxx").install resource("libcxx")
    (buildpath/"projects/libunwind").install resource("libunwind")
    (buildpath/"tools/lld").install resource("lld")
    (buildpath/"tools/lldb").install resource("lldb")
    (buildpath/"tools/polly").install resource("polly")
    (buildpath/"projects/compiler-rt").install resource("compiler-rt")

    # compiler-rt has some iOS simulator features that require i386 symbols
    # I'm assuming the rest of clang needs support too for 32-bit compilation
    # to work correctly, but if not, perhaps universal binaries could be
    # limited to compiler-rt. llvm makes this somewhat easier because compiler-rt
    # can almost be treated as an entirely different build from llvm.
    ENV.permit_arch_flags

    args = %W[
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_OSX_ARCHITECTURES=#{`uname -m`.chomp}
      -DCMAKE_OSX_DEPLOYMENT_TARGET=#{`xcrun --sdk macosx --show-sdk-version`.chomp}
      -DCMAKE_OSX_SYSROOT=#{`xcrun --sdk macosx --show-sdk-path`.chomp}
      -DCLANG_DEFAULT_OBJCOPY=/usr/local/opt/binutils/x86_64-apple-darwin#{`uname -r`.chomp}/bin/objcopy
      -DCMAKE_OBJCOPY=/usr/local/opt/binutils/x86_64-apple-darwin#{`uname -r`.chomp}/bin/objcopy
      -DCMAKE_OBJDUMP=/usr/local/opt/binutils/x86_64-apple-darwin#{`uname -r`.chomp}/bin/objdump
      -DBUILD_SHARED_LIBS=OFF
      -DCLANG_ANALYZER_BUILD_Z3=OFF
      -DCLANG_INCLUDE_TESTS=FALSE
      -DCLANG_TOOLS_EXTRA_INCLUDE_DOCS=ON
      -DCOMPILER_RT_INCLUDE_TESTS=OFF
      -DLIBCLANG_BUILD_STATIC=ON
      -DLIBOMP_ARCH=x86_64
      -DLINK_POLLY_INTO_TOOLS=ON
      -DLLVM_BUILD_EXTERNAL_COMPILER_RT=ON
      -DLLVM_BUILD_LLVM_DYLIB=ON
      -DLLVM_ENABLE_EH=ON
      -DLLVM_ENABLE_FFI=ON
      -DLLVM_ENABLE_LIBCXX=ON
      -DLLVM_ENABLE_RTTI=ON
      -DLLVM_INCLUDE_DOCS=OFF
      -DLLVM_INCLUDE_EXAMPLES=OFF
      -DLLVM_INCLUDE_TESTS=OFF
      -DLLVM_INSTALL_UTILS=ON
      -DLLVM_LINK_LLVM_DYLIB=OFF
      -DLLVM_OPTIMIZED_TABLEGEN=ON
      -DLLVM_TARGETS_TO_BUILD=all
      -DLLVM_USE_SPLIT_DWARF=ON
      -DWITH_POLLY=ON
      -DFFI_INCLUDE_DIR=#{Formula["libffi"].opt_lib}/libffi-#{Formula["libffi"].version}/include
      -DFFI_LIBRARY_DIR=#{Formula["libffi"].opt_lib}
      -DLLVM_CREATE_XCODE_TOOLCHAIN=ON
      -DLLDB_USE_SYSTEM_DEBUGSERVER=ON
      -DLLDB_DISABLE_PYTHON=1
      -DLIBOMP_INSTALL_ALIASES=OFF
      -DSPHINX_EXECUTABLE=#{Formula["sphinx-doc"].bin}/sphinx-build
      -DSPHINX_OUTPUT_HTML=OFF
      -DSPHINX_OUTPUT_MAN=ON
      -DSPHINX_WARNINGS_AS_ERRORS=OFF
    ]

    mkdir "build" do
      system "cmake", "-G", "Ninja", "..", *(std_cmake_args + args)
      system "ninja"
      system "ninja", "install"
      system "ninja", "install-xcode-toolchain"
    end

    (share/"clang/tools").install Dir["tools/clang/tools/scan-{build,view}"]
    (share/"cmake").install "cmake/modules"
    inreplace "#{share}/clang/tools/scan-build/bin/scan-build", "$RealBin/bin/clang", "#{bin}/clang"
    bin.install_symlink share/"clang/tools/scan-build/bin/scan-build", share/"clang/tools/scan-view/bin/scan-view"
    man1.install_symlink share/"clang/tools/scan-build/man/scan-build.1"

    # install clang-extra-tools binaries
    bin.install_symlink buildpath/"bin/modularize"
    bin.install_symlink buildpath/"bin/clang-change-namespace"
    bin.install_symlink buildpath/"bin/clang-move"
    bin.install_symlink buildpath/"bin/clang-include-fixer"
    bin.install_symlink buildpath/"bin/pp-trace"
    bin.install_symlink buildpath/"bin/clang-reorder-fields"
    bin.install_symlink buildpath/"bin/clang-query"
    bin.install_symlink buildpath/"bin/clang-tidy"
    bin.install_symlink buildpath/"bin/clang-doc"
    bin.install_symlink buildpath/"bin/clang-apply-replacements"

    # install llvm python bindings
    (lib/"python2.7/site-packages").install buildpath/"bindings/python/llvm"
    (lib/"python2.7/site-packages").install buildpath/"tools/clang/bindings/python/clang"
  end

  def caveats; <<~EOS
    To use the bundled libc++ please add the following LDFLAGS:
      LDFLAGS="-L#{opt_lib} -Wl,-rpath,#{opt_lib}"
  EOS
  end

  test do
    assert_equal prefix.to_s, shell_output("#{bin}/llvm-config --prefix").chomp

    (testpath/"omptest.c").write <<~EOS
      #include <stdlib.h>
      #include <stdio.h>
      #include <omp.h>

      int main() {
          #pragma omp parallel num_threads(4)
          {
            printf("Hello from thread %d, nthreads %d\\n", omp_get_thread_num(), omp_get_num_threads());
          }
          return EXIT_SUCCESS;
      }
    EOS

    clean_version = version.to_s[/(\d+\.?)+/]

    system "#{bin}/clang", "-L#{lib}", "-fopenmp", "-nobuiltininc",
                           "-I#{lib}/clang/#{clean_version}/include",
                           "omptest.c", "-o", "omptest"
    testresult = shell_output("./omptest")

    sorted_testresult = testresult.split("\n").sort.join("\n")
    expected_result = <<~EOS
      Hello from thread 0, nthreads 4
      Hello from thread 1, nthreads 4
      Hello from thread 2, nthreads 4
      Hello from thread 3, nthreads 4
    EOS
    assert_equal expected_result.strip, sorted_testresult.strip

    (testpath/"test.c").write <<~EOS
      #include <stdio.h>

      int main()
      {
        printf("Hello World!\\n");
        return 0;
      }
    EOS

    (testpath/"test.cpp").write <<~EOS
      #include <iostream>

      int main()
      {
        std::cout << "Hello World!" << std::endl;
        return 0;
      }
    EOS

    # Testing Command Line Tools
    if MacOS::CLT.installed?
      libclangclt = Dir["/Library/Developer/CommandLineTools/usr/lib/clang/#{MacOS::CLT.version.to_i}*"].last { |f| File.directory? f }

      system "#{bin}/clang++", "-v", "-nostdinc",
              "-I/Library/Developer/CommandLineTools/usr/include/c++/v1",
              "-I#{libclangclt}/include",
              "-I/usr/include", # need it because /Library/.../usr/include/c++/v1/iosfwd refers to <wchar.h>, which CLT installs to /usr/include
              "test.cpp", "-o", "testCLT++"
      assert_includes MachO::Tools.dylibs("testCLT++"), "/usr/lib/libc++.1.dylib"
      assert_equal "Hello World!", shell_output("./testCLT++").chomp

      system "#{bin}/clang", "-v", "-nostdinc",
              "-I/usr/include", # this is where CLT installs stdio.h
              "test.c", "-o", "testCLT"
      assert_equal "Hello World!", shell_output("./testCLT").chomp
    end

    # Testing Xcode
    if MacOS::Xcode.installed?
      libclangxc = Dir["#{MacOS::Xcode.toolchain_path}/usr/lib/clang/#{DevelopmentTools.clang_version}*"].last { |f| File.directory? f }

      system "#{bin}/clang++", "-v", "-nostdinc",
              "-I#{MacOS::Xcode.toolchain_path}/usr/include/c++/v1",
              "-I#{libclangxc}/include",
              "-I#{MacOS.sdk_path}/usr/include",
              "test.cpp", "-o", "testXC++"
      assert_includes MachO::Tools.dylibs("testXC++"), "/usr/lib/libc++.1.dylib"
      assert_equal "Hello World!", shell_output("./testXC++").chomp

      system "#{bin}/clang", "-v", "-nostdinc",
              "-I#{MacOS.sdk_path}/usr/include",
              "test.c", "-o", "testXC"
      assert_equal "Hello World!", shell_output("./testXC").chomp
    end

    # link against installed libc++
    # related to https://github.com/Homebrew/legacy-homebrew/issues/47149
    system "#{bin}/clang++", "-v", "-nostdinc",
            "-std=c++11", "-stdlib=libc++",
            "-I#{MacOS::Xcode.toolchain_path}/usr/include/c++/v1",
            "-I#{libclangxc}/include",
            "-I#{MacOS.sdk_path}/usr/include",
            "-L#{lib}",
            "-Wl,-rpath,#{lib}", "test.cpp", "-o", "test"
    assert_includes MachO::Tools.dylibs("test"), "#{opt_lib}/libc++.1.dylib"
    assert_equal "Hello World!", shell_output("./test").chomp
  end
end
