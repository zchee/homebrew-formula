class RipgrepHead < Formula
  desc "Search tool like grep and The Silver Searcher"
  homepage "https://github.com/BurntSushi/ripgrep"
  license "Unlicense"
  head "https://github.com/BurntSushi/ripgrep.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  env :std

  depends_on "asciidoctor" => :build
  depends_on "pkgconf" => :build
  depends_on "sccache" => :build
  depends_on "pcre2"

  def install
    # setup cargo with rustup
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : %x( sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }' )
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=#{target_cpu} -C opt-level=3 -C codegen-units=1 -C lto=fat -C panic=abort -C force-frame-pointers=on -C embed-bitcode=yes -Z dylib-lto -Z mir-opt-level=4 -Z inline-mir=yes -C llvm-args=-unroll-threshold=500 -C llvm-args=-enable-dfa-jump-thread -C link-arg=-Wl,-dead_strip"

    # setup sccache
    sccache_dir = "#{Etc.getpwuid.dir}/.cache/sccache"
    mkdir_p sccache_dir
    ENV["RUSTC_WRAPPER"] = "#{Formula["sccache"].opt_bin}/sccache"
    ENV["SCCACHE_DIR"] = sccache_dir

    ENV["PCRE2_SYS_STATIC"] = "1"

    system "rustup", "run", "nightly", "cargo", "install", "--verbose", *std_cargo_args(features: "pcre2")

    generate_completions_from_executable(bin/"rg", "--generate", base_name: "rg", shell_parameter_format: "complete-", shells: [:bash, :zsh, :fish])
    (man1/"rg.1").write Utils.safe_popen_read(bin/"rg", "--generate", "man")
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    system bin/"rg", "Hello World!", testpath
  end
end
