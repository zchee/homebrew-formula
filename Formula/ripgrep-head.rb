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

    ENV.append_path "PATH", "#{ENV["HOMEBREW_PREFIX"]}/rust/rustup/bin"
    ENV["RUSTUP_HOME"] = "#{ENV["HOMEBREW_PREFIX"]}/rust/rustup"
    ENV["RUSTFLAGS"] = "-C target-cpu=native"
    ENV["PCRE2_SYS_STATIC"] = "1"

    system "rustup", "run", "nightly", "cargo", "build", "--release", "--features", "#{features.join(" ")}"
    bin.install "target/release/rg"

    generate_completions_from_executable(bin/"rg", "--generate", base_name: "rg", shell_parameter_format: "complete-")
    (man1/"rg.1").write Utils.safe_popen_read(bin/"rg", "--generate", "man")
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    system "#{bin}/rg", "Hello World!", testpath
  end
end
