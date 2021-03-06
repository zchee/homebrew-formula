class GitDelta < Formula
  desc "Syntax-highlighting pager for git and diff output"
  homepage "https://github.com/dandavison/delta"
  license "MIT"
  head "https://github.com/dandavison/delta.git"

  bottle :unneeded

  depends_on "rust" => :build
  uses_from_macos "llvm"

  conflicts_with "delta", because: "both install a `delta` binary"

  def install
    system "cargo", "update", "--aggressive"
    system "cargo", "install", *std_cargo_args, "--all-features"

    bash_completion.install "etc/completion/completion.bash"
    zsh_completion.install "etc/completion/completion.zsh" => "_delta"
  end

  test do
    assert_match "delta #{version}", `#{bin}/delta --version`.chomp
  end
end
