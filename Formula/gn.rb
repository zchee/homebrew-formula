class Gn < Formula
  desc "GN is a meta-build system that generates build files for Ninja."
  homepage "https://gn.googlesource.com/gn"
  head "https://gn.googlesource.com/gn.git", branch: "main"

  depends_on "lld" => :build
  depends_on "llvm" => :build
  depends_on "ninja" => :build
  depends_on "python@3.14" => :build

  def install
    ENV["CXX"] = "#{Formula["llvm"].opt_bin}/clang++"
    ENV["AR"] = "#{Formula["llvm"].opt_bin}/llvm-ar"
    ENV["MACOSX_DEPLOYMENT_TARGET"] = `/usr/bin/sw_vers -productVersion`
    ENV.append "CFLAGS", "-I#{Formula["llvm"].opt_include} -D_LIBCPP_DISABLE_AVAILABILITY"
    ENV.append "LDFLAGS", "-L#{Formula["llvm"].opt_lib} -L#{Formula["llvm"].opt_lib}/c++ -L#{Formula["llvm"].opt_lib}/unwind -lunwind --ld-path=#{Formula["lld"].opt_bin}/ld64.lld"

    # llvm-project/llvm supported --icf=all flag
    inreplace "build/gen.py", /(if options.use_icf) and not platform.is_darwin\(\):/, "\\1:"

    args = %W[
      --platform=darwin 
      --host=darwin 
      --use-lto 
      --use-icf 
    ]
    system "#{Formula["python@3.14"].bin}/python3.14", "build/gen.py", *args
    system "#{Formula["ninja"].opt_prefix}/bin/ninja", "-v", "-C", "out", "gn"

    bin.install "out/gn" => "gn"
    lib.install "out/gn_lib.a" => "gn_lib.a"
  end
end
