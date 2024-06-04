class SigHead < Formula
  desc "Interactive grep (for streaming)"
  homepage "https://github.com/ynqa/sig"
  license ["MIT"]
  head "https://github.com/ynqa/sig.git", branch: "main"

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"

    # setup nightly cargo with rustup
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu}"

    # avoid invalid data in index - calculated checksum does not match expected
    # File.open("#{buildpath}/.git/info/exclude", "w") { |f| f.write ".brew_home/\n.DS_Store\n" }
    # system "git", "config", "--local", "index.skipHash", "false"

    ENV["SHELL_COMPLETIONS_DIR"] = buildpath

    system "rustup", "run", "nightly", "cargo", "install", "--all-features", "--root", prefix, "--path", "."

    # assets_dir = Dir["target/release/build/bat-*/out/assets"].first
    # man1.install "#{assets_dir}/manual/bat.1"
    # bash_completion.install "#{assets_dir}/completions/bat.bash" => "bat"
    # fish_completion.install "#{assets_dir}/completions/bat.fish"
    # zsh_completion.install "#{assets_dir}/completions/bat.zsh" => "_bat"
  end
end
