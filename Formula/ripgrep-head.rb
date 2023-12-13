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
    root_dir = Hardware::CPU.intel? ? "/usr" : "/opt"
    target_cpu = Hardware::CPU.intel? ? "x86-64-v4" : "apple-latest"
    features = %w(pcre2)
    if Hardware::CPU::intel?
      features += %w(simd-accel)
    end

    ENV.append_path "PATH", "#{ENV["HOMEBREW_PREFIX"]}/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{ENV["HOMEBREW_PREFIX"]}/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native"
    ENV["PCRE2_SYS_STATIC"] = "1"

    system "rustup", "run", "nightly", "cargo", "install", "--features", "#{features.join(" ")}", "--root", prefix, "--path", "."

    # Completion scripts and manpage are generated in the crate's build
    # directory, which includes a fingerprint hash. Try to locate it first
    # out_dir = Dir["target/release/build/ripgrep-*/out"].first
    # man1.install "#{out_dir}/rg.1"
    # bash_completion.install "#{out_dir}/rg.bash"
    # fish_completion.install "#{out_dir}/rg.fish"
    # zsh_completion.install "complete/_rg"
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    system "#{bin}/rg", "Hello World!", testpath
  end
end
