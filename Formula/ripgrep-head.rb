class RipgrepHead < Formula
  desc "Search tool like grep and The Silver Searcher"
  homepage "https://github.com/BurntSushi/ripgrep"
  license "Unlicense"
  head "https://github.com/BurntSushi/ripgrep.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "asciidoctor" => :build
  depends_on "pkg-config" => :build
  depends_on "pcre2"

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"
    rust_flags = %W[
      -C target-cpu=native
      -C target-cpu=#{target_cpu}
      -C opt-level=3
      -C force-frame-pointers=on
      -C debug-assertions=off
      -C incremental=on
      -C overflow-checks=off
      -C panic=abort
      -C codegen-units=1
      -C embed-bitcode=yes
      -C strip=symbols
      -Z dylib-lto
      -Z location-detail=none
    ]
    if Hardware::CPU.intel?
      rust_flags << "-C target-feature=+aes,+avx,+avx2,+avx512f,+avx512dq,+avx512cd,+avx512bw,+avx512vl,+avx512vnni"
    end

    # setup nightly cargo with rustup
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "#{rust_flags}"

    ENV.append_path "PATH", "#{ENV["HOMEBREW_PREFIX"]}/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{ENV["HOMEBREW_PREFIX"]}/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native"
    ENV["PCRE2_SYS_STATIC"] = "1"

    system "rustup", "run", "nightly", "cargo", "install", "--features", "pcre2", *std_cargo_args
    bin.install "target/release/rg"

    generate_completions_from_executable(bin/"rg", "--generate", base_name: "rg", shell_parameter_format: "complete-")
    (man1/"rg.1").write Utils.safe_popen_read(bin/"rg", "--generate", "man")
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    system bin/"rg", "Hello World!", testpath
  end
end
