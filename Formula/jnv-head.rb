class JnvHead < Formula
  desc "JSON navigator and interactive filter leveraging jq"
  homepage "https://github.com/ynqa/jnv"
  license ["MIT"]
  head "https://github.com/ynqa/jnv.git", branch: "main"

  env :std

  def install
    # setup cargo with rustup
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : %x( sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }' )
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu} -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"

    # setup sccache
    sccache_dir = "#{Etc.getpwuid.dir}/.cache/sccache"
    mkdir_p sccache_dir
    ENV["RUSTC_WRAPPER"] = "#{Formula["sccache"].opt_bin}/sccache"
    ENV["SCCACHE_DIR"] = sccache_dir

    ENV["SHELL_COMPLETIONS_DIR"] = buildpath

    system "rustup", "run", "nightly", "cargo", "install", "--all-features", "--root", prefix, "--path", "."
  end
end
