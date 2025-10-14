class ProtolsHead < Formula
  desc "Language Server for protocol buffers"
  homepage "https://github.com/coder3101/protols"
  license "MIT"
  head "https://github.com/coder3101/protols.git", branch: "main"

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"

    # setup nightly cargo with rustup
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu}"

    inreplace "rust-toolchain.toml", 'channel = "stable"', 'channel = "nightly"'

    system "rustup", "run", "nightly", "cargo", "install", "--all-features", "--root", prefix, "--path", "."

    # generate_completions_from_executable(bin/"fd", "--gen-completions", shells: [:bash, :fish], base_name: "fd")
    # zsh_completion.install "contrib/completion/_fd"
  end
end
