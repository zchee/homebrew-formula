class FdHead < Formula
  desc "Simple, fast and user-friendly alternative to find"
  homepage "https://github.com/sharkdp/fd"
  license any_of: ["Apache-2.0", "MIT"]
  head "https://github.com/sharkdp/fd.git", branch: "master"

  env :std

  def install
    ENV.append_path "PATH", "/usr/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "/usr/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=x86-64-v4 -C target-feature=+aes,+avx,+avx2,+avx512f,+avx512dq,+avx512cd,+avx512bw,+avx512vl"

    # avoid invalid data in index - calculated checksum does not match expected
    File.open("#{buildpath}/.git/info/exclude", "w") { |f| f.write ".brew_home/\n.DS_Store\n" }
    system "git", "config", "--local", "index.skipHash", "false"

    system "rustup", "run", "nightly", "cargo", "install", "--all-features", "--root", prefix, "--path", "."

    man1.install "doc/fd.1"
    generate_completions_from_executable(bin/"fd", "--gen-completions", shells: [:bash, :fish], base_name: "fd")
    zsh_completion.install "contrib/completion/_fd"
  end

  test do
    touch "foo_file"
    touch "test_file"
    assert_equal "test_file", shell_output("#{bin}/fd test").chomp
  end
end
