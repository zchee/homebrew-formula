class FdHead < Formula
  desc "Simple, fast and user-friendly alternative to find"
  homepage "https://github.com/sharkdp/fd"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/sharkdp/fd.git", branch: "master"

  env :std

  conflicts_with "fdclone", because: "both install `fd` binaries"

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

    inreplace "Cargo.toml", 'not(target_os = "macos"), ', ""
    ENV["JEMALLOC_SYS_WITH_LG_PAGE"] = "16" if Hardware::CPU.arm?
    system "rustup", "run", "nightly", "cargo", "install", *std_cargo_args(features: ["use-jemalloc", "completions"])

    generate_completions_from_executable(bin/"fd", "--gen-completions", shells: [:zsh, :fish], base_name: "fd")
    zsh_completion.install "contrib/completion/_fd"
    man1.install "doc/fd.1"
  end

  test do
    touch "foo_file"
    touch "test_file"
    assert_equal "test_file", shell_output("#{bin}/fd test").chomp
  end
end
