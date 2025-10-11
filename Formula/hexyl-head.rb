class HexylHead < Formula
  desc "A command-line hex viewer"
  homepage "https://github.com/sharkdp/hexyl"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/sharkdp/hexyl.git", branch: "master"

  env :std

  def install
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"

    # setup nightly cargo with rustup
    ENV.append_path "PATH", "#{root_dir}/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{root_dir}/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=#{target_cpu} -C opt-level=3 -C force-frame-pointers=on -C debug-assertions=off -C incremental=on -C overflow-checks=off"

    # avoid invalid data in index - calculated checksum does not match expected
    File.open("#{buildpath}/.git/info/exclude", "w") { |f| f.write ".brew_home/\n.DS_Store\n" }
    system "git", "config", "--local", "index.skipHash", "false"

    system "rustup", "run", "nightly", "cargo", "install", "--all-features", "--root", prefix, "--path", "."
  end

  test do
    touch "foo_file"
    touch "test_file"
    assert_equal "test_file", shell_output("#{bin}/fd test").chomp
  end
end
