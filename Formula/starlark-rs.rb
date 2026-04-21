class StarlarkRs < Formula
  desc "LSP bindings for starlark"
  homepage "https://github.com/facebookexperimental/starlark-rust"
  license "Unlicense"
  head "https://github.com/facebookexperimental/starlark-rust.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : %x( sysctl -n machdep.cpu.brand_string | awk '{ print tolower($1"-"$2) }' )

    # setup nightly cargo with rustup
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu} -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"

    system "cargo", "build", "--release", "--all-features", "--bin", "starlark"
    bin.install "target/release/starlark" => "starlark-rs"
  end
end
