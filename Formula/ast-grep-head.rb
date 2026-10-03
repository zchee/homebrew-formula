class AstGrepHead < Formula
  desc "Code searching, linting, rewriting"
  homepage "https://github.com/ast-grep/ast-grep"
  license "MIT"
  head "https://github.com/ast-grep/ast-grep.git", branch: "main"

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    target_cpu = Hardware::CPU.intel? ? "native" : `sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }'`
    target_feature = Hardware::CPU.intel? ? "" : "+neon"
    rustflags = %W[
      -C target-cpu=#{target_cpu}
      -C target-feature=#{target_feature}
      -C opt-level=3
      -C codegen-units=1
      -C lto=thin
      -C panic=abort
      -C force-frame-pointers=on
      -C embed-bitcode=yes
      -Z dylib-lto
      -Z mir-opt-level=4
      -Z inline-mir=yes
      -C llvm-args=-unroll-threshold=500
      -C llvm-args=-enable-dfa-jump-thread
      -C link-arg=-Wl,-dead_strip
    ]
    ENV["RUSTFLAGS"] = rustflags.join(" ")

    system "rustup", "run", "nightly", "cargo", "install", "--verbose", "--all-features", "--jobs=16", "--locked", "--root=#{prefix}", "--path=crates/cli"

    generate_completions_from_executable(bin/"ast-grep", "completions")
  end

  test do
    (testpath/"hi.js").write("console.log('it is me')")
    system bin/"ast-grep", "run", "-l", "js", "-p console.log", (testpath/"hi.js
")

    assert_match version.to_s, shell_output("#{bin}/ast-grep --version")
  end
end
