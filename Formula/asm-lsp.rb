class AsmLsp < Formula
  desc "Language server for NASM/GAS/GO Assembly"
  homepage "https://github.com/bergercookie/asm-lsp"
  license any_of: ["BSD-2"]
  head "https://github.com/bergercookie/asm-lsp.git", branch: "master"

  env :std

  def install
    # setup nightly cargo with rustup
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu}"

    # avoid invalid data in index - calculated checksum does not match expected
    # File.open("#{buildpath}/.git/info/exclude", "w") { |f| f.write ".brew_home/\n.DS_Store\n" }
    # system "git", "config", "--local", "index.skipHash", "false"

    system "rustup", "run", "nightly", "cargo", "install", "--all-features", "--root", prefix, "--path", "asm-lsp"
  end
end
