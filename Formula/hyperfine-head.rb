class HyperfineHead < Formula
  desc "Command-line benchmarking tool"
  homepage "https://github.com/sharkdp/hyperfine"
  license any_of: ["Apache-2.0", "MIT"]
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/sharkdp/hyperfine.git", branch: "master"

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"

    # setup nightly cargo with rustup
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu}"

    ENV["SHELL_COMPLETIONS_DIR"] = buildpath

    system "rustup", "run", "nightly", "cargo", "install", "--all-features", "--root", prefix, "--path", "."

    bash_completion.install "hyperfine.bash" => "hyperfine"
    fish_completion.install "hyperfine.fish"
    zsh_completion.install "_hyperfine"
    man1.install "doc/hyperfine.1"
  end

  test do
    output = shell_output("#{bin}/hyperfine 'sleep 0.3'")
    assert_match "Benchmark 1: sleep", output
  end
end
