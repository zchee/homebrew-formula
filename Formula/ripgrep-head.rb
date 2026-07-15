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

  # macOS: improve default explicit-file mmap searches
  patch do
    url "https://patch-diff.githubusercontent.com/raw/BurntSushi/ripgrep/pull/3340.patch?full_index=1"
    sha256 "ddd5954ad690692dee60e55a4b1a9df0a97b675b1d4045210bacebc722593bb7"
  end

  # fix: perf(ignore): don't search subdirs for git/ignore files if max depth is reached
  patch do
    url "https://patch-diff.githubusercontent.com/raw/BurntSushi/ripgrep/pull/3353.patch?full_index=1"
    sha256 "04b72a1e6591e63e6ca8568a7339d0dc3922415910174048a182962d2f2eaf64"
  end

  def install
    # setup cargo with rustup
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : %x( sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }' )
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=#{target_cpu} -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"

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
