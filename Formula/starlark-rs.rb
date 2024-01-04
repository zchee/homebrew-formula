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
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"
    features = %w(pcre2)

    ENV.append_path "PATH", "#{ENV["HOMEBREW_PREFIX"]}/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{ENV["HOMEBREW_PREFIX"]}/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native"

    system "cargo", "build", "--release", "--all-features", "--bin", "starlark"
    bin.install "target/release/starlark"
    bin.install_symlink "starlark" => "starlark-rs"
  end
end
