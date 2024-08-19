class GitDeltaHead < Formula
  desc "Syntax-highlighting pager for git and diff output"
  homepage "https://github.com/dandavison/delta"
  license "MIT"
  head "https://github.com/dandavison/delta.git", :branch => "main"

  depends_on "rust" => :build
  depends_on "llvm" => :build
  depends_on "zlib" => :build

  conflicts_with "delta", because: "both install a `delta` binary"

  def install
    system "cargo", "install", *std_cargo_args, "--all-features"
    bin.install_symlink "delta" => "git-delta"

    zsh_completion.install "etc/completion/completion.zsh" => "_delta"
  end

  test do
    assert_match "delta #{version}", `#{bin}/delta --version`.chomp
  end
end
