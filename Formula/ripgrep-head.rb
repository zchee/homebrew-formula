class RipgrepHead < Formula
  desc "Search tool like grep and The Silver Searcher"
  homepage "https://github.com/BurntSushi/ripgrep"
  license "Unlicense"
  head "https://github.com/BurntSushi/ripgrep.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "asciidoctor" => :build
  depends_on "pkg-config" => :build
  depends_on "pcre2" => :build

  env :std

  def install
    ENV.append_path "PATH", "/usr/local/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "/usr/local/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native -C target-cpu=x86-64-v4 -C target-feature=+aes,+avx,+avx2,+avx512f,+avx512dq,+avx512cd,+avx512bw,+avx512vl"
    ENV["PCRE2_SYS_STATIC"] = "1"

    system "rustup", "run", "nightly", "cargo", "install", "--features", %q[pcre2 simd-accel], "--root", prefix, "--path", "."

    # Completion scripts and manpage are generated in the crate's build
    # directory, which includes a fingerprint hash. Try to locate it first
    out_dir = Dir["target/release/build/ripgrep-*/out"].first
    man1.install "#{out_dir}/rg.1"
    bash_completion.install "#{out_dir}/rg.bash"
    fish_completion.install "#{out_dir}/rg.fish"
    zsh_completion.install "complete/_rg"
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    system "#{bin}/rg", "Hello World!", testpath
  end
end