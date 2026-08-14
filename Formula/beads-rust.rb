class BeadsRust < Formula
  desc "Fast Rust port of gastownhall/beads"
  homepage "https://github.com/Dicklesworthstone/beads_rust"
  license "MIT"
  head "https://github.com/Dicklesworthstone/beads_rust.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

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
      -C lto=fat
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

    system "rustup", "run", "nightly", "cargo", "install", *std_cargo_args

    generate_completions_from_executable(bin/"br", "completions")
  end
end
