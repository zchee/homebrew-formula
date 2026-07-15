class FdHead < Formula
  desc "Simple, fast and user-friendly alternative to find"
  homepage "https://github.com/sharkdp/fd"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/sharkdp/fd.git", branch: "master"

  env :std

  depends_on "jemalloc-head" => :build
  depends_on "sccache" => :build

  conflicts_with "fdclone", because: "both install `fd` binaries"

  def install
    # setup cargo with rustup
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : `sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }'`.chomp
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=#{target_cpu} -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"

    # setup sccache
    sccache_dir = "#{Etc.getpwuid.dir}/.cache/sccache"
    mkdir_p sccache_dir
    ENV["RUSTC_WRAPPER"] = "#{formula_opt_bin("sccache")}/sccache"
    ENV["SCCACHE_DIR"] = sccache_dir

    inreplace "Cargo.toml", 'not(target_os = "macos"), ', ""
    system "cat", "Cargo.toml"
    ENV["JEMALLOC_SYS_WITH_LG_PAGE"] = "16" if Hardware::CPU.arm?
    system "rustup", "run", "nightly", "cargo", "install", "--features", "use-jemalloc,completions", *std_cargo_args

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
