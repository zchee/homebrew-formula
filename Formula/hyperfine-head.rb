class HyperfineHead < Formula
  desc "Command-line benchmarking tool"
  homepage "https://github.com/sharkdp/hyperfine"
  head "https://github.com/sharkdp/hyperfine.git", branch: "master"
  license any_of: ["Apache-2.0", "MIT"]
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/sharkdp/hyperfine.git", branch: "master"

  env :std

  def install
    # setup nightly cargo with rustup
    ENV.append_path "PATH", "/usr/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "/usr/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=x86-64-v4 -C target-feature=+aes,+avx,+avx2,+avx512f,+avx512dq,+avx512cd,+avx512bw,+avx512vl"

    # avoid invalid data in index - calculated checksum does not match expected
    system "git", "config", "--local", "index.skipHash", "false"

    ENV["SHELL_COMPLETIONS_DIR"] = buildpath

    system "rustup", "run", "nightly", "cargo", "install", "--all-features", "--root", prefix, "--path", "."

    man1.install "doc/hyperfine.1"
    bash_completion.install "hyperfine.bash"
    fish_completion.install "hyperfine.fish"
    zsh_completion.install "_hyperfine"
  end

  test do
    output = shell_output("#{bin}/hyperfine 'sleep 0.3'")
    assert_match "Benchmark 1: sleep", output
  end
end
